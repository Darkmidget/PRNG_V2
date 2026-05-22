#!/usr/bin/env python3
import serial
import sys
import time

PORT = "COM8"
BAUD = 115200
TIMEOUT = 5

try:
    # Open serial port
    ser = serial.Serial(PORT, BAUD, timeout=TIMEOUT)
    print(f"[OK] Connected to {PORT} at {BAUD} baud")
    time.sleep(2)  # Give board time to send initial output
    
    # Read and display output
    print("\n[SERIAL OUTPUT]")
    print("=" * 60)
    
    while True:
        try:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    print(line)
                    sys.stdout.flush()
        except KeyboardInterrupt:
            print("\n\n[INTERRUPTED] Stopping monitor")
            break
        except Exception as e:
            print(f"[ERROR] {e}")
            break
    
    ser.close()
    print("[OK] Port closed")
    
except serial.SerialException as e:
    print(f"[ERROR] Failed to open {PORT}: {e}")
    sys.exit(1)
except Exception as e:
    print(f"[ERROR] {e}")
    sys.exit(1)
