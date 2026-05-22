#!/usr/bin/env python3
import serial
import time
import sys

try:
    # Open serial port
    ser = serial.Serial('COM8', 115200, timeout=1)
    print("[+] Opened COM8")
    
    # Toggle DTR to trigger reset
    print("[*] Triggering reset...")
    ser.dtr = False
    time.sleep(0.1)
    ser.dtr = True
    time.sleep(1)
    
    print("[+] Reset triggered. Board should be booting now.")
    print("[*] Reading output for 5 seconds...")
    
    # Read output
    start_time = time.time()
    while time.time() - start_time < 5:
        if ser.in_waiting:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if line:
                print(line)
                sys.stdout.flush()
    
    ser.close()
    print("\n[+] Done")
    
except Exception as e:
    print(f"[ERROR] {e}")
    sys.exit(1)
