import pandas as pd
import numpy as np
import os
import sys
from imblearn.over_sampling import SMOTE
from sklearn.model_selection import train_test_split


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def get_date_columns(df: pd.DataFrame) -> list:
    return [col for col in df.columns if col not in ["CONS_NO", "FLAG", "theft_type"]]


def split_data(df: pd.DataFrame, date_cols: list):
    """
    STEP 1 — Train/Test split PEHLE (SMOTE se pehle).
    Test set ko original imbalance ke saath untouched rakha jata hai,
    taake evaluation asli duniya jaisi ho.
    """
    print("=" * 50)
    print("STEP 1 — TRAIN / TEST SPLIT (before SMOTE)")
    print("=" * 50)

    if "FLAG" not in df.columns:
        print("Error: 'FLAG' column not found.")
        sys.exit(1)

    df = df.copy()
    df["FLAG"] = df["FLAG"].round().astype(int)

    train_df, test_df = train_test_split(
        df, test_size=0.2, stratify=df["FLAG"], random_state=42
    )

    print(f"Total consumers : {len(df)}")
    print(f"Train consumers : {len(train_df)}  {train_df['FLAG'].value_counts().to_dict()}")
    print(f"Test  consumers : {len(test_df)}   {test_df['FLAG'].value_counts().to_dict()}")
    print()

    return train_df, test_df


def apply_smote_on_train(train_df: pd.DataFrame, date_cols: list) -> pd.DataFrame:
    """
    STEP 2 — SMOTE sirf TRAIN data par.
    (Test data ko kabhi SMOTE nahi kiya jata.)
    """
    print("=" * 50)
    print("STEP 2 — APPLYING SMOTE (train only)")
    print("=" * 50)

    X = train_df[date_cols]
    y = train_df["FLAG"].astype(int)

    print("Class Distribution BEFORE SMOTE (train):")
    print(y.value_counts().to_dict())

    smote = SMOTE(random_state=42)
    X_resampled, y_resampled = smote.fit_resample(X, y)

    df_balanced = pd.DataFrame(X_resampled, columns=date_cols)
    df_balanced.insert(0, "FLAG", y_resampled)

    print("Class Distribution AFTER SMOTE (train):")
    print(df_balanced["FLAG"].value_counts().to_dict())
    print(f"Rows after SMOTE : {len(df_balanced)}")
    print()

    return df_balanced


def save_datasets(train_bal: pd.DataFrame, test_df: pd.DataFrame,
                  date_cols: list, train_path: str, test_path: str):
    print("=" * 50)
    print("STEP 3 — SAVING DATASETS")
    print("=" * 50)

    train_bal.to_csv(train_path, index=False)

    # Test file: sirf FLAG + date columns (same column order as train)
    test_out = test_df[["FLAG"] + date_cols]
    test_out.to_csv(test_path, index=False)

    print(f"Train (balanced) saved : {train_path}   rows={len(train_bal)}")
    print(f"Test  (original) saved : {test_path}   rows={len(test_out)}")
    print()


def run_smote_pipeline(input_path: str, train_path: str, test_path: str):
    print("\n" + "=" * 50)
    print("  GridEye — Split + SMOTE (leakage-free)")
    print("=" * 50 + "\n")

    df        = load_dataset(input_path)
    date_cols = get_date_columns(df)

    train_df, test_df = split_data(df, date_cols)
    train_bal         = apply_smote_on_train(train_df, date_cols)
    save_datasets(train_bal, test_df, date_cols, train_path, test_path)

    print("=" * 50)
    print("Split + SMOTE Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

    # Input: Imputed & clean file from Task-2
    INPUT_PATH = os.path.join(BASE_DIR, "dataset_cleaned.csv")

    # Outputs
    TRAIN_PATH = os.path.join(BASE_DIR, "balanced_train.csv")   # SMOTE-balanced (sirf training ke liye)
    TEST_PATH  = os.path.join(BASE_DIR, "test_raw.csv")         # original imbalance, untouched

    run_smote_pipeline(INPUT_PATH, TRAIN_PATH, TEST_PATH)