"""
GridEye — Stage 1: Incremental Z-Score Anomaly Detection (corrected)

Pehle wale version ki masail:
  1. Poore dataset ka mean/std ek saath nikalta tha (BATCH) — "incremental" nahi tha.
  2. Purani augmented_dataset.csv (4 copies of every consumer) par chalta tha.
  3. "Top suspicious" sirf sabse ZYADA consumption wale dikhata tha (nlargest of
     signed z), jabke theft aksar KAM consumption se hoti hai.
  4. Stage 2 (XGBoost) se koi link nahi tha.

Ab:
  - Welford's algorithm: running mean/std har naye consumer ke saath update hota hai.
    Har consumer ko score PEHLE kiya jata hai, phir baseline update hota hai
    (bilkul streaming ki tarah, koi retraining nahi).
  - Held-out test set par chalta hai (Task-12 ka output), dono taraf (high/low) flag.
  - Stage 1 ki apni precision/recall print hoti hai, aur Stage 2 ke saath
    "gate" (Stage1 -> Stage2) aur "sirf Stage2" ka comparison bhi.
"""

import os
import sys
import numpy as np
import pandas as pd
import joblib

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

HELD_OUT_PATH = os.path.join(BASE_DIR, "held_out_test_v5_xgb.csv")   # Task-12 output
MODEL_PATH    = os.path.join(BASE_DIR, "incremental_model_v5_xgb.pkl")
SCALER_PATH   = os.path.join(BASE_DIR, "scaler_v5_xgb.pkl")

Z_THRESHOLD = 2.0
WARMUP      = 500     # pehle itne consumers sirf baseline seekhne ke liye (flag nahi hote)
TOP_N       = 10


class IncrementalZScore:
    """Running mean / std (Welford). Naye data se baseline khud update hoti hai."""

    def __init__(self):
        self.n    = 0
        self.mean = 0.0
        self.m2   = 0.0

    @property
    def std(self) -> float:
        return float(np.sqrt(self.m2 / self.n)) if self.n > 1 else 0.0

    def update(self, x: float):
        self.n += 1
        delta = x - self.mean
        self.mean += delta / self.n
        self.m2 += delta * (x - self.mean)

    def zscore(self, x: float) -> float:
        s = self.std
        return 0.0 if s == 0 else (x - self.mean) / s

    def score_then_update(self, x: float) -> float:
        z = self.zscore(x)      # pehle purani baseline se score
        self.update(x)          # phir baseline update
        return z


def load_held_out(path: str) -> pd.DataFrame:
    if not os.path.exists(path):
        print(f"Error: File not found — '{path}'\n"
              f"Pehle Task-12 chalayein (woh held_out_test_v5_xgb.csv banata hai).")
        sys.exit(1)
    df = pd.read_csv(path)
    df["FLAG"] = df["FLAG"].round().astype(int)
    print(f"Held-out set loaded: {path}   rows={len(df)}\n")
    return df


def consumer_means(df: pd.DataFrame) -> np.ndarray:
    if "Mean_Consumption" in df.columns:          # Task-6 ka feature (same cheez)
        return df["Mean_Consumption"].to_numpy(dtype=np.float64)
    day_cols = [c for c in df.columns if c != "FLAG"]
    return df[day_cols].mean(axis=1).to_numpy(dtype=np.float64)


def run_stage1(df: pd.DataFrame):
    print("=" * 55)
    print("STEP 1 — INCREMENTAL Z-SCORE (streaming, Welford)")
    print("=" * 55)

    means = consumer_means(df)
    det   = IncrementalZScore()

    z_scores = np.zeros(len(df))
    flagged  = np.zeros(len(df), dtype=bool)

    for i, m in enumerate(means):
        z = det.score_then_update(m)
        z_scores[i] = z
        if i >= WARMUP:                           # warm-up ke dauran flag nahi
            flagged[i] = abs(z) > Z_THRESHOLD

    y = df["FLAG"].to_numpy()
    n_eval = len(df) - WARMUP
    ev = slice(WARMUP, None)

    print(f"Consumers streamed     : {len(df)}  (first {WARMUP} = warm-up)")
    print(f"Z-score threshold      : ±{Z_THRESHOLD}")
    print(f"Final running mean/std : {det.mean:.4f} / {det.std:.4f}")
    print(f"Flagged after warm-up  : {flagged[ev].sum()}  ({flagged[ev].mean() * 100:.2f}%)")
    print(f"   high-side (z > +{Z_THRESHOLD}) : {(z_scores[ev] >  Z_THRESHOLD).sum()}")
    print(f"   low-side  (z < -{Z_THRESHOLD}) : {(z_scores[ev] < -Z_THRESHOLD).sum()}")

    tp = int(((y[ev] == 1) & flagged[ev]).sum())
    fp = int(((y[ev] == 0) & flagged[ev]).sum())
    fn = int(((y[ev] == 1) & ~flagged[ev]).sum())
    prec = tp / (tp + fp) if tp + fp else 0.0
    rec  = tp / (tp + fn) if tp + fn else 0.0
    base = y[ev].mean()
    print(f"\nStage 1 alone vs true FLAG (after warm-up):")
    print(f"   Theft caught (recall)   : {rec * 100:.2f}%   ({tp} of {tp + fn})")
    print(f"   Precision               : {prec * 100:.2f}%   (theft rate in data = {base * 100:.2f}%)")
    print(f"   Honest consumers flagged: {fp}")
    print()

    return means, z_scores, flagged


def display_top(df: pd.DataFrame, means, z_scores):
    print("=" * 55)
    print(f"STEP 2 — TOP {TOP_N} MOST EXTREME CONSUMERS (by |z|, both directions)")
    print("=" * 55)
    idx = np.argsort(-np.abs(z_scores))[:TOP_N]
    out = pd.DataFrame({
        "Row"             : idx,
        "Actual FLAG"     : df["FLAG"].to_numpy()[idx],
        "Mean Consumption": np.round(means[idx], 4),
        "Z-Score"         : np.round(z_scores[idx], 4),
    })
    out["Verdict"] = np.where(out["Z-Score"].abs() > Z_THRESHOLD, "Anomaly Detected", "Normal")
    print(out.to_string(index=False))
    print()


def compare_pipeline(df: pd.DataFrame, flagged: np.ndarray):
    """Stage 2 sirf-akela vs Stage1 -> Stage2 (gate) — kaunsa behtar hai?"""
    print("=" * 55)
    print("STEP 3 — DUAL-STAGE vs STAGE-2-ONLY (same held-out rows)")
    print("=" * 55)

    if not (os.path.exists(MODEL_PATH) and os.path.exists(SCALER_PATH)):
        print("Model/scaler nahi mila — Task-12 chalayein, phir dobara. (Step skipped)\n")
        return

    model  = joblib.load(MODEL_PATH)
    scaler = joblib.load(SCALER_PATH)

    ev  = np.arange(len(df)) >= WARMUP
    X   = df.drop(columns=["FLAG"])
    y   = df["FLAG"].to_numpy()
    s2  = model.predict(scaler.transform(X)) == 1

    def report(name, pred):
        tp = int(((y[ev] == 1) & pred[ev]).sum())
        fp = int(((y[ev] == 0) & pred[ev]).sum())
        fn = int(((y[ev] == 1) & ~pred[ev]).sum())
        prec = tp / (tp + fp) if tp + fp else 0.0
        rec  = tp / (tp + fn) if tp + fn else 0.0
        f1   = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        print(f"{name:<34} recall={rec * 100:6.2f}%  precision={prec * 100:6.2f}%  "
              f"F1={f1 * 100:6.2f}%  (TP={tp}, FP={fp}, FN={fn})")

    report("Stage 2 only (XGBoost)",            s2)
    report("Stage 1 -> Stage 2 (gate)",         flagged & s2)
    report("Stage 1 OR Stage 2 (parallel)",     flagged | s2)
    print("\nNote: agar 'gate' ka recall bohat gir jaye, to Stage 1 ko gate ki jagah")
    print("      'priority screening' likhna behtar hai. Report mein jo asal number aaye wohi likhein.\n")


def run_stage1_pipeline(path: str):
    print("\n" + "=" * 55)
    print("  GridEye — Stage 1: Incremental Anomaly Detection")
    print("=" * 55 + "\n")

    df = load_held_out(path)
    means, z_scores, flagged = run_stage1(df)
    display_top(df, means, z_scores)
    compare_pipeline(df, flagged)

    print("=" * 55)
    print("Stage 1 Complete.")
    print("=" * 55 + "\n")


if __name__ == "__main__":
    run_stage1_pipeline(HELD_OUT_PATH)