set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build fixed_cic_comparison]
file mkdir $out
foreach m {0 1 2 4 8 16} {
 create_project -in_memory -part xczu9eg-ffvb1156-2-e
 read_verilog [file join $root BAAD_V1.srcs sources_1 new rate_controlled_cic_decimator.v]
 read_verilog [file join $root tests cic_compare_top.v]
 synth_design -top cic_compare_top -mode out_of_context -generic FIXED_M=$m
 create_clock -name dsp -period 16.129032 [get_ports clk]
 report_utilization -file [file join $out M${m}_utilization.rpt]
 report_timing_summary -file [file join $out M${m}_synthesis_timing.rpt]
 write_checkpoint -force [file join $out M${m}.dcp]
 puts "PASS fixed-core comparison M=$m (0 means runtime control); SYNTHESIS ONLY"
 close_project
}
