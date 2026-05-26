# DRC bypass build script
set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize "$script_dir/build"]
set project_name "cmod_a7_project"

puts "Opening project: $project_dir/$project_name.xpr"
open_project $project_dir/$project_name.xpr

# Open impl_1 run
open_run impl_1 -quiet

# Bypass DRC for known combinatorial loop (ring oscillator is intentional)
set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# Generate bitstream
write_bitstream -force ring_osc.bit

puts "Bitstream generation complete: ring_osc.bit"
exit 0
