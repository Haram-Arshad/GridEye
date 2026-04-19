import pandas as pd
import numpy as np
from sklearn.preprocessing import MinMaxScaler
import joblib
import os
import sys


def load_dataset(file_path: str) -> pd.DataFrame:
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)
    df = pd.read_csv(file_path)
    print(f"Dataset loaded successfully: {file_path}\n")
    return df


def separate_features_and_label(df: pd.DataFrame):
    print("=" * 50)
    print("STEP 1 — FEATURE & LABEL SEPARATION")
    print("=" * 50)

    if "FLAG" not in df.columns:
        print("Error: 'FLAG' column not found.")
        sys.exit(1)

    X = df.drop(columns=["FLAG"])
    y = df["FLAG"]

    print(f"Total samples       : {len(df)}")
    print(f"Feature columns     : {X.shape[1]}")
    print(f"Label column        : FLAG")
    print(f"Normal (0)          : {(y == 0).sum():>6}  ({(y == 0).mean() * 100:.2f}%)")
    print(f"Theft  (1)          : {(y == 1).sum():>6}  ({(y == 1).mean() * 100:.2f}%)")
    print()

    return X, y


def scale_features(X, output_dir: str):
    print("=" * 50)
    print("STEP 2 — MinMax SCALING")
    print("=" * 50)

    scaler   = MinMaxScaler(feature_range=(0, 1))
    X_scaled = scaler.fit_transform(X)

    scaler_path = os.path.join(output_dir, "scaler.pkl")
    joblib.dump(scaler, scaler_path)

    print(f"Scaling range       : [0, 1]")
    print(f"Features scaled     : {X_scaled.shape[1]}")
    print(f"Value min (post)    : {X_scaled.min():.4f}")
    print(f"Value max (post)    : {X_scaled.max():.4f}")
    print(f"Scaler saved        : {scaler_path}")
    print()

    return X_scaled


def reshape_for_lstm(X_scaled):
    print("=" * 50)
    print("STEP 3 — LSTM 3D RESHAPING")
    print("=" * 50)

    X_reshaped = X_scaled.reshape((X_scaled.shape[0], X_scaled.shape[1], 1))

    print(f"Shape before reshape : {X_scaled.shape}   → (samples, features)")
    print(f"Shape after  reshape : {X_reshaped.shape}  → (samples, time_steps, 1)")
    print()

    return X_reshaped


def save_arrays(X_reshaped, y, output_dir: str):
    print("=" * 50)
    print("STEP 4 — SAVING PROCESSED ARRAYS")
    print("=" * 50)

    x_path = os.path.join(output_dir, "X_train.npy")
    y_path = os.path.join(output_dir, "y_train.npy")

    np.save(x_path, X_reshaped)
    np.save(y_path, y)

    print(f"X_train saved       : {x_path}")
    print(f"y_train saved       : {y_path}")
    print(f"X_train shape       : {X_reshaped.shape}")
    print(f"y_train shape       : {y.shape}")
    print()


def run_preprocessing_pipeline(input_path: str, output_dir: str):
    print("\n" + "=" * 50)
    print("  GridEye — Preprocessing Pipeline")
    print("=" * 50 + "\n")

    df             = load_dataset(input_path)
    X, y           = separate_features_and_label(df)
    X_scaled       = scale_features(X, output_dir)
    X_reshaped     = reshape_for_lstm(X_scaled)
    save_arrays(X_reshaped, y, output_dir)

    print("=" * 50)
    print("Pipeline Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    INPUT_PATH = r"E:\Ayesha's VS CODES\GridEye Codes\balanced_data_final.csv"
    OUTPUT_DIR = r"E:\Ayesha's VS CODES\GridEye Codes"

    run_preprocessing_pipeline(INPUT_PATH, OUTPUT_DIR)