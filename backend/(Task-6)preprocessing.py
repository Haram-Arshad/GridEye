# Task 6: Final Data Preprocessing & Scaling

import pandas as pd
from sklearn.preprocessing import MinMaxScaler

# Load Dataset
df = pd.read_csv("dataset.csv")

print("Dataset Loaded Successfully!")

# Separate ID and Label columns
id_column = df["CONS_NO"]
label_column = df["FLAG"]

# Select energy consumption columns
energy_data = df.drop(columns=["CONS_NO", "FLAG"])

# 👉 YAHAN YE LINE ADD KARO
energy_data = energy_data.fillna(0)

# Initialize scaler
scaler = MinMaxScaler(feature_range=(0,1))

# Apply scaling
scaled_energy = scaler.fit_transform(energy_data)

# Convert back to dataframe
scaled_df = pd.DataFrame(scaled_energy, columns=energy_data.columns)

# Add ID and FLAG back
scaled_df.insert(0, "CONS_NO", id_column)
scaled_df.insert(1, "FLAG", label_column)

print("Scaling Applied Successfully!")

# Save cleaned dataset
scaled_df.to_csv("cleaned_dataset.csv", index=False)
scaled_df.to_pickle("cleaned_dataset.pkl")

print("Cleaned Dataset Saved Successfully!")