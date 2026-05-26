# TCL script for programming CMOD A7 with ring_osc.bit
set bitstream_file [file normalize "ring_osc.bit"]

# Check if bitstream exists
if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream file not found: $bitstream_file"
    exit 1
}

puts "Starting hardware programming..."
puts "Bitstream: $bitstream_file"

# Open hardware manager
catch {open_hw_manager}

# Wait a moment for hardware server
after 1000

# Connect to hardware server (may already be connected)
catch {connect_hw_server -allow_non_jtag}

after 500

# Get available targets
set targets [get_hw_targets]
if {[llength $targets] == 0} {
    puts "ERROR: No hardware targets found!"
    puts "Please check FPGA connection and try again."
    exit 1
}

# Open first target (the FPGA)
set target [lindex $targets 0]
puts "Opening target: $target"
open_hw_target $target

after 500

# Get the FPGA device
set devices [get_hw_devices]
if {[llength $devices] == 0} {
    puts "ERROR: No FPGA devices found!"
    exit 1
}

set device [lindex $devices 0]
puts "Programming device: $device"

# Program the device
set_property PROGRAM.FILE $bitstream_file $device
program_hw_devices $device

puts "Programming completed successfully!"
puts "Device $device programmed with $bitstream_file"

# Cleanup
catch {close_hw_target}
catch {disconnect_hw_server}
catch {close_hw_manager}

exit 0
