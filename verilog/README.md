# Standalone FPGA Conway's Game of Life & Display Driver

This directory contains the Verilog hardware description code, pin constraints, simulation testbenches, and build scripts for the fully integrated Conway's Game of Life simulation and physical SPI TFT display controller.

The system runs entirely standalone on a Digilent CMOD A7-35T FPGA board.

---

## 📁 Source Modules Overview

All modules are located in the [src/](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src) directory:

1. **[fpga_main.v](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src/fpga_main.v)**
   - Top-level master controller module.
   - Houses the central FSM (`S_WAIT`, `S_GOL`) that controls system state.
   - Debounces physical button inputs and routes startup signals to status LEDs.
2. **[ring_osc.v](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src/ring_osc.v)**
   - Hardware entropy harvester and PRNG source.
   - Implements a physical ring oscillator to feed a non-linear LFSR sequence, providing the 16-bit random seed.
3. **[hx8357d_controller.v](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src/hx8357d_controller.v)**
   - Display coordinator and frame rendering controller.
   - Manages screen startup delays, issues data commands over SPI, and reads cell states from BRAM memory buffers.
   - Active cells are rendered in vibrant RGB565 **Green** (`16'h07E0`), and inactive cells are drawn in **Black** (`16'h0000`) on the 320x480 resolution screen.
4. **[hx8357d_init.v](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src/hx8357d_init.v)**
   - Hardware ROM sequence that compiles display-driver configuration commands, enabling SPI screen startup.
5. **[game_of_life.v](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src/game_of_life.v)**
   - Conway's Game of Life processor. 
   - Reads active cell neighborhoods from the active ping-pong BRAM buffer and writes updated cell generations into the standby BRAM buffer, using wrap-around toroidal limits.
6. **[bram_framebuffer.v](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src/bram_framebuffer.v)**
   - Ping-pong FPGA block RAM framebuffers, storing and buffering pixel/cell matrices for display reads.
7. **[spi_master.v](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/src/spi_master.v)**
   - Custom hardware SPI transmitter module.

---

## 🛠️ Build and Deployment Instructions

Ensure Xilinx Vivado is installed and the Digilent board files are configured.

### Quick Deployment
To compile the bitstream, run synthesis/implementation, and flash the CMOD A7 FPGA persistently over JTAG, execute the PowerShell script:
```powershell
.\scripts\deployment\deploy.ps1
```
Or simply double-click the batch file:
```cmd
.\scripts\deployment\deploy.bat
```

### Manual CLI Execution
If you prefer running Vivado batch scripts directly:
```powershell
# Synthesize and implement design
vivado -mode batch -source scripts/build_tools/build.tcl

# Program the FPGA SRAM
vivado -mode batch -source scripts/build_tools/program.tcl
```

---

## 🧪 Simulation and Verification

The [testbench/](file:///c:/Users/DarkMidget/Desktop/temp/PRNG_V2/verilog/testbench) directory contains verification benches to validate the simulation and graphics controller logic before physical deployment:

- **`tb_game_of_life.v`**: Simulates cellular automaton generations and verifies active-cell survival rules.
- **`tb_hx8357d_controller.v`**: Simulates the physical SPI signals (`SCK`, `MOSI`, `CS`, `DC`) and verifies SPI transaction timing.

To run tests and compile waveforms, run the test runner script:
```powershell
.\run_tests.ps1
```
You can inspect the compiled simulation files using **Vivado Simulator (xsim)** or dump signals into waveform viewers.
