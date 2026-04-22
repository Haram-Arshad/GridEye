import firebase_admin
from firebase_admin import credentials, firestore
import random
import time
from datetime import datetime
import os

# 1. FIREBASE CONNECTION SETUP
KEY_PATH = os.path.join(os.path.dirname(__file__), 'serviceKey.json')

if not os.path.exists(KEY_PATH):
    print(f"Error: serviceKey.json NOT FOUND at {KEY_PATH}")
    exit()

cred = credentials.Certificate(KEY_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

print(">>> SUCCESS: GridEye Backend Connected to Firebase Cloud!")

# --- SIMULATOR CONFIGURATION ---
CONSUMER_IDS = ["MTR-KHI-001", "MTR-KHI-002", "MTR-KHI-003", "MTR-KHI-004", "MTR-KHI-005"]
STATUS_WEIGHTS = {"Normal": 0.70, "Fault": 0.15, "Theft": 0.15}
INTERVAL_SECONDS = 5 

def get_random_status():
    return random.choices(list(STATUS_WEIGHTS.keys()), weights=list(STATUS_WEIGHTS.values()), k=1)[0]

def simulate_reading(meter_id):
    status = get_random_status()
    load_val = round(random.uniform(5.5, 30.0), 2)

    if status == "Theft":
        load_val = round(load_val * random.uniform(0.1, 0.4), 2)
    elif status == "Fault":
        load_val = 0.00 

    # SIRF WAHI FIELDS JO METER READINGS SS MEIN HAIN (No Time Here)
    return {
        "currentLoad": str(load_val),
        "meterId": meter_id,
        "status": status,
        "lat": 24.871, 
        "lng": 67.05
    }

def upload_to_firebase(reading):
    try:
        # A. Update 'MeterReadings' (Wahi fields jayengi jo simulate_reading ne di hain)
        db.collection("MeterReadings").add(reading)
        
        # B. Alerts Logic (Ismein hum time khud add karenge Alerts SS ke liye)
        if reading["status"] != "Normal":
            alert_data = {
                "address": "Sector G, Karachi",
                "description": f"Urgent: {reading['status']} detected on Meter {reading['meterId']}.",
                "isRead": False,
                "meterId": reading["meterId"],
                "status": reading["status"],
                "time": datetime.now(), # <--- Alerts SS ke liye yahan time add kar diya
                "title": "Energy Theft Alert" if reading["status"] == "Theft" else "Technical Fault",
                "type": "Warning"
            }
            db.collection("Alerts").add(alert_data)
            
            if reading["status"] == "Fault":
                db.collection("Faults").add(alert_data)

        print(f"[LIVE] Data Pushed: {reading['meterId']} | Load: {reading['currentLoad']} | Status: {reading['status']}")
    
    except Exception as e:
        print(f"[X] Upload Failed: {e}")

def run_simulator():
    print("\n" + "="*50)
    print("  GRIDEYE LIVE SIMULATOR IS RUNNING...")
    print("  Press Ctrl+C to stop.")
    print("="*50 + "\n")

    try:
        while True:
            meter_id = random.choice(CONSUMER_IDS)
            reading = simulate_reading(meter_id)
            upload_to_firebase(reading)
            time.sleep(INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("\nSimulator stopped. Data pushing halted.")

if __name__ == "__main__":
    run_simulator()