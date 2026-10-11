# GridEye 👁️
### Dual-Stage AI for Electricity Theft & Fault Detection

**FYP | IISAT University, Gujranwala**

---

## About

GridEye is a real-time smart grid monitoring system that uses AI to automatically distinguish electricity theft from technical faults, reducing false accusations and recovering lost revenue for utility providers. It pairs a Dual-Stage Diagnostic Engine (streaming Z-Score anomaly detection + XGBoost classification, with SHAP explainability) with a live Virtual AMI pipeline and a dual-portal Flutter app (Admin + Consumer).

## Key Features

- **Dual-Stage AI:** Z-Score Anomaly Detection + XGBoost Classification
- **86.18% Testing Accuracy** | 1.89% Train/Test Gap
- **Real-time Firebase Dashboard** (Admin + Consumer)
- **Live Geospatial Map** across 12 Pakistani cities
- **Instant Theft/Fault Alerts** with ML Confidence Score

## Tech Stack

Python · XGBoost · Firebase Firestore · Flutter (Dart) · Scikit-learn · Google Maps Flutter · MQTT (EMQX)

---

## 1. Project Structure

```
grideye/
├── backend/
│   ├── training_pipeline/        # Task 1–11: offline data cleaning, SMOTE,
│   │                              # feature engineering, Stage 1/2 training & eval
│   ├── ami_emulator.py           # 12 virtual AMI meters (consumer side)
│   ├── ami_bridge.py             # MQTT -> validate -> ML/SHAP -> Firestore
│   ├── ml_engine.py              # XGBoost + SHAP, Time-Reveal logic
│   ├── grideye_common.py         # shared MQTT topic/schema contract
│   ├── billing.py                # single shared bill formula
│   ├── admin_simulator.py        # admin-side demo data (random MTR-XXX meters)
│   ├── register_meters.py        # registers the 12 fixed consumer meters
│   ├── clear_retained.py         # clears stale retained MQTT messages
│   ├── seed_usage_history.py     # seeds usage_history sub-collections
│   ├── mqtt_config.py            # MQTT credentials — FILL IN, see §3
│   └── serviceKey.json           # Firebase service account — NOT included, see §3
├── frontend/
│   └── lib/
│       ├── admin_portal/             # Admin dashboard, live map, meter archive, alerts
│       ├── consumer_portal.dart      # Consumer dashboard + GridBot chat sheet
│       │                             # (rule-based bilingual advisor, SHAP phrase map)
│       ├── usage_history.dart        # Billing/usage history (XGBoost-based)
│       ├── profile_screen.dart       # ConsumerProfileScreen
│       ├── jazzcash_payment_screen.dart  # Bill payment (real Phone Auth OTP)
│       └── firebase_options.dart     # Firebase config (via flutterfire configure)
├── docs/
│   └── firestore_schema.md       # Firestore collections/fields (no SQL is used)
└── README.md
```

## 2. Requirements

- Python 3.10+
- Flutter SDK (3.x) + Dart
- A Firebase project (Firestore + Authentication + Phone Authentication enabled)
- An EMQX (or any MQTT v3.1.1/TLS) broker — we used EMQX Serverless

## 3. One-Time Setup

### 3.1 Firebase

1. Create a Firebase project, enable **Cloud Firestore** and **Authentication** (Email/Password + Phone).
2. Firebase Console → Project Settings → Service Accounts → **Generate new private key**. Save the downloaded JSON as `backend/serviceKey.json`. (This file is intentionally excluded from version control — it contains a private credential. See `.gitignore`.)
3. Copy your Firebase web config into the Flutter app's `lib/firebase_options.dart` (via `flutterfire configure`, or paste values from Project Settings → General).

### 3.2 MQTT Broker

1. Create a free EMQX Serverless deployment (or any MQTT broker that supports TLS on port 8883).
2. Edit `backend/mqtt_config.py` and fill in your own values:
   ```python
   BROKER   = "xxxx.emqxsl.com"
   PORT     = 8883
   USERNAME = "your-username"
   PASSWORD = "your-password"
   TLS      = True
   ```
   (Alternatively, set `MQTT_BROKER` / `MQTT_USERNAME` / `MQTT_PASSWORD` environment variables — these take priority over `mqtt_config.py`.)

### 3.3 Python Backend

```bash
cd backend
pip install -r requirements.txt   # firebase-admin, paho-mqtt, xgboost, shap,
                                   # scikit-learn, pandas, numpy, joblib
```

### 3.4 Flutter App

```bash
cd frontend
flutter pub get
```

## 4. Running the System

Run these in **separate terminals**, in this order. The admin and consumer pipelines are fully independent — running one does not affect the other.

```bash
# 1. One-time: register the 12 fixed consumer meters in Firestore
python backend/register_meters.py

# 2. One-time (or after re-testing): clear stale retained MQTT messages
python backend/clear_retained.py

# 3. Consumer backend (bridge) — Terminal A
python backend/ami_bridge.py

# 4. Consumer backend (virtual meters) — Terminal B
python backend/ami_emulator.py --interval 10

# 5. Admin backend (demo data for the Admin Portal) — Terminal C
python backend/admin_simulator.py

# 6. (Optional) rebuild each meter's billing/theft-risk history
python backend/seed_usage_history.py --write

# 7. Flutter app
cd frontend
flutter run
```

> **Do not** run `ami_bridge.py` and `ami_emulator.py` without `--meters` customization unless `register_meters.py` has already been run — unregistered meters are rejected by design.

## 5. Offline ML Training Pipeline (optional — pretrained model included)

The trained model, scaler and held-out test set are already included under `backend/` (`incremental_model_v5_xgb.pkl`, `scaler_v5_xgb.pkl`, `held_out_test_v5_xgb.csv`). To retrain from scratch:

```bash
cd backend/training_pipeline
python Task-1_Data_analysis.py
python Task-2_Data_Processing.py
python Task-3_Smote_analysis.py
python Task-4_Check_zeros.py
python Task-5_EDA.py
python Task-6_feature_Engineering.py
python Task-8_firebase_status_simulator.py   # (admin live demo, not training)
python Task-10_Fault_classification.py       # trains Stage 2 (XGBoost)
python Task-9_Anomaly_detection.py           # evaluates Stage 1 (Z-score)
python Task-11_Evaluation.py                 # standalone re-evaluation
```

## 6. Known Limitations

- Voltage/current readings in the virtual AMI pipeline are synthetic (SGCC only provides daily kWh).
- Theft/Normal status comes from a held-out SGCC consumer profile revealed progressively over time ("Time-Reveal"), not from a physical meter's own accumulated history.
- JazzCash payment: phone-number verification is **real** (Firebase Phone Authentication sends an actual SMS OTP); MPIN confirmation and fund transfer are **simulated** (no JazzCash merchant account).
- Billing uses a simplified flat tariff calibrated against a real GEPCO bill, not the full WAPDA slab structure.

## 7. Team

| Member | Roll No | Role |
|---|---|---|
| Haram Arshad | 1220100449 | Flutter / Frontend |
| Ayesha Abid | 1220100357 | AI/ML & Backend |
| Areeba Abbas | 1220100245 | Documentation & Testing |

## 8. Supervisor

Ms. Areej Waseem, Lecturer, Department of Computer Science, IISAT Gujranwala.
