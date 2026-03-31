import pandas as pd
import json
import os

# Load your corrected 30-point data
df = pd.read_csv(r"E:\noor\lib\python\mumbai_ride_safety.csv")

# Filter true Mumbai points (geographic)
mumbai_true = df[
    (df['Latitude'] >= 18.8) & (df['Latitude'] <= 19.3) &
    (df['Longitude'] >= 72.7) & (df['Longitude'] <= 73.1)
].copy()
print(f"True Mumbai points: {len(mumbai_true)}")

# Define real hotspots (lat, lng, base_risk)
hotspots = [
    (18.925, 72.820, 0.9),   # Colaba
    (19.075, 72.885, 0.85),  # BKC
    (19.020, 72.840, 0.8),   # Dadar
    (19.130, 72.850, 0.7),   # Andheri
    (19.210, 72.980, 0.65),  # Thane
    (19.180, 72.830, 0.6),   # Malad
    (19.050, 72.890, 0.55),  # Chembur
]

# Expand: add 50 synthetic points per hotspot
expanded = []
for lat, lng, base_risk in hotspots:
    for i in range(50):
        # Add small noise (±200m)
        noisy_lat = lat + (i % 10 - 5) * 0.0002
        noisy_lng = lng + ((i // 10) - 2) * 0.0002
        # Vary risk slightly
        risk = max(0.3, min(1.0, base_risk + (i % 7 - 3) * 0.05))
        expanded.append({
            'Latitude': float(noisy_lat),
            'Longitude': float(noisy_lng),
            'risk': float(risk)
        })

# Combine with true points
for _, row in mumbai_true.iterrows():
    expanded.append({
        'Latitude': float(row['Latitude']),
        'Longitude': float(row['Longitude']),
        'risk': float(row['risk']) if 'risk' in row else 0.5
    })

# Save
output_dir = r"E:\noor\assets\data"
os.makedirs(output_dir, exist_ok=True)
with open(os.path.join(output_dir, "mumbai_risk_grid.json"), 'w') as f:
    json.dump(expanded, f, indent=2)

print(f"✅ Generated {len(expanded)} points (true + synthetic)")