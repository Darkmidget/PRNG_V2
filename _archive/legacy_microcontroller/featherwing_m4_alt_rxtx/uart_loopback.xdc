##==========================================================
## CMOD A7-35T Constraints for UART Loopback Test
##==========================================================

## Clock signal (12 MHz onboard oscillator)
set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 83.33 -waveform {0 41.66} [get_ports { clk }];
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF];

## UART pins on DIP connector
# DIP pin 22 - UART TX from FPGA (connects to Feather A4 / Serial3 RX)
set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];

# DIP pin 23 - UART RX to FPGA (connects to Feather A1 / Serial3 TX)
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { uart_rx }];

## Onboard LEDs for status indication
set_property -dict { PACKAGE_PIN A17   IOSTANDARD LVCMOS33 } [get_ports { led0 }];
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { led1 }];

## Configuration options - bitstream compression and SPI x4 for faster loading
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
