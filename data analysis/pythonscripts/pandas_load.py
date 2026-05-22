#!/usr/bin/env python3
"""CSV loading with pandas - more robust."""

from pathlib import Path
import pandas as pd
import numpy as np

def load_with_pandas(csv_path):
    """Try loading with pandas using various encoding options."""
    print("Attempting to load with pandas...")
    
    encodings_to_try = ['utf-16', 'utf-16-le', 'utf-8', 'utf-8-sig', 'latin-1', 'cp1252']
    
    for encoding in encodings_to_try:
        try:
            print(f"  Trying {encoding}...", end=' ')
            df = pd.read_csv(csv_path, encoding=encoding, dtype=str)
            print(f"✓ Success! Shape: {df.shape}")
            print(f"  Columns: {df.columns.tolist()}")
            print(f"  First few rows:")
            print(df.head(10))
            
            # Extract decimal values from 3rd column (index 2)
            decimal_col = df.iloc[:, 2]
            decimals = []
            for val in decimal_col:
                try:
                    dec = int(val)
                    if 0 <= dec <= 65535:
                        decimals.append(dec)
                except:
                    pass
            
            return np.array(decimals, dtype=np.uint16)
        except Exception as e:
            print(f"✗ Failed: {type(e).__name__}: {str(e)[:50]}")
    
    print("\nAll pandas encodings failed, trying custom approach...")
    return None

# Main
project_root = Path(__file__).parent.parent.parent
csv_path = project_root / "data analysis" / "random_values_ojas_flsr.csv"

print(f"CSV Path: {csv_path}")
print(f"Exists: {csv_path.exists()}")
print()

if csv_path.exists():
    decimals = load_with_pandas(str(csv_path))
    if decimals is not None:
        print(f"\nData loaded successfully!")
        print(f"Total values: {len(decimals)}")
        print(f"Min: {decimals.min()}, Max: {decimals.max()}, Mean: {decimals.mean():.2f}")
