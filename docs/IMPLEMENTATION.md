# UART-Seeded LFSR_NL Implementation

## Objective
Implement FPGA logic that:
1. Receives fingerprint bytes on UART RX
2. Uses received bytes as seed input
3. Runs the notebook-declared LFSR_NL randomization flow
4. Returns one 16-bit random output on UART TX

## UART Pin Configuration (Confirmed)
- DIP pin 22 (FPGA TX): `uart_tx` -> W19
- DIP pin 23 (FPGA RX): `uart_rx` -> V19
- Clock: `sysclk` -> L17 (12 MHz)

Constraint file used:
- `constraints/lfsr_nl_seed.xdc`

This matches the attached loopback reference pin map.

## Implemented Top Module
Top module:
- `src/lfsr_nl_seed_uart.v`

Build configuration:
- `scripts/config.tcl`
  - `TOP_MODULE = lfsr_nl_seed_uart`
  - `SOURCE_FILES = [list "lfsr_nl_seed_uart.v"]`
  - `CONSTRAINT_FILES = [list "lfsr_nl_seed.xdc"]`

## Data Protocol
### Receive side
- UART: 115200, 8N1
- Frame format: variable-length bytes terminated by `0xFF`
- Seed policy:
  - Uses first 2 payload bytes as seed
  - Big-endian seed mapping: `seed = {byte0, byte1}`
  - If only 1 payload byte is sent before terminator, seed becomes `{byte0, 0x00}`
  - Extra bytes after first two are ignored for seed derivation

### Randomization side
Implemented from notebook flow in hardware:
- XADC sampling path
- von Neumann corrector bit extraction
- 16-bit nonlinear LFSR feedback update
- Whitening using S-box and xor-mix functions

### Transmit side
- Returns one 16-bit random result per completed frame
- Byte order on UART TX: little-endian
  - First byte: random[7:0]
  - Second byte: random[15:8]

## Internal FSM
Top-level response FSM in `lfsr_nl_seed_uart.v`:
- `ST_IDLE`
- `ST_SEND_BYTE0`
- `ST_WAIT_BYTE0`
- `ST_SEND_BYTE1`
- `ST_WAIT_BYTE1`

## Build and Flash Result
Deployment command executed:
- `powershell -ExecutionPolicy Bypass -File .\deploy.ps1`

Observed result:
- Synthesis: success
- Implementation: success
- Bitstream generation: success
- Programming device over USB/JTAG: success

## Functional Host Test Result
Host test script used:
- `test_final.ps1`

Current observation:
- Script sends test frame, but host did not receive return bytes (timeout on COM4)

## Notes for Hardware Validation
If no bytes are received on host side after successful programming, verify physical serial path:
1. Host COM port corresponds to the UART bridge connected to DIP22/DIP23 path
2. RX/TX crossing is correct between bridge and FPGA pins
3. Shared GND is present
4. UART settings are 115200, 8N1

## Files Added/Modified
- Added: `src/lfsr_nl_seed_uart.v`
- Added: `constraints/lfsr_nl_seed.xdc`
- Modified: `scripts/config.tcl`
- Added: `IMPLEMENTATION.md`
