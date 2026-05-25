# FPGA Game of Life Quick Deployment Guide

## 🚀 One-Command Deployment

This project features a fully automated deployment script that compiles the Verilog code, performs physical synthesis, runs placement and routing, and programs the FPGA board persistently.

### Prerequisites
- **Xilinx Vivado** (2022.2 or newer) installed.
- **Digilent CMOD A7-35T FPGA** connected to the host via USB.
- USB serial drivers installed.

### Quick Start
To program your CMOD A7 with the Game of Life co-processor:

**Method 1: PowerShell (Recommended)**
```powershell
.\scripts\deployment\deploy.ps1
```

**Method 2: Double-click**
- Double-click the file `scripts\deployment\deploy.bat` in Windows Explorer.

---

## 📝 FSM Workflow and Testing

Once programmed, the co-processor FSM runs through three distinct states:

### 1. Wait/Idle State (`S_WAIT`)
- **System Action**: Holds the TFT display screen in active hardware reset.
- **Indicators**:
  - The Adafruit 3.5" TFT screen is **completely white**.
  - Onboard **LED[0]** (A17) is **ON**, indicating the system is waiting for user activation.

### 2. Seeding State
- **Trigger**: Press the push button connected to **btn[0]** (A18).
- **System Action**: Captures a high-entropy 16-bit random seed from the physical Ring Oscillator on the FPGA.
- **Status Change**: LED[0] turns **OFF**, and the master FSM transitions to `S_GOL`.

### 3. Conway's Game of Life State (`S_GOL`)
- **System Action**: Releases display reset, runs SPI register initialization ROM, and starts the simulation.
- **Rendering**:
  - Screen background is **Black** (`16'h0000`).
  - Active Conway cells are drawn in vibrant **Green** (`16'h07E0`).
- **Indicators**:
  - Onboard **LED[1]** (C16) turns **ON** once display initialization completes (`disp_ready`), indicating the co-processor simulation is running actively.

---

## 📁 Source & Constraints Configuration

If you modify structural interfaces or add custom constraints:

### Centralized Config File
Edit the project configuration in `scripts/build_tools/config.tcl`:
```tcl
set PROJECT_NAME "cmod_a7_project"
set TOP_MODULE "fpga_main"
set SOURCE_FILES [list \
    "fpga_main.v" \
    "ring_osc.v" \
    "hx8357d_controller.v" \
    "hx8357d_init.v" \
    "game_of_life.v" \
    "bram_framebuffer.v" \
    "spi_master.v" \
    "as608_controller.v" \
    "uart.v" \
]
set CONSTRAINT_FILES [list "CMODA7_Constrain.xdc"]
```

---

## 🔧 Advanced Script Options

Run automated deployment with custom parameters:

### Build Only (Skip Flashing)
```powershell
.\scripts\deployment\deploy.ps1 -BuildOnly
```
Useful for checking Verilog compilation and checking synthesis reports without writing to the physical board.

### Program Only (Skip Re-Synthesis)
```powershell
.\scripts\deployment\deploy.ps1 -SkipBuild
```
Use this to reprogram the JTAG chip instantly using an already generated `.bit` bitstream.
