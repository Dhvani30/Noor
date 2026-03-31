import pandas as pd
import numpy as np
import json
import os

df = pd.read_csv(r"E:\noor\lib\python\mumbai_ride_safety.csv")
mumbai = df[df['City'].str.contains('Mumbai', case=False, na=False)].copy()
mumbai = mumbai.dropna(subset=['Latitude', 'Longitude'])

mumbai['risk'] = (
    (mumbai['Crime_Severity'] == 'High') |
    (~mumbai['Resolved'].astype(bool)) |
    (~mumbai['Suspect_Arrested'].astype(bool))
).astype(int)

lat_min, lat_max = mumbai['Latitude'].min(), mumbai['Latitude'].max()
lng_min, lng_max = mumbai['Longitude'].min(), mumbai['Longitude'].max()

lats = np.arange(lat_min, lat_max, 0.004)
lngs = np.arange(lng_min, lng_max, 0.004)

total = len(lats) * len(lngs)
count = 0

points = []

for lat in lats:
    for lng in lngs:
        count += 1

        # Print progress every 50,000 cells
        if count % 50000 == 0:
            percent = (count / total) * 100
            print(f"Progress: {count}/{total} cells ({percent:.2f}%)")

        nearby = mumbai[
            (abs(mumbai['Latitude'] - lat) <= 0.004) &
            (abs(mumbai['Longitude'] - lng) <= 0.004)
        ]

        if len(nearby) > 0:
            avg_risk = nearby['risk'].mean()
            if avg_risk > 0.1:
                points.append({
                    'lat': round(lat, 6),
                    'lng': round(lng, 6),
                    'risk': round(float(avg_risk), 3)
                })

output_dir = r"E:\noor\assets\data"
os.makedirs(output_dir, exist_ok=True)

with open(os.path.join(output_dir, "mumbai_risk_grid.json"), 'w') as f:
    json.dump(points, f, indent=2)

print(f"✅ Generated {len(points)} heatmap points")