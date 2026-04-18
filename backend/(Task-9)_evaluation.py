import pandas as pd
import numpy as np
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import joblib
import os
import sys


def load_model_and_scaler(model_path: str, scaler_path: str):
    print("=" * 50)
    print("STEP 1 — LOADING MODEL & SCALER")
    print("=" * 50)

    for path in [model_path, scaler_path]:
        if not os.path.exists(path):
            print(f"Error: File not found — '{path}'")
            sys.exit(1)

    model  = joblib.load(model_path)
    scaler = joblib.load(scaler_path)

    print(f"Model loaded        : {model_path}")
    print(f"Scaler loaded       : {scaler_path}")
    print()

    return model, scaler


def load_and_prepare_data(data_path: str):
    print("=" * 50)
    print("STEP 2 — LOADING & PREPARING TEST DATA")
    print("=" * 50)

    if not os.path.exists(data_path):
        print(f"Error: File not found — '{data_path}'")
        sys.exit(1)

    df          = pd.read_csv(data_path)
    df          = df.select_dtypes(include=["number"]).fillna(0)
    df["FLAG"]  = df["FLAG"].round().astype(int)

    X = df.drop(columns=["FLAG"])
    y = df["FLAG"]

    print(f"Total samples       : {len(df)}")
    print(f"Features            : {X.shape[1]}")
    print(f"Normal (0)          : {(y == 0).sum():>6}  ({(y == 0).mean() * 100:.2f}%)")
    print(f"Theft  (1)          : {(y == 1).sum():>6}  ({(y == 1).mean() * 100:.2f}%)")
    print()

    return X, y


def run_evaluation(model, scaler, X, y):
    print("=" * 50)
    print("STEP 3 — PREDICTION & EVALUATION")
    print("=" * 50)

    X_scaled = scaler.transform(X)
    y_pred   = model.predict(X_scaled)

    accuracy = accuracy_score(y, y_pred) * 100
    cm       = confusion_matrix(y, y_pred)

    print(f"Overall Accuracy    : {accuracy:.2f}%\n")

    print("Confusion Matrix:")
    print(f"  True  Normal : {cm[0][0]:>5}  |  False Theft  : {cm[0][1]:>5}")
    print(f"  False Normal : {cm[1][0]:>5}  |  True  Theft  : {cm[1][1]:>5}")

    tn, fp, fn, tp = cm.ravel()
    print(f"\nFalse Positive Rate : {fp / (fp + tn) * 100:.2f}%  (Normal flagged as Theft)")
    print(f"False Negative Rate : {fn / (fn + tp) * 100:.2f}%  (Theft missed)")

    print("\nClassification Report:")
    print("-" * 50)
    print(classification_report(y, y_pred, target_names=["Normal (0)", "Theft (1)"]))


def run_evaluation_pipeline(model_path: str, scaler_path: str, data_path: str):
    print("\n" + "=" * 50)
    print("  GridEye — Model Evaluation Pipeline")
    print("=" * 50 + "\n")

    model, scaler = load_model_and_scaler(model_path, scaler_path)
    X, y          = load_and_prepare_data(data_path)
    run_evaluation(model, scaler, X, y)

    print("=" * 50)
    print("Evaluation Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    MODEL_PATH  = r"E:\Ayesha's VS CODES\GridEye Codes\incremental_model.pkl"
    SCALER_PATH = r"E:\Ayesha's VS CODES\GridEye Codes\scaler.pkl"
    DATA_PATH   = r"E:\Ayesha's VS CODES\GridEye Codes\balanced_data_final.csv"

    run_evaluation_pipeline(MODEL_PATH, SCALER_PATH, DATA_PATH)