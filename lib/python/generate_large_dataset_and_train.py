import pandas as pd
import numpy as np
import json
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import joblib

# ================= CONFIGURATION =================
OUTPUT_CSV = r"E:\noor\lib\python\mumbai_synthetic_large.csv"
MODEL_PATH = r"E:\noor\lib\python\risk_model_large.pkl"
OUTPUT_JSON = r"E:\noor\assets\data\mumbai_risk_grid.json"
OUTPUT_DIR = r"E:\noor\assets\data"

NUM_SYNTHETIC_RECORDS = 6000  # Generate 6,000 fake records

# Your 7 Real Hotspots (Lat, Lng, Base Risk, Name)
HOTSPOTS = [
    (18.925, 72.820, 0.95, "Colaba"),
    (19.075, 72.885, 0.90, "BKC"),
    (19.020, 72.840, 0.80, "Dadar"),
    (19.130, 72.850, 0.70, "Andheri"),
    (19.210, 72.980, 0.65, "Thane"),
    (19.180, 72.830, 0.55, "Malad"),
    (19.050, 72.890, 0.50, "Chembur"),
]

def generate_synthetic_data(n_records):
    print(f"🤖 Generating {n_records} synthetic crime records...")
    
    data = []
    
    for i in range(n_records):
        # 1. Pick a random hotspot to base this record on
        hotspot = HOTSPOTS[np.random.randint(0, len(HOTSPOTS))]
        base_lat, base_lng, base_risk, name = hotspot
        
        # 2. Add Noise to Location (Spread out within ~1.5km)
        # 0.01 degree approx 1.1km
        lat_noise = np.random.normal(0, 0.012) 
        lng_noise = np.random.normal(0, 0.012)
        
        lat = base_lat + lat_noise
        lng = base_lng + lng_noise
        
        # Keep strictly within Mumbai bounds
        if not (18.8 <= lat <= 19.3 and 72.7 <= lng <= 73.1):
            continue
            
        # 3. Determine Severity based on distance from hotspot center
        # Closer to center = Higher Severity
        dist = np.sqrt(lat_noise**2 + lng_noise**2)
        max_dist = 0.025 # ~2.5km radius
        
        if dist < 0.005: # Very close
            severity = np.random.choice([8, 9, 10], p=[0.2, 0.5, 0.3])
        elif dist < 0.015: # Medium distance
            severity = np.random.choice([4, 5, 6, 7], p=[0.2, 0.3, 0.3, 0.2])
        else: # Far edge
            severity = np.random.choice([1, 2, 3, 4], p=[0.3, 0.3, 0.3, 0.1])
            
        # 4. Determine Resolution Status
        # High risk areas are more likely to be Unresolved
        if base_risk > 0.8:
            is_unresolved = np.random.choice([True, False], p=[0.7, 0.3])
            is_suspect_free = np.random.choice([True, False], p=[0.6, 0.4])
        elif base_risk > 0.6:
            is_unresolved = np.random.choice([True, False], p=[0.4, 0.6])
            is_suspect_free = np.random.choice([True, False], p=[0.4, 0.6])
        else:
            is_unresolved = np.random.choice([True, False], p=[0.2, 0.8])
            is_suspect_free = np.random.choice([True, False], p=[0.2, 0.8])
            
        # 5. Random Time (for future features)
        hour = np.random.randint(0, 24)
        day = np.random.randint(0, 7)
        
        data.append({
            'Latitude': lat,
            'Longitude': lng,
            'Crime_Severity': severity,
            'Resolved': 'No' if is_unresolved else 'Yes',
            'Suspect_Arrested': 'No' if is_suspect_free else 'Yes',
            'Hour': hour,
            'DayOfWeek': day,
            'Target_Hotspot': name
        })
        
    return pd.DataFrame(data)

def engineer_features(df):
    print("🔧 Engineering features...")
    
    # Binary Flags
    df['Is_Unresolved'] = df['Resolved'].astype(str).str.lower().isin(['no', 'false', '0']).astype(int)
    df['Is_Suspect_Free'] = df['Suspect_Arrested'].astype(str).str.lower().isin(['no', 'false', '0']).astype(int)
    df['Is_Night'] = ((df['Hour'] >= 22) | (df['Hour'] <= 5)).astype(int)
    df['Is_Weekend'] = (df['DayOfWeek'] >= 5).astype(int)
    df['Is_High_Severity'] = (df['Crime_Severity'] >= 8).astype(int)
    
    # Target Label (What we want the AI to learn)
    # Logic: High Severity OR (Medium + Unresolved)
    def calc_target(row):
        if row['Crime_Severity'] >= 8: return 1
        if row['Crime_Severity'] >= 5 and (row['Is_Unresolved'] or row['Is_Suspect_Free']): return 1
        if row['Is_Night'] and row['Is_Unresolved']: return 1
        return 0
    
    df['Target_Danger'] = df.apply(calc_target, axis=1)
    
    feature_cols = ['Crime_Severity', 'Is_Unresolved', 'Is_Suspect_Free', 'Is_Night', 'Is_Weekend', 'Is_High_Severity']
    return df, feature_cols

def train_and_save(df, feature_cols):
    print("🌲 Training Random Forest on Large Dataset...")
    
    X = df[feature_cols]
    y = df['Target_Danger']
    
    # Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train
    model = RandomForestClassifier(n_estimators=200, max_depth=15, class_weight='balanced', n_jobs=-1)
    model.fit(X_train, y_train)
    
    # Eval
    acc = model.score(X_test, y_test)
    print(f"✅ Model Accuracy on Synthetic Data: {acc:.2%}")
    
    # Save Model
    joblib.dump(model, MODEL_PATH)
    
    # Generate Final JSON for Flutter using the Model's Probability
    print("🎨 Generating Smooth Heatmap JSON...")
    probs = model.predict_proba(X)[:, 1] # Probability of Danger
    df['AI_Risk'] = probs
    
    # Filter to keep only points within strict Mumbai bounds for the JSON
    mumbai_final = df[
        (df['Latitude'] >= 18.8) & (df['Latitude'] <= 19.3) &
        (df['Longitude'] >= 72.7) & (df['Longitude'] <= 73.1)
    ]
    
    points = []
    for _, row in mumbai_final.iterrows():
        points.append({
            'Latitude': float(row['Latitude']),
            'Longitude': float(row['Longitude']),
            'risk': float(row['AI_Risk'])
        })
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(points, f, indent=2)
        
    print(f"💾 Saved {len(points)} points to {OUTPUT_JSON}")
    print(f"📈 Risk Range: {min(p['risk'] for p in points):.3f} to {max(p['risk'] for p in points):.3f}")

if __name__ == "__main__":
    # 1. Generate Data
    df = generate_synthetic_data(NUM_SYNTHETIC_RECORDS)
    
    # Save the raw synthetic CSV so you can inspect it
    df.to_csv(OUTPUT_CSV, index=False)
    print(f"💾 Saved raw synthetic data to {OUTPUT_CSV}")
    
    # 2. Process & Train
    df_processed, feature_cols = engineer_features(df)
    
    # 3. Train & Output JSON
    train_and_save(df_processed, feature_cols)
    
    print("\n🎉 DONE! Your Flutter app now has a smooth, AI-generated heatmap based on 6,000+ data points.")