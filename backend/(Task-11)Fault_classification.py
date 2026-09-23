import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (classification_report, confusion_matrix,
                             roc_auc_score, average_precision_score)
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


def prepare_data(train_path: str, test_path: str, held_out_path: str):
    print("=" * 50)
    print("STEP 1 — DATA PREPARATION")
    print("=" * 50)

    # Train: SMOTE-balanced (Task-3) + features (Task-6)
    # Test : original imbalance, SMOTE se untouched + features (Task-6)
    train_df = load_dataset(train_path).select_dtypes(include=[np.number]).fillna(0)
    test_df  = load_dataset(test_path).select_dtypes(include=[np.number]).fillna(0)

    train_df["FLAG"] = train_df["FLAG"].round().astype(int)
    test_df["FLAG"]  = test_df["FLAG"].round().astype(int)

    X_train = train_df.drop(columns=["FLAG"])
    y_train = train_df["FLAG"]

    # Test ke columns ko train ke columns ke bilkul same order mein rakhna zaroori hai
    X_test  = test_df[X_train.columns]
    y_test  = test_df["FLAG"]

    print(f"Features            : {X_train.shape[1]}")
    print(f"Train samples       : {len(X_train)}  {y_train.value_counts().to_dict()}  (SMOTE-balanced)")
    print(f"Test  samples       : {len(X_test)}   {y_test.value_counts().to_dict()}  (original imbalance)")
    print()

    # Held-out test set save karna (Task-9 simulator aur Task-13 isay use karte hain)
    held_out_df         = X_test.copy()
    held_out_df["FLAG"] = y_test
    held_out_df.to_csv(held_out_path, index=False)
    print(f"Held-out test set saved : {held_out_path}\n")

    return X_train, X_test, y_train, y_test


def scale_data(X_train, X_test, scaler_path: str):
    print("=" * 50)
    print("STEP 2 — STANDARD SCALING")
    print("=" * 50)

    scaler         = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)   # fit sirf train par
    X_test_scaled  = scaler.transform(X_test)        # test par sirf transform

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
    print("STEP 4 — MODEL EVALUATION (on untouched test set)")
    print("=" * 50)

    y_pred        = model.predict(X_test_scaled)
    y_proba       = model.predict_proba(X_test_scaled)[:, 1]
    y_proba_train = model.predict_proba(X_train_scaled)[:, 1]

    train_acc = model.score(X_train_scaled, y_train)
    test_acc  = model.score(X_test_scaled,  y_test)
    train_auc = roc_auc_score(y_train, y_proba_train)
    test_auc  = roc_auc_score(y_test,  y_proba)

    # NOTE: train set is SMOTE-balanced (50/50), test set has the REAL
    # imbalance. So train accuracy and test accuracy are NOT directly
    # comparable. ROC-AUC does not depend on class balance, so the
    # overfitting check below uses AUC instead.
    print(f"Training Accuracy   : {train_acc * 100:.2f}%   (balanced train set)")
    print(f"Testing  Accuracy   : {test_acc  * 100:.2f}%   (real-imbalance test set)")

    baseline = (y_test == 0).mean() * 100
    print(f"Baseline (always Normal) : {baseline:.2f}%   <-- accuracy is se compare karein")

    print(f"\nTrain ROC-AUC       : {train_auc:.4f}")
    print(f"Test  ROC-AUC       : {test_auc:.4f}")
    if train_auc - test_auc > 0.15:
        print("Warning: Train AUC is much higher than test AUC -> model is overfitting.")
        print("         (Normal for tree models on raw daily readings; report it honestly.)")
    else:
        print("Train/test AUC gap is within acceptable range.")

    print("\nClassification Report:")
    print("-" * 50)
    print(classification_report(y_test, y_pred,
                                target_names=["Normal (0)", "Theft (1)"], digits=3))

    cm = confusion_matrix(y_test, y_pred)
    tn, fp, fn, tp = cm.ravel()
    print("Confusion Matrix:")
    print(f"  True  Normal : {tn:>6}  |  False Theft  : {fp:>6}")
    print(f"  False Normal : {fn:>6}  |  True  Theft  : {tp:>6}")

    print(f"\nFalse Positive Rate : {fp / (fp + tn) * 100:.2f}%  (Normal flagged as Theft)")
    print(f"False Negative Rate : {fn / (fn + tp) * 100:.2f}%  (Theft missed)")

    # Imbalanced data ke liye zyada meaningful metrics
    print(f"ROC-AUC             : {test_auc:.4f}")
    print(f"PR-AUC (Avg Prec.)  : {average_precision_score(y_test, y_proba):.4f}"
          f"   (random guessing would give ~{y_test.mean():.4f})")
    print()


def run_training_pipeline(train_path, test_path, model_path, scaler_path, held_out_path):
    print("\n" + "=" * 50)
    print("  GridEye — XGBoost Training Pipeline (v5, leakage-free)")
    print("=" * 50 + "\n")

    X_train, X_test, y_train, y_test = prepare_data(train_path, test_path, held_out_path)
    X_train_scaled, X_test_scaled    = scale_data(X_train, X_test, scaler_path)
    model                            = train_model(X_train_scaled, y_train, model_path)
    evaluate_model(model, X_train_scaled, X_test_scaled, y_train, y_test)

    print("=" * 50)
    print("Pipeline Complete.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

    TRAIN_PATH    = os.path.join(BASE_DIR, "features_train.csv")   # Task-6 output
    TEST_PATH     = os.path.join(BASE_DIR, "features_test.csv")    # Task-6 output
    MODEL_PATH    = os.path.join(BASE_DIR, "incremental_model_v5_xgb.pkl")
    SCALER_PATH   = os.path.join(BASE_DIR, "scaler_v5_xgb.pkl")
    HELD_OUT_PATH = os.path.join(BASE_DIR, "held_out_test_v5_xgb.csv")

    run_training_pipeline(TRAIN_PATH, TEST_PATH, MODEL_PATH, SCALER_PATH, HELD_OUT_PATH)