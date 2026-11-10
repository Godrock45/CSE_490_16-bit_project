set here      [file normalize [file dirname [info script]]]
set root      [file normalize [file join $here ..]]
set proj_name cpu16_basys3
set proj_dir  [file join $here vivado]
set part      xc7a35tcpg236-1

create_project -force $proj_name $proj_dir -part $part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
catch { set_property board_part digilentinc.com:basys3:part0:1.2 [current_project] }

set rtl_files {
    PC.sv ROM.sv decoder.sv control.sv registers.sv sign_extend.sv mux2.sv
    ALU.sv data_mem.sv ripple.sv shift_left1.sv branch_logic.sv cmp.sv top.sv
}
set srcs {}
foreach f $rtl_files { lappend srcs [file join $root RTL $f] }
foreach f {clk_gen.sv debounce.sv hex7seg.sv basys3_top.sv} { lappend srcs [file join $here $f] }
add_files -norecurse -fileset sources_1 $srcs
set_property file_type SystemVerilog [get_files $srcs]
set_property top basys3_top [get_filesets sources_1]

add_files -norecurse -fileset constrs_1 [list [file join $here basys3.xdc]]

set sims {}
foreach f {isa_ref.sv tb_cpu.sv tb_units.sv tb_random.sv tb_basys3.sv} { lappend sims [file join $root sim $f] }
add_files -norecurse -fileset sim_1 $sims
set_property file_type SystemVerilog [get_files $sims]
set_property top tb_cpu [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created [file join $proj_dir $proj_name.xpr]"
