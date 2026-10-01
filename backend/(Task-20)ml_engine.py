import os
import random
import time
from collections import namedtuple

import joblib
import numpy as np
import pandas as pd

MODEL_FILE  = "incremental_model_v5_xgb.pkl"
SCALER_FILE = "scaler_v5_xgb.pkl"
CSV_FILE    = "held_out_test_v5_xgb.csv"

ENGINEERED = ["Mean_Consumption", "Peak_Usage", "Min_Usage", "Std_Consumption",
              "Usage_Range", "Zero_Day_Count", "Missing_Day_Count"]

VIRTUAL_DAY_SECONDS    = 5    
MIN_REVEAL_DAYS_FOR_ML = 30   
CHECK_POINTS           = [40, 100, 250, 500]  
TAIL_CHECK_DAYS        = 90   

Prediction = namedtuple("Prediction", ["status", "confidence", "scaled"])


class MLEngine:
    def __init__(self, base_dir: str = None, bypass_meter_ids=()):
        import shap                                   

        base_dir = base_dir or os.path.dirname(os.path.abspath(__file__))
        print("📦 Loading ML model + held-out dataset...")
        self.model  = joblib.load(os.path.join(base_dir, MODEL_FILE))
        self.scaler = joblib.load(os.path.join(base_dir, SCALER_FILE))

        df = pd.read_csv(os.path.join(base_dir, CSV_FILE)).select_dtypes(include=[np.number])
        nan_cells = int(df.isna().sum().sum())
        if nan_cells:
            print(f"⚠️  held-out CSV mein {nan_cells} NaN cells hain — fillna(0) lag raha hai.")
        df = df.fillna(0)

        X_all = df.drop(columns=["FLAG"]).values
        y_all = df["FLAG"].values
        self.feature_cols = list(df.drop(columns=["FLAG"]).columns)
        self.feat_pos   = {c: self.feature_cols.index(c) for c in ENGINEERED if c in self.feature_cols}
        self.day_pos    = np.array([i for i, c in enumerate(self.feature_cols) if c not in ENGINEERED])
        self.total_days = len(self.day_pos)

        self.normal_profiles  = X_all[y_all == 0]
        self.theft_profiles   = X_all[y_all == 1]
        self.bypass_meter_ids = set(bypass_meter_ids)

        self._profiles = {}   
        self._start_t  = {}   

        self.explainer = shap.TreeExplainer(self.model)
        print(f"✅ ML ready | normal={len(self.normal_profiles)} theft={len(self.theft_profiles)} "
              f"| {self.total_days} days/profile | reveal={VIRTUAL_DAY_SECONDS}s/day "
              f"(~{round(self.total_days * VIRTUAL_DAY_SECONDS / 60, 1)} min for full history) "
              f"| SHAP TreeExplainer ready")

    # ── low-level helpers ────────────────────────────────────────
    def _scale(self, profile):
        return self.scaler.transform(pd.DataFrame([profile], columns=self.feature_cols))

    def _recompute_features(self, profile):
        if not self.feat_pos:
            return profile
        days = profile[self.day_pos]
        vals = {
            "Mean_Consumption":  days.mean(),
            "Peak_Usage":        days.max(),
            "Min_Usage":         days.min(),
            "Std_Consumption":   days.std(),
            "Usage_Range":       days.max() - days.min(),
            "Zero_Day_Count":    float((days == 0).sum()),
            "Missing_Day_Count": 0.0,
        }
        for name, pos in self.feat_pos.items():
            profile[pos] = vals[name]
        return profile

    def _build_revealed(self, baseline, revealed_days: int):
        
        revealed_days = max(1, min(self.total_days, int(revealed_days)))
        p    = baseline.astype(float).copy()
        days = p[self.day_pos]
        if revealed_days < self.total_days:
            days = days.copy()
            days[revealed_days:] = days[revealed_days - 1]
            p[self.day_pos] = days
        return self._recompute_features(p)

    def classify(self, baseline, revealed_days: int) -> Prediction:
        
        scaled = self._scale(self._build_revealed(baseline, revealed_days))
        pred   = self.model.predict(scaled)[0]
        conf   = int(round(float(max(self.model.predict_proba(scaled)[0])) * 100))
        return Prediction("Theft" if pred == 1 else "Normal", conf, scaled)

    def _tail_is_alive(self, profile) -> bool:
        
        days = profile[self.day_pos]
        tail = days[-min(TAIL_CHECK_DAYS, len(days)):]
        return tail.sum() > 0

    def _pick(self, pool, want: str, min_confidence: float = 0.75):
       
        for _ in range(500):
            p = random.choice(pool).astype(float)
            if not self._tail_is_alive(p):
                continue
            stable = True
            for cp in CHECK_POINTS:
                if cp > self.total_days:
                    continue
                pred = self.classify(p, revealed_days=cp)
                if pred.status != want or pred.confidence / 100.0 < min_confidence:
                    stable = False
                    break
            if stable:
                return p
        return random.choice(pool).astype(float)   

    # ── live (bridge) API — meter_id se juri state ────────────────
    def profile_for(self, meter_id: str):
        if meter_id not in self._profiles:
            want = "Theft" if meter_id in self.bypass_meter_ids else "Normal"
            pool = self.theft_profiles if want == "Theft" else self.normal_profiles
            self._profiles[meter_id] = self._pick(pool, want)
            self._start_t[meter_id]  = time.monotonic()
        return self._profiles[meter_id]

    def _revealed_days_now(self, meter_id: str) -> int:
        elapsed = time.monotonic() - self._start_t[meter_id]
        return min(self.total_days, int(elapsed / VIRTUAL_DAY_SECONDS) + 1)

    def predict(self, meter_id: str) -> Prediction:
        baseline = self.profile_for(meter_id)
        revealed = self._revealed_days_now(meter_id)

        if revealed < MIN_REVEAL_DAYS_FOR_ML:
            scaled = self._scale(self._build_revealed(baseline, revealed))
            return Prediction("Normal", 60, scaled)   # neutral default

        return self.classify(baseline, revealed)

    def days_revealed(self, meter_id: str) -> tuple:
        self.profile_for(meter_id)
        return self._revealed_days_now(meter_id), self.total_days

    def explain(self, scaled, top_n: int = 3) -> list:
        try:
            values = self.explainer.shap_values(scaled)[0]
            pairs  = sorted(zip(self.feature_cols, values),
                            key=lambda kv: abs(kv[1]), reverse=True)
            return [{"feature": f, "impact": round(float(v), 4)} for f, v in pairs[:top_n]]
        except Exception as e:
            print(f"  [SHAP] ✗ explanation failed: {e}")
            return []