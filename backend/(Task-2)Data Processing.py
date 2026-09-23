import pandas as pd
import numpy as np
import os
import sys


# True  -> jin consumers ki KOI bhi reading nahi hai (poori row khali) unhein hata dete hain.
# False -> unhein column-mean se bhar dete hain (sab ki row bilkul same ban jati hai -> model
#          "bilkul average profile = theft" jaisa fake shortcut seekh sakta hai).
DROP_EMPTY_ROWS = True


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def get_date_columns(df: pd.DataFrame) -> list:
    return [col for col in df.columns if col not in ["CONS_NO", "FLAG", "theft_type"]]


def show_missing_report(df: pd.DataFrame, date_cols: list, label: str):
    print("=" * 50)
    print(f"MISSING VALUE REPORT — {label}")
    print("=" * 50)

    total_cells   = df[date_cols].size
    total_missing = df[date_cols].isnull().sum().sum()
    missing_pct   = (total_missing / total_cells) * 100
    rows_with_nan = df[date_cols].isnull().any(axis=1).sum()

    print(f"Total readings          : {total_cells:,}")
    print(f"Total missing values    : {total_missing:,}  ({missing_pct:.2f}%)")
    print(f"Consumers with any NaN  : {rows_with_nan} out of {len(df)}")
    print()

    return total_missing


def clean_dataset(df: pd.DataFrame):
    print("=" * 50)
    print("STEP 1 — DATA CLEANING")
    print("=" * 50)

    if "FLAG" not in df.columns:
        print("Error: 'FLAG' column not found.")
        sys.exit(1)

    df["FLAG"] = df["FLAG"].round().astype(int)
    date_cols  = get_date_columns(df)

    # Make sure date columns are numeric (coerce bad values to NaN too)
    df[date_cols] = df[date_cols].apply(pd.to_numeric, errors="coerce")

    print(f"Total consumers     : {len(df)}")
    print(f"Date columns        : {len(date_cols)}")
    print()

    return df, date_cols


def sort_date_columns(df: pd.DataFrame, date_cols: list):
    """
    SGCC file ke date columns text ki tarah sorted hote hain (1/1, 1/10, 1/11 ... 1/19, 1/2 ...),
    chronological nahi. Forward/back-fill aur EDA time-order maangte hain, is liye
    pehle columns ko asli date ke hisaab se sort karte hain.
    """
    print("=" * 50)
    print("STEP 0 — SORT DATE COLUMNS CHRONOLOGICALLY")
    print("=" * 50)

    s = pd.Series(date_cols)
    parsed = pd.to_datetime(s, format="%m/%d/%Y", errors="coerce")
    if parsed.isna().any():
        parsed = pd.to_datetime(s, errors="coerce")
    if parsed.isna().any():
        print("Warning: kuch column names date nahi ban sake — column order unchanged.\n")
        return df, date_cols

    order       = np.argsort(parsed.values, kind="stable")
    sorted_cols = [date_cols[i] for i in order]
    if sorted_cols == list(date_cols):
        print("Columns pehle se chronological hain.\n")
    else:
        print(f"Columns re-ordered: {date_cols[:4]} ...  ->  {sorted_cols[:4]} ...")
        print(f"Range: {sorted_cols[0]}  ->  {sorted_cols[-1]}\n")

    other_cols = [c for c in df.columns if c not in date_cols]
    return df[other_cols + sorted_cols], sorted_cols


def handle_empty_rows(df: pd.DataFrame, date_cols: list) -> pd.DataFrame:
    print("=" * 50)
    print("STEP 1b — CONSUMERS WITH NO READINGS AT ALL")
    print("=" * 50)

    empty = df[date_cols].isnull().all(axis=1)
    n_empty = int(empty.sum())
    print(f"Completely empty consumers : {n_empty} out of {len(df)}")
    if n_empty:
        print(f"  their FLAG distribution  : {df.loc[empty, 'FLAG'].value_counts().to_dict()}")
        print(f"  overall FLAG distribution: {df['FLAG'].value_counts().to_dict()}")

    if DROP_EMPTY_ROWS and n_empty:
        df = df.loc[~empty].reset_index(drop=True)
        print(f"DROPPED {n_empty} empty consumers. Remaining: {len(df)}  "
              f"{df['FLAG'].value_counts().to_dict()}")
    print()
    return df


def impute_missing_values(df: pd.DataFrame, date_cols: list):
    print("=" * 50)
    print("STEP 2 — MISSING VALUE IMPUTATION")
    print("=" * 50)
    print("Method: Row-wise Forward-Fill + Backward-Fill")
    print("Reason: A missing meter reading means 'no data was transmitted'")
    print("        that day — NOT 'zero consumption'. Filling with each")
    print("        consumer's own nearest available reading is more")
    print("        realistic than filling with 0.")
    print("Fallback: If an entire consumer row is still missing after")
    print("        that (rare), use that column's overall mean.")
    print()

    # 1) Row-wise fill — each consumer's own nearby readings
    df[date_cols] = df[date_cols].T.ffill().bfill().T   # (fast version of row-wise fill)

    # 2) Fallback — column mean for any leftover NaN (whole row was missing)
    remaining_before_fallback = df[date_cols].isnull().sum().sum()
    if remaining_before_fallback > 0:
        df[date_cols] = df[date_cols].fillna(df[date_cols].mean())
        print(f"Rows needing column-mean fallback : {remaining_before_fallback:,} cells")
    else:
        print("No fallback needed — row-wise fill handled everything.")
    print()

    return df


def save_cleaned_dataset(df: pd.DataFrame, output_path: str):
    print("=" * 50)
    print("STEP 3 — SAVING CLEANED DATASET")
    print("=" * 50)

    df.to_csv(output_path, index=False)

    print(f"Output file         : {output_path}")
    print(f"Total rows saved    : {len(df)}")
    print(f"Total columns saved : {df.shape[1]}")
    print()


def run_preprocessing(input_path: str, output_path: str):
    print("\n" + "=" * 50)
    print("  GridEye — Preprocessing (Missing Value Fix)")
    print("=" * 50 + "\n")

    df = load_dataset(input_path)
    df, date_cols = clean_dataset(df)
    df, date_cols = sort_date_columns(df, date_cols)

    show_missing_report(df, date_cols, "BEFORE IMPUTATION")
    df = handle_empty_rows(df, date_cols)

    df = impute_missing_values(df, date_cols)

    remaining = show_missing_report(df, date_cols, "AFTER IMPUTATION")

    if remaining == 0:
        print("✅ All missing values successfully handled.\n")
    else:
        print(f"⚠ {remaining} missing values still remain — check data.\n")

    save_cleaned_dataset(df, output_path)

    print("=" * 50)
    print("Preprocessing Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

    # Input: Raw SGCC dataset file
    INPUT_PATH  = os.path.join(BASE_DIR, "dataset.csv")

    # Output: Imputed & cleaned dataset
    OUTPUT_PATH = os.path.join(BASE_DIR, "dataset_cleaned.csv")

    run_preprocessing(INPUT_PATH, OUTPUT_PATH)