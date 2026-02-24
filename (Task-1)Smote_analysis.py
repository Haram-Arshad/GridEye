# smote_analysis.py
# -----------------------------

# 1️⃣ Libraries
import pandas as pd
from imblearn.over_sampling import SMOTE
from collections import Counter

# 2️⃣ Load dataset
df = pd.read_csv("dataset.csv")
print("✅ Dataset Loaded Successfully!\n")

# First 5 rows
print("First 5 Rows (Head):")
print(df.head())

# Dataset shape
print("\nDataset Shape (Rows, Columns):", df.shape)

# Original class distribution
print("\nClass Distribution (FLAG):")
print(df['FLAG'].value_counts())

# 3️⃣ Handle missing values (numeric columns only)
num_cols = df.select_dtypes(include=['number']).columns  # int + float
df[num_cols] = df[num_cols].fillna(df[num_cols].median())
print("\n✅ Missing values in numeric columns filled!\n")

# 4️⃣ Features and Target
X = df.drop('FLAG', axis=1)
y = df['FLAG']

# 5️⃣ Select only numeric features for SMOTE
X_numeric = X.select_dtypes(include=['number'])
print("Numeric features shape for SMOTE:", X_numeric.shape)

# Optional: Test on a sample if memory issues
# sample_size = 10000
# X_numeric = X_numeric.sample(sample_size, random_state=42)
# y = y[X_numeric.index]

# 6️⃣ Apply SMOTE
smote = SMOTE(random_state=42)
X_resampled, y_resampled = smote.fit_resample(X_numeric, y)

# 7️⃣ Check class balance
print("\nBefore SMOTE:", Counter(y))
print("After SMOTE:", Counter(y_resampled))

# 8️⃣ Create new balanced DataFrame
df_resampled = pd.DataFrame(X_resampled, columns=X_numeric.columns)
df_resampled['FLAG'] = y_resampled
print("\nFirst 5 Rows of Resampled Data:")
print(df_resampled.head())

# 9️⃣ Save balanced dataset
df_resampled.to_csv("dataset_balanced.csv", index=False)
print("\n✅ Balanced dataset saved as 'dataset_balanced.csv'")