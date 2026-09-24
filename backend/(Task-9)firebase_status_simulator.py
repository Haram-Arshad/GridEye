import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
import joblib
import random
import time
from datetime import datetime, timedelta, timezone
import os
import json
import ssl
import paho.mqtt.client as mqtt
import shap
from billing import total_bill

# ── FIREBASE CONNECTION ────────────────────────────────
KEY_PATH = os.path.join(os.path.dirname(__file__), 'serviceKey.json')
if not firebase_admin._apps:
    cred = credentials.Certificate(KEY_PATH)
    firebase_admin.initialize_app(cred)
db = firestore.client()
print("✅ GridEye ML Simulator Connected!\n")

MQTT_BROKER   = os.environ.get("MQTT_BROKER")
MQTT_PORT     = int(os.environ.get("MQTT_PORT", "8883"))     # TLS port
MQTT_USERNAME = os.environ.get("MQTT_USERNAME")
MQTT_PASSWORD = os.environ.get("MQTT_PASSWORD")

try:                                  
    mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1,
                              client_id="grideye-simulator", protocol=mqtt.MQTTv311)
except AttributeError:                 
    mqtt_client = mqtt.Client(client_id="grideye-simulator", protocol=mqtt.MQTTv311)


def _on_mqtt_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ GridEye MQTT Publisher Connected!\n")
    else:
        print(f"⚠️  MQTT connect failed, rc={rc}")


mqtt_client.on_connect = _on_mqtt_connect

MQTT_ENABLED = False
if MQTT_BROKER and MQTT_USERNAME and MQTT_PASSWORD:
    try:
        mqtt_client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        mqtt_client.tls_set()         
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
        mqtt_client.loop_start()       
        MQTT_ENABLED = True
    except Exception as e:
        print(f"⚠️  MQTT unavailable, continuing without it: {e}")
else:
    print("ℹ️  MQTT credentials not set (env vars) — running Firestore-only.")


def publish_mqtt(topic: str, payload: dict):
    
    if not MQTT_ENABLED:
        return
    try:
        safe_payload = {
            k: (v.isoformat() if isinstance(v, datetime) else v)
            for k, v in payload.items()
        }
        mqtt_client.publish(topic, json.dumps(safe_payload), qos=1)
    except Exception as e:
        print(f"  [MQTT] ✗ publish failed on {topic}: {e}")


# ── PATHS ──────────────────────────────────────────────
BASE_DIR    = os.path.dirname(os.path.abspath(__file__))

# ── UPDATED: ab v5 XGBoost model + scaler use ho rahe hain ──
MODEL_PATH  = os.path.join(BASE_DIR, "incremental_model_v5_xgb.pkl")
SCALER_PATH = os.path.join(BASE_DIR, "scaler_v5_xgb.pkl")

CSV_PATH = os.path.join(BASE_DIR, "held_out_test_v5_xgb.csv")

# ── LOAD ML MODEL + DATASET ────────────────────────────
print("📦 Loading ML Model + Held-Out Dataset...")
model  = joblib.load(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)

df    = pd.read_csv(CSV_PATH)
df    = df.select_dtypes(include=[np.number]).fillna(0)
X_all = df.drop(columns=["FLAG"]).values
y_all = df["FLAG"].values

ENGINEERED    = ["Mean_Consumption", "Peak_Usage", "Min_Usage", "Std_Consumption",
                 "Usage_Range", "Zero_Day_Count", "Missing_Day_Count"]
FEATURE_COLS  = list(df.drop(columns=["FLAG"]).columns)
FEAT_POS      = {c: FEATURE_COLS.index(c) for c in ENGINEERED if c in FEATURE_COLS}
DAY_POS       = np.array([i for i, c in enumerate(FEATURE_COLS) if c not in ENGINEERED])

# ── (NEW) SHAP explainability setup ────────────────────
SHAP_EXPLAINER = shap.TreeExplainer(model)
print("✅ SHAP explainer ready (TreeExplainer on XGBoost)\n")

# Split held-out by label
NORMAL_PROFILES = X_all[y_all == 0]
THEFT_PROFILES  = X_all[y_all == 1]

print(f"✅ Held-out profiles loaded (genuinely unseen)")
print(f"   Normal profiles : {len(NORMAL_PROFILES)}")
print(f"   Theft  profiles : {len(THEFT_PROFILES)}\n")

# ── CONFIG ─────────────────────────────────────────────
INTERVAL_SECONDS            = 7
SECONDS_PER_HOUR            = 3600.0
HEALTH_CHECK_INTERVAL_SECONDS = 300
_last_health_check: dict[str, datetime] = {}

# ── CITY ZONES ─────────────────────────────────────────
CITY_ZONES = {
    "Karachi":    {"prefix": "MTR-KHI",
                   "area": "Gulshan-e-Iqbal, Karachi",
                   "lat": (24.80, 25.00), "lng": (66.98, 67.18)},
    "Lahore":     {"prefix": "MTR-LHR",
                   "area": "Model Town, Lahore",
                   "lat": (31.45, 31.60), "lng": (74.25, 74.40)},
    "Islamabad":  {"prefix": "MTR-ISB",
                   "area": "F-10 Sector, Islamabad",
                   "lat": (33.60, 33.72), "lng": (72.95, 73.10)},
    "Faisalabad": {"prefix": "MTR-FSD",
                   "area": "Peoples Colony, Faisalabad",
                   "lat": (31.35, 31.48), "lng": (73.05, 73.15)},
    "Multan":     {"prefix": "MTR-MUL",
                   "area": "Shah Rukn-e-Alam, Multan",
                   "lat": (30.15, 30.25), "lng": (71.40, 71.55)},
    "Peshawar":   {"prefix": "MTR-PSH",
                   "area": "Hayatabad, Peshawar",
                   "lat": (33.95, 34.05), "lng": (71.50, 71.65)},
    "Quetta":     {"prefix": "MTR-QTA",
                   "area": "Satellite Town, Quetta",
                   "lat": (30.10, 30.25), "lng": (66.90, 67.10)},
    "Sialkot":    {"prefix": "MTR-SKT",
                   "area": "Cantt Area, Sialkot",
                   "lat": (32.45, 32.55), "lng": (74.45, 74.60)},
    "Gujranwala": {"prefix": "MTR-GWL",
                   "area": "Trust Colony, Gujranwala",
                   "lat": (32.10, 32.25), "lng": (74.15, 74.30)},
    "Hyderabad":  {"prefix": "MTR-HYD",
                   "area": "Latifabad, Hyderabad",
                   "lat": (25.35, 25.45), "lng": (68.30, 68.45)},
    "Bahawalpur": {"prefix": "MTR-BWP",
                   "area": "Model Town, Bahawalpur",
                   "lat": (29.35, 29.45), "lng": (71.60, 71.75)},
    "Sukkur":     {"prefix": "MTR-SKR",
                   "area": "Rohri Road, Sukkur",
                   "lat": (27.65, 27.75), "lng": (68.82, 68.95)},
}

LOG_CONTENT = {
    "Normal": {
        "titles": ["Routine Health Check", "Grid Stability Verified",
                   "Periodic Monitor Pass", "System Scan Complete",
                   "Voltage Level Confirmed"],
        "descs":  ["All parameters within normal range.",
                   "No anomalies detected this cycle.",
                   "Voltage and load stable.",
                   "Meter responsive. Grid connected.",
                   "Load within safe operating limits."],
    },
    "Theft": {
        "titles": ["Load Anomaly Detected", "Power Bypass Detected",
                   "Unauthorized Tap Warning", "Meter Tampering Suspected",
                   "Consumption Irregularity"],
        "descs":  ["Illegal tap detected. Field team notified.",
                   "Load below expected. Possible bypass.",
                   "Data inconsistent. Theft protocol initiated.",
                   "Sharp unit drop. Tampering suspected.",
                   "Consumption gap exceeds threshold."],
    },
    "Fault": {
        "titles": ["Hardware Fault Detected", "Signal Loss Detected",
                   "Sensor Malfunction Alert", "Meter Offline Warning",
                   "Power Feed Disruption"],
        "descs":  ["Inconsistent data. Hardware check needed.",
                   "Signal lost. Connectivity issue suspected.",
                   "Abnormal readings. Component failure likely.",
                   "Voltage flatlined. Blown fuse suspected.",
                   "Meter failed to respond. Fault logged."],
    },
}

CONSUMER_METERS = [
    {"meterId": "CON-KHI-001", "city": "Karachi",
     "area": "Gulshan-e-Iqbal, Karachi", "lat": 24.921, "lng": 67.092},
    {"meterId": "CON-LHR-001", "city": "Lahore",
     "area": "Model Town, Lahore", "lat": 31.521, "lng": 74.329},
    {"meterId": "CON-ISB-001", "city": "Islamabad",
     "area": "F-10 Sector, Islamabad", "lat": 33.668, "lng": 73.032},
    {"meterId": "CON-FSD-001", "city": "Faisalabad",
     "area": "Peoples Colony, Faisalabad", "lat": 31.412, "lng": 73.111},
    {"meterId": "CON-MUL-001", "city": "Multan",
     "area": "Shah Rukn-e-Alam, Multan", "lat": 30.201, "lng": 71.478},
    {"meterId": "CON-PSH-001", "city": "Peshawar",
     "area": "Hayatabad, Peshawar", "lat": 33.998, "lng": 71.572},
    {"meterId": "CON-QTA-001", "city": "Quetta",
     "area": "Satellite Town, Quetta", "lat": 30.182, "lng": 67.002},
    {"meterId": "CON-SKT-001", "city": "Sialkot",
     "area": "Cantt Area, Sialkot", "lat": 32.501, "lng": 74.521},
    {"meterId": "CON-GWL-001", "city": "Gujranwala",
     "area": "Trust Colony, Gujranwala", "lat": 32.178, "lng": 74.221},
    {"meterId": "CON-HYD-001", "city": "Hyderabad",
     "area": "Latifabad, Hyderabad", "lat": 25.401, "lng": 68.372},
    {"meterId": "CON-BWP-001", "city": "Bahawalpur",
     "area": "Model Town, Bahawalpur", "lat": 29.401, "lng": 71.681},
    {"meterId": "CON-SKR-001", "city": "Sukkur",
     "area": "Rohri Road, Sukkur", "lat": 27.701, "lng": 68.872},
]

meter_counter = 1


# ── ✅ OPTION B: SYNTHETIC PROFILE GENERATOR ───────────
def recompute_features(profile: np.ndarray) -> np.ndarray:
    """Task-6 wali feature engineering, ek profile par (raw days se 7 features)."""
    if not FEAT_POS:
        return profile
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


def generate_synthetic_profile(base_profile: np.ndarray,
                                noise_level: float = 0.05) -> np.ndarray:
    
    synthetic = base_profile.astype(float).copy()
    noise = np.random.normal(0, noise_level, size=len(DAY_POS))
    synthetic[DAY_POS] = np.clip(synthetic[DAY_POS] * (1 + noise), 0, None)
    return recompute_features(synthetic)


# ── (NEW) SHAP EXPLANATION HELPER ──────────────────────
def get_shap_explanation(scaled_profile, top_n: int = 3) -> list:
    
    try:
        shap_values = SHAP_EXPLAINER.shap_values(scaled_profile)
        values = shap_values[0]
        contributions = list(zip(FEATURE_COLS, values))
        contributions.sort(key=lambda pair: abs(pair[1]), reverse=True)
        return [
            {"feature": f, "impact": round(float(v), 4)}
            for f, v in contributions[:top_n]
        ]
    except Exception as e:
        print(f"  [SHAP] ✗ explanation failed: {e}")
        return []


# ── ML PREDICTION ──────────────────────────────────────
def ml_predict_status(load_val: float) -> tuple:
    
    
    if load_val == 0.0:
        title = random.choice(LOG_CONTENT["Fault"]["titles"])
        desc  = random.choice(LOG_CONTENT["Fault"]["descs"])
        return "Fault", title, desc, random.randint(90, 99), []

    # Behavior-based pool selection
    use_theft_profile = load_val < 2.0
    base_pool = THEFT_PROFILES if use_theft_profile else NORMAL_PROFILES

    # ✅ Pick base profile + add synthetic noise
    base_profile      = random.choice(base_pool)
    synthetic_profile = generate_synthetic_profile(base_profile)

    # ML inference on synthetic profile
    scaled        = scaler.transform(pd.DataFrame([synthetic_profile], columns=FEATURE_COLS))
    prediction    = model.predict(scaled)[0]
    probabilities = model.predict_proba(scaled)[0]
    confidence    = int(round(max(probabilities) * 100))

    # (NEW) SHAP explanation for this specific prediction
    explanation = get_shap_explanation(scaled)

    status = "Theft" if prediction == 1 else "Normal"
    title  = random.choice(LOG_CONTENT[status]["titles"])
    desc   = random.choice(LOG_CONTENT[status]["descs"])

    return status, title, desc, confidence, explanation

THEFT_METER_IDS = {"CON-SKR-001", "CON-QTA-001"}  
                                                   

def _model_label(profile) -> str:
    scaled = scaler.transform(pd.DataFrame([profile], columns=FEATURE_COLS))
    return "Theft" if model.predict(scaled)[0] == 1 else "Normal"


def _pick_profile(pool, want: str):
    """Pool mein se woh profile chuno jise model `want` (Normal/Theft) kahe."""
    for _ in range(300):
        p = random.choice(pool).astype(float)
        if _model_label(p) == want:
            return p
    return random.choice(pool).astype(float)


METER_PROFILE = {
    m["meterId"]: (_pick_profile(THEFT_PROFILES, "Theft")
                   if m["meterId"] in THEFT_METER_IDS
                   else _pick_profile(NORMAL_PROFILES, "Normal"))
    for m in CONSUMER_METERS
}
print(f"✅ Consumer meter profiles assigned | Theft-scenario meters: {sorted(THEFT_METER_IDS)}\n")


def predict_meter_profile(meter_id: str) -> tuple:
    """Meter ke apne FIXED profile par (chhote noise ke saath) XGBoost chalata hai."""
    synthetic = generate_synthetic_profile(METER_PROFILE[meter_id])
    scaled    = scaler.transform(pd.DataFrame([synthetic], columns=FEATURE_COLS))
    pred      = model.predict(scaled)[0]
    conf      = int(round(max(model.predict_proba(scaled)[0]) * 100))
    return ("Theft" if pred == 1 else "Normal"), conf


# ── PUSH METERLOGS ──────────────────────────────────────
def push_meter_log_with_ml(m_id, load_float, status,
                            title, desc, ts,
                            is_critical, confidence,
                            explanation=None):
    explanation = explanation or []
    db.collection("MeterLogs").add({
        "meterId":       m_id,
        "loadValue":     float(load_float),
        "status":        status,
        "title":         title,
        "desc":          desc,
        "isCritical":    bool(is_critical),
        "ml_confidence": int(confidence),
        "explanation":   explanation,
        "time":          ts,
    })

    publish_mqtt(f"grideye/{m_id}/logs", {
        "meterId":       m_id,
        "loadValue":     float(load_float),
        "status":        status,
        "title":         title,
        "desc":          desc,
        "isCritical":    bool(is_critical),
        "ml_confidence": int(confidence),
        "explanation":   explanation,
        "time":          ts,
    })


# ── CONSUMER METERS SYNC ───────────────────────────────
def sync_consumer_meter(now: datetime):
    for meter in CONSUMER_METERS:
        try:
            c_id = meter["meterId"]
            hour = now.astimezone().hour

            if 7 <= hour <= 10 or 18 <= hour <= 23:
                c_load = round(random.uniform(4.0, 9.5), 3)
            elif 0 <= hour <= 5:
                c_load = round(random.uniform(0.5, 2.5), 3)
            else:
                c_load = round(random.uniform(2.0, 5.5), 3)

            # Theft meter: bypass ki wajah se recorded load kam
            if c_id in THEFT_METER_IDS:
                c_load = round(c_load * 0.3, 3)

            if random.random() < 0.005:
                c_load = 0.0

            if c_load == 0.0:
                c_status, c_conf = "Fault", random.randint(90, 99)
            else:
                c_status, c_conf = predict_meter_profile(c_id)

            meter_ref  = db.collection("meters").document(c_id)
            meter_snap = meter_ref.get()
            existing   = float(
                meter_snap.to_dict().get("units", 50.0)
            ) if meter_snap.exists else round(random.uniform(40, 120), 3)

            delta     = round(c_load * (INTERVAL_SECONDS / SECONDS_PER_HOUR), 4)
            new_units = round(existing + delta, 4)
            bill_est  = total_bill(new_units)

            consumer_payload = {
                "meterId":       c_id,
                "currentLoad":   float(c_load),
                "units":         new_units,
                "billEst":       bill_est,
                "status":        c_status,
                "ml_confidence": c_conf,
                "area":          meter["area"],
                "city":          meter["city"],
                "lat":           float(meter["lat"]),
                "lng":           float(meter["lng"]),
                "timestamp":     now,
            }

            meter_ref.set(consumer_payload, merge=True)

            publish_mqtt(f"grideye/consumer/{c_id}", consumer_payload)

            print(f"  [meters] ✔️ {c_id} | "
                  f"{c_status:<6} (ML:{c_conf}%) | "
                  f"{c_load}kW | units={new_units} | "
                  f"bill=Rs.{bill_est}")

        except Exception as e:
            print(f"  [meters] ✗ {meter['meterId']}: {e}")


# ── GENERATE ADMIN METER ────────────────────────────────
def generate_meter():
    global meter_counter
    city_name = random.choice(list(CITY_ZONES.keys()))
    city      = CITY_ZONES[city_name]
    lat = round(random.uniform(city["lat"][0], city["lat"][1]), 6)
    lng = round(random.uniform(city["lng"][0], city["lng"][1]), 6)
    meter_id = f"{city['prefix']}-{meter_counter:03d}"
    meter_counter += 1
    return meter_id, lat, lng, city_name, city["area"]


# ── MAIN UPLOAD ────────────────────────────────────────
def upload_to_firebase(reading):
    try:
        m_id  = reading["meterId"]
        lat   = reading["lat"]
        lng   = reading["lng"]
        city  = reading["city"]
        area  = reading["area"]
        
        now   = datetime.now(timezone.utc)

        raw_load = round(random.uniform(5.5, 30.0), 2)
        roll = random.random()
        if roll < 0.15:
            raw_load = 0.0
        elif roll < 0.35:
            raw_load = round(raw_load * 0.2, 2)

        status, real_title, real_desc, confidence, explanation = \
            ml_predict_status(raw_load)

        # 1. MeterReadings
        reading_payload = {
            "currentLoad": str(raw_load),
            "meterId":     m_id,
            "status":      status,
            "lat":         lat,
            "lng":         lng,
            "timestamp":   now,
        }
        db.collection("MeterReadings").add(reading_payload)

        publish_mqtt(f"grideye/{m_id}/readings", reading_payload)

        print(f"  [MeterReadings] ✔️ {m_id} | {city} | "
              f"{status} | ML:{confidence}%")

        # 2. Consumer sync
        sync_consumer_meter(now)

        # 3. MeterLogs
        if status in ("Theft", "Fault"):
            
            pre_ts = now - timedelta(minutes=random.randint(2, 6), seconds=random.randint(0, 59))
            push_meter_log_with_ml(
                m_id, raw_load, "Normal",
                "Pre-Detection Baseline",
                "Last stable reading before anomaly detected.",
                pre_ts, False, 0,
            )
            push_meter_log_with_ml(
                m_id, raw_load, status,
                real_title, real_desc,
                now, is_critical=(status == "Theft"),
                confidence=confidence,
                explanation=explanation,
            )
            print(f"  [MeterLogs] ✔️ {status} | ML:{confidence}%")

            # 4. Alert
            is_read = False if status == "Theft" else True
            alert_payload = {
                "address":     area,
                "description": real_desc,
                "isRead":      is_read,
                "meterId":     m_id,
                "status":      status,
                "lat":         lat,
                "lng":         lng,
                "time":        now,
                "title":       real_title,
                "type":        "Warning",
                "explanation": explanation,
            }
            db.collection("Alerts").add(alert_payload)

            # (NEW) mirror the alert over MQTT
            publish_mqtt(f"grideye/{m_id}/alerts", alert_payload)

            print(f"  [Alerts] ✔️ {status} | isRead={is_read}")

        else:
            last_check = _last_health_check.get(m_id)
            elapsed    = (
                (now - last_check).total_seconds()
                if last_check
                else HEALTH_CHECK_INTERVAL_SECONDS + 1
            )
            if elapsed >= HEALTH_CHECK_INTERVAL_SECONDS:
                _last_health_check[m_id] = now
                push_meter_log_with_ml(
                    m_id, raw_load, "Normal",
                    random.choice(LOG_CONTENT["Normal"]["titles"]),
                    random.choice(LOG_CONTENT["Normal"]["descs"]),
                    now, False, confidence,
                    explanation=explanation,
                )
                print(f"  [MeterLogs] ✔️ Health check | ML:{confidence}%")
            else:
                remaining = int(HEALTH_CHECK_INTERVAL_SECONDS - elapsed)
                print(f"  [MeterLogs] ─ Next check in {remaining}s")

    except Exception as e:
        print(f"[X] Error: {e}")


# ── RUN ────────────────────────────────────────────────
def run_simulator():
    print("\n" + "=" * 65)
    print("  GRIDEYE — ML SIMULATOR (Option B: Synthetic Noise)")
    print("  Dataset  : held_out_test_v5_xgb.csv (genuinely unseen)")
    print("  Approach : Gaussian noise (σ=5%) → infinite unique profiles")
    print("  MeterLog : Anomaly=immediate | Normal=5-min interval")
    print("  Telemetry: mirrored to MQTT broker on grideye/# topics")
    print("  Explain  : SHAP top-3 feature contributions per prediction")
    print("=" * 65 + "\n")

    cycle = 1
    try:
        while True:
            print(f"\n{'─'*65}")
            print(f"  Cycle #{cycle} — "
                  f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'─'*65}")

            meter_id, lat, lng, city, area = generate_meter()
            upload_to_firebase({
                "meterId": meter_id,
                "lat": lat, "lng": lng,
                "city": city, "area": area,
            })

            print(f"\n  ⏱️  Next in {INTERVAL_SECONDS}s...")
            time.sleep(INTERVAL_SECONDS)
            cycle += 1

    except KeyboardInterrupt:
        print(f"\n[STOPPED] Total cycles: {cycle-1}")
        if MQTT_ENABLED:
            mqtt_client.loop_stop()
            mqtt_client.disconnect()


if __name__ == "__main__":
    run_simulator()