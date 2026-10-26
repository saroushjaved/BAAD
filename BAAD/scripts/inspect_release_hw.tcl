set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root build hardware_release project baad_release.xpr]
foreach r [get_runs] {
    puts "RUN_STATE|$r|[get_property STATUS $r]|[get_property PROGRESS $r]|refresh=[get_property NEEDS_REFRESH $r]"
}
close_project
