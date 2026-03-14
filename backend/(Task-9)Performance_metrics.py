# Task 9: Performance Metrics & Validation

import pandas as pd
import numpy as np
from sklearn.metrics import accuracy_score, precision_score, recall_score, confusion_matrix

# Load cleaned dataset
df = pd.read_csv("cleaned_dataset.csv")

print("Dataset Loaded!")

# Use first 100 rows as test data
test_df = df.head(100)

# Actual labels
y_true = test_df["FLAG"]

# Select energy columns
energy_data = test_df.drop(columns=["CONS_NO", "FLAG"])

# Simple anomaly detection logic
mean_consumption = energy_data.mean(axis=1)

global_mean = mean_consumption.mean()
global_std = mean_consumption.std()

z_scores = (mean_consumption - global_mean) / global_std

# Predicted labels
y_pred = (z_scores > 1.5).astype(int)

# Metrics
accuracy = accuracy_score(y_true, y_pred)
precision = precision_score(y_true, y_pred)
recall = recall_score(y_true, y_pred)

print("\nAccuracy:", accuracy)
print("Precision:", precision)
print("Recall:", recall)

# Confusion Matrix
cm = confusion_matrix(y_true, y_pred)

print("\nConfusion Matrix:")
print(cm)