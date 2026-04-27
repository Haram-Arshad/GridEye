import firebase_admin
from firebase_admin import credentials, firestore
import random
import time
from datetime import datetime, timedelta
import os
import uuid

# ── FIREBASE CONNECTION ────────────────────────────────────────────────────────
KEY_PATH = os.path.join(os.path.dirname(__file__), 'serviceKey.json')
cred = credentials.Certificate(KEY_PATH)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()
print(">>> SUCCESS: GridEye Pakistan Fixed-Zone Simulator Connected!")

# ── CONFIGURATION ──────────────────────────────────────────────────────────────
INTERVAL_SECONDS   = 7
BILL_RATE_PER_UNIT = 35     # PKR — billEst = int(units * 35)

# ── 12-CITY BOUNDING BOXES ────────────────────────────────────────────────────
CITY_ZONES = {
    "Karachi": {
        "prefix": "MTR-KHI",
        "area":   "Gulshan-e-Iqbal, Karachi",
        "lat":    (24.80, 25.00),
        "lng":    (66.98, 67.18),
    },
    "Lahore": {
        "prefix": "MTR-LHR",
        "area":   "Model Town, Lahore",
        "lat":    (31.45, 31.60),
        "lng":    (74.25, 74.40),
    },
    "Islamabad": {
        "prefix": "MTR-ISB",
        "area":   "F-10 Sector, Islamabad",
        "lat":    (33.60, 33.72),
        "lng":    (72.95, 73.10),
    },
    "Faisalabad": {
        "prefix": "MTR-FSD",
        "area":   "Peoples Colony, Faisalabad",
        "lat":    (31.35, 31.48),
        "lng":    (73.05, 73.15),
    },
    "Multan": {
        "prefix": "MTR-MUL",
        "area":   "Shah Rukn-e-Alam, Multan",
        "lat":    (30.15, 30.25),
        "lng":    (71.40, 71.55),
    },
    "Peshawar": {
        "prefix": "MTR-PSH",
        "area":   "Hayatabad, Peshawar",
        "lat":    (33.95, 34.05),
        "lng":    (71.50, 71.65),
    },
    "Quetta": {
        "prefix": "MTR-QTA",
        "area":   "Satellite Town, Quetta",
        "lat":    (30.10, 30.25),
        "lng":    (66.90, 67.10),
    },
    "Sialkot": {
        "prefix": "MTR-SKT",
        "area":   "Cantt Area, Sialkot",
        "lat":    (32.45, 32.55),
        "lng":    (74.45, 74.60),
    },
    "Gujranwala": {
        "prefix": "MTR-GWL",
        "area":   "Trust Colony, Gujranwala",
        "lat":    (32.10, 32.25),
        "lng":    (74.15, 74.30),
    },
    "Hyderabad": {
        "prefix": "MTR-HYD",
        "area":   "Latifabad, Hyderabad",
        "lat":    (25.35, 25.45),
        "lng":    (68.30, 68.45),
    },
    "Bahawalpur": {
        "prefix": "MTR-BWP",
        "area":   "Model Town, Bahawalpur",
        "lat":    (29.35, 29.45),
        "lng":    (71.60, 71.75),
    },
    "Sukkur": {
        "prefix": "MTR-SKR",
        "area":   "Rohri Road, Sukkur",
        "lat":    (27.65, 27.75),
        "lng":    (68.82, 68.95),
    },
}

# ── DYNAMIC CONTENT POOLS — STRICTLY UNDER 7 WORDS ───────────────────────────
LOG_CONTENT = {
    "Normal": {
        "titles": [
            "System Health Check",
            "Routine Scan Complete",
            "Grid Stability Verified",
            "Load Balance Confirmed",
            "Voltage Level Normal",
            "Diagnostics Passed",
            "Periodic Monitor Pass",
        ],
        "descs": [
            "Voltage within range. No action needed.",
            "Stable connection. All parameters healthy.",
            "No anomalies detected this cycle.",
            "Load within safe operating limits.",
            "Sensor readings consistent and verified.",
            "Meter link active and responsive.",
            "Normal consumption. Grid is stable.",
        ],
    },
    "Theft": {
        "titles": [
            "Security Alert",
            "Load Anomaly Detected",
            "Power Bypass Detected",
            "Unauthorized Tap Warning",
            "Meter Tampering Suspected",
            "Illegal Connection Flagged",
            "Consumption Irregularity",
        ],
        "descs": [
            "Unusual pattern found. Inspection advised.",
            "Illegal tap detected. Field team notified.",
            "Load below expected. Possible bypass.",
            "Data inconsistent. Theft protocol initiated.",
            "Sharp unit drop. Tampering suspected.",
            "Diversion matches known theft signatures.",
            "Consumption gap exceeds threshold.",
        ],
    },
    "Fault": {
        "titles": [
            "Technical Issue Reported",
            "Hardware Fault Detected",
            "Signal Loss Detected",
            "Sensor Malfunction Alert",
            "Communication Error",
            "Meter Offline Warning",
            "Power Feed Disruption",
        ],
        "descs": [
            "Inconsistent data. Hardware check needed.",
            "Meter needs physical inspection.",
            "Signal lost. Connectivity issue suspected.",
            "Abnormal readings. Component failure likely.",
            "Meter failed to respond. Fault logged.",
            "Voltage flatlined. Blown fuse suspected.",
            "Meter in safe-mode. Repeated failures.",
        ],
    },
}

# Pre-check pool for normal log slots (all under 7 words)
PRE_CHECK_POOL = [
    ("Pre-Cycle Baseline Recorded",  "Meter active before main evaluation."),
    ("Meter Online Confirmed",        "Meter responding at cycle start."),
    ("Initial Handshake Verified",    "Handshake confirmed. Starting diagnostics."),
    ("Cycle Start Health Check",      "Initial load snapshot recorded."),
    ("Connection Established",        "Meter communication verified."),
    ("Startup Diagnostic Passed",     "Startup checks passed. Monitoring active."),
    ("Meter Ready for Evaluation",    "Heartbeat confirmed. Baseline logged."),
    ("Mid-Cycle Verification",        "Secondary scan. Meter still online."),
    ("Secondary Scan Initiated",      "Load cross-checked with grid supply."),
    ("Signal Strength Verified",      "Signal stable before final push."),
]

# ── METER COUNTER ──────────────────────────────────────────────────────────────
meter_counter = 1


# ── HELPERS ───────────────────────────────────────────────────────────────────
def generate_meter():
    """
    Brand-new unique meterId every cycle.
    lat/lng sampled from the chosen city's tight bounding box.
    """
    global meter_counter
    city_name = random.choice(list(CITY_ZONES.keys()))
    city      = CITY_ZONES[city_name]

    lat = round(random.uniform(city["lat"][0], city["lat"][1]), 6)
    lng = round(random.uniform(city["lng"][0], city["lng"][1]), 6)

    meter_id = f"{city['prefix']}-{meter_counter:03d}"
    meter_counter += 1

    return meter_id, float(lat), float(lng), city_name, city["area"]


def simulate_reading():
    """Compose a full reading payload for one simulation cycle."""
    meter_id, lat, lng, city_name, area = generate_meter()

    status = random.choices(
        ["Normal", "Theft", "Fault"],
        weights=[0.65, 0.20, 0.15],
        k=1
    )[0]

    load_val = round(random.uniform(5.5, 30.0), 2)
    if status == "Theft":
        load_val = round(load_val * 0.2, 2)
    elif status == "Fault":
        load_val = 0.0

    return {
        "currentLoad": str(load_val),   # String  — MeterReadings field
        "loadFloat":   float(load_val), # Double  — MeterLogs / meters field
        "meterId":     meter_id,
        "status":      status,
        "lat":         lat,             # Double
        "lng":         lng,             # Double
        "city":        city_name,
        "area":        area,
    }


def get_log_content(status):
    """Pick independent random title + desc from the pool for a given status."""
    pool = LOG_CONTENT[status]
    return random.choice(pool["titles"]), random.choice(pool["descs"])


def push_meter_log(m_id, load_float, status, title, desc, timestamp):
    """Write one document to MeterLogs via .add() — always a new document."""
    db.collection("MeterLogs").add({
        "meterId":    m_id,                     # String — same ID always
        "loadValue":  float(load_float),         # Double
        "status":     status,                    # String
        "title":      title,                     # String
        "desc":       desc,                      # String
        "isCritical": bool(status == "Theft"),   # True ONLY for Theft
        "time":       timestamp,                 # Timestamp
    })


def resolve_is_read(status):
    """
    Theft  → random.choice([True, False])
    Fault  → Always True (silent technical log, no badge)
    """
    if status == "Theft":
        return random.choice([True, False])
    return True  # Fault


# ── CONSUMER PORTAL — FIXED METER POOL ───────────────────────────────────────
# These 12 fixed IDs (one per city) are dedicated to the consumer portal.
# They are NEVER used for MeterReadings / admin map — zero collision.
# Being fixed means every cycle revisits the same docs → units truly grow.
CONSUMER_METERS = [
    {"meterId": "CON-KHI-001", "city": "Karachi",     "area": "Gulshan-e-Iqbal, Karachi",   "lat": 24.921, "lng": 67.092},
    {"meterId": "CON-LHR-001", "city": "Lahore",      "area": "Model Town, Lahore",          "lat": 31.521, "lng": 74.329},
    {"meterId": "CON-ISB-001", "city": "Islamabad",   "area": "F-10 Sector, Islamabad",      "lat": 33.668, "lng": 73.032},
    {"meterId": "CON-FSD-001", "city": "Faisalabad",  "area": "Peoples Colony, Faisalabad",  "lat": 31.412, "lng": 73.111},
    {"meterId": "CON-MUL-001", "city": "Multan",      "area": "Shah Rukn-e-Alam, Multan",    "lat": 30.201, "lng": 71.478},
    {"meterId": "CON-PSH-001", "city": "Peshawar",    "area": "Hayatabad, Peshawar",         "lat": 33.998, "lng": 71.572},
    {"meterId": "CON-QTA-001", "city": "Quetta",      "area": "Satellite Town, Quetta",      "lat": 30.182, "lng": 67.002},
    {"meterId": "CON-SKT-001", "city": "Sialkot",     "area": "Cantt Area, Sialkot",         "lat": 32.501, "lng": 74.521},
    {"meterId": "CON-GWL-001", "city": "Gujranwala",  "area": "Trust Colony, Gujranwala",    "lat": 32.178, "lng": 74.221},
    {"meterId": "CON-HYD-001", "city": "Hyderabad",   "area": "Latifabad, Hyderabad",        "lat": 25.401, "lng": 68.372},
    {"meterId": "CON-BWP-001", "city": "Bahawalpur",  "area": "Model Town, Bahawalpur",      "lat": 29.401, "lng": 71.681},
    {"meterId": "CON-SKR-001", "city": "Sukkur",      "area": "Rohri Road, Sukkur",          "lat": 27.701, "lng": 68.872},
]

# How many kWh 1 unit represents in our simulation.
# Real formula: units_consumed = (load_kW × hours_elapsed)
# At 7s interval → hours_elapsed = 7/3600 ≈ 0.001944 hr
# So each cycle: Δunits = currentLoad × (INTERVAL_SECONDS / 3600)
SECONDS_PER_HOUR = 3600.0


def sync_consumer_meter(now):
    """
    Update ALL 12 fixed consumer meters every cycle.

    Real-world model
    ────────────────
    • currentLoad  → randomised per meter per cycle (kW), status-aware
    • Δunits       → currentLoad × (INTERVAL_SECONDS / 3600)   [kWh physics]
    • units        → previous units + Δunits                   [cumulative]
    • billEst      → int(units × BILL_RATE_PER_UNIT)           [PKR integer]

    All three fields are derived from each other — fully synchronized.
    Status logic mirrors admin side so consumer UI cards reflect real states.
    """
    for meter in CONSUMER_METERS:
        try:
            c_id  = meter["meterId"]
            city  = meter["city"]
            area  = meter["area"]
            lat   = meter["lat"]
            lng   = meter["lng"]

            # ── Determine status for this meter this cycle ─────────────────
            c_status = random.choices(
                ["Normal", "Theft", "Fault"],
                weights=[0.70, 0.18, 0.12],
                k=1
            )[0]

            # ── Simulate realistic currentLoad (kW) ────────────────────────
            if c_status == "Fault":
                c_load = 0.0                                    # outage
            elif c_status == "Theft":
                c_load = round(random.uniform(0.3, 1.5), 3)    # abnormally low
            else:
                # Time-of-day aware: peak hours (7-10am, 6-11pm) → higher load
                hour = now.hour
                if 7 <= hour <= 10 or 18 <= hour <= 23:
                    c_load = round(random.uniform(4.0, 9.5), 3)  # peak
                elif 0 <= hour <= 5:
                    c_load = round(random.uniform(0.5, 2.5), 3)  # night low
                else:
                    c_load = round(random.uniform(2.0, 5.5), 3)  # day normal

            # ── Fetch existing units from Firestore ────────────────────────
            meter_ref  = db.collection("meters").document(c_id)
            meter_snap = meter_ref.get()

            if meter_snap.exists:
                existing_units = float(meter_snap.to_dict().get("units", 50.0))
            else:
                # First-ever write — seed with a realistic starting value
                # (random so each meter starts at a different point on the bill)
                existing_units = round(random.uniform(40.0, 120.0), 3)

            # ── Physics-based unit increment ───────────────────────────────
            # Δunits = kW × hours  →  kWh consumed this interval
            delta_units = round(c_load * (INTERVAL_SECONDS / SECONDS_PER_HOUR), 4)
            new_units   = round(existing_units + delta_units, 4)   # Float

            # ── Bill estimate — always derived from units ──────────────────
            bill_est = int(new_units * BILL_RATE_PER_UNIT)          # Integer PKR

            # ── Write to Firestore ─────────────────────────────────────────
            meter_ref.set({
                "meterId":     c_id,
                "currentLoad": float(c_load),    # Float kW — live draw
                "units":       new_units,         # Float kWh — cumulative
                "billEst":     bill_est,           # Integer PKR — always in sync
                "status":      c_status,
                "area":        area,
                "city":        city,
                "lat":         float(lat),
                "lng":         float(lng),
                "timestamp":   now,
            }, merge=True)

            print(f"  [meters]        ✔ {c_id} | {c_status:<6} "
                  f"| load={c_load}kW | +{delta_units}kWh "
                  f"| units={new_units} | bill=Rs.{bill_est}")

        except Exception as e:
            print(f"  [meters]        ✗ {meter['meterId']} error: {e}")


def upload_to_firebase(reading):
    try:
        m_id       = reading["meterId"]
        status     = reading["status"]
        load_float = reading["loadFloat"]
        lat        = reading["lat"]
        lng        = reading["lng"]
        city       = reading["city"]
        area       = reading["area"]
        now        = datetime.now()

        # ── 1. METER READINGS (.add() — 1 new doc = 1 new map pin) ────────
        db.collection("MeterReadings").add({
            "currentLoad": reading["currentLoad"],  # String
            "meterId":     m_id,
            "status":      status,
            "lat":         lat,                     # Double
            "lng":         lng,                     # Double
            "timestamp":   now,
        })
        print(f"  [MeterReadings] ✔ Added  → {m_id} | {city} | {status} "
              f"| lat={lat}, lng={lng}")

        # ── 2. CONSUMER PORTAL — all 12 fixed meters updated every cycle ─
        sync_consumer_meter(now)

        # ── 3. METER LOGS — 3 to 7 docs, same meterId, 2s apart ──────────
        #
        # total_logs   = random 3–7
        # normal_count = total_logs - 1  (Normal system checks)
        # final log    = real detected status
        # timestamp    = now + (index * 2 seconds)  ← strictly sequential
        total_logs   = random.randint(3, 7)
        normal_count = total_logs - 1

        pre_sample = random.sample(
            PRE_CHECK_POOL, k=min(normal_count, len(PRE_CHECK_POOL))
        )

        for idx in range(normal_count):
            t_title, t_desc = pre_sample[idx % len(pre_sample)]
            ts = now + timedelta(seconds=idx * 2)
            push_meter_log(m_id, load_float, "Normal", t_title, t_desc, ts)
            print(f"  [MeterLogs]     ✔ Log {idx + 1}/{total_logs} "
                  f"→ Normal  | \"{t_title}\" [{ts.strftime('%H:%M:%S')}]")

        # Final log — real status
        real_title, real_desc = get_log_content(status)
        final_ts = now + timedelta(seconds=normal_count * 2)
        push_meter_log(m_id, load_float, status, real_title, real_desc, final_ts)
        print(f"  [MeterLogs]     ✔ Log {total_logs}/{total_logs} "
              f"→ {status:<6} | \"{real_title}\" [{final_ts.strftime('%H:%M:%S')}]")

        # ── 4. ALERTS — THEFT & FAULT ONLY ────────────────────────────────
        if status in ("Theft", "Fault"):
            is_read   = resolve_is_read(status)
            badge_lbl = "🔴 NEW (badge ON)" if not is_read else "✅ Seen (badge OFF)"

            db.collection("Alerts").add({
                "address":     area,
                "description": real_desc,
                "isRead":      is_read,
                "meterId":     m_id,
                "status":      status,
                "lat":         lat,         # Double
                "lng":         lng,         # Double
                "time":        now,
                "title":       real_title,
                "type":        "Warning",
            })
            print(f"  [Alerts]        ✔ Pushed → {status} | isRead={is_read} | {badge_lbl}")
        else:
            print(f"  [Alerts]        ─ Skipped (Normal — no alert needed)")

    except Exception as e:
        print(f"[X] Firebase Error: {e}")


def run_simulator():
    print("\n" + "=" * 68)
    print("   GRIDEYE — 12-CITY ZONES  |  LIVE CONSUMER PORTAL SYNC")
    print("   Cities: Karachi | Lahore | Islamabad | Faisalabad | Multan")
    print("           Peshawar | Quetta | Sialkot | Gujranwala | Hyderabad")
    print("           Bahawalpur | Sukkur")
    print("   Admin  → MeterReadings .add()  1 doc = 1 map pin (exact match)")
    print("   Admin  → MeterLogs     3–7 docs, same meterId, 2s apart")
    print("   Consumer → 12 fixed CON-*** meters, physics-based unit growth")
    print("   Consumer → Δunits = load × (7s / 3600)  |  billEst = int(units × 35)")
    print("   Consumer → time-of-day load | peak 4-9.5kW | night 0.5-2.5kW")
    print("=" * 68 + "\n")

    cycle = 1
    try:
        while True:
            print(f"\n{'─' * 68}")
            print(f"  Cycle #{cycle}  —  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'─' * 68}")

            reading = simulate_reading()
            upload_to_firebase(reading)

            print(f"\n  ⏱  Next cycle in {INTERVAL_SECONDS} seconds...")
            time.sleep(INTERVAL_SECONDS)
            cycle += 1

    except KeyboardInterrupt:
        print(f"\n\n[STOPPED] Simulator shut down. Total cycles: {cycle - 1}")


if __name__ == "__main__":
    run_simulator()