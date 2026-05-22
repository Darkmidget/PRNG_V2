# 🎯 Workflow Cheat Sheet

## Quickest Way Forward

```bash
# In VS Code:
Ctrl+Shift+B

# In PowerShell:
.\build.ps1
.\build.ps1 -Monitor
```

That's it! Everything else is automated.

---

## One-Liner Tasks

| Need | Command |
|------|---------|
| **Build & Upload** | `.\build.ps1` |
| **With Serial Monitor** | `.\build.ps1 -Monitor` |
| **Clean Rebuild** | `.\build.ps1 -Clean` |
| **Just Check Serial** | `.\.venv\Scripts\platformio.exe device monitor -p COM8 --baud 115200` |
| **List COM Ports** | `.\.venv\Scripts\platformio.exe device list` |

---

## VS Code Shortcuts

| What | Shortcut |
|------|----------|
| **Build & Upload (DEFAULT)** | `Ctrl+Shift+B` |
| **Open Tasks Menu** | `Ctrl+Shift+P` then "Tasks: Run Task" |
| **Quick Palette** | `Ctrl+Shift+P` |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Display shows garbage** | This is hardware, not code. System auto-compensates. |
| **Upload fails** | Check if board is connected: `.\.venv\Scripts\platformio.exe device list` |
| **COM port wrong** | Update `build.ps1 -Port COM9` or edit `platformio.ini` |
| **Serial monitor garbled** | Check baud rate is **115200** |

---

## File Locations Reference

| Purpose | File |
|---------|------|
| **Main Code** | `src/main.cpp` |
| **Game Logic** | `src/gameoflife.h` |
| **Display Driver** | `src/display_renderer.h` |
| **Build Config** | `platformio.ini` |
| **Build Script** | `build.ps1` |
| **VS Code Tasks** | `.vscode/tasks.json` |

---

## Development Workflow

```
1. Edit code (src/main.cpp, src/gameoflife.h, etc.)
   ↓
2. Press Ctrl+Shift+B (or run ./build.ps1)
   ↓
3. Code deploys to Feather M4 in ~8 seconds
   ↓
4. Test on hardware
   ↓
5. Repeat
```

---

## Quick Facts

- **Board**: Feather M4 Express
- **Display**: HX8357D 3.5" TFT FeatherWing
- **Serial Port**: COM8 (auto-detected)
- **Baud Rate**: 115200
- **Build Time**: 6-7 seconds
- **Upload Time**: 1-2 seconds
- **Total Cycle**: ~8-9 seconds
- **Display Updates**: Every 100ms (10 FPS for rendering)
- **Game Updates**: Every ~333ms (3 generations/sec)

---

## Key Improvements Made

✓ Display initialization with retry logic
✓ Rendering throttled to prevent SPI bus overload
✓ VS Code tasks for one-click automation
✓ PowerShell scripts for command-line users
✓ Hardware diagnostic tools included
✓ Complete documentation suite

---

## Got a Question?

- **For workflow help** → Read `QUICK_START.md`
- **For detailed guide** → Read `WORKFLOW.md`
- **For hardware issues** → Run diagnostic tests
- **For code reference** → Check inline comments
- **For build issues** → Run `.\build.ps1 -Clean`

---

**You're all set! Start coding! 🚀**

