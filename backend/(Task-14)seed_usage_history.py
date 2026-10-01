import calendar
import os
import sys
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

from billing import total_bill
from grideye_common import BYPASS_METER_IDS
from ml_engine import MLEngine

WRITE          = "--write" in sys.argv
BASE_DIR       = os.path.dirname(os.path.abspath(__file__))
KEY_PATH       = os.path.join(BASE_DIR, "serviceKey.json")

MODEL_LABEL    = "XGBoost_SGCC_v5"   
N_MONTHS       = 3
DAYS_PER_MONTH = 30                 

# ── Firestore ──────────────────────────────────────────────────────
if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(KEY_PATH))
db = firestore.client()

meter_ids = sorted(d.id for d in db.collection("meters").stream())
if not meter_ids:
    sys.exit("meters collection khali hai — pehle register_meters.py chalao.")

engine = MLEngine(BASE_DIR, bypass_meter_ids=BYPASS_METER_IDS)


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


months    = last_full_months(N_MONTHS)
theft_ids = BYPASS_METER_IDS & set(meter_ids)

print(f"\nMode: {'WRITE' if WRITE else 'DRY RUN (kuch nahi likha jayega)'}")
print(f"Meters: {len(meter_ids)} | Months: {[f'{calendar.month_abbr[m]} {y}' for y, m in months]}")
print(f"Theft-scenario meters: {sorted(theft_ids)}\n")

for meter_id in meter_ids:
    baseline = engine.profile_for(meter_id)     
    daily    = baseline[engine.day_pos]         

    docs = []
    for i, (y, m) in enumerate(months):
        end   = len(daily) - DAYS_PER_MONTH * (N_MONTHS - 1 - i)
        units = round(float(daily[max(0, end - DAYS_PER_MONTH):end].sum()), 1)

        pred = engine.classify(baseline, revealed_days=end)

        docs.append((f"{calendar.month_abbr[m]}_{y}", {
            "amount":     int(total_bill(units)),
            "confidence": int(pred.confidence),
            "isPaid":     bool(i < N_MONTHS - 1),  
            "label":      f"{calendar.month_name[m]} {y}",
            "ml_model":   MODEL_LABEL,
            "month":      calendar.month_abbr[m],
            "theft_risk": "High" if pred.status == "Theft" else "Low",
            "timestamp":  datetime(y, m, 1, tzinfo=timezone.utc),
            "units":      float(units),
        }))

    print(meter_id)
    for doc_id, d in docs:
        print(f"   {doc_id:<9} {d['units']:>7.1f} kWh  Rs.{d['amount']:<6} "
              f"{d['theft_risk']:<4} ({d['confidence']}%)  paid={d['isPaid']}")

    if WRITE:
        hist  = db.collection("meters").document(meter_id).collection("usage_history")
        batch = db.batch()
        for old in hist.stream():          
            batch.delete(old.reference)
        for doc_id, d in docs:
            batch.set(hist.document(doc_id), d)
        batch.commit()

print("\n✅ Done." if WRITE else "\nDry run complete. Theek lage to: python seed_usage_history.py --write")