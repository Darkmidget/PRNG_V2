#!/usr/bin/env python3
"""Explore the CSV file format and content."""

import os
import sys

csv_path = r"data analysis\random_values_ojas_flsr.csv"

# Check file size
if os.path.exists(csv_path):
    size = os.path.getsize(csv_path)
    print(f"File size: {size} bytes")
    
    # Try reading as binary first
    with open(csv_path, 'rb') as f:
        first_bytes = f.read(200)
        print(f"First 200 bytes (hex): {first_bytes.hex()}")
        print(f"First 200 bytes (repr): {repr(first_bytes)}")
        
    # Try reading as text (UTF-8-SIG to handle BOM)
    try:
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            lines = f.readlines()[:10]
            print(f"\nFirst 10 lines (UTF-8-SIG):")
            for i, line in enumerate(lines, 1):
                print(f"  Line {i}: {line.strip()}")
    except Exception as e:
        print(f"Cannot read as UTF-8: {e}")
        
    # Try as CSV with UTF-8-SIG
    try:
        import csv
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            rows = []
            for i, row in enumerate(reader):
                # Skip empty rows
                if not row.get('DecimalValue'):
                    continue
                rows.append(row)
                if i < 10:
                    print(f"CSV Row {i}: Index={row.get('Index')}, Hex={row.get('HexValue')}, Decimal={row.get('DecimalValue')}")
            
            print(f"\nTotal non-empty rows: {len(rows)}")
            
            # Analyze decimal values
            decimals = [int(row['DecimalValue']) for row in rows if row.get('DecimalValue')]
            if decimals:
                print(f"Min value: {min(decimals)}")
                print(f"Max value: {max(decimals)}")
                print(f"Mean value: {sum(decimals)/len(decimals):.2f}")
    except Exception as e:
        print(f"Cannot parse as CSV UTF-8-SIG: {e}")
else:
    print(f"File not found: {csv_path}")
