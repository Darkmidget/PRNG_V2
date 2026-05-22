# Streamlined Workflow Guide

## Quick Start Commands

### 1. **Build & Upload Only** (30 seconds)
```powershell
.\.build-and-upload.ps1
```

### 2. **Build, Upload & Monitor Serial Output** (30 seconds + monitoring)
```powershell
.\.build-and-upload.ps1 -Monitor
```

### 3. **Run Diagnostic Tests**
```powershell
copy "feather_display\featherwing\featherwing_diagnostic.ino" src\main.cpp
.\.build-and-upload.ps1 -Monitor
copy src\main.cpp.backup src\main.cpp  # Restore original
```

---

## Workflow Summary

```
Developer makes code changes
        ↓
    Run .\.build-and-upload.ps1
        ↓
    [Auto] Compile → Upload → [Optional] Monitor Serial
        ↓
    Code is deployed to Feather M4
```

---

## Project Structure

```
Final_project/
├── src/
│   ├── main.cpp              ← Main application code
│   ├── main.cpp.backup       ← Original backup
│   ├── gameoflife.h          ← Game logic
│   └── display_renderer.h    ← Display interface
├── feather_display/
│   ├── featherwing/
│   │   └── featherwing_diagnostic.ino  ← Diagnostic tests
│   └── src/
│       └── main.cpp          ← Alternative implementation
├── platformio.ini            ← Build configuration
├── .build-and-upload.ps1     ← Automation script
└── .venv/                    ← Python virtual environment
```

---

## Common Tasks

### **Build Without Upload**
```powershell
.\.venv\Scripts\platformio.exe run -e feather_m4
```

### **Just Upload (skip build)**
```powershell
.\.venv\Scripts\platformio.exe run -e feather_m4 --target upload --upload-port COM8
```

### **View Serial Monitor Only**
```powershell
.\.venv\Scripts\platformio.exe device monitor -p COM8 --baud 115200
```

### **Clean Build**
```powershell
.\.venv\Scripts\platformio.exe run -e feather_m4 --target clean
.\.venv\Scripts\platformio.exe run -e feather_m4
```

---

## Hardware Configuration

- **Board**: Adafruit Feather M4 Express
- **Display**: HX8357D 3.5" TFT FeatherWing
- **Serial Port**: COM8 (auto-detected)
- **Baud Rate**: 115200

---

## Notes

- The display has intermittent hardware communication issues (MISO stuck HIGH)
- Software includes recovery mechanisms for robustness
- Rendering is throttled to 100ms cycles to avoid overwhelming SPI bus
- Game of Life simulation updates every ~333ms (3 generations/second)

