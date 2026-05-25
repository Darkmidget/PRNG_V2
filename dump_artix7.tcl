open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices] 0]
current_hw_device $device

set supported_parts [get_cfgmem_parts -of_objects $device]
set fp [open "artix7_parts.txt" w]
puts $fp $supported_parts
close $fp

close_hw_target
disconnect_hw_server
close_hw_manager
exit
