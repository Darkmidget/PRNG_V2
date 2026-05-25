set parts [get_cfgmem_parts {mx25l3233f*}]
puts "FOUND_PARTS_MX: $parts"
set parts [get_cfgmem_parts {*25*32*}]
puts "FOUND_PARTS_2532: $parts"
exit
