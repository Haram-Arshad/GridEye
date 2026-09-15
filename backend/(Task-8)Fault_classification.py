import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
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


def prepare_data(df: pd.DataFrame, held_out_path: str):
    print("=" * 50)
    print("STEP 1 — DATA PREPARATION")
    print("=" * 50)

    df = df.select_dtypes(include=[np.number]).fillna(0)
    df["FLAG"] = df["FLAG"].round().astype(int)

    X = df.drop(columns=["FLAG"])
    y = df["FLAG"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"Total samples       : {len(df)}")
    print(f"Features            : {X.shape[1]}")
    print(f"Train samples       : {len(X_train)}  (80%)")
    print(f"Test  samples       : {len(X_test)}   (20%)")
    print()

    held_out_df = X_test.copy()
    held_out_df["FLAG"] = y_test
    held_out_df.to_csv(held_out_path, index=False)
    print(f"Held-out test set saved : {held_out_path}\n")

    return X_train, X_test, y_train, y_test


def scale_data(X_train, X_test, scaler_path: str):
    print("=" * 50)
    print("STEP 2 — STANDARD SCALING")
    print("=" * 50)

    scaler         = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled  = scaler.transform(X_test)

    joblib.dump(scaler, scaler_path)
    print(f"Scaler saved        : {scaler_path}\n")

    return X_train_scaled, X_test_scaled


def train_model(X_train_scaled, y_train, model_path: str):
    print("=" * 50)
    print("STEP 3 — TRAINING XGBOOST (v5)")
    print("=" * 50)
    print("Training in progress... (please wait)")

    model = XGBClassifier(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_lambda=1.0,
        eval_metric="logloss",
        random_state=42,
        n_jobs=-1
    )
    model.fit(X_train_scaled, y_train)
    joblib.dump(model, model_path)

    print(f"n_estimators        : 300")
    print(f"max_depth           : 6")
    print(f"learning_rate       : 0.05")
    print(f"Model saved         : {model_path}\n")

    return model


def evaluate_model(model, X_train_scaled, X_test_scaled, y_train, y_test):
    print("=" * 50)
    print("STEP 4 — MODEL EVALUATION")
    print("=" * 50)

    train_acc = model.score(X_train_scaled, y_train)
    test_acc  = model.score(X_test_scaled,  y_test)

    print(f"Training Accuracy   : {train_acc * 100:.2f}%")
    print(f"Testing  Accuracy   : {test_acc  * 100:.2f}%")

    if train_acc - test_acc > 0.10:
        print("\nWarning: Possible overfitting detected (train vs test gap > 10%).")
    else:
        print("\nGap is within acceptable range.")

    y_pred = model.predict(X_test_scaled)

    print("\nClassification Report:")
    print("-" * 50)
    print(classification_report(y_test, y_pred, target_names=["Normal (0)", "Theft (1)"]))

    cm = confusion_matrix(y_test, y_pred)
    print("Confusion Matrix:")
    print(f"  True  Normal : {cm[0][0]:>5}  |  False Theft  : {cm[0][1]:>5}")
    print(f"  False Normal : {cm[1][0]:>5}  |  True  Theft  : {cm[1][1]:>5}")
    print()


def run_training_pipeline(input_path, model_path, scaler_path, held_out_path):
    print("\n" + "=" * 50)
    print("  GridEye — XGBoost Training Pipeline (v5)")
    print("=" * 50 + "\n")

    df                                = load_dataset(input_path)
    X_train, X_test, y_train, y_test  = prepare_data(df, held_out_path)
    X_train_scaled, X_test_scaled     = scale_data(X_train, X_test, scaler_path)
    model                             = train_model(X_train_scaled, y_train, model_path)
    evaluate_model(model, X_train_scaled, X_test_scaled, y_train, y_test)

    print("=" * 50)
    print("Pipeline Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    BASE_DIR       = os.path.dirname(os.path.abspath(__file__))

    # ── UPDATED: ab v2 (cleaned) dataset se train hoga ──
    INPUT_PATH     = os.path.join(BASE_DIR, "balanced_data_final_v2.csv")

    # ── SAFE: naye naam se save, purana (75.27%) model untouched ──
    MODEL_PATH     = os.path.join(BASE_DIR, "incremental_model_v5_xgb.pkl")
    SCALER_PATH    = os.path.join(BASE_DIR, "scaler_v5_xgb.pkl")
    HELD_OUT_PATH  = os.path.join(BASE_DIR, "held_out_test_v5_xgb.csv")

    run_training_pipeline(INPUT_PATH, MODEL_PATH, SCALER_PATH, HELD_OUT_PATH)