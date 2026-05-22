# Feather M4 Fingerprint Sensor - Quick Reference

## Connection
```
Sensor TX (white) → D0 (RX)
Sensor RX (green) → D1 (TX)
GND → GND
3V3 → 3V3
```

## Serial Monitor Command
⚠️ **IMPORTANT: Use 57600 baud, NOT 115200**

```powershell
.venv\Scripts\platformio.exe device monitor -p COM8 --baud 57600
```

## Why Two Baud Rates?
- **Serial (USB @115200)**: Program uploads, debug messages
- **Serial1 (D0/D1 @57600)**: Fingerprint sensor (fixed speed)

These are independent UART interfaces.

## Available Commands
```
STATUS    - Show sensor status and enrolled templates
LIST_IDS  - List all 16 enrolled fingerprint IDs  
SCAN      - Wait for finger, identify
INIT      - Reinitialize sensor
HELP      - Show all commands
```

## Expected Status Output
```
Enrolled Templates: 16
Sensor Capacity: 300
Security Level: 3
Status: OK ✓
```

## Troubleshooting

**Garbled text?**
→ Change baud rate to 57600

**Sensor not detected?**
→ Check D0/D1 connections, verify 3V3 power
