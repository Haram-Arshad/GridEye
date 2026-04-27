import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os
import sys


BALANCED_PATH  = r"E:\Ayesha's VS CODES\GridEye Codes\balanced_data_final.csv"
AUGMENTED_PATH = r"E:\Ayesha's VS CODES\GridEye Codes\augmented_dataset.csv"
OUTPUT_FOLDER  = r"E:\Ayesha's VS CODES\GridEye Codes\EDA_Outputs"


def load_dataset(file_path: str):
    if not os.path.exists(file_path):
        print(f"Error: File not found — '{file_path}'")
        sys.exit(1)

    df        = pd.read_csv(file_path)
    date_cols = [col for col in df.columns if col not in ["CONS_NO", "FLAG", "theft_type"]]
    X         = df[date_cols].apply(pd.to_numeric, errors="coerce").to_numpy(dtype=np.float32)

    if df["FLAG"].dtype == object:
        y = df["FLAG"].map({"Normal": 0, "Theft": 1}).fillna(0).astype(int).to_numpy()
    else:
        y = df["FLAG"].round().astype(int).to_numpy()

    print(f"Loaded : {file_path}")
    print(f"Shape  : {df.shape}")
    print(f"Normal (0) : {(y == 0).sum():>6}  ({(y == 0).mean() * 100:.2f}%)")
    print(f"Theft  (1) : {(y == 1).sum():>6}  ({(y == 1).mean() * 100:.2f}%)\n")

    return X, y


def setup_output_folder(folder: str):
    os.makedirs(folder, exist_ok=True)
    print(f"Output folder ready : {folder}\n")


def plot_class_distribution(y, output_folder: str):
    print("Generating — Class Distribution...")

    labels = ["Normal (0)", "Theft (1)"]
    counts = [np.sum(y == 0), np.sum(y == 1)]
    colors = ["#2ecc71", "#e74c3c"]

    plt.figure(figsize=(7, 5))
    bars = plt.bar(labels, counts, color=colors, edgecolor="black", width=0.5)

    for bar, count in zip(bars, counts):
        plt.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 30,
            str(count),
            ha="center", fontsize=11, fontweight="bold"
        )

    plt.title("Class Distribution — Normal vs Theft", fontsize=13, fontweight="bold")
    plt.ylabel("Number of Consumers")
    plt.ylim(0, max(counts) * 1.15)
    plt.tight_layout()
    plt.savefig(os.path.join(output_folder, "class_distribution.png"), dpi=150)
    plt.close()
    print("  Saved: class_distribution.png")


def plot_average_load_profile(X, output_folder: str):
    print("Generating — Average Load Profile...")

    mean_profile = np.nanmean(X, axis=0)

    plt.figure(figsize=(12, 4))
    plt.plot(mean_profile, color="#3498db", linewidth=1)
    plt.title("Average Daily Load Profile (All Consumers)", fontsize=13, fontweight="bold")
    plt.xlabel("Day Index (2014 -> 2016)")
    plt.ylabel("Average Consumption (kWh)")
    plt.tight_layout()
    plt.savefig(os.path.join(output_folder, "average_load_profile.png"), dpi=150)
    plt.close()
    print("  Saved: average_load_profile.png")


def plot_theft_vs_normal_profile(X, y, output_folder: str):
    print("Generating — Theft vs Normal Load Profile...")

    normal_profile = np.nanmean(X[y == 0], axis=0)
    theft_profile  = np.nanmean(X[y == 1], axis=0)

    plt.figure(figsize=(12, 4))
    plt.plot(normal_profile, label="Normal (0)", color="#2ecc71", linewidth=1)
    plt.plot(theft_profile,  label="Theft  (1)", color="#e74c3c", linewidth=1)
    plt.title("Load Profile Comparison — Normal vs Theft", fontsize=13, fontweight="bold")
    plt.xlabel("Day Index (2014 -> 2016)")
    plt.ylabel("Average Consumption (kWh)")
    plt.legend(fontsize=10)
    plt.tight_layout()
    plt.savefig(os.path.join(output_folder, "theft_vs_normal_profile.png"), dpi=150)
    plt.close()
    print("  Saved: theft_vs_normal_profile.png")


def plot_missing_values_heatmap(augmented_path: str, output_folder: str):
    print("Generating — Missing Values Heatmap...")

    if not os.path.exists(augmented_path):
        print("  Warning: Augmented dataset not found — skipping heatmap.")
        return

    df        = pd.read_csv(augmented_path)
    date_cols = [col for col in df.columns if col not in ["CONS_NO", "FLAG", "theft_type"]]
    X_raw     = df[date_cols].apply(pd.to_numeric, errors="coerce").to_numpy(dtype=np.float32)

    sample      = X_raw[:100, :]
    nan_matrix  = np.isnan(sample).astype(int)
    missing_pct = np.isnan(X_raw).mean() * 100

    plt.figure(figsize=(14, 5))
    sns.heatmap(nan_matrix, cmap="Reds", cbar=True, xticklabels=False, yticklabels=False)
    plt.title(
        f"Missing Values Heatmap — First 100 Consumers  |  Total Missing: {missing_pct:.1f}%",
        fontsize=12, fontweight="bold"
    )
    plt.xlabel("Day Index (2014 -> 2016)")
    plt.ylabel("Consumer Index")
    plt.tight_layout()
    plt.savefig(os.path.join(output_folder, "missing_values_heatmap.png"), dpi=150)
    plt.close()
    print("  Saved: missing_values_heatmap.png")


def run_eda(balanced_path: str, augmented_path: str, output_folder: str):
    print("\n" + "=" * 50)
    print("  GridEye -- Exploratory Data Analysis (EDA)")
    print("=" * 50 + "\n")

    setup_output_folder(output_folder)

    print("=" * 50)
    print("LOADING BALANCED DATASET")
    print("=" * 50)
    X, y = load_dataset(balanced_path)

    print("=" * 50)
    print("GENERATING PLOTS")
    print("=" * 50)

    plot_class_distribution(y, output_folder)
    plot_average_load_profile(X, output_folder)
    plot_theft_vs_normal_profile(X, y, output_folder)
    plot_missing_values_heatmap(augmented_path, output_folder)

    print()
    print("=" * 50)
    print("EDA Complete. All plots saved.")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    run_eda(BALANCED_PATH, AUGMENTED_PATH, OUTPUT_FOLDER)