# Task 7: Stage-1 Anomaly Detection

import pandas as pd
import numpy as np

# Load cleaned dataset
df = pd.read_csv("cleaned_dataset.csv")

print("Dataset Loaded!")

# Scan first 100 rows
sample_df = df.head(100)

# Extract IDs
consumer_ids = sample_df["CONS_NO"]

# Select energy consumption columns
energy_data = sample_df.drop(columns=["CONS_NO", "FLAG"])

# Calculate mean consumption for each consumer
mean_consumption = energy_data.mean(axis=1)

# Calculate anomaly score using Z-score
global_mean = mean_consumption.mean()
global_std = mean_consumption.std()

z_scores = (mean_consumption - global_mean) / global_std

# Get Top 5 anomalies
top5_indices = z_scores.nlargest(5).index

# Get anomaly IDs
anomaly_ids = consumer_ids.loc[top5_indices]

print("\nSuspicious Consumers (Anomaly IDs):")
print(anomaly_ids.tolist())