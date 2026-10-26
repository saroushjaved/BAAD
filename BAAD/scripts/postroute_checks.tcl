set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build hardware_release]
open_project [file join $out project baad_release.xpr]
open_run impl_1
report_bus_skew -file [file join $out reports bus_skew.rpt]
check_timing -verbose -file [file join $out reports check_timing.rpt]
puts "POSTROUTE_CHECKS_COMPLETE"
close_project
