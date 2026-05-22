# 🚀 Quick Deployment Guide
powershell.exe -ExecutionPolicy Bypass -File ".\scripts\deployment\deploy.ps1"
## ✨ One-Command FPGA Programming!

You now have a super simple workflow:

### 1. Edit your Verilog file
```verilog
// Edit: src/switch_display.v (or your design)
```

### 2. Run ONE command
```powershell
.\scripts\deployment\deploy.ps1
```

**That's it!** The script automatically:
- ✅ Finds Vivado (no PATH setup needed)
- ✅ Cleans old builds
- ✅ Synthesizes & implements your design
- ✅ Generates bitstream
- ✅ Programs your FPGA

Takes 2-5 minutes total.

---

## 📖 Usage Options

### Full Build + Program (default)
```powershell
.\scripts\deployment\deploy.ps1
```

### Program Only (skip build)
```powershell
.\scripts\deployment\deploy.ps1 -SkipBuild
```
Use when you just made changes in `config.tcl` or want to reprogram

### Build Only (no programming)
```powershell
.\scripts\deployment\deploy.ps1 -BuildOnly
```
Use to check if your design compiles without waiting for programming

---

## 🔧 Configuration

Most of the time you don't need to change anything! But if you create a new design:

### Update `scripts/build_tools/config.tcl`
```tcl
set TOP_MODULE "your_module_name"
set SOURCE_FILES [list "your_file.v"]
set CONSTRAINT_FILES [list "DSL_Starter_Kit.xdc"]
```

Your new `.v` files go in `src/` folder.

---

## 💡current Project: switch_display

**What it does:**
- Reads 10 switches (values 0-1023)
- Displays decimal value on 4-digit 7-segment display
- Live updates as you toggle switches

**Ports:**
- `clk` - 12MHz clock from CMOD A7
- `sw[9:0]` - 10 switches input
- `seg[7:0]` - 7-segment display segments
- `hex[5:0]` - Digit select (multiplexing)

---

## 🎯 Typical Workflow

```powershell
# 1. Edit your design
code src/switch_display.v

# 2. Deploy to FPGA (one command!)
.\scripts\deployment\deploy.ps1

# 3. Test on hardware
# (flip switches, see results)
```

---

## ❗ Troubleshooting

### "Execution Policy" error
```powershell
# Run once:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or use:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deployment\deploy.ps1
```

### "Vivado not found"
Edit `scripts\deployment\deploy.ps1` and add your Vivado path to the `$vivadoPaths` array (around line 20).

### "No FPGA detected"
- Check USB cable
- Verify FPGA shows up in Device Manager
- Close Vivado GUI if it's open
- Try unplugging and replugging USB

### Build errors
- Check syntax in your `.v` file
- Verify port names match constraint file
- Check the build output for specific error messages

---

## 📁 Project Structure

```
Your Project/
│
├── USAGE.md            ← This file
│
├── src/
│   └── *.v             ← Your Verilog source files
│
├── scripts/
│   ├── build_tools/
│   │   ├── config.tcl      ← Project configuration
│   │   ├── build.tcl       ← Build automation
│   │   └── program.tcl     ← Programming automation
│   └── deployment/
│       ├── deploy.ps1      ← ONE-COMMAND SCRIPT (run this!)
│       └── deploy.bat      ← Double-click version
│
├── constraints/
│   └── DSL_Starter_Kit.xdc  ← Pin mappings
│
└── build/
    └── *.bit           ← Generated bitstream
```

---

## 🎓 Tips

1. **Fast iteration**: Use `-BuildOnly` to check compilation, then deploy when ready
2. **Multiple designs**: Copy the whole folder, change `TOP_MODULE` in config.tcl
3. **Version control**: Commit your `.v` files and `scripts/config.tcl`
4. **Reports**: Check `build/*.rpt` for timing/utilization details

---

## 🔄 Comparison: Old vs New Workflow

### Before (Manual Process) ❌
```powershell
# 1. Find and add Vivado to PATH
$env:PATH = "C:\...\Vivado\bin;" + $env:PATH

# 2. Navigate to project
cd "long\path\to\project"

# 3. Clean old builds
Remove-Item build\*.runs -Recurse -Force

# 4. Build
vivado -mode batch -source scripts/build_tools/build.tcl

# 5. Check for errors... wait... hope it works...

# 6. Program
vivado -mode batch -source scripts/build_tools/program.tcl

# 7. Repeat all steps every edit! 😓
```

### Now (Streamlined) ✅
```powershell
.\scripts\deployment\deploy.ps1
```

**Done!** 🎉

---

## 📚 Learn More

- [Vivado Documentation](https://docs.xilinx.com/)
- [Verilog Tutorial](../T04_Verilog_demo/)
- [FPGA Constraints Guide](constraints/DSL_Starter_Kit.xdc)

---

**Last Updated**: March 2026  
**Course**: SUTD DSL - Term 6  
**Board**: Digilent CMOD A7 with DSL Starter Kit

💡 **Questions?** Check the Jupyter notebooks in `T04_Verilog_demo/` folder!
