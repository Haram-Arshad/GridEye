import pandas as pd
import numpy as np
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Optional: Task-7 ke synthetic theft rows use karne hon to True karein
# (pehle Task-7 chalana zaroori hai). Default False.
USE_THEFT_AUGMENTATION = False

# Task-3 ke naye outputs
TRAIN_IN  = os.path.join(BASE_DIR, "balanced_train_aug.csv" if USE_THEFT_AUGMENTATION
                                   else "balanced_train.csv")
TEST_IN   = os.path.join(BASE_DIR, "test_raw.csv")

# Task-12 in files ko use karega
TRAIN_OUT = os.path.join(BASE_DIR, "features_train.csv")
TEST_OUT  = os.path.join(BASE_DIR, "features_test.csv")


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def get_date_columns(df: pd.DataFrame) -> list:
    return [col for col in df.columns if col not in ["CONS_NO", "FLAG", "theft_type"]]


def extract_features(df: pd.DataFrame):
    print("=" * 50)
    print("STEP 1 — FEATURE EXTRACTION")
    print("=" * 50)

    date_cols   = get_date_columns(df)
    consumption = df[date_cols].to_numpy(dtype=np.float32)

    # Har feature har consumer (row) ki apni readings se nikalta hai,
    # is liye train/test ke beech koi leakage nahi hoti.
    df["Mean_Consumption"]   = np.nanmean(consumption, axis=1)
    df["Peak_Usage"]         = np.nanmax(consumption, axis=1)
    df["Min_Usage"]          = np.nanmin(consumption, axis=1)
    df["Std_Consumption"]    = np.nanstd(consumption, axis=1)
    df["Usage_Range"]        = df["Peak_Usage"] - df["Min_Usage"]
    df["Zero_Day_Count"]     = (consumption == 0).sum(axis=1)
    df["Missing_Day_Count"]  = pd.isna(df[date_cols]).sum(axis=1)

    features = [
        "Mean_Consumption",
        "Peak_Usage",
        "Min_Usage",
        "Std_Consumption",
        "Usage_Range",
        "Zero_Day_Count",
        "Missing_Day_Count",
    ]

    for feat in features:
        print(f"  + {feat}")
    print()

    return df, features


def display_summary(df: pd.DataFrame, features: list):
    print("=" * 50)
    print("STEP 2 — FEATURE SUMMARY")
    print("=" * 50)

    print(df[features].describe().round(2).to_string())
    print()

    if "FLAG" in df.columns:
        print("Per-Class Averages (Normal vs Theft):")
        print("-" * 50)
        print(df.groupby("FLAG")[features].mean().round(2).to_string())
        print()


def save_dataset(df: pd.DataFrame, output_path: str):
    print("=" * 50)
    print("STEP 3 — SAVING DATASET")
    print("=" * 50)

    df.to_csv(output_path, index=False)

    print(f"Output file    : {output_path}")
    print(f"Total rows     : {len(df)}")
    print(f"Total columns  : {df.shape[1]}")
    print()


def run_feature_engineering(input_path: str, output_path: str):
    print("\n" + "=" * 50)
    print("  GridEye — Feature Engineering Pipeline")
    print("=" * 50 + "\n")

    df           = load_dataset(input_path)
    df, features = extract_features(df)
    display_summary(df, features)
    save_dataset(df, output_path)

    print("=" * 50)
    print("Pipeline Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    # Dono files par same feature engineering chalti hai
    run_feature_engineering(TRAIN_IN, TRAIN_OUT)
    run_feature_engineering(TEST_IN,  TEST_OUT)