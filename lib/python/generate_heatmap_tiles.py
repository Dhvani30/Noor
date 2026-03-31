import pandas as pd
import numpy as np
import json
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib
from datetime import datetime

# ================= CONFIGURATION =================
CSV_PATH = r"E:\noor\lib\python\mumbai_ride_safety.csv"
MODEL_PATH = r"E:\noor\lib\python\risk_model_advanced.pkl"
OUTPUT_JSON = r"E:\noor\assets\data\mumbai_risk_grid.json"
OUTPUT_DIR = r"E:\noor\assets\data"

# Mumbai Geographic Bounds
LAT_MIN, LAT_MAX = 18.8, 19.3
LNG_MIN, LNG_MAX = 72.7, 73.1

def load_and_prepare_data():
    print("📂 Loading data...")
    if not os.path.exists(CSV_PATH):
        raise FileNotFoundError(f"CSV not found at {CSV_PATH}")
    
    df = pd.read_csv(CSV_PATH)
    
    # Filter strictly to Mumbai coordinates
    mumbai_df = df[
        (df['Latitude'] >= LAT_MIN) & (df['Latitude'] <= LAT_MAX) &
        (df['Longitude'] >= LNG_MIN) & (df['Longitude'] <= LNG_MAX)
    ].copy()
    
    print(f"📍 Found {len(mumbai_df)} records within Mumbai bounds.")
    if len(mumbai_df) == 0:
        raise ValueError("No data found in Mumbai bounds.")
        
    return mumbai_df

def engineer_features(df):
    print(" Engineering Advanced Features...")
    
    # 1. Handle Missing Values
    df['Crime_Severity'] = pd.to_numeric(df['Crime_Severity'], errors='coerce').fillna(5)
    df['Resolved'] = df['Resolved'].astype(str).fillna('Yes')
    df['Suspect_Arrested'] = df['Suspect_Arrested'].astype(str).fillna('Yes')
    
    # If you have a 'Timestamp' or 'Date' column, uncomment below to extract time features
    # df['Timestamp'] = pd.to_datetime(df['Timestamp'], errors='coerce')
    # df['Hour'] = df['Timestamp'].dt.hour.fillna(12)
    # df['DayOfWeek'] = df['Timestamp'].dt.dayofweek.fillna(3)
    # For now, we simulate time based on row index if no date column exists (Optional)
    df['Hour'] = 12 # Default noon if no time data
    df['DayOfWeek'] = 3 # Default Wednesday if no date data
    
    # 2. Create Binary & Categorical Features
    
    # A. Status Flags
    df['Is_Unresolved'] = df['Resolved'].str.lower().isin(['no', 'false', '0', 'n', 'nan']).astype(int)
    df['Is_Suspect_Free'] = df['Suspect_Arrested'].str.lower().isin(['no', 'false', '0', 'n', 'nan']).astype(int)
    
    # B. Severity Categories (One-Hot Encoding logic simplified)
    df['Is_High_Severity'] = (df['Crime_Severity'] >= 8).astype(int)
    df['Is_Medium_Severity'] = ((df['Crime_Severity'] >= 4) & (df['Crime_Severity'] < 8)).astype(int)
    
    # C. Time-Based Features (If you add real timestamps later, these become dynamic)
    df['Is_Night'] = ((df['Hour'] >= 22) | (df['Hour'] <= 5)).astype(int)
    df['Is_Weekend'] = (df['DayOfWeek'] >= 5).astype(int)
    
    # D. Location Density Proxy (Simple clustering hint)
    # Crimes in dense areas (approximated by lat/lng ranges) might have different risks
    # Example: South Mumbai (Lat < 19.0) often has different crime patterns
    df['Is_South_Mumbai'] = (df['Latitude'] < 19.0).astype(int)
    
    # 3. Define Final Feature List (7 Columns)
    feature_cols = [
        'Crime_Severity', 
        'Is_Unresolved', 
        'Is_Suspect_Free', 
        'Is_High_Severity', 
        'Is_Medium_Severity',
        'Is_Night', 
        'Is_South_Mumbai'
    ]
    
    X = df[feature_cols]
    
    # 4. Create Target Label (y) - The "Ground Truth" for training
    # Logic: High Severity OR (Medium + Unresolved) OR (Night + Unresolved)
    def calculate_advanced_label(row):
        if row['Is_High_Severity'] == 1:
            return 1
        if row['Is_Medium_Severity'] == 1 and (row['Is_Unresolved'] == 1 or row['Is_Suspect_Free'] == 1):
            return 1
        if row['Is_Night'] == 1 and row['Is_Unresolved'] == 1:
            return 1
        return 0
    
    y = df.apply(calculate_advanced_label, axis=1)
    
    print(f"⚖️ Data Balance: Safe={sum(y==0)}, Dangerous={sum(y==1)}")
    print(f"📊 Features used: {feature_cols}")
    
    return X, y, feature_cols

def train_model(X, y):
    print("🌲 Training Advanced Random Forest Classifier...")
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    # Model with more trees for complex patterns
    model = RandomForestClassifier(
        n_estimators=200,          # More trees for stability
        max_depth=15,              # Deeper trees to capture complex interactions
        min_samples_split=5,       # Prevent overfitting on small noise
        random_state=42,
        class_weight='balanced',
        n_jobs=-1
    )
    
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    print("\n📊 Model Performance Report:")
    print(classification_report(y_test, y_pred, target_names=['Safe', 'Dangerous']))
    
    # Show Feature Importance (Which columns matter most?)
    importances = model.feature_importances_
    features = X.columns
    fi_df = pd.DataFrame({'Feature': features, 'Importance': importances}).sort_values(by='Importance', ascending=False)
    print("\n🏆 Top Factors Influencing Risk:")
    print(fi_df.to_string(index=False))
    
    # Save model
    joblib.dump(model, MODEL_PATH)
    print(f"💾 Model saved to {MODEL_PATH}")
    
    return model

def generate_smooth_heatmap(df, model, feature_cols):
    print("🎨 Generating smooth AI heatmap probabilities...")
    
    X_all = df[feature_cols]
    
    # Predict Probabilities
    probs = model.predict_proba(X_all)
    df['ai_risk_score'] = probs[:, 1] # Probability of Danger
    
    # Optional: Slight visual boost for high-confidence predictions
    df['final_risk'] = df['ai_risk_score'].apply(lambda x: min(1.0, x * 1.05) if x > 0.6 else x)

    return df

def save_json(df):
    print("💾 Saving JSON for Flutter...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    points = []
    for _, row in df.iterrows():
        points.append({
            'Latitude': float(row['Latitude']),
            'Longitude': float(row['Longitude']),
            'risk': float(row['final_risk'])
        })
    
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(points, f, indent=2)
        
    print(f"✅ SUCCESS!")
    print(f"📂 Output saved to: {OUTPUT_JSON}")
    print(f"📈 Risk Score Range: {df['final_risk'].min():.3f} to {df['final_risk'].max():.3f}")

if __name__ == "__main__":
    try:
        df = load_and_prepare_data()
        X, y, feature_cols = engineer_features(df)
        model = train_model(X, y)
        df_processed = generate_smooth_heatmap(df, model, feature_cols)
        save_json(df_processed)
    except Exception as e:
        print(f"❌ Error occurred: {e}")
        import traceback
        traceback.print_exc()