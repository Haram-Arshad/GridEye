
# -----------------------------
# feature_engineering.py
# -----------------------------

import pandas as pd

# Load dataset
df = pd.read_csv("dataset.csv")
print("✅ Dataset Loaded Successfully!")

# Moving Average (7-day window)
df["Moving_Avg_7"] = df.iloc[:, 1:].mean(axis=1)

# Peak Usage (maximum daily consumption)
df["Peak_Usage"] = df.iloc[:, 1:].max(axis=1)

# Save new dataset
df.to_csv("feature_engineered_dataset.csv", index=False)

print("✅ Feature Engineering Completed!")
print("📁 New file saved as: feature_engineered_dataset.csv")

# Display first 5 rows
print(df[["Moving_Avg_7", "Peak_Usage"]].head())