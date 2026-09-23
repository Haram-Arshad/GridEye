import pandas as pd
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
df = pd.read_csv(os.path.join(BASE_DIR, "dataset_cleaned.csv"))

date_cols = [col for col in df.columns if col not in ["CONS_NO", "FLAG", "theft_type"]]

total_cells = df[date_cols].size
zero_count = (df[date_cols] == 0).sum().sum()
zero_pct = (zero_count / total_cells) * 100

print(f"Total Readings : {total_cells:,}")
print(f"Zero Readings  : {zero_count:,} ({zero_pct:.2f}%)")