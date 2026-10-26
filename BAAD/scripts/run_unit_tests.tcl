set root [file normalize [file join [file dirname [info script]] ..]]
set tag [expr {[llength $argv] ? [lindex $argv 0] : "current"}]
set out [file join $root build unit_$tag]
file mkdir $out
create_project -force baad_unit $out -part xczu9eg-ffvb1156-2-e
add_files [glob [file join $root BAAD_V1.srcs sources_1 new *.v]]
set tests [list]
foreach extra [glob -nocomplain [file join $root tests tb_*.sv]] {
    add_files -fileset sim_1 $extra
    lappend tests [file rootname [file tail $extra]]
}
foreach test [list tb_decimation_decision_control tb_rate_controlled_cic_decimator] {
    lappend tests $test
    add_files -fileset sim_1 [file join $root BAAD_V1.srcs sim_1 new $test.v]
}
set_property xsim.simulate.runtime all [get_filesets sim_1]
set executed [list]
foreach test $tests {
    if {[llength $argv] > 1 && ![string match [lindex $argv 1] $test]} {continue}
    lappend executed $test
    set_property top $test [get_filesets sim_1]
    update_compile_order -fileset sim_1
    launch_simulation
    close_sim
    set log [file join $out baad_unit.sim sim_1 behav xsim simulate.log]
    set fp [open $log r]; set result [read $fp]; close $fp
    file copy -force $log [file join $out $test.log]
    if {[regexp {FAIL|ERROR|Fatal:|FATAL} $result] || ![regexp {PASS} $result]} {
        error "Regression failed: $test; see $log"
    }
}
if {![llength $executed]} {error "No tests matched requested filter"}
puts "PASS: executed $executed"
