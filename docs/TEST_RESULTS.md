# 🧪 Hardware & Software Test Results

**Date:** April 21, 2026  
**Board:** Adafruit Feather M4 Express  
**Current Status:** Mixed, with strict startup validation in place

---

## Verified Results

### 1. ✅ Fingerprint Sensor on Serial1
- D0/D1 wiring is the active sensor connection.
- The sensor handshake succeeds when the hardware is present and responding.
- The firmware stops at startup if the sensor does not initialize.

### 2. ✅ FPGA UART on Serial3
- A4/A1 wiring is the active FPGA connection.
- The startup loopback diagnostic passes 12/12 patterns on a connected FPGA.
- The `T` command repeats the same 12-pattern diagnostic.

### 3. ✅ Display and Game of Life
- The HX8357D display initializes successfully.
- Game of Life renders and continues after startup verification.

---

## Current Runtime Behavior

- Startup performs explicit hardware checks and prints a system status summary.
- The firmware does not use fallback seeds.
- If the FPGA does not return a valid numeric seed, the fingerprint workflow fails explicitly.
- If the fingerprint sensor does not initialize, the system halts instead of continuing silently.

---

## Wiring Summary

| Component | Pin | Status |
|-----------|-----|--------|
| Fingerprint TX | D0 (RX) | Verified |
| Fingerprint RX | D1 (TX) | Verified |
| Fingerprint GND | GND | Verified |
| Fingerprint 3V3 | 3V3 | Verified |
| FPGA TX | A4 (RX) | Verified in loopback diagnostic |
| FPGA RX | A1 (TX) | Verified in loopback diagnostic |

---

## Notes

- The old Serial2/D12/D13 FPGA notes are obsolete for the current firmware.
- The active FPGA path is Serial3 on A4/A1.
- The current workflow is fingerprint scan -> FPGA seed response -> Game of Life restart.
