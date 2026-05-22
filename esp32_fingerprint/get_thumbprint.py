#!/usr/bin/env python3
"""
Simple Fingerprint Capture - One command to get & save fingerprint data
Usage: python get_thumbprint.py
"""

import serial
import csv
import time
from pathlib import Path
from datetime import datetime

DATA_DIR = Path("fingerprints")
TEMPLATES_CSV = DATA_DIR / "templates.csv"

def get_fingerprint(port="COM5", baud=115200):
    """Connect and capture all fingerprints"""
    DATA_DIR.mkdir(exist_ok=True)
    
    print("\n" + "="*70)
    print("FINGERPRINT CAPTURE TOOL")
    print("="*70)
    
    # Connect
    try:
        ser = serial.Serial(port, baud, timeout=2)
        time.sleep(1)
        print(f"\n[✓] Connected to {port}")
    except Exception as e:
        print(f"\n[✗] Failed to connect: {e}")
        return
    
    # Menu
    print("""
OPTIONS:
1. Quick Scan - Place finger on sensor
2. List Fingerprints - Show enrolled IDs
3. Export Single - Export one fingerprint by ID
4. Export All - Export all fingerprints
5. Exit
""")
    
    choice = input("Choose (1-5): ").strip()
    
    if choice == '1':
        print("\nPlace your finger on the sensor...")
        ser.write(b"SCAN\n")
        print("[→] SCAN command sent\n")
        time.sleep(4)
    
    elif choice == '2':
        print("\nFetching fingerprint list...")
        ser.write(b"LIST_IDS\n")
        print("[→] LIST_IDS command sent\n")
        time.sleep(3)
    
    elif choice == '3':
        fid = input("Enter fingerprint ID (1-16): ").strip()
        print(f"\nExporting fingerprint {fid}...")
        ser.write(f"TEMPLATE_EXPORT {fid}\n".encode())
        print(f"[→] TEMPLATE_EXPORT {fid} sent\n")
        time.sleep(3)
    
    elif choice == '4':
        print("\nExporting ALL fingerprints...")
        print("This may take 30+ seconds, please wait...\n")
        ser.write(b"TEMPLATE_EXPORT_ALL\n")
        print("[→] TEMPLATE_EXPORT_ALL sent\n")
        time.sleep(5)
    
    elif choice == '5':
        print("Exiting...")
        ser.close()
        return
    
    else:
        print("Invalid choice")
        ser.close()
        return
    
    # Read response
    print("Reading response...\n")
    responses = []
    for _ in range(50):
        try:
            if ser.in_waiting:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(f"[←] {line}")
                    responses.append(line)
        except:
            pass
        time.sleep(0.1)
    
    # Save templates
    template_chunks = [r for r in responses if r.startswith("TEMPLATE_CHUNK:")]
    
    if template_chunks:
        print(f"\n[✓] Received {len(template_chunks)} template chunks")
        
        # Parse and save
        entries = []
        for line in template_chunks:
            parts = line.split(":")
            if len(parts) >= 4:
                try:
                    fid = int(parts[1])
                    chunk_idx = int(parts[2])
                    hex_data = ":".join(parts[3:])
                    entries.append({
                        'timestamp': datetime.now().isoformat(),
                        'fingerprint_id': fid,
                        'chunk_index': chunk_idx,
                        'hex_payload': hex_data
                    })
                except:
                    pass
        
        if entries:
            # Save to CSV
            file_exists = TEMPLATES_CSV.exists()
            with open(TEMPLATES_CSV, 'a', encoding='utf-8', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['timestamp', 'fingerprint_id', 'chunk_index', 'hex_payload'])
                if not file_exists:
                    writer.writeheader()
                writer.writerows(entries)
            
            print(f"[✓] Saved {len(entries)} entries to {TEMPLATES_CSV}")
            
            # Show summary
            print("\n" + "-"*70)
            print("CAPTURED:")
            print("-"*70)
            from collections import defaultdict
            by_id = defaultdict(list)
            for e in entries:
                by_id[e['fingerprint_id']].append(e)
            
            for fid in sorted(by_id.keys()):
                chunks = by_id[fid]
                total_bytes = sum(len(c['hex_payload'])//2 for c in chunks)
                print(f"  Fingerprint {fid}: {len(chunks)} chunks, {total_bytes} bytes")
                if total_bytes >= 128:
                    print(f"               ✓ Complete template")
    
    else:
        print("\n[⚠] No template data received")
        print("Showing all responses:")
        for r in responses:
            print(f"  {r}")
    
    # Cleanup
    ser.close()
    print("\n[✓] Done!")

if __name__ == "__main__":
    get_fingerprint()
