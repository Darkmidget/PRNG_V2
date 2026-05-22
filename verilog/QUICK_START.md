# FPGA Quick Deployment Guide

## 🚀 One-Command Deployment

This project now has a streamlined deployment process. Just edit your Verilog file and run one command!

### Prerequisites
- Vivado installed (2022.2 or newer)
- CMOD A7 FPGA connected via USB
- Driver installed

### Quick Start

**Method 1: PowerShell (Recommended)**
```powershell
.\scripts\deployment\deploy.ps1
```

**Method 2: Double-click**
- Double-click `scripts\deployment\deploy.bat` in Windows Explorer

**Method 3: From VS Code Terminal**
```powershell
cd verilog/FPGA-Vivado-Verilog-VS-code-Project-Template
.\scripts\deployment\deploy.ps1
```

### What It Does
The `deploy.ps1` script automatically:
1. ✓ Finds and configures Vivado (no PATH setup needed!)
2. ✓ Cleans previous build artifacts
3. ✓ Synthesizes your design
4. ✓ Implements and generates bitstream
5. ✓ Programs your FPGA
6. ✓ Verifies success

**Total time: 2-5 minutes**

---

## 📝 Typical Workflow

### 1. Edit Your Design
Edit your Verilog file in `src/`:
```verilog
// src/switch_display.v
module switch_display(
    input wire clk,
    input wire [9:0] sw,
    output reg [7:0] seg,
    output reg [5:0] hex
);
    // Your code here
endmodule
```

### 2. Update Configuration (if needed)
Only needed if changing top module or constraints:
```tcl
# scripts/build_tools/config.tcl
set TOP_MODULE "switch_display"
set SOURCE_FILES [list "switch_display.v"]
set CONSTRAINT_FILES [list "DSL_Starter_Kit.xdc"]
```

### 3. Deploy!
```powershell
.\scripts\deployment\deploy.ps1
```

That's it! Your FPGA is programmed.

---

## 🎯 Advanced Options

### Build Only (Don't Program)
```powershell
.\scripts\deployment\deploy.ps1 -BuildOnly
```
Useful for checking if your design compiles without programming.

### Program Only (Skip Build)
```powershell
.\scripts\deployment\deploy.ps1 -SkipBuild
```
Use this if you just want to reprogram with an existing bitstream.

### Manual Build and Program (Old Way)
If you prefer manual control:
```powershell
# Build
vivado -mode batch -source scripts/build_tools/build.tcl

# Program
vivado -mode batch -source scripts/build_tools/program.tcl
```

---

## 🔧 Troubleshooting

### "Vivado not found"
The script searches common installation paths. If your Vivado is elsewhere, edit `deploy.ps1`:
```powershell
$vivadoPaths = @(
    "C:\YourCustomPath\Vivado\bin",
    # ... existing paths
)
```

### "No FPGA detected"
- Ensure USB cable is connected
- Check Device Manager for the FPGA
- Install Xilinx USB driver if needed
- Close any other programs using the FPGA

### "Build failed"
- Check syntax errors in your Verilog file
- Verify pin constraints match your module ports
- Review the build output for specific errors

### "Permission denied" when running script
Run once to allow script execution:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📁 Project Structure

```
FPGA-Vivado-Verilog-VS-code-Project-Template/
│
├── QUICK_START.md          ← This file
│
├── src/
│   └── switch_display.v    ← Your Verilog source
│
├── constraints/
│   ├── CMODA7_Constrain.xdc
│   └── DSL_Starter_Kit.xdc ← Pin mappings for DSL kit
│
├── scripts/
│   ├── build_tools/
│   │   ├── config.tcl      ← Project configuration
│   │   ├── build.tcl       ← Build automation
│   │   └── program.tcl     ← Programming automation
│   └── deployment/
│       ├── deploy.ps1      ← ONE-COMMAND DEPLOYMENT SCRIPT
│       └── deploy.bat      ← Double-click version
│
└── build/
    └── cmod_a7_project.runs/
        └── impl_1/
            └── switch_display.bit  ← Generated bitstream
```

---

## 💡 Tips

1. **Faster iterations**: Use `-BuildOnly` to check compilation without waiting for programming
2. **Multiple designs**: Copy entire project folder, change `TOP_MODULE` in config.tcl
3. **Debug timing**: Check `build/timing_summary.rpt` for timing violations
4. **Resource usage**: See `build/utilization.rpt` for FPGA resource usage

---

## 🎓 Current Design: Switch Display

The current project displays switch values on 7-segment displays:
- **Input**: 10 switches (sw[9:0]) = values 0-1023
- **Output**: 4-digit 7-segment display showing decimal value
- **Clock**: 12 MHz from CMOD A7

Test it:
1. Program FPGA: `.\deploy.ps1`
2. Flip switches on your board
3. See decimal value on displays!

---

## 📚 Next Steps

Want to create your own design?
1. Copy an existing .v file in `src/` as a template
2. Update `config.tcl` with your module name
3. Update pin constraints if using different I/O
4. Run `.\scripts\deployment\deploy.ps1`
5. Done!

---

**Last Updated**: March 2026
**For**: SUTD DSL Course - Term 6
