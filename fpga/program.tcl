set here [file normalize [file dirname [info script]]]
set bit  [file join $here cpu16_basys3.bit]
if {![file exists $bit]} { error "$bit not found -- run fpga/build.tcl first" }

if {[catch {open_hw_manager}]} { open_hw }
connect_hw_server -allow_non_jtag
open_hw_target
set dev [lindex [get_hw_devices xc7a35t*] 0]
if {$dev eq ""} { error "no xc7a35t found -- is the Basys 3 plugged in and switched on?" }
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
puts "Programmed $dev with $bit"
close_hw_target
disconnect_hw_server
