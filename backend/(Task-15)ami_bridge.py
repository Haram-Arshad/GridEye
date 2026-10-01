import os
import queue
import random
import threading
import time
from collections import Counter
from datetime import datetime, timezone

from billing import total_bill
from grideye_common import (
    BYPASS_METER_IDS, SUB_BIRTH, SUB_STATUS, SUB_TELEMETRY,
    loads_json, mqtt_settings, new_client, parse_telemetry, split_topic, start_client,
    t_status,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

METERS_WRITE_INTERVAL_S     = 10     
REGISTRY_REFRESH_COOLDOWN_S = 30
STATS_INTERVAL_S            = 60
WARN_COOLDOWN_S             = 30


def _due(last, interval: float, now: float) -> bool:
    return last is None or (now - last) >= interval


class MeterState:
    """Har meter ki chhoti si yaad-dasht (memory mein, Firestore se read nahi karni parti)."""
    def __init__(self):
        self.registration     = None    
        self.connection       = None    
        self.status           = None    
        self.last_seq         = None
        self.last_energy      = None
        self.last_meter_write = None


class Bridge:
    def __init__(self, db, engine):
        self.db         = db
        self.engine     = engine
        self.registry   = {}                       
        self.states     = {}
        self.queue      = queue.Queue()
        self.stats      = Counter()
        self.stop_event = threading.Event()
        self._registry_loaded_at = None
        self._warned    = {}

    # ── helpers ──────────────────────────────────────────────────
    def state(self, meter_id: str) -> MeterState:
        return self.states.setdefault(meter_id, MeterState())

    def _warn(self, key: str, msg: str):
        now = time.monotonic()
        if now - self._warned.get(key, -1e9) >= WARN_COOLDOWN_S:
            self._warned[key] = now
            print(msg)

    # ── registry ─────────────────────────────────────────────────
    def load_registry(self):
        n = 0
        for doc in self.db.collection("meters").stream():
            data = doc.to_dict() or {}
            self.registry[doc.id] = data
            self.state(doc.id).registration = data.get("registration")
            n += 1
        self._registry_loaded_at = time.monotonic()
        active = sum(1 for s in self.states.values() if s.registration == "active")
        print(f"📒 Registry loaded: {n} registered meters ({active} already active)")

    def is_registered(self, meter_id: str) -> bool:
        if meter_id in self.registry:
            return True
        if (self._registry_loaded_at is None or
                time.monotonic() - self._registry_loaded_at >= REGISTRY_REFRESH_COOLDOWN_S):
            self.load_registry()                 
        return meter_id in self.registry

    # ── MQTT entry ───────────────────────────────────────────────
    def on_message(self, client, userdata, msg):
        self.queue.put((msg.topic, msg.payload))  

    def run(self):
        last_stats = time.monotonic()
        while not self.stop_event.is_set():
            try:
                topic, payload = self.queue.get(timeout=1)
                self.handle(topic, payload)
            except queue.Empty:
                pass
            if time.monotonic() - last_stats >= STATS_INTERVAL_S:
                last_stats = time.monotonic()
                s = self.stats
                print(f"📊 received={s['received']} written={s['writes_ok']} "
                      f"invalid={s['dropped_invalid']} duplicate={s['dropped_duplicate']} "
                      f"rejected={s['rejected_unregistered'] + s['rejected_no_birth']} "
                      f"errors={s['errors']}")

    def handle(self, topic: str, payload: bytes):
        meter_id, kind = split_topic(topic)
        if not meter_id or not payload:           
            return
        try:
            if kind == "birth":
                self.on_birth(meter_id, payload)
            elif kind == "telemetry":
                self.on_telemetry(meter_id, payload)
            elif kind == "status":
                self.on_status(meter_id, payload)
        except ValueError as e:                   
            self.stats["dropped_invalid"] += 1
            self._warn(f"invalid:{meter_id}", f"  ⚠️ {meter_id}: data skip kiya — {e}")
        except Exception as e:                    
            self.stats["errors"] += 1
            self._warn(f"error:{meter_id}", f"  ✗ {meter_id}: {type(e).__name__}: {e}")

    # ── birth = registration ─────────────────────────────────────
    def on_birth(self, meter_id: str, payload: bytes):
        data = loads_json(payload)
        if not isinstance(data, dict):
            raise ValueError("birth payload object nahi hai")
        if data.get("meterId", meter_id) != meter_id:
            raise ValueError("birth: meterId mismatch")
        if not self.is_registered(meter_id):
            self.stats["rejected_unregistered"] += 1
            self._warn(f"unreg:{meter_id}", f"  ⛔ birth REJECT — {meter_id} registered nahi hai")
            return

        st = self.state(meter_id)
        was_active = st.registration == "active"
        st.registration = "active"
        st.connection   = "online"
        st.last_seq     = None                    
        doc = {
            "registration": "active",
            "connection":   "online",
            "lastBirth":    datetime.now(timezone.utc),
            "meterModel":   data.get("model"),
            "fwVersion":    data.get("fw"),
            "protocol":     data.get("protocol"),
        }
        if not was_active:
            doc["activatedAt"] = datetime.now(timezone.utc)
        self._set_meter(meter_id, {k: v for k, v in doc.items() if v is not None})
        print(f"  🔗 {meter_id}: birth accepted -> "
              f"{'pending -> active' if not was_active else 'active (reconnect)'}")

    # ── status (Last Will) ───────────────────────────────────────
    def on_status(self, meter_id: str, payload: bytes):
        data = loads_json(payload)
        if not isinstance(data, dict):
            raise ValueError("status payload object nahi hai")
        if not self.is_registered(meter_id):
            self.stats["rejected_unregistered"] += 1
            return
        state = data.get("state")
        st = self.state(meter_id)
        if state == "online":
            st.connection = "online"
        elif state == "offline":
            self._handle_offline(meter_id)

    def _handle_offline(self, meter_id: str):
        st = self.state(meter_id)
        if st.connection == "offline" or st.registration != "active":
            st.connection = "offline"
            return
        st.connection = "offline"
        st.status     = "Fault"
        self._set_meter(meter_id, {
            "status":        "Fault",
            "connection":    "offline",
            "ml_confidence": 100,
            "explanation":   [],
            "timestamp":     datetime.now(timezone.utc),
        })
        print(f"  📴 {meter_id}: OFFLINE (Last Will) -> status=Fault")

    # ── telemetry (asli kaam) ────────────────────────────────────
    def on_telemetry(self, meter_id: str, payload: bytes):
        self.stats["received"] += 1
        if not self.is_registered(meter_id):
            self.stats["rejected_unregistered"] += 1
            self._warn(f"unreg:{meter_id}", f"  ⛔ {meter_id}: registered nahi — data reject")
            return
        st = self.state(meter_id)
        if st.registration != "active":
            self.stats["rejected_no_birth"] += 1
            self._warn(f"nobirth:{meter_id}", f"  ⏳ {meter_id}: birth nahi aaya (pending) — data skip")
            return

        t = parse_telemetry(loads_json(payload), meter_id)     # ValueError = skip

        if t["seq"] is not None and t["seq"] == st.last_seq:   # QoS1 duplicate
            self.stats["dropped_duplicate"] += 1
            return
        if st.last_energy is not None and t["energy_kwh"] < st.last_energy - 1e-6:
            raise ValueError(f"energy register kam hua ({st.last_energy} -> {t['energy_kwh']})")
        st.last_seq, st.last_energy = t["seq"], t["energy_kwh"]
        st.connection = "online"

        power, energy, ts = t["power_kw"], t["energy_kwh"], t["ts"]

        scaled = None
        if t["event"] == "POWER_FAIL":              
            status, conf = "Fault", 100
        elif t["tamper"]:
            status, conf = "Theft", 100
        else:
            pred = self.engine.predict(meter_id)
            status, conf, scaled = pred.status, pred.confidence, pred.scaled

        now_m   = time.monotonic()
        changed = status != st.status

        if changed or _due(st.last_meter_write, METERS_WRITE_INTERVAL_S, now_m):
            explanation = self.engine.explain(scaled) if (status in ("Theft", "Fault") and scaled is not None) else []
            doc = {
                "meterId":       meter_id,
                "currentLoad":   round(power, 3),
                "units":         round(energy, 4),
                "billEst":       total_bill(energy),
                "status":        status,
                "ml_confidence": conf,
                "explanation":   explanation,
                "timestamp":     ts,
                "connection":    "online",
            }
            if t["voltage_v"] is not None:
                doc["voltage"] = round(t["voltage_v"], 1)
            if t["current_a"] is not None:
                doc["current"] = round(t["current_a"], 2)
            self._set_meter(meter_id, doc)
            st.last_meter_write = now_m
            tag = " 🚨" if status in ("Theft", "Fault") else ""
            print(f"  [meters] ✔️ {meter_id} | {status:<6} (conf:{conf}%) | {power}kW | "
                  f"units={round(energy, 4)} | bill=Rs.{doc['billEst']}{tag}")

        st.status = status

    def _set_meter(self, meter_id: str, doc: dict):
        try:
            self.db.collection("meters").document(meter_id).set(doc, merge=True)
            self.stats["writes_ok"] += 1
        except Exception as e:
            self.stats["errors"] += 1
            self._warn("fs:meters", f"  ✗ Firestore meters: {type(e).__name__}: {e}")


def init_firestore():
    import firebase_admin
    from firebase_admin import credentials, firestore
    if not firebase_admin._apps:
        firebase_admin.initialize_app(
            credentials.Certificate(os.path.join(BASE_DIR, "serviceKey.json")))
    return firestore.client()


def main():
    print("\n" + "=" * 65)
    print("  GRIDEYE — AMI BRIDGE (MQTT -> validate -> ML/SHAP -> Firestore)")
    print("  Writes ONLY meters/{id} — admin's MeterReadings/MeterLogs/Alerts")
    print("  collections yahan se kabhi nahi chhuti (admin_simulator.py ka kaam hai)")
    print("=" * 65 + "\n")
    db = init_firestore()
    print("✅ Firestore connected")

    from ml_engine import MLEngine
    engine = MLEngine(BASE_DIR, bypass_meter_ids=BYPASS_METER_IDS)

    bridge = Bridge(db, engine)
    bridge.load_registry()

    cfg    = mqtt_settings()
    client = new_client("grideye-bridge")

    def on_connect(c, userdata, flags, rc):
        if rc == 0:
           
            for mid in bridge.registry.keys():
                c.publish(t_status(mid), payload=None, qos=1, retain=True)
            time.sleep(0.3)   
            c.subscribe([(SUB_BIRTH, 1), (SUB_STATUS, 1), (SUB_TELEMETRY, 1)])
            print(f"✅ Bridge MQTT connected — cleared {len(bridge.registry)} stale "
                  f"status topics + subscribed (birth, status, telemetry)\n")
        else:
            print(f"⚠️  MQTT connect failed rc={rc}")

    client.on_connect = on_connect
    client.on_message = bridge.on_message
    start_client(client, cfg)

    try:
        bridge.run()
    except KeyboardInterrupt:
        print("\n[STOPPED] bridge band ho raha hai")
    finally:
        bridge.stop_event.set()
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()