import pandas as pd
import json
import os

# Load data
csv_path = r"E:\noor\lib\python\mumbai_ride_safety.csv"
df = pd.read_csv(csv_path)

# 🔍 Diagnose first
print("Unique Crime_Severity values:", sorted(df['Crime_Severity'].dropna().unique()))
print("Sample rows:")
print(df[['Crime_Severity', 'Resolved', 'Suspect_Arrested']].head(10))

# ✅ Filter by Mumbai geography (not city name)
mumbai = df[
    (df['Latitude'] >= 18.8) & (df['Latitude'] <= 19.3) &
    (df['Longitude'] >= 72.7) & (df['Longitude'] <= 73.1)
].copy()
print(f"Geographic Mumbai rows: {len(mumbai)}")

# 🎯 Risk mapping for numerical Crime_Severity
severity_map = {
    1: 0.2,
    3: 0.5,
    4: 0.6,
    5: 0.7,
    6: 0.75,
    8: 0.85,
    9: 0.9,
    10: 0.95,
}

def compute_risk(row):
    # Base risk from Crime_Severity
    severity_val = row['Crime_Severity']
    base_risk = severity_map.get(severity_val, 0.3)  # default medium

    # Boost if unresolved or suspect not arrested
    unresolved = False
    if pd.notna(row['Resolved']):
        resolved_str = str(row['Resolved']).lower()
        unresolved = resolved_str in ['no', 'false', '0', 'n']
    
    suspect_not_arrested = False
    if pd.notna(row['Suspect_Arrested']):
        arrested_str = str(row['Suspect_Arrested']).lower()
        suspect_not_arrested = arrested_str in ['no', 'false', '0', 'n']

    if unresolved or suspect_not_arrested:
        base_risk = min(base_risk + 0.2, 1.0)  # cap at 1.0

    return float(base_risk)

# Apply
mumbai['risk'] = mumbai.apply(compute_risk, axis=1)

# Generate points
points = []
for _, row in mumbai.iterrows():
    points.append({
        'lat': float(row['Latitude']),
        'lng': float(row['Longitude']),
        'risk': float(row['risk'])
    })

# Save
output_dir = r"E:\noor\assets\data"
os.makedirs(output_dir, exist_ok=True)
with open(os.path.join(output_dir, "mumbai_risk_grid.json"), 'w') as f:
    json.dump(points, f, indent=2)

print(f"✅ Generated {len(points)} points with risk = {min(p['risk'] for p in points):.2f} to {max(p['risk'] for p in points):.2f}")