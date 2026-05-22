#!/usr/bin/env python3
"""Better CSV explorer that handles mixed encoding."""

import os
import csv

csv_path = r"data analysis\random_values_ojas_flsr.csv"

if os.path.exists(csv_path):
    size = os.path.getsize(csv_path)
    print(f"File size: {size} bytes")
    
    # Read raw bytes and analyze
    with open(csv_path, 'rb') as f:
        data = f.read()
        
    # Skip BOM if present
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
        print("Detected UTF-8 BOM, skipping...")
    
    # Detect encoding by looking at null bytes pattern
    # If we see alternating nulls, it's likely UTF-16
    null_positions = [i for i, b in enumerate(data[:1000]) if b == 0]
    
    if null_positions:
        # Check if nulls are regularly spaced (every other byte = UTF-16)
        diffs = [null_positions[i+1] - null_positions[i] for i in range(len(null_positions)-1)]
        if len(set(diffs)) == 1 and diffs[0] == 2:
            print("Detected UTF-16 LE encoding (regular null spacing)")
            
            # Try UTF-16 LE after BOM
            try:
                text = data.decode('utf-16-le', errors='ignore')
                lines = text.split('\n')
                print(f"\nFirst 10 lines:")
                for i, line in enumerate(lines[:10]):
                    print(f"  Line {i}: {line.strip()}")
                    
                # Parse as CSV
                text_input = '\n'.join(lines)
                reader = list(csv.DictReader(text_input.split('\n')))
                print(f"\nTotal CSV records: {len(reader)}")
                
                decimals = []
                for row in reader:
                    if row.get('DecimalValue'):
                        try:
                            decimals.append(int(row['DecimalValue']))
                        except:
                            pass
                
                if decimals:
                    print(f"Min value: {min(decimals)}")
                    print(f"Max value: {max(decimals)}")
                    print(f"Mean value: {sum(decimals)/len(decimals):.2f}")
                    print(f"Total valid decimal values: {len(decimals)}")
                    
            except Exception as e:
                print(f"Error: {e}")
        else:
            print(f"Null byte pattern unclear: {diffs[:20]}")
    else:
        print("No null bytes detected")
else:
    print(f"File not found: {csv_path}")
