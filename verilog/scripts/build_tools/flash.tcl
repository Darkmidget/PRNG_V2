# TCL script for programming CMOD A7 SPI Flash via JTAG
# This script converts the bitstream to MCS and programs the onboard flash

set script_dir [file dirname [file normalize [info script]]]

# Load project configuration
set config_file [file normalize "$script_dir/config.tcl"]
if {![file exists $config_file]} {
    puts "ERROR: Configuration file not found: $config_file"
    puts "Please create config.tcl in the scripts directory"
    exit 1
}
source $config_file

# Set paths based on configuration
set project_dir [file normalize "$script_dir/../../$BUILD_DIR"]
set project_name $PROJECT_NAME
set bitstream_file "$project_dir/$project_name.runs/impl_1/$TOP_MODULE.bit"
set mcs_file "$project_dir/$project_name.runs/impl_1/$TOP_MODULE.mcs"

# Check if bitstream exists
if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream file not found: $bitstream_file"
    puts "Please run build.tcl first to generate the bitstream"
    exit 1
}

puts "Generating MCS file from bitstream..."
write_cfgmem -format mcs -size 4 -interface SPIx4 -loadbit "up 0x00000000 $bitstream_file" -force -file $mcs_file

# Open hardware manager
open_hw_manager

# Connect to hardware server
connect_hw_server -allow_non_jtag

# Open target board
open_hw_target

# Set the current hardware device
set device [lindex [get_hw_devices] 0]
current_hw_device $device

puts "Configuring hardware for flash programming..."
# Cmod A7-35T uses either Macronix or ISSI 32Mbit SPI Flash depending on the board revision.
# If Macronix (mx25l3233f/mx25l3273f) fails, we try the ISSI part (is25lp032d-spi-x1_x2_x4).
set flash_part "mx25l3273f-spi-x1_x2_x4"
set mem_device [lindex [get_cfgmem_parts $flash_part] 0]

create_hw_cfgmem -hw_device $device -mem_dev $mem_device
set cfgmem [get_property PROGRAM.HW_CFGMEM $device]

set_property PROGRAM.FILES [list $mcs_file] $cfgmem
set_property PROGRAM.PRM_FILE {} $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $cfgmem
set_property PROGRAM.BLANK_CHECK  0 $cfgmem
set_property PROGRAM.ERASE  1 $cfgmem
set_property PROGRAM.CFG_PROGRAM  1 $cfgmem
set_property PROGRAM.VERIFY  1 $cfgmem
set_property PROGRAM.CHECKSUM  0 $cfgmem
set_property PROGRAM.ADDRESS_RANGE {use_file} $cfgmem

puts "Programming SPI Flash with: $mcs_file"
puts "This may take 30-60 seconds..."
program_hw_cfgmem -hw_cfgmem $cfgmem

puts "Booting from flash..."
boot_hw_device $device
refresh_hw_device $device

puts "Flash programming completed successfully!"

# Close hardware manager
close_hw_target
disconnect_hw_server
close_hw_manager
