# Game of Life Hardware Wiring Guide

This guide details the physical wiring needed to run the integrated Game of Life workflow on the CMOD A7-35T FPGA.

## Required Hardware
- CMOD A7-35T FPGA
- AS606 Thumbprint Sensor (UART interface)
- Adafruit 3.5" TFT HX8357D Display (SPI interface)
- 1x Push Button (for triggering the scan)

## Pin Assignments

Based on the unified constraints file (`verilog/constraints/CMODA7_Constrain.xdc`), ensure the following physical connections:

### CMOD A7 Board Basics
| FPGA Component | Pin / Port | Description |
| --- | --- | --- |
| `sysclk` | **L17** | 12 MHz Onboard Oscillator |
| `btn[0]` | **A18** | Push button to trigger fingerprint scan |
| `led[0]` | **A17** | Status LED: Waiting for button press |
| `led[1]` | **C16** | Status LED: Game of Life running |

### AS606 Thumbprint Sensor (UART)
| Sensor Pin | FPGA Port | FPGA Pin Name | Physical DIP Pin | Description |
| --- | --- | --- | --- | --- |
| **TX** | `as606_rx` | **V19** | DIP Pin 23 | Sensor Transmit -> FPGA Receive |
| **RX** | `as606_tx` | **W19** | DIP Pin 22 | Sensor Receive <- FPGA Transmit |
| **VCC** | N/A | **VU** / **3.3V**| N/A | Ensure voltage compatibility (3.3V recommended) |
| **GND** | N/A | **GND** | N/A | Common Ground |

### HX8357D TFT Display (SPI)
| Display Pin | FPGA Port | FPGA Pin Name | Physical DIP Pin / Header | Description |
| --- | --- | --- | --- | --- |
| **CS** | `tft_cs` | **M3** | pio[01] | SPI Chip Select (Active Low) |
| **D/C** | `tft_dc` | **L3** | pio[02] | Data / Command Selection |
| **RST** | `tft_rst` | **A16** | pio[03] | Reset |
| **SCK** | `tft_sck` | **K3** | pio[04] | SPI Clock |
| **MOSI** | `tft_mosi`| **C15** | pio[05] | SPI Master Out Slave In |
| **VCC** | N/A | **3.3V** | N/A | Power (3.3V) |
| **GND** | N/A | **GND** | N/A | Common Ground |

## Workflow Execution Steps
1. Power on the CMOD A7. LED[0] should light up, indicating the system is waiting.
2. Press the push button connected to `btn[0]` (A18). 
3. The AS606 sensor will wait for a finger. Place your finger on the scanner.
4. Once scanned, the FPGA harvests the scan timing/status to generate a dynamic PRNG seed.
5. The display initializes, LED[1] lights up, and the Game of Life begins with the custom seed!
