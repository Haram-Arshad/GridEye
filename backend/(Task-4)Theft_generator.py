import pandas as pd
import numpy as np
import os
import sys


INPUT_PATH  = r"E:\Ayesha's VS CODES\GridEye Codes\balanced_data_final.csv"
OUTPUT_PATH = r"E:\Ayesha's VS CODES\GridEye Codes\augmented_dataset.csv"


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def get_date_columns(df: pd.DataFrame) -> list:
    return [col for col in df.columns if col not in ["CONS_NO", "FLAG"]]


def generate_normal(df: pd.DataFrame) -> pd.DataFrame:
    result               = df.copy()
    result["theft_type"] = "Normal"
    return result


def generate_partial_bypass(df: pd.DataFrame, date_cols: list) -> pd.DataFrame:
    result = df.copy()
    for col in date_cols:
        mask             = result[col].notna()
        result.loc[mask, col] = result.loc[mask, col] * np.random.uniform(0.5, 0.8, mask.sum())
    result["theft_type"] = "Partial_Bypass"
    return result


def generate_total_bypass(df: pd.DataFrame, date_cols: list) -> pd.DataFrame:
    result = df.copy()
    for col in date_cols:
        mask             = result[col].notna()
        result.loc[mask, col] = result.loc[mask, col] * np.random.uniform(0.0, 0.2, mask.sum())
    result["theft_type"] = "Total_Bypass"
    return result


def generate_price_shifting(df: pd.DataFrame, date_cols: list) -> pd.DataFrame:
    result = df.copy()
    for col in date_cols:
        mask             = result[col].notna()
        result.loc[mask, col] = result.loc[mask, col] * np.random.uniform(0.7, 1.2, mask.sum())
    result["theft_type"] = "Price_Shifting"
    return result


def display_summary(df: pd.DataFrame):
    print("=" * 50)
    print("AUGMENTED DATASET SUMMARY")
    print("=" * 50)

    print(f"Total rows          : {len(df)}")
    print(f"Total columns       : {df.shape[1]}")
    print()

    print("Theft Type Distribution:")
    print("-" * 50)
    counts = df["theft_type"].value_counts()
    for label, count in counts.items():
        pct = count / len(df) * 100
        print(f"  {label:<20} : {count:>6}  ({pct:.2f}%)")
    print()

    print("FLAG Distribution:")
    print("-" * 50)
    flag_counts = df["FLAG"].value_counts()
    for label, count in flag_counts.items():
        pct = count / len(df) * 100
        name = "Normal" if label == 0 else "Theft"
        print(f"  {name} ({label})            : {count:>6}  ({pct:.2f}%)")
    print()


def save_dataset(df: pd.DataFrame, output_path: str):
    print("=" * 50)
    print("SAVING AUGMENTED DATASET")
    print("=" * 50)

    df.to_csv(output_path, index=False)
    print(f"Output file    : {output_path}")
    print(f"Total rows     : {len(df)}")
    print()


def run_theft_generation(input_path: str, output_path: str):
    print("\n" + "=" * 50)
    print("  GridEye — Synthetic Theft Generation Pipeline")
    print("=" * 50 + "\n")

    df        = load_dataset(input_path)
    date_cols = get_date_columns(df)

    print("=" * 50)
    print("STEP 1 — GENERATING THEFT VARIANTS")
    print("=" * 50)

    normal        = generate_normal(df)
    print("  + Normal          — done")

    partial       = generate_partial_bypass(df, date_cols)
    print("  + Partial Bypass  — done")

    total         = generate_total_bypass(df, date_cols)
    print("  + Total Bypass    — done")

    price_shift   = generate_price_shifting(df, date_cols)
    print("  + Price Shifting  — done")
    print()

    print("=" * 50)
    print("STEP 2 — COMBINING ALL VARIANTS")
    print("=" * 50)

    final_df = pd.concat(
        [normal, partial, total, price_shift],
        ignore_index=True
    )
    print(f"Combined shape  : {final_df.shape}\n")

    display_summary(final_df)
    save_dataset(final_df, output_path)

    print("=" * 50)
    print("Pipeline Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    run_theft_generation(INPUT_PATH, OUTPUT_PATH)