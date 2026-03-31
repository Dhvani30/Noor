# check_columns.py
import pandas as pd

df = pd.read_csv(r"E:\noor\lib\python\mumbai_ride_safety.csv")  # 👈 Use your actual filename
print("Available columns:")
for col in df.columns:
    print(f"  - '{col}'")