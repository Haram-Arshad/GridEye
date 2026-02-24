import pandas as pd

# Load dataset
df = pd.read_csv("dataset.csv")

print("Dataset Loaded Successfully!\n")

# Print first 5 rows
print("First 5 Rows (Head):")
print(df.head())

# Print shape
print("\nDataset Shape (Rows, Columns):")
print(df.shape)

# Check class distribution
print("\nClass Distribution (FLAG):")
print(df['FLAG'].value_counts())