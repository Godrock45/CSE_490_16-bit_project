source [file join [file dirname [info script]] create_project.tcl]

set jobs 4

launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synthesis failed -- see [file join $proj_dir $proj_name.runs synth_1 runme.log]"
}

launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "implementation failed -- see [file join $proj_dir $proj_name.runs impl_1 runme.log]"
}

open_run impl_1
set rpt [file join $here reports]
file mkdir $rpt
report_utilization    -file [file join $rpt utilization.rpt]
report_timing_summary -file [file join $rpt timing_summary.rpt]

set bit [file join $proj_dir $proj_name.runs impl_1 basys3_top.bit]
file copy -force $bit [file join $here cpu16_basys3.bit]

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts ""
puts "Bitstream : [file join $here cpu16_basys3.bit]"
puts "Setup WNS : $wns ns (must be >= 0)"
puts "Reports   : $rpt"
