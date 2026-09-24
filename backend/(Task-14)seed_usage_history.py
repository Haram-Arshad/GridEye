import os
import sys
import calendar
from datetime import datetime, timezone

import numpy as np
import pandas as pd
import joblib
import firebase_admin
from firebase_admin import credentials, firestore

from billing import total_bill

WRITE          = "--write" in sys.argv
BASE_DIR       = os.path.dirname(os.path.abspath(__file__))
KEY_PATH       = os.path.join(BASE_DIR, "serviceKey.json")
MODEL_PATH     = os.path.join(BASE_DIR, "incremental_model_v5_xgb.pkl")
SCALER_PATH    = os.path.join(BASE_DIR, "scaler_v5_xgb.pkl")
CSV_PATH       = os.path.join(BASE_DIR, "held_out_test_v5_xgb.csv")

MODEL_LABEL    = "XGBoost_SGCC_v5"   
N_MONTHS       = 3
DAYS_PER_MONTH = 30                  
THEFT_METER_IDS = {"CON-SKR-001", "CON-QTA-001"}   
NOISE_LEVEL    = 0.05                
rng            = np.random.default_rng(42)

# ── model + held-out data (simulator jaisa hi setup) ───────────────
model  = joblib.load(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)

df = pd.read_csv(CSV_PATH).select_dtypes(include=[np.number])
nan_cells = int(df.isna().sum().sum())
if nan_cells:
    print(f"⚠️  held-out CSV mein {nan_cells} NaN cells hain — fillna(0) lag raha hai "
          f"(simulator bhi yehi karta hai). Report mein imputation wala claim check karo.")
df = df.fillna(0)

X_all        = df.drop(columns=["FLAG"]).values
y_all        = df["FLAG"].values
FEATURE_COLS = list(df.drop(columns=["FLAG"]).columns)
ENGINEERED   = ["Mean_Consumption", "Peak_Usage", "Min_Usage", "Std_Consumption",
                "Usage_Range", "Zero_Day_Count", "Missing_Day_Count"]
FEAT_POS     = {c: FEATURE_COLS.index(c) for c in ENGINEERED if c in FEATURE_COLS}
DAY_POS      = np.array([i for i, c in enumerate(FEATURE_COLS) if c not in ENGINEERED])

NORMAL_PROFILES = X_all[y_all == 0]
THEFT_PROFILES  = X_all[y_all == 1]


def recompute_features(profile: np.ndarray) -> np.ndarray:
    days = profile[DAY_POS]
    vals = {
        "Mean_Consumption":  days.mean(),
        "Peak_Usage":        days.max(),
        "Min_Usage":         days.min(),
        "Std_Consumption":   days.std(),
        "Usage_Range":       days.max() - days.min(),
        "Zero_Day_Count":    float((days == 0).sum()),
        "Missing_Day_Count": 0.0,
    }
    for name, pos in FEAT_POS.items():
        profile[pos] = vals[name]
    return profile


def noisy_copy(profile: np.ndarray) -> np.ndarray:
    p = profile.astype(float).copy()
    noise = rng.normal(0, NOISE_LEVEL, size=len(DAY_POS))
    p[DAY_POS] = np.clip(p[DAY_POS] * (1 + noise), 0, None)
    return recompute_features(p)


def predict(profile: np.ndarray):
    x     = scaler.transform(pd.DataFrame([profile], columns=FEATURE_COLS))
    pred  = int(model.predict(x)[0])
    proba = model.predict_proba(x)[0]
    return pred, int(round(float(max(proba)) * 100))


def pick_profile(pool, want: str):
    for _ in range(300):
        p = pool[rng.integers(len(pool))].astype(float)
        pred, _ = predict(p)
        if (pred == 1) == (want == "Theft"):
            return p
    return pool[rng.integers(len(pool))].astype(float)


def last_full_months(n: int):
    now = datetime.now(timezone.utc)
    y, m = now.year, now.month
    out = []
    for _ in range(n):
        m -= 1
        if m == 0:
            y, m = y - 1, 12
        out.append((y, m))
    return out[::-1]


# ── Firestore ──────────────────────────────────────────────────────
if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(KEY_PATH))
db = firestore.client()

meter_ids = sorted(d.id for d in db.collection("meters").stream())
if not meter_ids:
    sys.exit("meters collection khali hai — pehle simulator chalao.")

theft_ids = THEFT_METER_IDS & set(meter_ids)
months = last_full_months(N_MONTHS)

print(f"\nMode: {'WRITE' if WRITE else 'DRY RUN (kuch nahi likha jayega)'}")
print(f"Meters: {len(meter_ids)} | Months: {[f'{calendar.month_abbr[m]} {y}' for y, m in months]}")
print(f"Theft-scenario meters: {sorted(theft_ids)}\n")

for meter_id in meter_ids:
    is_theft = meter_id in theft_ids
    profile  = pick_profile(THEFT_PROFILES if is_theft else NORMAL_PROFILES,
                            "Theft" if is_theft else "Normal")
    daily   = profile[DAY_POS]          

    docs = []
    for i, (y, m) in enumerate(months):
        end   = len(daily) - DAYS_PER_MONTH * (N_MONTHS - 1 - i)
        units = round(float(daily[end - DAYS_PER_MONTH:end].sum()), 1)
        pred, conf = predict(noisy_copy(profile))
        docs.append((f"{calendar.month_abbr[m]}_{y}", {
            "amount":     int(total_bill(units)),
            "confidence": int(conf),
            "isPaid":     bool(i < N_MONTHS - 1),   # sab se naya mahina unpaid
            "label":      f"{calendar.month_name[m]} {y}",
            "ml_model":   MODEL_LABEL,
            "month":      calendar.month_abbr[m],
            "theft_risk": "High" if pred == 1 else "Low",
            "timestamp":  datetime(y, m, 1, tzinfo=timezone.utc),
            "units":      float(units),
        }))

    print(meter_id)
    for doc_id, d in docs:
        print(f"   {doc_id:<9} {d['units']:>7.1f} kWh  Rs.{d['amount']:<6} "
              f"{d['theft_risk']:<4} ({d['confidence']}%)  paid={d['isPaid']}")

    if WRITE:
        hist = db.collection("meters").document(meter_id).collection("usage_history")
        batch = db.batch()
        for old in hist.stream():         
            batch.delete(old.reference)
        for doc_id, d in docs:
            batch.set(hist.document(doc_id), d)
        batch.commit()

print("\n✅ Done." if WRITE else "\nDry run complete.")