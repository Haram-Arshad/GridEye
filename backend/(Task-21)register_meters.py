import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

METERS = [
    {"meterId": "CON-KHI-001", "city": "Karachi", "area": "Gulshan-e-Iqbal, Karachi", "lat": 24.921, "lng": 67.092},
    {"meterId": "CON-LHR-001", "city": "Lahore", "area": "Model Town, Lahore", "lat": 31.521, "lng": 74.329},
    {"meterId": "CON-ISB-001", "city": "Islamabad", "area": "F-10 Sector, Islamabad", "lat": 33.668, "lng": 73.032},
    {"meterId": "CON-FSD-001", "city": "Faisalabad", "area": "Peoples Colony, Faisalabad", "lat": 31.412, "lng": 73.111},
    {"meterId": "CON-MUL-001", "city": "Multan", "area": "Shah Rukn-e-Alam, Multan", "lat": 30.201, "lng": 71.478},
    {"meterId": "CON-PSH-001", "city": "Peshawar", "area": "Hayatabad, Peshawar", "lat": 33.998, "lng": 71.572},
    {"meterId": "CON-QTA-001", "city": "Quetta", "area": "Satellite Town, Quetta", "lat": 30.182, "lng": 67.002},
    {"meterId": "CON-SKT-001", "city": "Sialkot", "area": "Cantt Area, Sialkot", "lat": 32.501, "lng": 74.521},
    {"meterId": "CON-GWL-001", "city": "Gujranwala", "area": "Trust Colony, Gujranwala", "lat": 32.178, "lng": 74.221},
    {"meterId": "CON-HYD-001", "city": "Hyderabad", "area": "Latifabad, Hyderabad", "lat": 25.401, "lng": 68.372},
    {"meterId": "CON-BWP-001", "city": "Bahawalpur", "area": "Model Town, Bahawalpur", "lat": 29.401, "lng": 71.681},
    {"meterId": "CON-SKR-001", "city": "Sukkur", "area": "Rohri Road, Sukkur", "lat": 27.701, "lng": 68.872},
]

for m in METERS:
    ref  = db.collection("meters").document(m["meterId"])
    snap = ref.get()

    doc = {
        "meterId": m["meterId"],
        "city":    m["city"],
        "area":    m["area"],
        "lat":     m["lat"],
        "lng":     m["lng"],
    }
    if not snap.exists:
        doc["registration"] = "pending"   

    ref.set(doc, merge=True)              
                                          

    state = "already existed" if snap.exists else "created (pending)"
    print(f"✅ {m['meterId']} — {state}")

print("\n🎉 12 meters registered/synced successfully!")