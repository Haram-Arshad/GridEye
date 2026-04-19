import random
import time
from datetime import datetime


CONSUMER_IDS = [
    "CONS_001", "CONS_002", "CONS_003", "CONS_004", "CONS_005"
]

STATUS_WEIGHTS = {
    "Normal" : 0.70,
    "Fault"  : 0.15,
    "Theft"  : 0.15,
}

INTERVAL_SECONDS = 5


def get_random_status() -> str:
    statuses     = list(STATUS_WEIGHTS.keys())
    weights      = list(STATUS_WEIGHTS.values())
    return random.choices(statuses, weights=weights, k=1)[0]


def get_status_label(status: str) -> str:
    labels = {
        "Normal" : "NORMAL  —  No anomaly detected.",
        "Fault"  : "FAULT   —  Technical meter fault detected.",
        "Theft"  : "THEFT   —  Energy theft pattern detected!",
    }
    return labels.get(status, status)


def simulate_reading(consumer_id: str) -> dict:
    status      = get_random_status()
    consumption = round(random.uniform(2.5, 45.0), 2)

    if status == "Theft":
        consumption = round(consumption * random.uniform(0.1, 0.4), 2)
    elif status == "Fault":
        consumption = round(consumption * random.uniform(0.0, 0.15), 2)

    return {
        "consumer_id" : consumer_id,
        "status"      : status,
        "consumption" : consumption,
        "timestamp"   : datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }


def display_reading(reading: dict):
    print("=" * 55)
    print(f"  Timestamp    : {reading['timestamp']}")
    print(f"  Consumer ID  : {reading['consumer_id']}")
    print(f"  Consumption  : {reading['consumption']} kWh")
    print(f"  Status       : {get_status_label(reading['status'])}")
    print("=" * 55)
    print()


def run_simulator():
    print("\n" + "=" * 55)
    print("  GridEye — Firebase Meter Status Simulator")
    print("=" * 55)
    print(f"  Monitoring {len(CONSUMER_IDS)} consumers")
    print(f"  Interval     : {INTERVAL_SECONDS} seconds")
    print(f"  Press Ctrl+C to stop.")
    print("=" * 55 + "\n")

    try:
        while True:
            consumer_id = random.choice(CONSUMER_IDS)
            reading     = simulate_reading(consumer_id)
            display_reading(reading)
            time.sleep(INTERVAL_SECONDS)

    except KeyboardInterrupt:
        print("\n" + "=" * 55)
        print("  Simulator stopped.")
        print("=" * 55 + "\n")


if __name__ == "__main__":
    run_simulator()