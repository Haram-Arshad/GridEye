import time

from grideye_common import METER_IDS, mqtt_settings, new_client, t_birth, t_status, t_telemetry

cfg    = mqtt_settings()
client = new_client("grideye-clear-retained")

connected = {"ok": False}

def on_connect(c, userdata, flags, rc):
    connected["ok"] = (rc == 0)

client.on_connect = on_connect
if cfg["username"]:
    client.username_pw_set(cfg["username"], cfg["password"])
if cfg["tls"]:
    client.tls_set()
client.connect(cfg["broker"], cfg["port"], keepalive=cfg["keepalive"])
client.loop_start()

for _ in range(50):
    if connected["ok"]:
        break
    time.sleep(0.1)
else:
    raise SystemExit("MQTT connect nahi hua — broker settings check karo.")

print(f"✅ Connected to {cfg['broker']} — clearing retained messages for {len(METER_IDS)} meters...")
for m in METER_IDS:
    for topic in (t_status(m), t_birth(m), t_telemetry(m)):
        client.publish(topic, payload=None, qos=1, retain=True)
        print(f"  cleared {topic}")

time.sleep(1)   
client.loop_stop()
client.disconnect()
print("\n🎉 Done.")