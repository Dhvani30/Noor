import pandas as pd
import numpy as np
import json
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import joblib

# ================= CONFIGURATION =================
CSV_PATH = r"E:\noor\lib\python\mumbai_ride_safety.csv"
OUTPUT_CSV = r"E:\noor\lib\python\mumbai_synthetic_large.csv"
MODEL_PATH = r"E:\noor\lib\python\risk_model_final.pkl"
OUTPUT_JSON = r"E:\noor\assets\data\mumbai_risk_grid.json"
OUTPUT_DIR = r"E:\noor\assets\data"

NUM_SYNTHETIC_RECORDS = 6000  # Generate 6,000 points for a smooth map

# Your 7 Real Hotspots (Lat, Lng, Base Risk Level)
HOTSPOTS = [
    (18.925, 72.820, 0.95), # Colaba
    (19.075, 72.885, 0.90), # BKC
    (19.020, 72.840, 0.80), # Dadar
    (19.130, 72.850, 0.70), # Andheri
    (19.210, 72.980, 0.65), # Thane
    (19.180, 72.830, 0.55), # Malad
    (19.050, 72.890, 0.50), # Chembur
]

def generate_synthetic_data(n_records):
    print(f"🤖 Generating {n_records} synthetic crime records based on 7 hotspots...")
    data = []
    
    for i in range(n_records):
        # 1. Pick random hotspot
        h_lat, h_lng, h_risk = HOTSPOTS[np.random.randint(0, len(HOTSPOTS))]
        
        # 2. Add Location Noise (Spread ~1.5km)
        lat = h_lat + np.random.normal(0, 0.012)
        lng = h_lng + np.random.normal(0, 0.012)
        
        # Keep within Mumbai bounds
        if not (18.8 <= lat <= 19.3 and 72.7 <= lng <= 73.1):
            continue
            
        # 3. Determine Severity based on distance from center
        dist = np.sqrt((lat - h_lat)**2 + (lng - h_lng)**2)
        if dist < 0.005: # Close to hotspot
            severity = np.random.choice([8, 9, 10], p=[0.2, 0.5, 0.3])
        elif dist < 0.015: # Medium distance
            severity = np.random.choice([4, 5, 6, 7], p=[0.2, 0.3, 0.3, 0.2])
        else: # Far edge
            severity = np.random.choice([1, 2, 3, 4], p=[0.3, 0.3, 0.3, 0.1])
            
        # 4. Determine Status (Unresolved/Arrested) based on risk level
        if h_risk > 0.8:
            is_unresolved = np.random.choice([1, 0], p=[0.7, 0.3])
            is_suspect_free = np.random.choice([1, 0], p=[0.6, 0.4])
        elif h_risk > 0.6:
            is_unresolved = np.random.choice([1, 0], p=[0.4, 0.6])
            is_suspect_free = np.random.choice([1, 0], p=[0.4, 0.6])
        else:
            is_unresolved = np.random.choice([1, 0], p=[0.2, 0.8])
            is_suspect_free = np.random.choice([1, 0], p=[0.2, 0.8])
            
        # 5. Random Time
        hour = np.random.randint(0, 24)
        day = np.random.randint(0, 7)
        
        data.append({
            'Latitude': lat,
            'Longitude': lng,
            'Crime_Severity': severity,
            'Resolved': 'No' if is_unresolved else 'Yes',
            'Suspect_Arrested': 'No' if is_suspect_free else 'Yes',
            'Hour': hour,
            'DayOfWeek': day
        })
        
    return pd.DataFrame(data)

def engineer_features(df):
    print("🔧 Engineering features for AI...")
    df['Is_Unresolved'] = df['Resolved'].astype(str).str.lower().isin(['no', 'false', '0']).astype(int)
    df['Is_Suspect_Free'] = df['Suspect_Arrested'].astype(str).str.lower().isin(['no', 'false', '0']).astype(int)
    df['Is_Night'] = ((df['Hour'] >= 22) | (df['Hour'] <= 5)).astype(int)
    df['Is_High_Severity'] = (df['Crime_Severity'] >= 8).astype(int)
    
    # Target: What defines "Danger"?
    def calc_target(row):
        if row['Crime_Severity'] >= 8: return 1
        if row['Crime_Severity'] >= 5 and (row['Is_Unresolved'] or row['Is_Suspect_Free']): return 1
        if row['Is_Night'] and row['Is_Unresolved']: return 1
        return 0
    
    df['Target_Danger'] = df.apply(calc_target, axis=1)
    return df

def train_and_export(df):
    print("🌲 Training Random Forest...")
    feature_cols = ['Crime_Severity', 'Is_Unresolved', 'Is_Suspect_Free', 'Is_Night', 'Is_High_Severity']
    X = df[feature_cols]
    y = df['Target_Danger']
    
    # Train
    model = RandomForestClassifier(n_estimators=200, max_depth=15, class_weight='balanced', n_jobs=-1)
    model.fit(X, y)
    
    # Save Model
    joblib.dump(model, MODEL_PATH)
    print(f"💾 Model saved to {MODEL_PATH}")
    
    # Predict Smooth Probabilities for ALL points
    print("🎨 Generating smooth risk scores...")
    probs = model.predict_proba(X)[:, 1] # Probability of Danger (0.0 to 1.0)
    df['AI_Risk'] = probs
    
    # Prepare JSON
    points = []
    for _, row in df.iterrows():
        points.append({
            'Latitude': float(row['Latitude']),
            'Longitude': float(row['Longitude']),
            'risk': float(row['AI_Risk'])
        })
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(points, f, indent=2)
        
    print(f"✅ SUCCESS!")
    print(f"📂 JSON saved: {OUTPUT_JSON}")
    print(f"📊 Total Points: {len(points)}")
    print(f"📈 Risk Range: {min(p['risk'] for p in points):.3f} to {max(p['risk'] for p in points):.3f}")

if __name__ == "__main__":
    # 1. Generate Data
    df = generate_synthetic_data(NUM_SYNTHETIC_RECORDS)
    df.to_csv(OUTPUT_CSV, index=False) # Save raw CSV for inspection
    
    # 2. Process & Train
    df_processed = engineer_features(df)
    
    # 3. Export
    train_and_export(df_processed)