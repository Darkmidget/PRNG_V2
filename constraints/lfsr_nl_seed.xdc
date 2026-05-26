##==========================================================
## CMOD A7-35T Constraints for UART Seeded LFSR_NL
##==========================================================

## Clock signal (12 MHz onboard oscillator)
set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { sysclk }];
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { sysclk }];

## UART pins on DIP connector
## DIP pin 22 - UART TX from FPGA
set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];

## DIP pin 23 - UART RX to FPGA
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { uart_rx }];

## Optional LEDs for status
set_property -dict { PACKAGE_PIN A17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];

## Configuration options
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Allow combinatorial loops for TRNG Ring Oscillator
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical *ring*]
