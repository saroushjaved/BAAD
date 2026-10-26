set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build hardware_release]
set reports [file join $out reports]
file mkdir $reports
if {[file exists [file join $out project baad_release.xpr]]} {
    error "Release project already exists; inspect and resume with resume_release_hw.tcl, or choose a new output directory."
}
create_project baad_release [file join $out project] -part xczu9eg-ffvb1156-2-e
set_property board_part xilinx.com:zcu102:part0:3.4 [current_project]
add_files [glob [file join $root BAAD_V1.srcs sources_1 new *.v]]
add_files [glob [file join $root BAAD_V1.ip_user_files mem_init_files *.mem]]
source [file join $root scripts main_bd.tcl]
source [file join $root scripts integrate_release.tcl]
generate_target all [get_files *.bd]
add_files [make_wrapper -files [get_files *.bd] -top]
set_property top BAAD_BD_wrapper [current_fileset]
update_compile_order -fileset sources_1
if {[lsearch -exact $argv project_only] >= 0} {
    puts "PASS: release source project generated without rebuilding implementation"
    close_project
    exit
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
report_timing_summary -report_unconstrained -file [file join $reports timing.rpt]
report_methodology -file [file join $reports methodology.rpt]
report_drc -file [file join $reports drc.rpt]
report_cdc -file [file join $reports cdc.rpt]
report_utilization -hierarchical -file [file join $reports utilization.rpt]
report_power -file [file join $reports power_estimated.rpt]
report_clock_interaction -file [file join $reports clocks.rpt]
write_debug_probes -force [file join $out BAAD_BD_wrapper.ltx]
write_hw_platform -fixed -include_bit -force -file [file join $out BAAD_BD_wrapper.xsa]
file copy -force [file join $out project baad_release.runs impl_1 BAAD_BD_wrapper.bit] [file join $out BAAD_BD_wrapper.bit]
puts "Hardware build completed; signoff reports must pass release checks: $reports"
