import pandas as pd
import os
import sys
from imblearn.over_sampling import SMOTE


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def clean_and_prepare(df: pd.DataFrame):
    print("=" * 50)
    print("STEP 1 — DATA CLEANING")
    print("=" * 50)

    if "FLAG" not in df.columns:
        print("Error: 'FLAG' column not found.")
        sys.exit(1)

    df["FLAG"] = df["FLAG"].round().astype(int)
    df = df.select_dtypes(include=["number"]).fillna(0)

    counts = df["FLAG"].value_counts()
    dist   = df["FLAG"].value_counts(normalize=True) * 100

    print(f"Total consumers     : {len(df)}")
    print(f"Normal (0)          : {counts.get(0, 0):>6}  ({dist.get(0, 0.0):.2f}%)")
    print(f"Theft  (1)          : {counts.get(1, 0):>6}  ({dist.get(1, 0.0):.2f}%)")
    print(f"Missing values fill : NaN → 0")
    print()

    X = df.drop("FLAG", axis=1)
    y = df["FLAG"]
    return X, y


def apply_smote(X, y):
    print("=" * 50)
    print("STEP 2 — APPLYING HYBRID SMOTE")
    print("=" * 50)

    smote = SMOTE(sampling_strategy="auto", random_state=42)
    X_res, y_res = smote.fit_resample(X, y)

    print(f"SMOTE applied successfully.")
    print(f"Features used       : {X.shape[1]}")
    print(f"Rows before SMOTE   : {len(X)}")
    print(f"Rows after  SMOTE   : {len(X_res)}")
    print()

    return X_res, y_res


def save_balanced_dataset(X_res, y_res, output_path: str):
    print("=" * 50)
    print("STEP 3 — SAVING BALANCED DATASET")
    print("=" * 50)

    balanced_df = pd.concat(
        [pd.DataFrame(X_res), pd.Series(y_res, name="FLAG")],
        axis=1
    )

    counts = balanced_df["FLAG"].value_counts()
    dist   = balanced_df["FLAG"].value_counts(normalize=True) * 100

    balanced_df.to_csv(output_path, index=False)

    print(f"Output file         : {output_path}")
    print(f"Total rows saved    : {len(balanced_df)}")
    print(f"Normal (0)          : {counts.get(0, 0):>6}  ({dist.get(0, 0.0):.2f}%)")
    print(f"Theft  (1)          : {counts.get(1, 0):>6}  ({dist.get(1, 0.0):.2f}%)")
    print()


def run_smote_pipeline(input_path: str, output_path: str):
    print("\n" + "=" * 50)
    print("  GridEye — SMOTE Balancing Pipeline")
    print("=" * 50 + "\n")

    df         = load_dataset(input_path)
    X, y       = clean_and_prepare(df)
    X_res, y_res = apply_smote(X, y)
    save_balanced_dataset(X_res, y_res, output_path)

    print("=" * 50)
    print("Pipeline Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    INPUT_PATH  = r"E:\Ayesha's VS CODES\GridEye Codes\augmented_dataset.csv"
    OUTPUT_PATH = r"E:\Ayesha's VS CODES\GridEye Codes\balanced_data_final.csv"

    run_smote_pipeline(INPUT_PATH, OUTPUT_PATH)