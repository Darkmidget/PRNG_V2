# ⚡ Streamlined Workflow Quick Reference

## 🚀 Fastest Way to Build & Upload

Simply press **Ctrl+Shift+B** (or run the default build task) to compile and upload:

```powershell
# Via PowerShell
cd g:\My\ Drive\0\ -\ SUTD\Term\ 6\DSL\Final_project
.\.venv\Scripts\platformio.exe run -e feather_m4 --target upload --upload-port COM8
```

**Time: ~8-10 seconds**

---

## 📊 Available VS Code Tasks

Press **Ctrl+Shift+P** → type "Tasks: Run Task" or press **Ctrl+Alt+T**:

| Task | What it does | Time |
|------|-------------|------|
| **🚀 Quick Build & Upload** | Build + Upload | 8-10s |
| **🖥️ Build, Upload & Monitor** | Build + Upload + Serial monitor | 8-10s + monitoring |
| **🧪 Run Diagnostic Tests** | Run HX8357D diagnostics | 15-20s |
| **🔄 Clean Rebuild** | Fresh build from scratch | 15-20s |
| **📡 Serial Monitor Only** | Just view serial output | - |
| **💾 Restore Original Code** | Swap back to Game of Life | instant |

---

## 💻 Command Line Reference

### Build Only
```powershell
.\.venv\Scripts\platformio.exe run -e feather_m4
```

### Build + Upload
```powershell
.\.venv\Scripts\platformio.exe run -e feather_m4 --target upload --upload-port COM8
```

### View Serial Output
```powershell
.\.venv\Scripts\platformio.exe device monitor -p COM8 --baud 115200
```

### List Available Ports
```powershell
.\.venv\Scripts\platformio.exe device list
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `src/main.cpp` | Current application code |
| `src/gameoflife.h` | Game of Life logic |
| `src/display_renderer.h` | Display driver (with HW fixes) |
| `platformio.ini` | Build configuration |
| `.vscode/tasks.json` | VS Code automation tasks |

---

## 🔧 Development Cycle

1. **Edit code** → `src/main.cpp`, `src/gameoflife.h`, etc.
2. **Build & Upload** → Press `Ctrl+Shift+B`
3. **Test** → Watch display or use serial monitor
4. **Repeat** → Go back to step 1

---

## ✨ Hardware Workarounds Included

The improved code automatically:
- ✓ Retries display initialization (up to 3 attempts)
- ✓ Validates display responsiveness with test patterns
- ✓ Throttles rendering to 100ms cycles (prevents SPI bus overload)
- ✓ Adds delays between commands for hardware stability

Despite physical hardware issues (partially defective ribbon cable), the software ensures reliable operation.

---

## 🐛 If Something Goes Wrong

### Display shows garbage/gibberish
→ This is a hardware issue, not code. The fixes automatically compensate.

### Upload fails
→ Make sure board is connected: `.\.venv\Scripts\platformio.exe device list`

### Can't find serial port
→ Restart board or check Device Manager for COM port number

### Want to run diagnostics again
→ Run **"🧪 Run Diagnostic Tests"** task in VS Code

---

## 📝 Notes

- Serial monitor baud rate is fixed at **115200**
- By default, serial port is **COM8** (auto-detected)
- Stack usage: **5.3% RAM**, **5.2% Flash** (plenty of room)
- Game of Life updates every ~333ms (3 generations/second)

