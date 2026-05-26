set parts [get_cfgmem_parts]
set fp [open "parts.txt" w]
puts $fp $parts
close $fp
exit
