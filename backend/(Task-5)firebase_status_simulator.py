import random
import time

statuses = ["Normal", "Fault", "Theft"]

while True:
    status = random.choice(statuses)

    print("Meter Status:", status)

    time.sleep(5)