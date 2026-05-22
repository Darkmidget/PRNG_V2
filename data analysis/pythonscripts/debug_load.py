#!/usr/bin/env python3
"""Debug CSV loading."""

from pathlib import Path
import numpy as np

def load_random_values_debug(csv_path):
    """Load decimal values with debug output."""
    print(f"Opening file: {csv_path}")
    
    with open(csv_path, 'rb') as f:
        data = f.read()
    
    print(f"File size: {len(data)} bytes")
    
    # Skip UTF-8 BOM if present
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
        print("Skipped UTF-8 BOM")
    
    # Decode as UTF-16 LE
    print("Decoding as UTF-16 LE...")
    text = data.decode('utf-16-le', errors='ignore')
    
    # Split by line endings (CRLF or LF)
    lines = text.replace('\r\n', '\n').replace('\r', '\n').split('\n')
    
    print(f"Total lines: {len(lines)}")
    
    # Parse CSV
    decimals = []
    for line_idx, line in enumerate(lines):
        line = line.strip()
        if not line:  # Skip empty lines
            continue
        
        # Skip header line
        if line_idx == 0 and 'Index' in line:
            print(f"Line {line_idx}: HEADER - {line[:100]}")
            continue
        
        # Split by comma
        parts = line.split(',')
        
        if line_idx < 5:
            print(f"Line {line_idx}: Parts={len(parts)}, Content='{line[:100]}'")
        
        # We expect at least 3 columns: Index, HexValue, DecimalValue
        if len(parts) >= 3:
            try:
                # DecimalValue is the 3rd column (index 2)
                dec_val_str = parts[2].strip()
                if dec_val_str:
                    dec_val = int(dec_val_str)
                    # Validate it's in range [0, 65535]
                    if 0 <= dec_val <= 65535:
                        decimals.append(dec_val)
                        if len(decimals) <= 5:
                            print(f"  Loaded: Index={parts[0]}, Hex={parts[1]}, Decimal={dec_val}")
            except (ValueError, IndexError) as e:
                # Skip lines that can't be parsed
                if line_idx < 5:
                    print(f"  Parse error: {e}")
    
    print(f"\nTotal values loaded: {len(decimals)}")
    return np.array(decimals, dtype=np.uint16)

# Main
project_root = Path(__file__).parent.parent.parent
csv_path = project_root / "data analysis" / "random_values_ojas_flsr.csv"

print(f"CSV Path: {csv_path}")
print(f"Exists: {csv_path.exists()}")
print()

if csv_path.exists():
    data = load_random_values_debug(str(csv_path))
    if len(data) > 0:
        print(f"\nMin: {data.min()}, Max: {data.max()}, Mean: {data.mean():.2f}")
