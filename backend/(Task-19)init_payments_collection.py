import os
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def init_firestore():
    import firebase_admin
    from firebase_admin import credentials, firestore
    if not firebase_admin._apps:
        firebase_admin.initialize_app(
            credentials.Certificate(os.path.join(BASE_DIR, "serviceKey.json")))
    return firestore.client()


def main():
    print("\n" + "=" * 60)
    print("  GRIDEYE — payments collection seeder")
    print("=" * 60 + "\n")

    db = init_firestore()
    print("✅ Firestore connected")

    col = db.collection("payments")

    existing = list(col.limit(1).stream())
    if existing:
        print(f"ℹ️  'payments' collection pehle se maujood hai "
              f"({len(list(col.stream()))} doc(s)) — kuch nahi badla.")
        return

    doc_id = "_example_schema"
    col.document(doc_id).set({
        "meterID":     "CON-KHI-001",
        "amount":      0,
        "phoneNumber": "03000000000",
        "status":      "Example",
        "method":      "JazzCash (Simulated)",
        "timestamp":   datetime.now(timezone.utc),
        "note":        "Placeholder doc — safe to delete. Real payments "
                        "are written automatically by the app with a "
                        "random txnId (e.g. JC5493028174).",
    })
    print(f"✅ 'payments' collection ban gayi — placeholder doc likha: {doc_id}")
    print("   (Real payments app khud likhega jab pehla asli payment hoga.)")


if __name__ == "__main__":
    main()