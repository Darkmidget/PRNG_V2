open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices] 0]
current_hw_device $device

set parts [get_cfgmem_parts -filter {MANUFACTURER=="Macronix" && SIZE=="32"}]
puts "MACRONIX_32M_PARTS: $parts"

set spansion [get_cfgmem_parts -filter {MANUFACTURER=="Spansion" && SIZE=="32"}]
puts "SPANSION_32M_PARTS: $spansion"

close_hw_target
disconnect_hw_server
close_hw_manager
exit
