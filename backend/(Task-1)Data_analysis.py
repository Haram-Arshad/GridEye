import pandas as pd
import os
import sys


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def get_date_columns(df: pd.DataFrame) -> list:
    return [col for col in df.columns if col not in ["CONS_NO", "FLAG"]]


def display_overview(df: pd.DataFrame):
    date_cols = get_date_columns(df)
    print("=" * 50)
    print("DATASET OVERVIEW")
    print("=" * 50)
    print(f"Total Consumers     : {df.shape[0]}")
    print(f"Total Columns       : {df.shape[1]}")
    print(f"Date Columns        : {len(date_cols)}  ({date_cols[0]}  →  {date_cols[-1]})")
    print(f"Consumer ID Column  : CONS_NO")
    print(f"Label Column        : FLAG (0 = Normal, 1 = Theft)")
    print()


def display_class_distribution(df: pd.DataFrame):
    print("=" * 50)
    print("CLASS DISTRIBUTION (FLAG Column)")
    print("=" * 50)

    if "FLAG" not in df.columns:
        print("Warning: 'FLAG' column not found in dataset.")
        return

    counts = df["FLAG"].value_counts()
    dist   = df["FLAG"].value_counts(normalize=True) * 100

    normal_count = counts.get(0, 0)
    theft_count  = counts.get(1, 0)
    normal_pct   = dist.get(0, 0.0)
    theft_pct    = dist.get(1, 0.0)

    print(f"Normal (0) : {normal_count:>6} consumers  ({normal_pct:.2f}%)")
    print(f"Theft  (1) : {theft_count:>6} consumers  ({theft_pct:.2f}%)")

    if theft_pct < 20:
        print("\nNote: Class imbalance detected. Hybrid SMOTE is recommended before model training.")
    print()


def display_missing_values(df: pd.DataFrame):
    print("=" * 50)
    print("MISSING VALUE ANALYSIS")
    print("=" * 50)

    date_cols   = get_date_columns(df)
    date_df     = df[date_cols]

    total_cells   = date_df.size
    total_missing = date_df.isnull().sum().sum()
    missing_pct   = (total_missing / total_cells) * 100

    consumers_with_nulls = date_df.isnull().any(axis=1).sum()

    print(f"Total date readings     : {total_cells:,}")
    print(f"Total missing values    : {total_missing:,}  ({missing_pct:.2f}%)")
    print(f"Consumers with any NaN  : {consumers_with_nulls} out of {df.shape[0]}")

    if total_missing > 0:
        print("\nNote: Missing values detected. Data cleaning pipeline required before training.")
    else:
        print("\nNo missing values detected.")
    print()


def display_consumption_stats(df: pd.DataFrame):
    print("=" * 50)
    print("ENERGY CONSUMPTION STATISTICS")
    print("=" * 50)

    date_cols = get_date_columns(df)

    all_values = df[date_cols].values.flatten()
    all_values = all_values[~pd.isnull(all_values)]

    print(f"Mean daily consumption   : {all_values.mean():.2f}")
    print(f"Median daily consumption : {pd.Series(all_values).median():.2f}")
    print(f"Std deviation            : {all_values.std():.2f}")
    print(f"Min value                : {all_values.min():.2f}")
    print(f"Max value                : {all_values.max():.2f}")
    print()

    normal_df = df[df["FLAG"] == 0][date_cols].values.flatten()
    theft_df  = df[df["FLAG"] == 1][date_cols].values.flatten()

    normal_df = normal_df[~pd.isnull(normal_df)]
    theft_df  = theft_df[~pd.isnull(theft_df)]

    print(f"Avg consumption — Normal consumers : {normal_df.mean():.2f}")
    print(f"Avg consumption — Theft  consumers : {theft_df.mean():.2f}")
    print()


def run_analysis(file_path: str):
    print("\n" + "=" * 50)
    print("  GridEye — Data Intelligence & Preprocessing")
    print("=" * 50 + "\n")

    df = load_dataset(file_path)

    display_overview(df)
    display_class_distribution(df)
    display_missing_values(df)
    display_consumption_stats(df)

    print("=" * 50)
    print("Analysis Complete.")
    print("=" * 50 + "\n")

    return df


if __name__ == "__main__":
    DATASET_PATH = r"E:\Ayesha's VS CODES\GridEye Codes\augmented_dataset.csv"
    df = run_analysis(DATASET_PATH)
