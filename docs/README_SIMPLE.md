# Fingerprint Capture Setup - Streamlined

## Quick Start

### 1️⃣ **Simple Capture** (Recommended)
```bash
python get_thumbprint.py
```

**What it does:**
- Connect to ESP32 on COM5
- Show menu: Scan, List, Export One, or Export All
- Capture fingerprint data
- Save to `fingerprints/templates.csv`

**Usage:**
```
OPTIONS:
1. Quick Scan - Place finger on sensor
2. List Fingerprints - Show enrolled IDs
3. Export Single - Export one fingerprint by ID
4. Export All - Export all fingerprints
5. Exit

Choose (1-5): 4  ← Export all fingerprints
```

---

### 2️⃣ **Advanced Menu** (More options)
```bash
python fingerprint_capture.py
```

**Features:**
- More menu options
- Persistent connection
- Multiple operations in one session
- Data summary

---

### 3️⃣ **Check Hardware**
```bash
python hardware_probe.py
```

**What it does:**
- Test serial connection
- Verify ESP32 responds
- Check sensor connectivity

---

## File Structure

```
Final_project/
├── src/
│   └── main.cpp              ← ESP32 firmware
├── platformio.ini            ← Build config
├── get_thumbprint.py         ← ⭐ USE THIS - Simple capture
├── fingerprint_capture.py    ← Full menu system
├── hardware_probe.py         ← Hardware test
├── save_fingerprint.py       ← Background capture
└── fingerprints/
    ├── templates.csv         ← Your fingerprint data
    ├── index.csv            ← Fingerprint registry
    └── events.csv           ← Operation log
```

---

## Workflow

### First Time Setup
```bash
# 1. Check hardware works
python hardware_probe.py

# 2. Build and upload firmware
platformio run -v

# 3. Export all fingerprints
python get_thumbprint.py
  → Choose "4. Export All"
```

### Regular Use
```bash
# Quick capture all
python get_thumbprint.py
  → Choose "4. Export All"
  → Data saved to templates.csv
```

---

## Data Location

All fingerprint data saved in:
```
fingerprints/templates.csv
```

**Format:**
```
timestamp,fingerprint_id,chunk_index,hex_payload
2026-04-02T01:11:22...,1,0,03035F1D040142...
2026-04-02T01:11:23...,1,1,0000000000...
2026-04-02T01:11:24...,1,2,EEAACFBAAAAA...
2026-04-02T01:11:25...,1,3,0101010101...
```

---

## Troubleshooting

### "Failed to connect"
- Check ESP32 is connected to COM5
- Verify USB cable
- Run `hardware_probe.py` to diagnose

### "No template data received"
- Ensure fingerprints are enrolled on sensor
- Run "2. List Fingerprints" to see what's there
- Check firmware is recent (run `platformio run -v`)

### "Empty response"
- Increase timeout in the script
- Check baud rate (should be 115200)
- Verify RX/TX pins (16/17)

---

## ESP32 Setup

**Hardware:**
- TX → Pin 16
- RX → Pin 17
- GND → GND
- VCC → 3.3V

**Commands:**
- `SCAN` - Scan a finger
- `LIST_IDS` - List enrolled fingerprints
- `TEMPLATE_EXPORT {ID}` - Export single fingerprint
- `TEMPLATE_EXPORT_ALL` - Export all fingerprints

---

## Data Format

Each fingerprint = 128 bytes = 4 chunks of 32 bytes

```
Chunk 0: Header (0x0303) + metadata
Chunk 1-2: Minutiae data
Chunk 3: Padding

Total: 128 bytes → 256 hex characters
```

Example:
```
03035F1D040142017C0000000000000000000000000000000000000000000000
│││├─ AS608 header signature
```

---

## Next Steps

1. ✅ Capture fingerprints: `python get_thumbprint.py`
2. ✅ View saved data: Check `fingerprints/templates.csv`
3. ✅ Build matching system: Compare templates
4. ✅ Implement authentication: Use fingerprint for login

---

## Tips

- **Stationary finger**: Keep thumb still 2-3 seconds on sensor
- **Clean sensor**: Wipe sensor before capturing
- **Multiple scans**: Capture 2-3 times per person for best results
- **Export all**: Easier than exporting one-by-one

---

**Questions?** Check the CSV files or run `hardware_probe.py` for diagnostics.
