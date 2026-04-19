import pandas as pd
import numpy as np
import os
import sys


INPUT_PATH  = r"E:\Ayesha's VS CODES\GridEye Codes\augmented_dataset.csv"
TOP_N       = 10
Z_THRESHOLD = 2.0


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def get_date_columns(df: pd.DataFrame) -> list:
    exclude = {"CONS_NO", "FLAG", "theft_type"}
    return [col for col in df.columns if col not in exclude and df[col].dtype != object]


def compute_z_scores(df: pd.DataFrame, date_cols: list) -> pd.Series:
    consumption      = df[date_cols].to_numpy(dtype=np.float32)
    mean_per_consumer = np.nanmean(consumption, axis=1)

    global_mean      = np.nanmean(mean_per_consumer)
    global_std       = np.nanstd(mean_per_consumer)
    if global_std == 0:
        global_std = 1

    z_scores         = (mean_per_consumer - global_mean) / global_std
    return pd.Series(z_scores, index=df.index)


def run_anomaly_detection(df: pd.DataFrame, z_scores: pd.Series):
    print("=" * 55)
    print("STEP 1 — Z-SCORE ANOMALY DETECTION")
    print("=" * 55)

    date_cols         = get_date_columns(df)
    consumption       = df[date_cols].to_numpy(dtype=np.float32)
    mean_per_consumer = np.nanmean(consumption, axis=1)

    print(f"Total consumers     : {len(df)}")
    print(f"Z-score threshold   : ±{Z_THRESHOLD}")
    print(f"Global mean         : {np.nanmean(mean_per_consumer):.4f}")
    print(f"Global std          : {np.nanstd(mean_per_consumer):.4f}")

    flagged           = (z_scores.abs() > Z_THRESHOLD).sum()
    print(f"Flagged anomalies   : {flagged}  ({flagged / len(df) * 100:.2f}%)")
    print()

    return mean_per_consumer


def display_top_anomalies(df: pd.DataFrame, z_scores: pd.Series, mean_per_consumer):
    print("=" * 55)
    print(f"STEP 2 — TOP {TOP_N} SUSPICIOUS CONSUMERS")
    print("=" * 55)

    top_indices = z_scores.nlargest(TOP_N).index

    results = pd.DataFrame({
        "Consumer ID"     : df.loc[top_indices, "CONS_NO"].values if "CONS_NO" in df.columns else top_indices.tolist(),
        "Actual FLAG"     : df.loc[top_indices, "FLAG"].values,
        "Mean Consumption": np.round(mean_per_consumer[top_indices], 4),
        "Z-Score"         : np.round(z_scores.loc[top_indices].values, 4),
    })

    results["Verdict"] = results["Z-Score"].apply(
        lambda z: "Anomaly Detected" if abs(z) > Z_THRESHOLD else "Normal"
    )

    print(results.to_string(index=False))
    print()

    correct = (results["Actual FLAG"] == 1).sum()
    print(f"Theft correctly flagged : {correct} / {TOP_N}  ({correct / TOP_N * 100:.1f}%)")
    print()


def run_stage1_pipeline(input_path: str):
    print("\n" + "=" * 55)
    print("  GridEye — Stage 1: Anomaly Detection")
    print("=" * 55 + "\n")

    df                 = load_dataset(input_path)
    date_cols          = get_date_columns(df)
    z_scores           = compute_z_scores(df, date_cols)
    mean_per_consumer  = run_anomaly_detection(df, z_scores)
    display_top_anomalies(df, z_scores, mean_per_consumer)

    print("=" * 55)
    print("Stage 1 Complete.")
    print("=" * 55 + "\n")


if __name__ == "__main__":
    run_stage1_pipeline(INPUT_PATH)