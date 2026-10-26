# Resume the generated release project only; no original/chain-only project is
# reset. Run only after confirming no surviving process owns these runs.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build hardware_release]
set reports [file join $out reports]
open_project [file join $out project baad_release.xpr]
open_bd_design [get_files *.bd]
update_module_reference [get_ips -all BAAD_BD_dds_axi_config_regs_0_0]
update_module_reference [get_ips -all BAAD_BD_DMA_DEBUG_FRAME_0]
validate_bd_design
save_bd_design
generate_target all [get_files *.bd]
update_compile_order -fileset sources_1
# Reset only incomplete or stale synthesis run products in this generated
# project. Preserve completed, unchanged IP checkpoints from the prior run.
foreach r [get_runs -filter {IS_SYNTHESIS == 1}] {
    set progress [get_property PROGRESS $r]
    set stale [get_property NEEDS_REFRESH $r]
    puts "RESUME_CHECK|$r|[get_property STATUS $r]|$progress|refresh=$stale"
    if {$progress ne "100%" || $stale} { reset_run $r }
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
source [file join $root scripts export_release_artifacts.tcl]
