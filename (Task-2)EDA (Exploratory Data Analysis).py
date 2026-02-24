import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os

# ==============================
# Load Dataset
# ==============================
data = pd.read_csv("dataset.csv")

# ==============================
# Separate Columns Properly
# ==============================

# First column = ID (skip it)
# Last column = Label
# Middle columns = Load readings

y = data.iloc[:, -1].values
X = data.iloc[:, 1:-1].to_numpy(dtype=np.float32)  # Skip ID column

# ==============================
# Create Output Folder
# ==============================
output_folder = "EDA_Outputs"
os.makedirs(output_folder, exist_ok=True)

# ==============================
# Graph 1: Class Distribution
# ==============================
plt.figure()
sns.countplot(x=y)
plt.title("Theft vs Normal Distribution")
plt.savefig(f"{output_folder}/class_distribution.png")
plt.show()
plt.close()

# ==============================
# Graph 2: Average Load Profile
# ==============================
mean_profile = np.mean(X, axis=0)

plt.figure()
plt.plot(mean_profile)
plt.title("Average Load Profile")
plt.savefig(f"{output_folder}/average_load_profile.png")
plt.show()
plt.close()

# ==============================
# Graph 3: Theft vs Normal Profile
# ==============================
normal_profile = np.mean(X[y == 0], axis=0)
theft_profile = np.mean(X[y == 1], axis=0)

plt.figure()
plt.plot(normal_profile, label="Normal")
plt.plot(theft_profile, label="Theft")
plt.legend()
plt.title("Theft vs Normal Load Profile")
plt.savefig(f"{output_folder}/theft_vs_normal_profile.png")
plt.show()
plt.close()

print("EDA Completed Successfully!")