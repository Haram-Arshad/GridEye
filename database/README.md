# Database — Firestore Schema & Configuration

GridEye uses **Google Cloud Firestore** (NoSQL, document-based) as its database — there are no SQL files or a relational schema, since the project's real-time, hierarchical sensor/event data (telemetry streams, per-consumer usage history, live alerts) fits a document model far better than fixed relational tables.

Project: `grideye-official` | Database: `(default)` | Location: `nam5`

---

## 1. `meters/{meterId}`

The core registry of all 12 consumer AMI meters (document ID = meter ID, e.g. `CON-BWP-001`).

| Field | Type | Description |
|---|---|---|
| `activatedAt` | timestamp | When the meter first registered/connected |
| `lastBirth` | timestamp | Last MQTT "birth" message received |
| `area` | string | Locality, e.g. `"Model Town, Bahawalpur"` |
| `city` | string | City name |
| `lat`, `lng` | number | GPS coordinates (for the live map) |
| `connection` | string | `"online"` / `"offline"` |
| `current` | number | Latest current reading (A, synthetic) |
| `currentLoad` | number | Latest power load (kW) |
| `billEst` | number | Latest estimated bill (Rs) |
| `fwVersion` | string | Virtual meter firmware version tag |

**Subcollection:** `meters/{meterId}/usage_history/{month}` — see §2.

## 2. `meters/{meterId}/usage_history/{month}`

One document per month per consumer (e.g. `Aug_2026`), written by the Dual-Stage Diagnostic Engine.

| Field | Type | Description |
|---|---|---|
| `month` | string | 3-letter month, e.g. `"Aug"` |
| `label` | string | Display label, e.g. `"August 2026"` |
| `timestamp` | timestamp | Billing period start |
| `units` | number | Units consumed (kWh) that month |
| `amount` | number | Computed bill (Rs) via `billing.py` |
| `isPaid` | boolean | Payment status |
| `theft_risk` | string | `"Low"` / `"Medium"` / `"High"` — Stage 2 classification |
| `confidence` | number | XGBoost confidence score (%) |
| `ml_model` | string | Model tag, e.g. `"XGBoost_SGCC_v5"` |

## 3. `MeterReadings/{autoId}`

Live, high-frequency reading stream for the Admin Portal's map/overview (admin-side simulator).

| Field | Type | Description |
|---|---|---|
| `meterId` | string | Admin-side meter ID, e.g. `"MTR-GWL-007"` |
| `status` | string | `"Normal"` / `"Theft"` / `"Fault"` |
| `currentLoad` | string/number | Instantaneous load |
| `lat`, `lng` | number | GPS coordinates |
| `timestamp` | timestamp | Reading time |

## 4. `MeterLogs/{autoId}`

Historical log entries per reading/event, used for the per-meter detail/explanation timeline.

| Field | Type | Description |
|---|---|---|
| `meterId` | string | Admin-side meter ID |
| `status` | string | `"Normal"` / `"Theft"` / `"Fault"` |
| `loadValue` | number | Load at log time |
| `ml_confidence` | number | Model confidence (%) |
| `isCritical` | boolean | Whether this log entry is flagged critical |
| `time` | timestamp | Log timestamp |
| `title` | string | Short title, e.g. `"Pre-Detection Baseline"` |
| `desc` | string | Human-readable description |
| `explanation` | map | Nested SHAP/explanation sub-fields (subset of the above) |

## 5. `Alerts/{autoId}`

Theft/fault alerts surfaced on the Admin dashboard.

| Field | Type | Description |
|---|---|---|
| `meterId` | string | Admin-side meter ID |
| `status` | string | `"Fault"` / `"Theft"` |
| `type` | string | `"Warning"` / `"Critical"` |
| `title` | string | e.g. `"Meter Offline Warning"` |
| `description` | string | e.g. `"Voltage flatlined. Blown fuse suspected."` |
| `address` | string | Human-readable location |
| `lat`, `lng` | number | GPS coordinates |
| `isRead` | boolean | Admin read/unread flag |
| `time` | timestamp | Alert time |
| `explanation` | map | SHAP-based explanation fields |

## 6. `Faults/{autoId}`

Fault-specific records (distinct from general Alerts), including manually acknowledged ones.

| Field | Type | Description |
|---|---|---|
| `meterID` | string | Meter ID (consumer or admin side) |
| `status` | string | `"Resolved"` / `"Open"` |
| `type` | string | e.g. `"SYSTEM: HIGH LOAD"` |
| `description` | string | e.g. `"User reported outage manually."` |
| `consumerAck` | boolean | Whether the consumer acknowledged it |
| `timestamp` | timestamp | Fault time |

## 7. `financials/current_metrics`

Single document holding live utility-wide financial KPIs (Admin dashboard).

| Field | Type | Description |
|---|---|---|
| `totalRevenue` | number | Total revenue collected (Rs) |
| `theftLosses` | number | Estimated losses from theft (Rs) |
| `penaltyRecovered` | number | Penalties recovered from theft cases (Rs) |
| `unpaidBills` | number | Count of unpaid bills |
| `lastUpdated` | timestamp | Last recompute time |

## 8. `system_stats/{document}`

Dashboard/report snapshots: `dashboard_data` (live KPIs), plus monthly snapshots (`january_2026`, `february_2026`, `march_2026`, …) and `overall_metrics`, `emergency_report`.

| Field | Type | Description |
|---|---|---|
| `activeCases` | number | Currently open theft/fault cases |
| `efficiency` | number | Grid efficiency (%) |
| `lastMonthEff` | number | Previous month's efficiency (%) |
| `gridLoss` | number | Estimated grid loss (Rs or units) |
| `revenue` | number | Revenue for that snapshot |

## 9. `meter_resolved_archive/{meterId}`

Archive flag for meters whose theft/fault case has been closed.

| Field | Type | Description |
|---|---|---|
| `archived` | boolean | Always `true` for archived entries |
| `archivedAt` | timestamp | When the case was archived |

## 10. `users/{uid}`

Firebase Authentication-linked consumer profile (document ID = Firebase Auth UID).

| Field | Type | Description |
|---|---|---|
| `email` | string | Consumer's login email |
| `meterID` | string | The meter linked to this account |
| `role` | string | `"consumer"` / `"admin"` |

## 11. `payments/{paymentId}`

JazzCash (simulated) bill-payment receipts.

| Field | Type | Description |
|---|---|---|
| `meterID` | string | Meter the payment is for |
| `amount` | number | Amount paid (Rs) |
| `method` | string | `"JazzCash (Simulated)"` |
| `phoneNumber` | string | Verified phone number (real Firebase Phone Auth OTP) |
| `status` | string | `"Completed"` |
| `timestamp` | timestamp | Payment time |

---

## Why Firestore instead of SQL

GridEye's data is naturally hierarchical and event-driven (a meter → its monthly usage history; a reading → its explanation sub-fields) and needs real-time listeners (`StreamBuilder` in Flutter) pushing live updates to both the Admin and Consumer portals as MQTT telemetry arrives. Firestore's document/subcollection model and native real-time sync made this a better fit than a relational database for this use case, avoiding the added complexity of a separate real-time layer on top of SQL.

## Configuration

- Firebase project: see `frontend/lib/firebase_options.dart` (generated via `flutterfire configure`)
- Service account (server-side read/write via `firebase-admin`): `backend/serviceKey.json` — **not included in this submission**, as it contains a private credential (see root `.gitignore`)
- Android config: `database/google-services.json`
