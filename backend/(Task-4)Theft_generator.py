# -----------------------------
# (Task-4)Theft_generator.py
# GridEye FYP
# Synthetic Theft Generation
# -----------------------------

import pandas as pd
import numpy as np

# 1️⃣ Load balanced dataset
df = pd.read_csv("dataset_balanced.csv")

print("Dataset Loaded Successfully")
print("Dataset Shape:", df.shape)

# 2️⃣ Numeric columns identify karo
numeric_cols = df.select_dtypes(include=['int64', 'float64']).columns

# 3️⃣ Normal data
normal_df = df.copy()
normal_df["theft_type"] = "Normal"

# 4️⃣ Partial Bypass Theft
partial_bypass = df.copy()

for col in numeric_cols:
    partial_bypass[col] = partial_bypass[col] * np.random.uniform(0.5, 0.8)

partial_bypass["theft_type"] = "Partial_Bypass"

# 5️⃣ Total Bypass Theft
total_bypass = df.copy()

for col in numeric_cols:
    total_bypass[col] = total_bypass[col] * np.random.uniform(0.0, 0.2)

total_bypass["theft_type"] = "Total_Bypass"

# 6️⃣ Price Shifting Theft
price_shift = df.copy()

for col in numeric_cols:
    price_shift[col] = price_shift[col] * np.random.uniform(0.7, 1.2)

price_shift["theft_type"] = "Price_Shifting"

# 7️⃣ Combine all data
final_dataset = pd.concat(
    [normal_df, partial_bypass, total_bypass, price_shift],
    ignore_index=True
)

print("Final Dataset Shape:", final_dataset.shape)

# 8️⃣ Save new dataset
final_dataset.to_csv("augmented_dataset.csv", index=False)

print("Synthetic Theft Generated Successfully")
print("Augmented Dataset Saved: augmented_dataset.csv")