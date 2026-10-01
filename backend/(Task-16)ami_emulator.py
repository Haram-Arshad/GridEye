import argparse
import json
import os
import random
import time
import uuid
from datetime import datetime, timezone, timedelta

from grideye_common import (
    BYPASS_METER_IDS, METER_IDS, SCHEMA_VERSION,
    mqtt_settings, new_client, start_client,
    t_birth, t_status, t_telemetry, utc_now_iso,
)

PK_TZ = timezone(timedelta(hours=5)) 

BYPASS_FACTOR    = 0.3       
POWER_FAIL_PROB  = 0.001     
NOMINAL_VOLTAGE  = 230.0
POWER_FACTOR     = 0.95


class VirtualMeter:
    def __init__(self, meter_id: str, cfg: dict, state_dir: str, energy_scale: float,
                 force_hour: int = None):
        self.force_hour   = force_hour   
        self.id           = meter_id
        self.cfg          = cfg
        self.energy_scale = energy_scale          
        self.state_file   = os.path.join(state_dir, f"{meter_id}.json")
        self.boot_id      = uuid.uuid4().hex[:8]
        self.seq          = 0
        self.connected    = False
        self._power       = None       
        self.energy_kwh   = self._load_energy()

        self.client = new_client(f"ami-{meter_id}")
        self.client.will_set(
            t_status(meter_id),
            json.dumps({"meterId": meter_id, "state": "offline",
                        "reason": "unexpected_disconnect"}),
            qos=1, retain=True)
        self.client.on_connect    = self._on_connect
        self.client.on_disconnect = self._on_disconnect

    def _load_energy(self) -> float:
        try:
            with open(self.state_file, "r", encoding="utf-8") as f:
                return float(json.load(f)["energy_kwh"])
        except (OSError, ValueError, KeyError):
            return round(random.uniform(40, 120), 3)

    def _save_energy(self):
        tmp = self.state_file + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump({"energy_kwh": self.energy_kwh}, f)
            os.replace(tmp, self.state_file)
        except OSError as e:
            print(f"  [{self.id}] ⚠️ energy state save nahi hui: {e}")

    # ── MQTT callbacks ───────────────────────────────────────────
    def _on_connect(self, client, userdata, flags, rc):
        if rc != 0:
            print(f"  [{self.id}] ⚠️ MQTT connect failed rc={rc}")
            return
        self.connected = True
        client.publish(t_status(self.id),
                       json.dumps({"meterId": self.id, "state": "online"}),
                       qos=1, retain=True)
        client.publish(t_birth(self.id), json.dumps({
            "schema":       SCHEMA_VERSION,
            "meterId":      self.id,
            "ts":           utc_now_iso(),
            "boot_id":      self.boot_id,
            "manufacturer": "GridEye-Virtual",
            "model":        "VAMI-1",
            "fw":           "1.0.0",
            "protocol":     "MQTT/TLS",
            "energy_kwh":   round(self.energy_kwh, 4),
        }), qos=1, retain=True)
        print(f"  [{self.id}] ✅ connected + birth sent")

    def _on_disconnect(self, client, userdata, rc):
        self.connected = False
        if rc != 0:
            print(f"  [{self.id}] ⚠️ connection lost (rc={rc}), auto-reconnect...")

    # ── ek reading ───────────────────────────────────────────────
    def _power_range(self, hour: int = None):
        """Is waqt (Pakistan local ghanta) ka normal load range (min, max) kW."""
        if hour is None:
            hour = datetime.now(timezone.utc).astimezone(PK_TZ).hour
        if 7 <= hour <= 10 or 18 <= hour <= 23:
            lo, hi = 4.0, 9.5
        elif 0 <= hour <= 5:
            lo, hi = 0.5, 2.5
        else:
            lo, hi = 2.0, 5.5
        if self.id in BYPASS_METER_IDS:
            lo, hi = lo * BYPASS_FACTOR, hi * BYPASS_FACTOR
        return lo, hi

    def _power_kw(self) -> float:
        
        lo, hi = self._power_range(self.force_hour)
        target = random.uniform(lo, hi)
        if self._power is None:
            self._power = target
        else:
            self._power += (target - self._power) * 0.30       
            self._power += random.gauss(0, (hi - lo) * 0.03)   
            self._power = min(max(self._power, lo * 0.5), hi * 1.05)
        return round(self._power, 3)

    def tick(self, interval_s: float):
        event = "NONE"
        power = self._power_kw()
        if random.random() < POWER_FAIL_PROB:
            power, event = 0.0, "POWER_FAIL"

        self.energy_kwh += power * interval_s * self.energy_scale / 3600.0
        self._save_energy()

        if not self.connected:
            print(f"  [{self.id}] offline — reading skip (energy register chal raha hai)")
            return

        voltage = round(NOMINAL_VOLTAGE - 0.5 * power + random.gauss(0, 1.2), 1) if power > 0 else 0.0
        current = round(power * 1000.0 / (max(voltage, 1.0) * POWER_FACTOR), 2) if power > 0 else 0.0

        self.seq += 1
        payload = {
            "schema":     SCHEMA_VERSION,
            "meterId":    self.id,
            "ts":         utc_now_iso(),
            "seq":        self.seq,
            "energy_kwh": round(self.energy_kwh, 4),
            "power_kw":   power,
            "voltage_v":  voltage if voltage > 0 else None,   # synthetic
            "current_a":  current,                            # synthetic
            "tamper":     False,
            "event":      event,
        }
        self.client.publish(t_telemetry(self.id), json.dumps(payload), qos=1, retain=True)
        print(f"  [{self.id}] #{self.seq:<4} {power:>6.2f} kW | {self.energy_kwh:>10.4f} kWh"
              f"{'  ⚡POWER_FAIL' if event != 'NONE' else ''}")

    def stop(self):
        try:
            if self.connected:
                info = self.client.publish(
                    t_status(self.id),
                    json.dumps({"meterId": self.id, "state": "offline", "reason": "shutdown"}),
                    qos=1, retain=True)
                info.wait_for_publish(timeout=3)
            self.client.disconnect()
            self.client.loop_stop()
        except Exception:
            pass


def main():
    ap = argparse.ArgumentParser(description="GridEye virtual AMI meter emulator")
    ap.add_argument("--meters", default=",".join(METER_IDS),
                    help="comma-separated meter IDs (default: saare 12)")
    ap.add_argument("--interval", type=float, default=10.0,
                    help="har meter ki readings ka gap, seconds (default 10)")
    ap.add_argument("--energy-scale", type=float, default=1.0,
                    help="energy accrual ki speed (1 = real time; 60 = demo ke liye tez)")
    ap.add_argument("--force-hour", type=int, default=None,
                    help="demo ke liye din/raat ka load-bucket force karo (0-23, PKT). "
                         "Na diya to asli PKT waqt use hota hai.")
    ap.add_argument("--state-dir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                        "emulator_state"))
    args = ap.parse_args()

    ids = [m.strip() for m in args.meters.split(",") if m.strip()]
    os.makedirs(args.state_dir, exist_ok=True)
    cfg = mqtt_settings()

    print("\n" + "=" * 65)
    print("  GRIDEYE — VIRTUAL AMI METER EMULATOR")
    print(f"  Meters   : {len(ids)} | interval {args.interval}s | broker {cfg['broker']}")
    print("  Publish  : grideye/{meterId}/birth | telemetry | status (LWT)")
    print("  Voltage/current SYNTHETIC hain (SGCC mein sirf daily kWh hai)")
    print("=" * 65 + "\n")

    meters = [VirtualMeter(m, cfg, args.state_dir, args.energy_scale, args.force_hour) for m in ids]
    for m in meters:
        start_client(m.client, cfg)

    gap = args.interval / max(len(meters), 1)     
    try:
        while True:
            for m in meters:
                m.tick(args.interval)
                time.sleep(gap)
    except KeyboardInterrupt:
        print("\n[STOPPING] meters ko saaf tareeqe se offline kar raha hoon...")
    finally:
        for m in meters:
            m.stop()

if __name__ == "__main__":
    main()