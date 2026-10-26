# Called after main_bd.tcl in a fresh project. Existing signal processing stays
# in place; insert the burst drain between the snapshot packer and async FIFO.
set_property -dict [list CONFIG.PRIM_SOURCE {No_buffer} CONFIG.USE_LOCKED {true} CONFIG.USE_RESET {true} CONFIG.RESET_TYPE {ACTIVE_LOW}] [get_bd_cells Clock_62M]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins Clock_62M/resetn]
connect_bd_net [get_bd_pins Clock_62M/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 CLOCK_GOOD
set_property CONFIG.CONST_VAL 1 [get_bd_cells CLOCK_GOOD]
connect_bd_net [get_bd_pins CLOCK_GOOD/dout] [get_bd_pins rst_ps8_0_99M/dcm_locked]
create_bd_cell -type module -reference baad_burst_capture BURST_CAPTURE
disconnect_bd_intf_net [get_bd_intf_nets -of_objects [get_bd_intf_pins DATA_FIFO/S_AXIS]] [get_bd_intf_pins DATA_FIFO/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins DMA_DEBUG_FRAME/m_axis] [get_bd_intf_pins BURST_CAPTURE/s_axis]
connect_bd_intf_net [get_bd_intf_pins BURST_CAPTURE/m_axis] [get_bd_intf_pins DATA_FIFO/S_AXIS]
foreach {source target} {
 Clock_62M/clk_out1 BURST_CAPTURE/clk
 proc_sys_reset_0/peripheral_aresetn BURST_CAPTURE/rst_n
 dds_axi_config_regs_0/cfg_burst_control BURST_CAPTURE/control
 dds_axi_config_regs_0/cfg_burst_sample_count BURST_CAPTURE/sample_count
 BURST_CAPTURE/status dds_axi_config_regs_0/burst_status
 BURST_CAPTURE/capture_id dds_axi_config_regs_0/burst_capture_id
 DMA_DEBUG_FRAME/records_emitted dds_axi_config_regs_0/records_emitted
 DMA_DEBUG_FRAME/records_dropped dds_axi_config_regs_0/records_dropped
 dds_axi_config_regs_0/capture_flush DMA_DEBUG_FRAME/capture_flush
 IQ_Mixing/I_out BURST_CAPTURE/psd_i
 IQ_Mixing/Q_out BURST_CAPTURE/psd_q
 and_2_to_1_valid_CIC/valid_out BURST_CAPTURE/psd_valid
 CIC_Decimator/m_i BURST_CAPTURE/cic_i
 CIC_Decimator/m_q BURST_CAPTURE/cic_q
 CIC_Decimator/m_valid BURST_CAPTURE/cic_valid
 CIC_Decimator/settling BURST_CAPTURE/settling
 CIC_Decimator/rate_changed BURST_CAPTURE/rate_changed
 CIC_Decimator/cfg_error BURST_CAPTURE/cfg_error
 CIC_Decimator/overflow BURST_CAPTURE/cic_overflow
 CIC_Decimator/active_decimation_factor BURST_CAPTURE/active_m
 CIC_Decimator/active_gain_shift BURST_CAPTURE/gain_shift
 DECIMATION_DECISION/decision_valid BURST_CAPTURE/decision_valid
 DECIMATION_DECISION/decision_error BURST_CAPTURE/decision_error
 BANDWIDTH_ESTIMATOR/frame_id BURST_CAPTURE/frame_id
} {connect_bd_net [get_bd_pins $source] [get_bd_pins $target]}
disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins DATA_FIFO/s_axis_aresetn]] [get_bd_pins DATA_FIFO/s_axis_aresetn]
connect_bd_net [get_bd_pins dds_axi_config_regs_0/capture_resetn] [get_bd_pins DATA_FIFO/s_axis_aresetn]
# Use the same I/Q-valid conjunction as the processing chain for debug samples.
disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins DMA_DEBUG_FRAME/psd_input_valid]] [get_bd_pins DMA_DEBUG_FRAME/psd_input_valid]
connect_bd_net [get_bd_pins and_2_to_1_valid_CIC/valid_out] [get_bd_pins DMA_DEBUG_FRAME/psd_input_valid]
# DMA memory interconnect runs at 100 MHz, so release its reset in that domain.
disconnect_bd_net [get_bd_nets -of_objects [get_bd_pins axi_dma_smc/aresetn]] [get_bd_pins axi_dma_smc/aresetn]
connect_bd_net [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] [get_bd_pins axi_dma_smc/aresetn]
validate_bd_design
save_bd_design
