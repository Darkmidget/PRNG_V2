# Game of Life Hardware Wiring Guide

This guide details the physical wiring needed to run the fully integrated, standalone Game of Life workflow on the Digilent CMOD A7-35T FPGA co-processor.

---

## 🛠️ Required Hardware
1. **Digilent CMOD A7-35T FPGA** (equipped with the Xilinx Artix-7 chip)
2. **Adafruit 3.5" TFT HX8357D Display** (SPI interface version)
3. **1x Momentary Push Button** (active-high trigger for seed capturing)
4. **Jumper Wires & Breadboard**

> [!NOTE]
> The AS606 fingerprint sensor and the Adafruit Feather M4 Express microcontroller have been bypassed. The simulation, physical random number generation, display initialization, and SPI driving are managed **entirely** inside the FPGA fabric.

---

## 🔌 Pin Assignments & Mapping

Wire your hardware according to the unified constraints file (`CMODA7_Constrain.xdc`) mapped below:

### 1. Board Status and Inputs
| FPGA Pin Name | Physical DIP Pin | Component | Connection Type | Description |
|---|---|---|---|---|
| **L17** | Board Oscillator | Master Clock | Onboard | 12 MHz clock source driving all synchronous logic |
| **A18** | DIP Pin 24 / BTN0 | Push Button | External Input | Connect to one terminal of the push button. Wire the other terminal to **3.3V** with a **10kΩ pull-down resistor** to GND. |
| **A17** | Onboard LED0 | LED indicator | Onboard | Status Indicator: ON when waiting for button press |
| **C16** | Onboard LED1 | LED indicator | Onboard | Status Indicator: ON when Game of Life is active |

### 2. Adafruit 3.5" TFT HX8357D Display Interface
Connect the SPI pins of the Adafruit display directly to the CMOD A7 breakout pins:

| FPGA Port | FPGA Pin Name | Physical DIP Pin | Display Pin | Connection Description |
|---|---|---|---|---|
| `tft_cs` | **M3** | DIP Pin 1 | **CS** | SPI Chip Select (Active Low) |
| `tft_dc` | **L3** | DIP Pin 2 | **D/C** | Data / Command Selection |
| `tft_rst` | **A16** | DIP Pin 3 | **RST** | TFT Physical Hardware Reset |
| `tft_sck` | **K3** | DIP Pin 4 | **CLK** / **SCK** | SPI Serial Clock |
| `tft_mosi` | **C15** | DIP Pin 5 | **MOSI** | SPI Master Out Slave In |
| **3.3V** | **3.3V** | Pin 3.3V | **VCC** | Power (3.3V) |
| **GND** | **GND** | GND Pin | **GND** | Common ground reference |

---

## 🚀 Execution Workflow
Once wired and programmed:
1. **Power up the board** (via USB). **LED[0]** lights up instantly, and the display remains blank/white (held in reset).
2. **Press the push button** connected to **btn[0]** (A18).
3. The FPGA immediately harvests high-entropy seed data from the physical Ring Oscillator, launches the SPI ROM initialization sequence (the screen turns black), lights up **LED[1]**, and starts rendering Conway's Game of Life in vibrant **Green** (`16'h07E0`) against a **Black** background.
