#!/usr/bin/env python3
"""
Comprehensive Fingerprint Capture & Management Tool
Single script to handle all fingerprint operations
"""

import serial
import csv
import time
import sys
from pathlib import Path
from datetime import datetime
from collections import defaultdict

# Configuration
DATA_DIR = Path("fingerprints")
TEMPLATES_CSV = DATA_DIR / "templates.csv"
INDEX_CSV = DATA_DIR / "index.csv"
EVENTS_CSV = DATA_DIR / "events.csv"

# AS608 settings
DEFAULT_BAUD = 115200
DEFAULT_PORT = "COM5"
TIMEOUT = 10

class FingerprintCapture:
    def __init__(self):
        self.serial_conn = None
        self.templates = defaultdict(list)
        self.load_existing_data()
        DATA_DIR.mkdir(exist_ok=True)
    
    def load_existing_data(self):
        """Load existing templates from CSV"""
        if not TEMPLATES_CSV.exists():
            return
        
        try:
            with open(TEMPLATES_CSV, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    fid = int(row['fingerprint_id'])
                    self.templates[fid].append(row)
        except:
            pass
    
    def connect_serial(self, port=DEFAULT_PORT, baud=DEFAULT_BAUD):
        """Connect to ESP32"""
        try:
            self.serial_conn = serial.Serial(port, baud, timeout=2)
            time.sleep(1)
            print(f"[✓] Connected to {port} at {baud} baud")
            return True
        except Exception as e:
            print(f"[✗] Connection failed: {e}")
            return False
    
    def send_command(self, cmd):
        """Send command to ESP32"""
        if not self.serial_conn:
            print("[✗] Not connected")
            return False
        
        try:
            self.serial_conn.write(f"{cmd}\n".encode())
            print(f"[→] Sent: {cmd}")
            return True
        except Exception as e:
            print(f"[✗] Send failed: {e}")
            return False
    
    def read_response(self, timeout_sec=TIMEOUT):
        """Read response from ESP32"""
        if not self.serial_conn:
            return []
        
        responses = []
        start_time = time.time()
        
        while time.time() - start_time < timeout_sec:
            try:
                if self.serial_conn.in_waiting:
                    line = self.serial_conn.readline().decode('utf-8', errors='ignore').strip()
                    if line:
                        responses.append(line)
                        print(f"[←] {line}")
            except:
                pass
            
            time.sleep(0.1)
        
        return responses
    
    def save_templates_to_csv(self, responses):
        """Save template chunks to CSV"""
        new_entries = []
        
        for line in responses:
            if line.startswith("TEMPLATE_CHUNK:"):
                parts = line.split(":")
                if len(parts) >= 4:
                    try:
                        fid = int(parts[1])
                        chunk_idx = int(parts[2])
                        hex_data = ":".join(parts[3:])
                        
                        entry = {
                            'timestamp': datetime.now().isoformat(),
                            'fingerprint_id': fid,
                            'chunk_index': chunk_idx,
                            'hex_payload': hex_data
                        }
                        new_entries.append(entry)
                    except:
                        pass
        
        if new_entries:
            # Append to CSV
            file_exists = TEMPLATES_CSV.exists()
            with open(TEMPLATES_CSV, 'a', encoding='utf-8', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['timestamp', 'fingerprint_id', 'chunk_index', 'hex_payload'])
                if not file_exists:
                    writer.writeheader()
                writer.writerows(new_entries)
            
            print(f"[✓] Saved {len(new_entries)} template chunks to {TEMPLATES_CSV}")
            self.log_event(f"Saved {len(new_entries)} template chunks")
    
    def log_event(self, message):
        """Log event to CSV"""
        file_exists = EVENTS_CSV.exists()
        with open(EVENTS_CSV, 'a', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['timestamp', 'event'])
            if not file_exists:
                writer.writeheader()
            writer.writerow({
                'timestamp': datetime.now().isoformat(),
                'event': message
            })
    
    def quick_scan_single(self):
        """Scan and export one fingerprint"""
        print("\n" + "="*70)
        print("QUICK SCAN - Single Fingerprint")
        print("="*70)
        
        fid = input("Enter fingerprint ID (1-16): ").strip()
        
        self.send_command(f"TEMPLATE_EXPORT {fid}")
        responses = self.read_response()
        self.save_templates_to_csv(responses)
    
    def scan_and_save(self):
        """Scan a finger and save immediately"""
        print("\n" + "="*70)
        print("SCAN & SAVE - Quick Capture")
        print("="*70)
        print("""
INSTRUCTIONS:
1. Place your finger on the sensor
2. Keep it stationary for 2-3 seconds
3. Remove finger when sensor beeps
""")
        
        input("Press ENTER when ready to scan...")
        
        self.send_command("SCAN")
        responses = self.read_response(timeout_sec=5)
        
        for line in responses:
            if "matched_id" in line.lower():
                print(f"[✓] {line}")
    
    def list_fingerprints(self):
        """List all enrolled fingerprints"""
        print("\n" + "="*70)
        print("LIST ALL FINGERPRINTS")
        print("="*70)
        
        self.send_command("LIST_IDS")
        responses = self.read_response(timeout_sec=5)
        
        for line in responses:
            print(f"  {line}")
    
    def export_all_templates(self):
        """Export all enrolled fingerprints"""
        print("\n" + "="*70)
        print("EXPORT ALL FINGERPRINTS")
        print("="*70)
        print("This will export all enrolled fingerprints to CSV...")
        input("Press ENTER to start...")
        
        self.send_command("TEMPLATE_EXPORT_ALL")
        responses = self.read_response(timeout_sec=30)
        self.save_templates_to_csv(responses)
    
    def show_summary(self):
        """Show data summary"""
        print("\n" + "="*70)
        print("FINGERPRINT DATA SUMMARY")
        print("="*70)
        
        if not TEMPLATES_CSV.exists():
            print("No templates collected yet")
            return
        
        templates_by_id = defaultdict(list)
        with open(TEMPLATES_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                fid = int(row['fingerprint_id'])
                templates_by_id[fid].append(row)
        
        print(f"\nCollected templates: {len(templates_by_id)}")
        for fid in sorted(templates_by_id.keys()):
            chunks = templates_by_id[fid]
            total_bytes = sum(len(c['hex_payload'])//2 for c in chunks)
            print(f"  Fingerprint {fid:2d}: {len(chunks)} chunks, {total_bytes} bytes")
    
    def main_menu(self):
        """Main interactive menu"""
        print("\n" + "="*70)
        print("FINGERPRINT CAPTURE TOOL")
        print("="*70)
        print("""
1. Quick Scan - Place finger and capture
2. List Enrolled Fingerprints
3. Export Single Fingerprint by ID
4. Export ALL Fingerprints
5. Show Data Summary
6. Exit
""")
    
    def run(self):
        """Main program loop"""
        # Connect to serial
        port = input(f"Enter COM port (default {DEFAULT_PORT}): ").strip() or DEFAULT_PORT
        if not self.connect_serial(port):
            return
        
        print(f"\n[✓] Connected!")
        self.log_event(f"Session started on {port}")
        
        # Main loop
        while True:
            self.main_menu()
            choice = input("Choose option (1-6): ").strip()
            
            try:
                if choice == '1':
                    self.scan_and_save()
                elif choice == '2':
                    self.list_fingerprints()
                elif choice == '3':
                    self.quick_scan_single()
                elif choice == '4':
                    self.export_all_templates()
                elif choice == '5':
                    self.show_summary()
                elif choice == '6':
                    print("\nExiting...")
                    self.log_event("Session ended")
                    break
                else:
                    print("Invalid choice")
            except KeyboardInterrupt:
                print("\n\nInterrupted")
                break
            except Exception as e:
                print(f"Error: {e}")
        
        if self.serial_conn:
            self.serial_conn.close()

def main():
    """Entry point"""
    app = FingerprintCapture()
    app.run()

if __name__ == "__main__":
    main()
