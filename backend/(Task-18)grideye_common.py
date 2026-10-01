import json
import math
import os
from datetime import datetime, timedelta, timezone

import paho.mqtt.client as mqtt

SCHEMA_VERSION = 1
TOPIC_ROOT     = "grideye"

METER_IDS = [
    "CON-KHI-001", "CON-LHR-001", "CON-ISB-001", "CON-FSD-001",
    "CON-MUL-001", "CON-PSH-001", "CON-QTA-001", "CON-SKT-001",
    "CON-GWL-001", "CON-HYD-001", "CON-BWP-001", "CON-SKR-001",
]
BYPASS_METER_IDS = {"CON-SKR-001", "CON-QTA-001"}

def t_birth(meter_id: str) -> str:
    return f"{TOPIC_ROOT}/{meter_id}/birth"

def t_telemetry(meter_id: str) -> str:
    return f"{TOPIC_ROOT}/{meter_id}/telemetry"

def t_status(meter_id: str) -> str:
    return f"{TOPIC_ROOT}/{meter_id}/status"

SUB_BIRTH     = f"{TOPIC_ROOT}/+/birth"
SUB_TELEMETRY = f"{TOPIC_ROOT}/+/telemetry"
SUB_STATUS    = f"{TOPIC_ROOT}/+/status"

def split_topic(topic: str):
    """'grideye/CON-KHI-001/telemetry' -> ('CON-KHI-001', 'telemetry'), warna (None, None)."""
    parts = topic.split("/")
    if len(parts) == 3 and parts[0] == TOPIC_ROOT:
        return parts[1], parts[2]
    return None, None

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def mqtt_settings() -> dict:
    broker   = os.environ.get("MQTT_BROKER")
    port     = os.environ.get("MQTT_PORT")
    username = os.environ.get("MQTT_USERNAME")
    password = os.environ.get("MQTT_PASSWORD")
    tls_env  = os.environ.get("MQTT_TLS")

    if not broker:
        try:
            import mqtt_config as _cfg
            broker   = broker   or getattr(_cfg, "BROKER", None)
            port     = port     or str(getattr(_cfg, "PORT", 8883))
            username = username or getattr(_cfg, "USERNAME", None)
            password = password or getattr(_cfg, "PASSWORD", None)
            if tls_env is None:
                tls_env = "1" if getattr(_cfg, "TLS", True) else "0"
            print("ℹ️  MQTT env vars nahi mile — mqtt_config.py se settings li gayi hain.")
        except ImportError:
            pass

    if not broker:
        raise SystemExit(
            "MQTT broker settings nahi milin.\n"
            '  Ya to: $env:MQTT_BROKER="xxxx.emqxsl.com"; $env:MQTT_USERNAME="..."; '
            '$env:MQTT_PASSWORD="..."\n'
            "  Ya: mqtt_config.py file bana kar usme BROKER/USERNAME/PASSWORD bhar do."
        )
    return {
        "broker":    broker,
        "port":      int(port or "8883"),
        "username":  username,
        "password":  password,
        "tls":       (tls_env != "0") if tls_env is not None else True,
        "keepalive": int(os.environ.get("MQTT_KEEPALIVE", "30")),
    }

def new_client(client_id: str):
    try:                                   
        return mqtt.Client(mqtt.CallbackAPIVersion.VERSION1,
                           client_id=client_id, protocol=mqtt.MQTTv311)
    except AttributeError:                 
        return mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv311)


def start_client(client, cfg: dict):
    """
    Background mein connect + apne aap reconnect. will_set()/on_connect
    pehle set kar lo, phir ye call karo.
    """
    if cfg["username"]:
        client.username_pw_set(cfg["username"], cfg["password"])
    if cfg["tls"]:
        client.tls_set()                   
    client.reconnect_delay_set(min_delay=1, max_delay=30)
    client.connect_async(cfg["broker"], cfg["port"], keepalive=cfg["keepalive"])
    client.loop_start()

def _number(raw: dict, options, required: bool, lo: float, hi: float):
    """options = [(key, factor), ...]; pehli mili hui key li jati hai."""
    for key, factor in options:
        if key in raw and raw[key] is not None:
            v = raw[key]
            if isinstance(v, bool) or not isinstance(v, (int, float)):
                raise ValueError(f"{key} number nahi hai")
            v = float(v) * factor
            if not math.isfinite(v) or v < lo or v > hi:
                raise ValueError(f"{key} range se bahar hai ({v})")
            return v
    if required:
        raise ValueError(f"{options[0][0]} missing hai")
    return None


def parse_telemetry(raw, topic_meter_id: str, max_future_s: int = 300) -> dict:
    """
    Meter ka raw JSON -> saaf, validated dict. Ghalat data par ValueError
    (bridge use skip kar deta hai, crash nahi hota).
    """
    if not isinstance(raw, dict):
        raise ValueError("payload JSON object nahi hai")

    payload_id = raw.get("meterId", topic_meter_id)
    if payload_id != topic_meter_id:
        raise ValueError(f"meterId mismatch (topic={topic_meter_id}, payload={payload_id})")

    energy  = _number(raw, [("energy_kwh", 1.0), ("energy_wh", 0.001)], True,  0.0, 1e7)
    power   = _number(raw, [("power_kw", 1.0),  ("power_w", 0.001)],    True,  0.0, 100.0)
    voltage = _number(raw, [("voltage_v", 1.0)],                         False, 50.0, 500.0)
    current = _number(raw, [("current_a", 1.0)],                         False, 0.0, 1000.0)

    ts_raw = raw.get("ts")
    if not isinstance(ts_raw, str):
        raise ValueError("ts missing hai")
    try:
        ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
    except ValueError:
        raise ValueError(f"ts parse nahi hua ({ts_raw})")
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    if ts > datetime.now(timezone.utc) + timedelta(seconds=max_future_s):
        raise ValueError("ts future mein hai")

    seq = raw.get("seq")
    if seq is not None and (isinstance(seq, bool) or not isinstance(seq, int)):
        raise ValueError("seq integer nahi hai")

    return {
        "meterId":    topic_meter_id,
        "ts":         ts,
        "seq":        seq,
        "energy_kwh": energy,
        "power_kw":   power,
        "voltage_v":  voltage,
        "current_a":  current,
        "tamper":     bool(raw.get("tamper", False)),
        "event":      str(raw.get("event", "NONE")).upper(),
    }


def loads_json(payload: bytes):
    """bytes -> python object, ghalat JSON par ValueError."""
    try:
        return json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        raise ValueError(f"JSON parse nahi hua: {e}")