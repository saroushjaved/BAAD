set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root BAAD_V1.xpr]
open_bd_design [file join $root BAAD_V1.srcs sources_1 bd BAAD_BD BAAD_BD.bd]
write_bd_tcl -force [file join $root scripts main_bd.tcl]
close_project
