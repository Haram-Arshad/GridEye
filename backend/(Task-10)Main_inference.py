# GridEye Final Inference Script

import pandas as pd
import numpy as np

# Load dataset
df = pd.read_csv("cleaned_dataset.csv")

print("GridEye Model Started")

# Take one sample row
sample = df.iloc[0]

consumer_id = sample["CONS_NO"]

# Energy data
energy_data = sample.drop(["CONS_NO", "FLAG"])

# Simple anomaly logic
mean_value = energy_data.mean()

if mean_value > 0.7:
    anomaly = True
else:
    anomaly = False


# Classification logic
def classify_anomaly(voltage, current):

    if voltage < 210 and current < 5:
        return "Technical Fault"

    elif current < 5 and voltage >= 210:
        return "Electricity Theft"

    else:
        return "Normal"


# Demo voltage/current values
voltage = 220
current = 3

result = classify_anomaly(voltage, current)

print("\nConsumer ID:", consumer_id)

if anomaly:
    print("Anomaly Detected!")
    print("Classification:", result)

else:
    print("No Anomaly Detected")


# Model Accuracy = 0.04    