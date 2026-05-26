# Vivado TCL Build Script for Ring Oscillator PRNG
# Set working directory to project root
set script_dir [file dirname [info script]]
set proj_dir [file normalize [file join $script_dir ".."]]
set build_dir [file join $proj_dir "build"]
set src_dir [file join $proj_dir "src"]
set xdc_dir [file join $proj_dir "constraints"]

cd $proj_dir

# Create project if it doesn't exist
if {[file exists $build_dir/cmod_a7_project.xpr]} {
    puts "Opening existing project..."
    open_project $build_dir/cmod_a7_project.xpr
} else {
    puts "Creating new project: cmod_a7_project"
    create_project cmod_a7_project $build_dir -part xc7a35tcpg236-1 -force
}

# Set Project Settings
set_property target_language Verilog [current_project]
set_property default_lib work [current_project]

# Add design sources - RING_OSC
add_files -fileset sources_1 $src_dir/ring_osc.v
set_property file_type {Verilog} [get_files $src_dir/ring_osc.v]

# Add constraints
add_files -fileset constrs_1 $xdc_dir/CMODA7_Constrain.xdc
add_files -fileset constrs_1 $xdc_dir/DSL_Starter_Kit.xdc

# Set top module
set_property top ring_osc [current_fileset]

# Save project
save_project_as $build_dir/cmod_a7_project -force

puts "Running Synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check for synthesis errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Running Implementation..."
reset_run impl_1  
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check for implementation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

puts "Writing Bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Generate reports
report_timing_summary -file $build_dir/timing_summary.rpt
report_utilization -file $build_dir/utilization.rpt
report_power -file $build_dir/power.rpt

puts "Bitstream generation complete!"
puts "Output: $build_dir/cmod_a7_project.runs/impl_1/ring_osc.bit"

close_project
exit 0
