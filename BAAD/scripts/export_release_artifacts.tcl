# Called with a completed release project open; root/out may already exist.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build hardware_release]
set reports [file join $out reports]
file mkdir $reports
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
puts "Hardware build exported; review signoff reports before release: $reports"
