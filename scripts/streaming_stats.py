#!/usr/bin/env python3
"""Streaming CSV stats extractor."""

import os

csv_path = r"data analysis\random_values_ojas_flsr.csv"

if os.path.exists(csv_path):
    print("Starting to read file...")
    with open(csv_path, 'rb') as f:
        data = f.read()
    
    print(f"File read: {len(data)} bytes")
    
    # Skip BOM
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
        print("BOM skipped")
    
    # Decode UTF-16 LE
    print("Decoding UTF-16-LE...")
    text = data.decode('utf-16-le', errors='ignore')
    print(f"Decoded: {len(text)} characters")
    
    # Normalize line endings
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    lines = text.split('\n')
    print(f"Lines: {len(lines)}")
    
    # Parse CSV
    print("Parsing CSV...")
    decimals = []
    for i, line in enumerate(lines):
        if i % 100000 == 0:
            print(f"  Processed {i} lines, {len(decimals)} values")
        
        parts = line.strip().split(',')
        if len(parts) >= 3:
            try:
                dec_val = int(parts[2])
                if 0 <= dec_val <= 65535:
                    decimals.append(dec_val)
            except:
                pass
    
    if decimals:
        print(f"\nResults:")
        print(f"Total values: {len(decimals)}")
        print(f"Min: {min(decimals)}")
        print(f"Max: {max(decimals)}")
        print(f"Mean: {sum(decimals)/len(decimals):.2f}")
        
else:
    print(f"File not found: {csv_path}")
