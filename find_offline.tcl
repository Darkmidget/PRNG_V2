set parts [get_cfgmem_parts * -filter {MANUFACTURER=="Macronix" && SIZE=="32"}]
set fp [open "macronix32.txt" w]
puts $fp $parts
close $fp

set parts_a7 [get_cfgmem_parts * -filter {MANUFACTURER=="Macronix" && SIZE=="32"}]
set fp2 [open "macronix32_a7.txt" w]
puts $fp2 $parts_a7
close $fp2

set spansion [get_cfgmem_parts * -filter {MANUFACTURER=="Spansion" && SIZE=="32"}]
set fp3 [open "spansion32.txt" w]
puts $fp3 $spansion
close $fp3

exit
