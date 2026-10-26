
################################################################
# This is a generated script based on design: BAAD_BD
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2025.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source BAAD_BD_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# bandwidth_estimator, decimation_decision_control, rate_controlled_cic_decimator, and_2_to_1, dds_axi_config_regs, dma_debug_frame_packer, multitone_adder, and_6_to_1, hann_rom_q15, FFT_Frame_Counter, and_2_to_1, psd_hann_multiply, fft_input_packer, fft_config_driver, fft_output_unpacker, and_2_to_1, psd_magnitude_squared

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu9eg-ffvb1156-2-e
   set_property BOARD_PART xilinx.com:zcu102:part0:3.4 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name BAAD_BD

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:axis_data_fifo:2.0\
xilinx.com:ip:zynq_ultra_ps_e:3.5\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:axi_clock_converter:2.1\
xilinx.com:ip:ila:6.2\
xilinx.com:ip:dds_compiler:6.0\
xilinx.com:ip:xlslice:1.0\
xilinx.com:ip:mult_gen:12.0\
xilinx.com:ip:fir_compiler:7.2\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:xfft:9.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
bandwidth_estimator\
decimation_decision_control\
rate_controlled_cic_decimator\
and_2_to_1\
dds_axi_config_regs\
dma_debug_frame_packer\
multitone_adder\
and_6_to_1\
hann_rom_q15\
FFT_Frame_Counter\
and_2_to_1\
psd_hann_multiply\
fft_input_packer\
fft_config_driver\
fft_output_unpacker\
and_2_to_1\
psd_magnitude_squared\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: Power_Spectral_Density
proc create_hier_cell_Power_Spectral_Density { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_Power_Spectral_Density() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -type clk clock
  create_bd_pin -dir I -from 15 -to 0 I_in
  create_bd_pin -dir I -from 15 -to 0 Q_in
  create_bd_pin -dir I valid2
  create_bd_pin -dir I valid1
  create_bd_pin -dir I -type rst rst_n
  create_bd_pin -dir O psd_valid_out
  create_bd_pin -dir O -from 32 -to 0 psd_power
  create_bd_pin -dir O -from 10 -to 0 psd_bin
  create_bd_pin -dir O psd_last
  create_bd_pin -dir O psd_overflow

  # Create instance: hann_rom_q15_0, and set properties
  set block_name hann_rom_q15
  set block_cell_name hann_rom_q15_0
  if { [catch {set hann_rom_q15_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $hann_rom_q15_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: FFT_Frame_Counter, and set properties
  set block_name FFT_Frame_Counter
  set block_cell_name FFT_Frame_Counter
  if { [catch {set FFT_Frame_Counter [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $FFT_Frame_Counter eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: and_2_to_1_0, and set properties
  set block_name and_2_to_1
  set block_cell_name and_2_to_1_0
  if { [catch {set and_2_to_1_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $and_2_to_1_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: PSD_hann_multiply, and set properties
  set block_name psd_hann_multiply
  set block_cell_name PSD_hann_multiply
  if { [catch {set PSD_hann_multiply [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $PSD_hann_multiply eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: FFT_Input_Packer, and set properties
  set block_name fft_input_packer
  set block_cell_name FFT_Input_Packer
  if { [catch {set FFT_Input_Packer [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $FFT_Input_Packer eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: FFT, and set properties
  set FFT [ create_bd_cell -type ip -vlnv xilinx.com:ip:xfft:9.1 FFT ]
  set_property -dict [list \
    CONFIG.aresetn {true} \
    CONFIG.implementation_options {pipelined_streaming_io} \
    CONFIG.input_width {16} \
    CONFIG.number_of_stages_using_block_ram_for_data_and_phase_factors {4} \
    CONFIG.output_ordering {natural_order} \
    CONFIG.ovflo {true} \
    CONFIG.rounding_modes {convergent_rounding} \
    CONFIG.super_sample_rates {1} \
    CONFIG.target_clock_frequency {62} \
    CONFIG.target_data_throughput {50} \
    CONFIG.throttle_scheme {realtime} \
    CONFIG.transform_length {2048} \
    CONFIG.xk_index {true} \
  ] $FFT


  # Create instance: fft_config_driver_0, and set properties
  set block_name fft_config_driver
  set block_cell_name fft_config_driver_0
  if { [catch {set fft_config_driver_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $fft_config_driver_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: fft_output_unpacker_0, and set properties
  set block_name fft_output_unpacker
  set block_cell_name fft_output_unpacker_0
  if { [catch {set fft_output_unpacker_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $fft_output_unpacker_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: and_2_to_1_1, and set properties
  set block_name and_2_to_1
  set block_cell_name and_2_to_1_1
  if { [catch {set and_2_to_1_1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $and_2_to_1_1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: psd_magnitude_squared_0, and set properties
  set block_name psd_magnitude_squared
  set block_cell_name psd_magnitude_squared_0
  if { [catch {set psd_magnitude_squared_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $psd_magnitude_squared_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net FFT_Input_Packer_s_axis_data [get_bd_intf_pins FFT_Input_Packer/s_axis_data] [get_bd_intf_pins FFT/S_AXIS_DATA]
  connect_bd_intf_net -intf_net fft_config_driver_0_s_axis_config [get_bd_intf_pins fft_config_driver_0/s_axis_config] [get_bd_intf_pins FFT/S_AXIS_CONFIG]

  # Create port connections
  connect_bd_net -net FFT_Frame_Counter_I_out  [get_bd_pins FFT_Frame_Counter/I_out] \
  [get_bd_pins PSD_hann_multiply/I_in]
  connect_bd_net -net FFT_Frame_Counter_Q_out  [get_bd_pins FFT_Frame_Counter/Q_out] \
  [get_bd_pins PSD_hann_multiply/Q_in]
  connect_bd_net -net FFT_Frame_Counter_last_out  [get_bd_pins FFT_Frame_Counter/last_out] \
  [get_bd_pins PSD_hann_multiply/last_in]
  connect_bd_net -net FFT_Frame_Counter_sample_index  [get_bd_pins FFT_Frame_Counter/sample_index] \
  [get_bd_pins hann_rom_q15_0/addr]
  connect_bd_net -net FFT_Frame_Counter_valid_out  [get_bd_pins FFT_Frame_Counter/valid_out] \
  [get_bd_pins hann_rom_q15_0/valid_in] \
  [get_bd_pins PSD_hann_multiply/valid_in]
  connect_bd_net -net FFT_m_axis_data_tdata  [get_bd_pins FFT/m_axis_data_tdata] \
  [get_bd_pins fft_output_unpacker_0/m_axis_data_tdata]
  connect_bd_net -net FFT_m_axis_data_tlast  [get_bd_pins FFT/m_axis_data_tlast] \
  [get_bd_pins fft_output_unpacker_0/m_axis_data_tlast]
  connect_bd_net -net FFT_m_axis_data_tuser  [get_bd_pins FFT/m_axis_data_tuser] \
  [get_bd_pins fft_output_unpacker_0/m_axis_data_tuser]
  connect_bd_net -net FFT_m_axis_data_tvalid  [get_bd_pins FFT/m_axis_data_tvalid] \
  [get_bd_pins fft_output_unpacker_0/m_axis_data_tvalid]
  connect_bd_net -net I_in_1  [get_bd_pins I_in] \
  [get_bd_pins FFT_Frame_Counter/I_in]
  connect_bd_net -net PSD_hann_multiply_I_win  [get_bd_pins PSD_hann_multiply/I_win] \
  [get_bd_pins FFT_Input_Packer/I_in]
  connect_bd_net -net PSD_hann_multiply_Q_win  [get_bd_pins PSD_hann_multiply/Q_win] \
  [get_bd_pins FFT_Input_Packer/Q_in]
  connect_bd_net -net PSD_hann_multiply_last_out  [get_bd_pins PSD_hann_multiply/last_out] \
  [get_bd_pins FFT_Input_Packer/last_in]
  connect_bd_net -net PSD_hann_multiply_valid_out  [get_bd_pins PSD_hann_multiply/valid_out] \
  [get_bd_pins and_2_to_1_1/valid1]
  connect_bd_net -net Q_in_1  [get_bd_pins Q_in] \
  [get_bd_pins FFT_Frame_Counter/Q_in]
  connect_bd_net -net and_2_to_1_0_valid_out  [get_bd_pins and_2_to_1_0/valid_out] \
  [get_bd_pins FFT_Frame_Counter/valid_in]
  connect_bd_net -net and_2_to_1_1_valid_out  [get_bd_pins and_2_to_1_1/valid_out] \
  [get_bd_pins FFT_Input_Packer/valid_in]
  connect_bd_net -net clk_wiz_clk_out1  [get_bd_pins clock] \
  [get_bd_pins hann_rom_q15_0/clk] \
  [get_bd_pins FFT_Input_Packer/clk] \
  [get_bd_pins FFT/aclk] \
  [get_bd_pins psd_magnitude_squared_0/clk] \
  [get_bd_pins FFT_Frame_Counter/clk] \
  [get_bd_pins PSD_hann_multiply/clk] \
  [get_bd_pins fft_config_driver_0/aclk] \
  [get_bd_pins fft_output_unpacker_0/clk]
  connect_bd_net -net fft_config_driver_0_config_done  [get_bd_pins fft_config_driver_0/config_done] \
  [get_bd_pins and_2_to_1_1/valid2]
  connect_bd_net -net fft_output_unpacker_0_fft_bin  [get_bd_pins fft_output_unpacker_0/fft_bin] \
  [get_bd_pins psd_magnitude_squared_0/fft_bin]
  connect_bd_net -net fft_output_unpacker_0_fft_im  [get_bd_pins fft_output_unpacker_0/fft_im] \
  [get_bd_pins psd_magnitude_squared_0/fft_im]
  connect_bd_net -net fft_output_unpacker_0_fft_last  [get_bd_pins fft_output_unpacker_0/fft_last] \
  [get_bd_pins psd_magnitude_squared_0/fft_last]
  connect_bd_net -net fft_output_unpacker_0_fft_overflow  [get_bd_pins fft_output_unpacker_0/fft_overflow] \
  [get_bd_pins psd_magnitude_squared_0/fft_overflow]
  connect_bd_net -net fft_output_unpacker_0_fft_re  [get_bd_pins fft_output_unpacker_0/fft_re] \
  [get_bd_pins psd_magnitude_squared_0/fft_re]
  connect_bd_net -net fft_output_unpacker_0_fft_valid  [get_bd_pins fft_output_unpacker_0/fft_valid] \
  [get_bd_pins psd_magnitude_squared_0/fft_valid]
  connect_bd_net -net hann_rom_q15_0_coeff_out  [get_bd_pins hann_rom_q15_0/coeff_out] \
  [get_bd_pins PSD_hann_multiply/coeff_in]
  connect_bd_net -net hann_rom_q15_0_valid_out  [get_bd_pins hann_rom_q15_0/valid_out] \
  [get_bd_pins PSD_hann_multiply/coeff_valid]
  connect_bd_net -net psd_magnitude_squared_0_psd_bin  [get_bd_pins psd_magnitude_squared_0/psd_bin] \
  [get_bd_pins psd_bin]
  connect_bd_net -net psd_magnitude_squared_0_psd_last  [get_bd_pins psd_magnitude_squared_0/psd_last] \
  [get_bd_pins psd_last]
  connect_bd_net -net psd_magnitude_squared_0_psd_overflow  [get_bd_pins psd_magnitude_squared_0/psd_overflow] \
  [get_bd_pins psd_overflow]
  connect_bd_net -net psd_magnitude_squared_0_psd_power  [get_bd_pins psd_magnitude_squared_0/psd_power] \
  [get_bd_pins psd_power]
  connect_bd_net -net psd_magnitude_squared_0_psd_valid  [get_bd_pins psd_magnitude_squared_0/psd_valid] \
  [get_bd_pins psd_valid_out]
  connect_bd_net -net rst_n_1  [get_bd_pins rst_n] \
  [get_bd_pins FFT/aresetn] \
  [get_bd_pins FFT_Frame_Counter/rst_n] \
  [get_bd_pins hann_rom_q15_0/rst_n] \
  [get_bd_pins PSD_hann_multiply/rst_n] \
  [get_bd_pins FFT_Input_Packer/rst_n] \
  [get_bd_pins fft_config_driver_0/aresetn] \
  [get_bd_pins fft_output_unpacker_0/rst_n] \
  [get_bd_pins psd_magnitude_squared_0/rst_n]
  connect_bd_net -net valid1_1  [get_bd_pins valid1] \
  [get_bd_pins and_2_to_1_0/valid1]
  connect_bd_net -net valid2_1  [get_bd_pins valid2] \
  [get_bd_pins and_2_to_1_0/valid2]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: IQ_Mixing
proc create_hier_cell_IQ_Mixing { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_IQ_Mixing() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -type clk clock
  create_bd_pin -dir I -from 15 -to 0 -type data B
  create_bd_pin -dir O -from 15 -to 0 -type data I_out
  create_bd_pin -dir O -from 15 -to 0 -type data Q_out
  create_bd_pin -dir O valid_out
  create_bd_pin -dir O m_axis_data_tvalid

  # Create instance: DDS_IF_Generation, and set properties
  set DDS_IF_Generation [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 DDS_IF_Generation ]
  set_property -dict [list \
    CONFIG.DDS_Clock_Rate {62} \
    CONFIG.Frequency_Resolution {1} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Latency {10} \
    CONFIG.M_DATA_Has_TUSER {Not_Required} \
    CONFIG.Negative_Sine {true} \
    CONFIG.Noise_Shaping {Auto} \
    CONFIG.OUTPUT_FORM {Twos_Complement} \
    CONFIG.Optimization_Goal {Speed} \
    CONFIG.Output_Frequency1 {10} \
    CONFIG.Output_Width {14} \
    CONFIG.PINC1 {101001010010100101001010} \
    CONFIG.Phase_Width {26} \
    CONFIG.Spurious_Free_Dynamic_Range {80} \
  ] $DDS_IF_Generation


  # Create instance: SINE, and set properties
  set SINE [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 SINE ]
  set_property -dict [list \
    CONFIG.DIN_FROM {29} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {32} \
  ] $SINE


  # Create instance: COSINE, and set properties
  set COSINE [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 COSINE ]
  set_property -dict [list \
    CONFIG.DIN_FROM {13} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {32} \
  ] $COSINE


  # Create instance: Input_Q, and set properties
  set Input_Q [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 Input_Q ]
  set_property -dict [list \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthHigh {28} \
    CONFIG.OutputWidthLow {13} \
    CONFIG.PipeStages {4} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {14} \
    CONFIG.PortBType {Signed} \
    CONFIG.PortBWidth {16} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $Input_Q


  # Create instance: Input_I, and set properties
  set Input_I [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 Input_I ]
  set_property -dict [list \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthHigh {28} \
    CONFIG.OutputWidthLow {13} \
    CONFIG.PipeStages {4} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {14} \
    CONFIG.PortBType {Signed} \
    CONFIG.PortBWidth {16} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $Input_I


  # Create instance: LPF_Q, and set properties
  set LPF_Q [ create_bd_cell -type ip -vlnv xilinx.com:ip:fir_compiler:7.2 LPF_Q ]
  set_property -dict [list \
    CONFIG.Clock_Frequency {62} \
    CONFIG.CoefficientSource {COE_File} \
    CONFIG.Coefficient_File [file normalize [file join $::script_folder .. BAAD_V1.ip_user_files mem_init_files ddc_lpf_order128_q15.coe]] \
    CONFIG.Coefficient_Fractional_Bits {0} \
    CONFIG.Coefficient_Sets {1} \
    CONFIG.Coefficient_Sign {Signed} \
    CONFIG.Coefficient_Structure {Inferred} \
    CONFIG.Coefficient_Width {16} \
    CONFIG.ColumnConfig {65} \
    CONFIG.Filter_Architecture {Systolic_Multiply_Accumulate} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Output_Width {33} \
    CONFIG.Quantization {Integer_Coefficients} \
    CONFIG.Sample_Frequency {62} \
  ] $LPF_Q


  # Create instance: LPF_I, and set properties
  set LPF_I [ create_bd_cell -type ip -vlnv xilinx.com:ip:fir_compiler:7.2 LPF_I ]
  set_property -dict [list \
    CONFIG.Clock_Frequency {62} \
    CONFIG.CoefficientSource {COE_File} \
    CONFIG.Coefficient_File [file normalize [file join $::script_folder .. BAAD_V1.ip_user_files mem_init_files ddc_lpf_order128_q15.coe]] \
    CONFIG.Coefficient_Fractional_Bits {0} \
    CONFIG.Coefficient_Sets {1} \
    CONFIG.Coefficient_Sign {Signed} \
    CONFIG.Coefficient_Structure {Inferred} \
    CONFIG.Coefficient_Width {16} \
    CONFIG.ColumnConfig {65} \
    CONFIG.Filter_Architecture {Systolic_Multiply_Accumulate} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.Output_Width {33} \
    CONFIG.Quantization {Integer_Coefficients} \
    CONFIG.Sample_Frequency {62} \
  ] $LPF_I


  # Create instance: HIGH, and set properties
  set HIGH [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 HIGH ]

  # Create instance: SLICE_Q_LPF, and set properties
  set SLICE_Q_LPF [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 SLICE_Q_LPF ]
  set_property -dict [list \
    CONFIG.DIN_FROM {30} \
    CONFIG.DIN_TO {15} \
    CONFIG.DIN_WIDTH {40} \
  ] $SLICE_Q_LPF


  # Create instance: SLICE_I_LPF, and set properties
  set SLICE_I_LPF [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 SLICE_I_LPF ]
  set_property -dict [list \
    CONFIG.DIN_FROM {30} \
    CONFIG.DIN_TO {15} \
    CONFIG.DIN_WIDTH {40} \
  ] $SLICE_I_LPF


  # Create port connections
  connect_bd_net -net B_1  [get_bd_pins B] \
  [get_bd_pins Input_Q/B] \
  [get_bd_pins Input_I/B]
  connect_bd_net -net COSINE_Dout  [get_bd_pins COSINE/Dout] \
  [get_bd_pins Input_I/A]
  connect_bd_net -net DDS_IF_Generation_m_axis_data_tdata  [get_bd_pins DDS_IF_Generation/m_axis_data_tdata] \
  [get_bd_pins SINE/Din] \
  [get_bd_pins COSINE/Din]
  connect_bd_net -net HIGH_dout  [get_bd_pins HIGH/dout] \
  [get_bd_pins LPF_I/aresetn] \
  [get_bd_pins LPF_Q/aresetn] \
  [get_bd_pins LPF_I/s_axis_data_tvalid] \
  [get_bd_pins LPF_Q/s_axis_data_tvalid]
  connect_bd_net -net Input_I_P  [get_bd_pins Input_I/P] \
  [get_bd_pins LPF_I/s_axis_data_tdata]
  connect_bd_net -net Input_Q_P  [get_bd_pins Input_Q/P] \
  [get_bd_pins LPF_Q/s_axis_data_tdata]
  connect_bd_net -net LPF_I_m_axis_data_tdata  [get_bd_pins LPF_I/m_axis_data_tdata] \
  [get_bd_pins SLICE_I_LPF/Din]
  connect_bd_net -net LPF_I_m_axis_data_tvalid  [get_bd_pins LPF_I/m_axis_data_tvalid] \
  [get_bd_pins valid_out]
  connect_bd_net -net LPF_Q_m_axis_data_tdata  [get_bd_pins LPF_Q/m_axis_data_tdata] \
  [get_bd_pins SLICE_Q_LPF/Din]
  connect_bd_net -net LPF_Q_m_axis_data_tvalid  [get_bd_pins LPF_Q/m_axis_data_tvalid] \
  [get_bd_pins m_axis_data_tvalid]
  connect_bd_net -net SINE_Dout  [get_bd_pins SINE/Dout] \
  [get_bd_pins Input_Q/A]
  connect_bd_net -net SLICE_I_LPF_Dout  [get_bd_pins SLICE_I_LPF/Dout] \
  [get_bd_pins I_out]
  connect_bd_net -net SLICE_Q_LPF_Dout  [get_bd_pins SLICE_Q_LPF/Dout] \
  [get_bd_pins Q_out]
  connect_bd_net -net clock_1  [get_bd_pins clock] \
  [get_bd_pins DDS_IF_Generation/aclk] \
  [get_bd_pins Input_Q/CLK] \
  [get_bd_pins Input_I/CLK] \
  [get_bd_pins LPF_I/aclk] \
  [get_bd_pins LPF_Q/aclk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: Signal_Generation
proc create_hier_cell_Signal_Generation { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_Signal_Generation() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_CONFIG

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_CONFIG1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_CONFIG2

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_CONFIG3

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_CONFIG4

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_CONFIG5


  # Create pins
  create_bd_pin -dir I -type clk clock
  create_bd_pin -dir O valid_out
  create_bd_pin -dir O -from 15 -to 0 dout

  # Create instance: Wave_1, and set properties
  set Wave_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 Wave_1 ]
  set_property -dict [list \
    CONFIG.DATA_Has_TLAST {Not_Required} \
    CONFIG.DDS_Clock_Rate {62} \
    CONFIG.Frequency_Resolution {1} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Has_TREADY {true} \
    CONFIG.Latency {16} \
    CONFIG.Latency_Configuration {Auto} \
    CONFIG.M_DATA_Has_TUSER {Not_Required} \
    CONFIG.Noise_Shaping {Auto} \
    CONFIG.OUTPUT_FORM {Twos_Complement} \
    CONFIG.Optimization_Goal {Speed} \
    CONFIG.Output_Frequency1 {0} \
    CONFIG.Output_Selection {Sine} \
    CONFIG.Output_Width {14} \
    CONFIG.PINC1 {0} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.Phase_Width {26} \
    CONFIG.Phase_offset {None} \
    CONFIG.S_PHASE_Has_TUSER {Not_Required} \
    CONFIG.Spurious_Free_Dynamic_Range {80} \
  ] $Wave_1


  # Create instance: Wave_2, and set properties
  set Wave_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 Wave_2 ]
  set_property -dict [list \
    CONFIG.DATA_Has_TLAST {Not_Required} \
    CONFIG.DDS_Clock_Rate {62} \
    CONFIG.Frequency_Resolution {1} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Has_TREADY {true} \
    CONFIG.Latency {16} \
    CONFIG.M_DATA_Has_TUSER {Not_Required} \
    CONFIG.Noise_Shaping {Auto} \
    CONFIG.OUTPUT_FORM {Twos_Complement} \
    CONFIG.Optimization_Goal {Speed} \
    CONFIG.Output_Frequency1 {0} \
    CONFIG.Output_Selection {Sine} \
    CONFIG.Output_Width {14} \
    CONFIG.PINC1 {0} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.Phase_Width {26} \
    CONFIG.S_PHASE_Has_TUSER {Not_Required} \
    CONFIG.Spurious_Free_Dynamic_Range {80} \
  ] $Wave_2


  # Create instance: Wave_4, and set properties
  set Wave_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 Wave_4 ]
  set_property -dict [list \
    CONFIG.DATA_Has_TLAST {Not_Required} \
    CONFIG.DDS_Clock_Rate {62} \
    CONFIG.Frequency_Resolution {1} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Has_TREADY {true} \
    CONFIG.Latency {16} \
    CONFIG.M_DATA_Has_TUSER {Not_Required} \
    CONFIG.Noise_Shaping {Auto} \
    CONFIG.OUTPUT_FORM {Twos_Complement} \
    CONFIG.Optimization_Goal {Speed} \
    CONFIG.Output_Frequency1 {0} \
    CONFIG.Output_Selection {Sine} \
    CONFIG.Output_Width {14} \
    CONFIG.PINC1 {0} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.Phase_Width {26} \
    CONFIG.S_PHASE_Has_TUSER {Not_Required} \
    CONFIG.Spurious_Free_Dynamic_Range {80} \
  ] $Wave_4


  # Create instance: Wave_5, and set properties
  set Wave_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 Wave_5 ]
  set_property -dict [list \
    CONFIG.DATA_Has_TLAST {Not_Required} \
    CONFIG.DDS_Clock_Rate {62} \
    CONFIG.Frequency_Resolution {1} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Has_TREADY {true} \
    CONFIG.Latency {16} \
    CONFIG.M_DATA_Has_TUSER {Not_Required} \
    CONFIG.Noise_Shaping {Auto} \
    CONFIG.OUTPUT_FORM {Twos_Complement} \
    CONFIG.Optimization_Goal {Speed} \
    CONFIG.Output_Frequency1 {0} \
    CONFIG.Output_Selection {Sine} \
    CONFIG.Output_Width {14} \
    CONFIG.PINC1 {0} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.Phase_Width {26} \
    CONFIG.S_PHASE_Has_TUSER {Not_Required} \
    CONFIG.Spurious_Free_Dynamic_Range {80} \
  ] $Wave_5


  # Create instance: Wave_3, and set properties
  set Wave_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 Wave_3 ]
  set_property -dict [list \
    CONFIG.DATA_Has_TLAST {Not_Required} \
    CONFIG.DDS_Clock_Rate {62} \
    CONFIG.Frequency_Resolution {1} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Has_TREADY {true} \
    CONFIG.Latency {16} \
    CONFIG.M_DATA_Has_TUSER {Not_Required} \
    CONFIG.Noise_Shaping {Auto} \
    CONFIG.OUTPUT_FORM {Twos_Complement} \
    CONFIG.Optimization_Goal {Speed} \
    CONFIG.Output_Frequency1 {0} \
    CONFIG.Output_Selection {Sine} \
    CONFIG.Output_Width {14} \
    CONFIG.PINC1 {0} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.Phase_Width {26} \
    CONFIG.S_PHASE_Has_TUSER {Not_Required} \
    CONFIG.Spurious_Free_Dynamic_Range {80} \
  ] $Wave_3


  # Create instance: Wave_6, and set properties
  set Wave_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:dds_compiler:6.0 Wave_6 ]
  set_property -dict [list \
    CONFIG.DATA_Has_TLAST {Not_Required} \
    CONFIG.DDS_Clock_Rate {62} \
    CONFIG.Frequency_Resolution {1} \
    CONFIG.Has_Phase_Out {false} \
    CONFIG.Has_TREADY {true} \
    CONFIG.Latency {16} \
    CONFIG.M_DATA_Has_TUSER {Not_Required} \
    CONFIG.Noise_Shaping {Auto} \
    CONFIG.OUTPUT_FORM {Twos_Complement} \
    CONFIG.Optimization_Goal {Speed} \
    CONFIG.Output_Frequency1 {0} \
    CONFIG.Output_Selection {Sine} \
    CONFIG.Output_Width {14} \
    CONFIG.PINC1 {0} \
    CONFIG.Phase_Increment {Programmable} \
    CONFIG.Phase_Width {26} \
    CONFIG.S_PHASE_Has_TUSER {Not_Required} \
    CONFIG.Spurious_Free_Dynamic_Range {80} \
  ] $Wave_6


  # Create instance: multitone_adder_0, and set properties
  set block_name multitone_adder
  set block_cell_name multitone_adder_0
  if { [catch {set multitone_adder_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $multitone_adder_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: and_6_to_1_0, and set properties
  set block_name and_6_to_1
  set block_cell_name and_6_to_1_0
  if { [catch {set and_6_to_1_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $and_6_to_1_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins Wave_1/S_AXIS_CONFIG] [get_bd_intf_pins S_AXIS_CONFIG]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins Wave_2/S_AXIS_CONFIG] [get_bd_intf_pins S_AXIS_CONFIG1]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins Wave_3/S_AXIS_CONFIG] [get_bd_intf_pins S_AXIS_CONFIG2]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins Wave_4/S_AXIS_CONFIG] [get_bd_intf_pins S_AXIS_CONFIG3]
  connect_bd_intf_net -intf_net S_AXIS_CONFIG4_1 [get_bd_intf_pins S_AXIS_CONFIG4] [get_bd_intf_pins Wave_5/S_AXIS_CONFIG]
  connect_bd_intf_net -intf_net S_AXIS_CONFIG5_1 [get_bd_intf_pins S_AXIS_CONFIG5] [get_bd_intf_pins Wave_6/S_AXIS_CONFIG]

  # Create port connections
  connect_bd_net -net Wave_10MHz_m_axis_data_tdata  [get_bd_pins Wave_4/m_axis_data_tdata] \
  [get_bd_pins multitone_adder_0/dds4]
  connect_bd_net -net Wave_10MHz_m_axis_data_tvalid  [get_bd_pins Wave_4/m_axis_data_tvalid] \
  [get_bd_pins and_6_to_1_0/valid3]
  connect_bd_net -net Wave_15MHz_m_axis_data_tdata  [get_bd_pins Wave_5/m_axis_data_tdata] \
  [get_bd_pins multitone_adder_0/dds5]
  connect_bd_net -net Wave_15MHz_m_axis_data_tvalid  [get_bd_pins Wave_5/m_axis_data_tvalid] \
  [get_bd_pins and_6_to_1_0/valid4]
  connect_bd_net -net Wave_1MHz_m_axis_data_tdata  [get_bd_pins Wave_1/m_axis_data_tdata] \
  [get_bd_pins multitone_adder_0/dds1]
  connect_bd_net -net Wave_1MHz_m_axis_data_tvalid  [get_bd_pins Wave_1/m_axis_data_tvalid] \
  [get_bd_pins and_6_to_1_0/valid1]
  connect_bd_net -net Wave_20MHz_m_axis_data_tdata  [get_bd_pins Wave_6/m_axis_data_tdata] \
  [get_bd_pins multitone_adder_0/dds6]
  connect_bd_net -net Wave_20MHz_m_axis_data_tvalid  [get_bd_pins Wave_6/m_axis_data_tvalid] \
  [get_bd_pins and_6_to_1_0/valid6]
  connect_bd_net -net Wave_3MHz_m_axis_data_tdata  [get_bd_pins Wave_2/m_axis_data_tdata] \
  [get_bd_pins multitone_adder_0/dds2]
  connect_bd_net -net Wave_3MHz_m_axis_data_tvalid  [get_bd_pins Wave_2/m_axis_data_tvalid] \
  [get_bd_pins and_6_to_1_0/valid2]
  connect_bd_net -net Wave_5MHz_m_axis_data_tdata  [get_bd_pins Wave_3/m_axis_data_tdata] \
  [get_bd_pins multitone_adder_0/dds3]
  connect_bd_net -net Wave_5MHz_m_axis_data_tvalid  [get_bd_pins Wave_3/m_axis_data_tvalid] \
  [get_bd_pins and_6_to_1_0/valid5]
  connect_bd_net -net and_6_to_1_0_valid_out  [get_bd_pins and_6_to_1_0/valid_out] \
  [get_bd_pins valid_out]
  connect_bd_net -net clock_1  [get_bd_pins clock] \
  [get_bd_pins Wave_1/aclk] \
  [get_bd_pins Wave_2/aclk] \
  [get_bd_pins Wave_4/aclk] \
  [get_bd_pins Wave_5/aclk] \
  [get_bd_pins Wave_3/aclk] \
  [get_bd_pins Wave_6/aclk] \
  [get_bd_pins multitone_adder_0/clk]
  connect_bd_net -net multitone_adder_0_dout  [get_bd_pins multitone_adder_0/dout] \
  [get_bd_pins dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports

  # Create ports

  # Create instance: Signal_Generation
  create_hier_cell_Signal_Generation [current_bd_instance .] Signal_Generation

  # Create instance: IQ_Mixing
  create_hier_cell_IQ_Mixing [current_bd_instance .] IQ_Mixing

  # Create instance: Power_Spectral_Density
  create_hier_cell_Power_Spectral_Density [current_bd_instance .] Power_Spectral_Density

  # Create instance: BANDWIDTH_ESTIMATOR, and set properties
  set block_name bandwidth_estimator
  set block_cell_name BANDWIDTH_ESTIMATOR
  if { [catch {set BANDWIDTH_ESTIMATOR [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $BANDWIDTH_ESTIMATOR eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: DECIMATION_DECISION, and set properties
  set block_name decimation_decision_control
  set block_cell_name DECIMATION_DECISION
  if { [catch {set DECIMATION_DECISION [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $DECIMATION_DECISION eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: CIC_Decimator, and set properties
  set block_name rate_controlled_cic_decimator
  set block_cell_name CIC_Decimator
  if { [catch {set CIC_Decimator [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $CIC_Decimator eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: and_2_to_1_valid_CIC, and set properties
  set block_name and_2_to_1
  set block_cell_name and_2_to_1_valid_CIC
  if { [catch {set and_2_to_1_valid_CIC [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $and_2_to_1_valid_CIC eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: dds_axi_config_regs_0, and set properties
  set block_name dds_axi_config_regs
  set block_cell_name dds_axi_config_regs_0
  if { [catch {set dds_axi_config_regs_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $dds_axi_config_regs_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  set_property -dict [ list \
   CONFIG.FREQ_HZ {62000967} \
   CONFIG.CLK_DOMAIN {BAAD_BD_Clock_62M_0_clk_out1} \
 ] [get_bd_intf_pins $dds_axi_config_regs_0/dds0_s_axis_config]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {62000967} \
   CONFIG.CLK_DOMAIN {BAAD_BD_Clock_62M_0_clk_out1} \
 ] [get_bd_intf_pins $dds_axi_config_regs_0/dds1_s_axis_config]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {62000967} \
   CONFIG.CLK_DOMAIN {BAAD_BD_Clock_62M_0_clk_out1} \
 ] [get_bd_intf_pins $dds_axi_config_regs_0/dds2_s_axis_config]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {62000967} \
   CONFIG.CLK_DOMAIN {BAAD_BD_Clock_62M_0_clk_out1} \
 ] [get_bd_intf_pins $dds_axi_config_regs_0/dds3_s_axis_config]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {62000967} \
   CONFIG.CLK_DOMAIN {BAAD_BD_Clock_62M_0_clk_out1} \
 ] [get_bd_intf_pins $dds_axi_config_regs_0/dds4_s_axis_config]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {62000967} \
   CONFIG.CLK_DOMAIN {BAAD_BD_Clock_62M_0_clk_out1} \
 ] [get_bd_intf_pins $dds_axi_config_regs_0/dds5_s_axis_config]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {62000967} \
 ] [get_bd_pins $dds_axi_config_regs_0/s_axi_aclk]

  # Create instance: DMA_DEBUG_FRAME, and set properties
  set block_name dma_debug_frame_packer
  set block_cell_name DMA_DEBUG_FRAME
  if { [catch {set DMA_DEBUG_FRAME [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $DMA_DEBUG_FRAME eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: Clock_62M, and set properties
  set Clock_62M [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 Clock_62M ]
  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {225.699} \
    CONFIG.CLKOUT1_PHASE_ERROR {352.530} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {62} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {108.125} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {19.375} \
    CONFIG.MMCM_DIVCLK_DIVIDE {9} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_RESET {false} \
  ] $Clock_62M


  # Create instance: axi_smc, and set properties
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc ]
  set_property -dict [list \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {2} \
  ] $axi_smc


  # Create instance: DATA_FIFO, and set properties
  set DATA_FIFO [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 DATA_FIFO ]
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {2048} \
    CONFIG.FIFO_MODE {2} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.TDATA_NUM_BYTES {8} \
  ] $DATA_FIFO


  # Create instance: zynq_ultra_ps_e_0, and set properties
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0 ]
  set_property -dict [list \
    CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
    CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
    CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
    CONFIG.PSU_DYNAMIC_DDR_CONFIG_EN {1} \
    CONFIG.PSU_MIO_13_POLARITY {Default} \
    CONFIG.PSU_MIO_22_POLARITY {Default} \
    CONFIG.PSU_MIO_23_POLARITY {Default} \
    CONFIG.PSU_MIO_26_POLARITY {Default} \
    CONFIG.PSU_MIO_32_POLARITY {Default} \
    CONFIG.PSU_MIO_33_POLARITY {Default} \
    CONFIG.PSU_MIO_35_POLARITY {Default} \
    CONFIG.PSU_MIO_36_POLARITY {Default} \
    CONFIG.PSU_MIO_37_POLARITY {Default} \
    CONFIG.PSU_MIO_38_POLARITY {Default} \
    CONFIG.PSU_MIO_43_POLARITY {Default} \
    CONFIG.PSU_MIO_6_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_6_SLEW {fast} \
    CONFIG.PSU_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Feedback Clk#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad\
SPI Flash#Quad SPI Flash#GPIO0 MIO#I2C 0#I2C 0#I2C 1#I2C 1#UART 0#UART 0#UART 1#UART 1#GPIO0 MIO#GPIO0 MIO#CAN 1#CAN 1#GPIO1 MIO#DPAUX#DPAUX#DPAUX#DPAUX#PCIE#GPIO1 MIO#GPIO1 MIO#PMU GPO 2#GPIO1 MIO#GPIO1\
MIO#GPIO1 MIO#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem\
3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#MDIO 3#MDIO 3} \
    CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#clk_for_lpbk#n_ss_out_upper#mo_upper[0]#mo_upper[1]#mo_upper[2]#mo_upper[3]#sclk_out_upper#gpio0[13]#scl_out#sda_out#scl_out#sda_out#rxd#txd#txd#rxd#gpio0[22]#gpio0[23]#phy_tx#phy_rx#gpio1[26]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#reset_n#gpio1[32]#gpio1[33]#gpo[2]#gpio1[35]#gpio1[36]#gpio1[37]#gpio1[38]#sdio1_data_out[4]#sdio1_data_out[5]#sdio1_data_out[6]#sdio1_data_out[7]#gpio1[43]#sdio1_wp#sdio1_cd_n#sdio1_data_out[0]#sdio1_data_out[1]#sdio1_data_out[2]#sdio1_data_out[3]#sdio1_cmd_out#sdio1_clk_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem3_mdc#gem3_mdio_out}\
\
    CONFIG.PSU_SD1_INTERNAL_BUS_WIDTH {8} \
    CONFIG.PSU_USB3__DUAL_CLOCK_ENABLE {1} \
    CONFIG.PSU__ACT_DDR_FREQ_MHZ {1066.560059} \
    CONFIG.PSU__AFI0_COHERENCY {0} \
    CONFIG.PSU__CAN1__GRP_CLK__ENABLE {0} \
    CONFIG.PSU__CAN1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__CAN1__PERIPHERAL__IO {MIO 24 .. 25} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1199.880127} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__FREQMHZ {1200} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {533.280029} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1067} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {599.940063} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {24.997501} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED {0} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {26.783037} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {299.970032} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.940063} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {499.950043} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {533.280029} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {499.950043} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {49.995003} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {499.950043} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {1499.850098} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {124.987511} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {499.950043} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.481262} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {124.987511} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {187.481262} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {249.975021} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.998001} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
    CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {1} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT {2} \
    CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} \
    CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
    CONFIG.PSU__DDRC__CL {15} \
    CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
    CONFIG.PSU__DDRC__COMPONENTS {UDIMM} \
    CONFIG.PSU__DDRC__CWL {14} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} \
    CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} \
    CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY {4096 MBits} \
    CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} \
    CONFIG.PSU__DDRC__DRAM_WIDTH {8 Bits} \
    CONFIG.PSU__DDRC__ECC {Disabled} \
    CONFIG.PSU__DDRC__FGRM {1X} \
    CONFIG.PSU__DDRC__LP_ASR {manual normal} \
    CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} \
    CONFIG.PSU__DDRC__PARITY_ENABLE {0} \
    CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} \
    CONFIG.PSU__DDRC__PHY_DBI_MODE {0} \
    CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} \
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT {15} \
    CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
    CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2133P} \
    CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
    CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
    CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
    CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
    CONFIG.PSU__DDRC__T_FAW {30.0} \
    CONFIG.PSU__DDRC__T_RAS_MIN {33} \
    CONFIG.PSU__DDRC__T_RC {47.06} \
    CONFIG.PSU__DDRC__T_RCD {15} \
    CONFIG.PSU__DDRC__T_RP {15} \
    CONFIG.PSU__DDRC__VREF {1} \
    CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {1} \
    CONFIG.PSU__DDR__INTERFACE__FREQMHZ {533.500} \
    CONFIG.PSU__DISPLAYPORT__LANE0__ENABLE {1} \
    CONFIG.PSU__DISPLAYPORT__LANE0__IO {GT Lane1} \
    CONFIG.PSU__DISPLAYPORT__LANE1__ENABLE {0} \
    CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DLL__ISUSED {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__IO {MIO 27 .. 30} \
    CONFIG.PSU__DP__LANE_SEL {Single Lower} \
    CONFIG.PSU__DP__REF_CLK_FREQ {27} \
    CONFIG.PSU__DP__REF_CLK_SEL {Ref Clk3} \
    CONFIG.PSU__ENET3__FIFO__ENABLE {0} \
    CONFIG.PSU__ENET3__GRP_MDIO__ENABLE {1} \
    CONFIG.PSU__ENET3__GRP_MDIO__IO {MIO 76 .. 77} \
    CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__ENET3__PERIPHERAL__IO {MIO 64 .. 75} \
    CONFIG.PSU__ENET3__PTP__ENABLE {0} \
    CONFIG.PSU__ENET3__TSU__ENABLE {0} \
    CONFIG.PSU__FPDMASTERS_COHERENCY {0} \
    CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__GEM3_COHERENCY {0} \
    CONFIG.PSU__GEM3_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__GEM__TSU__ENABLE {0} \
    CONFIG.PSU__GPIO0_MIO__IO {MIO 0 .. 25} \
    CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__GPIO1_MIO__IO {MIO 26 .. 51} \
    CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__GT__LINK_SPEED {HBR} \
    CONFIG.PSU__GT__PRE_EMPH_LVL_4 {0} \
    CONFIG.PSU__GT__VLT_SWNG_LVL_4 {0} \
    CONFIG.PSU__I2C0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__I2C0__PERIPHERAL__IO {MIO 14 .. 15} \
    CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__I2C1__PERIPHERAL__IO {MIO 16 .. 17} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__TTC0__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC1__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC2__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC3__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ {99.990005} \
    CONFIG.PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__OVERRIDE__BASIC_CLOCK {0} \
    CONFIG.PSU__PCIE__BAR0_ENABLE {0} \
    CONFIG.PSU__PCIE__BAR0_VAL {0x0} \
    CONFIG.PSU__PCIE__BAR1_ENABLE {0} \
    CONFIG.PSU__PCIE__BAR1_VAL {0x0} \
    CONFIG.PSU__PCIE__BAR2_VAL {0x0} \
    CONFIG.PSU__PCIE__BAR3_VAL {0x0} \
    CONFIG.PSU__PCIE__BAR4_VAL {0x0} \
    CONFIG.PSU__PCIE__BAR5_VAL {0x0} \
    CONFIG.PSU__PCIE__CLASS_CODE_BASE {0x06} \
    CONFIG.PSU__PCIE__CLASS_CODE_INTERFACE {0x0} \
    CONFIG.PSU__PCIE__CLASS_CODE_SUB {0x4} \
    CONFIG.PSU__PCIE__CLASS_CODE_VALUE {0x60400} \
    CONFIG.PSU__PCIE__CRS_SW_VISIBILITY {1} \
    CONFIG.PSU__PCIE__DEVICE_ID {0xD021} \
    CONFIG.PSU__PCIE__DEVICE_PORT_TYPE {Root Port} \
    CONFIG.PSU__PCIE__EROM_ENABLE {0} \
    CONFIG.PSU__PCIE__EROM_VAL {0x0} \
    CONFIG.PSU__PCIE__LANE0__ENABLE {1} \
    CONFIG.PSU__PCIE__LANE0__IO {GT Lane0} \
    CONFIG.PSU__PCIE__LANE1__ENABLE {0} \
    CONFIG.PSU__PCIE__LANE2__ENABLE {0} \
    CONFIG.PSU__PCIE__LANE3__ENABLE {0} \
    CONFIG.PSU__PCIE__LINK_SPEED {5.0 Gb/s} \
    CONFIG.PSU__PCIE__MAXIMUM_LINK_WIDTH {x1} \
    CONFIG.PSU__PCIE__MAX_PAYLOAD_SIZE {256 bytes} \
    CONFIG.PSU__PCIE__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__PCIE__PERIPHERAL__ENDPOINT_ENABLE {0} \
    CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_ENABLE {1} \
    CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_IO {MIO 31} \
    CONFIG.PSU__PCIE__REF_CLK_FREQ {100} \
    CONFIG.PSU__PCIE__REF_CLK_SEL {Ref Clk0} \
    CONFIG.PSU__PCIE__RESET__POLARITY {Active Low} \
    CONFIG.PSU__PCIE__REVISION_ID {0x0} \
    CONFIG.PSU__PCIE__SUBSYSTEM_ID {0x7} \
    CONFIG.PSU__PCIE__SUBSYSTEM_VENDOR_ID {0x10EE} \
    CONFIG.PSU__PCIE__VENDOR_ID {0x10EE} \
    CONFIG.PSU__PL_CLK0_BUF {TRUE} \
    CONFIG.PSU__PMU_COHERENCY {0} \
    CONFIG.PSU__PMU__AIBACK__ENABLE {0} \
    CONFIG.PSU__PMU__EMIO_GPI__ENABLE {0} \
    CONFIG.PSU__PMU__EMIO_GPO__ENABLE {0} \
    CONFIG.PSU__PMU__GPI0__ENABLE {0} \
    CONFIG.PSU__PMU__GPI1__ENABLE {0} \
    CONFIG.PSU__PMU__GPI2__ENABLE {0} \
    CONFIG.PSU__PMU__GPI3__ENABLE {0} \
    CONFIG.PSU__PMU__GPI4__ENABLE {0} \
    CONFIG.PSU__PMU__GPI5__ENABLE {0} \
    CONFIG.PSU__PMU__GPO0__ENABLE {0} \
    CONFIG.PSU__PMU__GPO1__ENABLE {0} \
    CONFIG.PSU__PMU__GPO2__ENABLE {1} \
    CONFIG.PSU__PMU__GPO2__IO {MIO 34} \
    CONFIG.PSU__PMU__GPO2__POLARITY {high} \
    CONFIG.PSU__PMU__GPO3__ENABLE {0} \
    CONFIG.PSU__PMU__GPO4__ENABLE {0} \
    CONFIG.PSU__PMU__GPO5__ENABLE {0} \
    CONFIG.PSU__PMU__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__PMU__PLERROR__ENABLE {0} \
    CONFIG.PSU__PRESET_APPLIED {1} \
    CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;1|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;0|SATA1:NonSecure;1|SATA0:NonSecure;1|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;1|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1}\
\
    CONFIG.PSU__PROTECTION__SLAVES {LPD;USB3_1_XHCI;FE300000;FE3FFFFF;0|LPD;USB3_1;FF9E0000;FF9EFFFF;0|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;1|LPD;TTC3;FF140000;FF14FFFF;1|LPD;TTC2;FF130000;FF13FFFF;1|LPD;TTC1;FF120000;FF12FFFF;1|LPD;TTC0;FF110000;FF11FFFF;1|FPD;SWDT1;FD4D0000;FD4DFFFF;1|LPD;SWDT0;FF150000;FF15FFFF;1|LPD;SPI1;FF050000;FF05FFFF;0|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;1|LPD;SD0;FF160000;FF16FFFF;0|FPD;SATA;FD0C0000;FD0CFFFF;1|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;1|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;1|FPD;PCIE_LOW;E0000000;EFFFFFFF;1|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;1|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;1|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;1|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;1|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;1|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;1|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;0|LPD;GEM0;FF0B0000;FF0BFFFF;0|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display\
Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;87FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;1|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1}\
\
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.330} \
    CONFIG.PSU__QSPI_COHERENCY {0} \
    CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {1} \
    CONFIG.PSU__QSPI__GRP_FBCLK__IO {MIO 6} \
    CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE {x4} \
    CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__QSPI__PERIPHERAL__IO {MIO 0 .. 12} \
    CONFIG.PSU__QSPI__PERIPHERAL__MODE {Dual Parallel} \
    CONFIG.PSU__SATA__LANE0__ENABLE {0} \
    CONFIG.PSU__SATA__LANE1__IO {GT Lane3} \
    CONFIG.PSU__SATA__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SATA__REF_CLK_FREQ {125} \
    CONFIG.PSU__SATA__REF_CLK_SEL {Ref Clk1} \
    CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__SD1_COHERENCY {0} \
    CONFIG.PSU__SD1_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__SD1__CLK_100_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_200_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_50_DDR_ITAP_DLY {0x3D} \
    CONFIG.PSU__SD1__CLK_50_DDR_OTAP_DLY {0x4} \
    CONFIG.PSU__SD1__CLK_50_SDR_ITAP_DLY {0x15} \
    CONFIG.PSU__SD1__CLK_50_SDR_OTAP_DLY {0x5} \
    CONFIG.PSU__SD1__DATA_TRANSFER_MODE {8Bit} \
    CONFIG.PSU__SD1__GRP_CD__ENABLE {1} \
    CONFIG.PSU__SD1__GRP_CD__IO {MIO 45} \
    CONFIG.PSU__SD1__GRP_POW__ENABLE {0} \
    CONFIG.PSU__SD1__GRP_WP__ENABLE {1} \
    CONFIG.PSU__SD1__GRP_WP__IO {MIO 44} \
    CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SD1__PERIPHERAL__IO {MIO 39 .. 51} \
    CONFIG.PSU__SD1__SLOT_TYPE {SD 3.0} \
    CONFIG.PSU__SWDT0__CLOCK__ENABLE {0} \
    CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SWDT0__RESET__ENABLE {0} \
    CONFIG.PSU__SWDT1__CLOCK__ENABLE {0} \
    CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SWDT1__RESET__ENABLE {0} \
    CONFIG.PSU__TSU__BUFG_PORT_PAIR {0} \
    CONFIG.PSU__TTC0__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC0__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__TTC1__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC1__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__TTC2__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC2__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__TTC3__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC3__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__UART0__BAUD_RATE {115200} \
    CONFIG.PSU__UART0__MODEM__ENABLE {0} \
    CONFIG.PSU__UART0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__UART0__PERIPHERAL__IO {MIO 18 .. 19} \
    CONFIG.PSU__UART1__BAUD_RATE {115200} \
    CONFIG.PSU__UART1__MODEM__ENABLE {0} \
    CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 20 .. 21} \
    CONFIG.PSU__USB0_COHERENCY {0} \
    CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
    CONFIG.PSU__USB0__REF_CLK_FREQ {26} \
    CONFIG.PSU__USB0__REF_CLK_SEL {Ref Clk2} \
    CONFIG.PSU__USB2_0__EMIO__ENABLE {0} \
    CONFIG.PSU__USB3_0__EMIO__ENABLE {0} \
    CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane2} \
    CONFIG.PSU__USB__RESET__MODE {Boot Pin} \
    CONFIG.PSU__USB__RESET__POLARITY {Active Low} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP0 {1} \
  ] $zynq_ultra_ps_e_0


  # Create instance: DMA_FRAME, and set properties
  set DMA_FRAME [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 DMA_FRAME ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_m_axi_s2mm_data_width {64} \
    CONFIG.c_s_axis_s2mm_tdata_width {64} \
    CONFIG.c_sg_length_width {24} \
  ] $DMA_FRAME


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: axi_dma_smc, and set properties
  set axi_dma_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_dma_smc ]

  # Create instance: rst_ps8_0_99M, and set properties
  set rst_ps8_0_99M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_99M ]
  set_property CONFIG.RESET_BOARD_INTERFACE {Custom} $rst_ps8_0_99M


  # Create instance: axi_clock_converter_0, and set properties
  set axi_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 axi_clock_converter_0 ]
  set_property CONFIG.PROTOCOL {AXI4LITE} $axi_clock_converter_0


  # Create instance: ILA_IN, and set properties
  set ILA_IN [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ILA_IN ]
  set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_PROBE0_WIDTH {16} \
    CONFIG.C_PROBE1_WIDTH {16} \
    CONFIG.C_PROBE4_WIDTH {16} \
  ] $ILA_IN


  # Create instance: ILA_BW, and set properties
  set ILA_BW [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ILA_BW ]
  set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {20} \
    CONFIG.C_PROBE10_WIDTH {13} \
    CONFIG.C_PROBE11_WIDTH {13} \
    CONFIG.C_PROBE12_WIDTH {12} \
    CONFIG.C_PROBE13_WIDTH {12} \
    CONFIG.C_PROBE14_WIDTH {11} \
    CONFIG.C_PROBE15_WIDTH {13} \
    CONFIG.C_PROBE16_WIDTH {33} \
    CONFIG.C_PROBE17_WIDTH {33} \
    CONFIG.C_PROBE18_WIDTH {45} \
    CONFIG.C_PROBE19_WIDTH {45} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {12} \
    CONFIG.C_PROBE6_WIDTH {12} \
    CONFIG.C_PROBE7_WIDTH {12} \
    CONFIG.C_PROBE8_WIDTH {11} \
    CONFIG.C_PROBE9_WIDTH {11} \
  ] $ILA_BW


  # Create instance: ILA_PSD, and set properties
  set ILA_PSD [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ILA_PSD ]
  set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {10} \
    CONFIG.C_PROBE0_WIDTH {16} \
    CONFIG.C_PROBE1_WIDTH {16} \
    CONFIG.C_PROBE6_WIDTH {33} \
    CONFIG.C_PROBE7_WIDTH {11} \
  ] $ILA_PSD


  # Create instance: ILA_DECE, and set properties
  set ILA_DECE [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ILA_DECE ]
  set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {17} \
    CONFIG.C_PROBE10_WIDTH {16} \
    CONFIG.C_PROBE15_WIDTH {12} \
    CONFIG.C_PROBE16_WIDTH {16} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {12} \
    CONFIG.C_PROBE6_WIDTH {12} \
    CONFIG.C_PROBE8_WIDTH {32} \
    CONFIG.C_PROBE9_WIDTH {16} \
  ] $ILA_DECE


  # Create instance: ILA_DMA_F, and set properties
  set ILA_DMA_F [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ILA_DMA_F ]
  set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_NUM_OF_PROBES {5} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
  ] $ILA_DMA_F


  # Create interface connections
  connect_bd_intf_net -intf_net DATA_FIFO_M_AXIS [get_bd_intf_pins DATA_FIFO/M_AXIS] [get_bd_intf_pins DMA_FRAME/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net DMA_DEBUG_FRAME_m_axis [get_bd_intf_pins DMA_DEBUG_FRAME/m_axis] [get_bd_intf_pins DATA_FIFO/S_AXIS]
  connect_bd_intf_net -intf_net DMA_FRAME_M_AXI_S2MM [get_bd_intf_pins DMA_FRAME/M_AXI_S2MM] [get_bd_intf_pins axi_dma_smc/S00_AXI]
  connect_bd_intf_net -intf_net axi_clock_converter_0_M_AXI [get_bd_intf_pins axi_clock_converter_0/M_AXI] [get_bd_intf_pins dds_axi_config_regs_0/s_axi]
  connect_bd_intf_net -intf_net axi_dma_smc_M00_AXI [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HPC0_FPD] [get_bd_intf_pins axi_dma_smc/M00_AXI]
  connect_bd_intf_net -intf_net axi_smc_M00_AXI [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins axi_clock_converter_0/S_AXI]
  connect_bd_intf_net -intf_net axi_smc_M01_AXI [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins DMA_FRAME/S_AXI_LITE]
  connect_bd_intf_net -intf_net dds_axi_config_regs_0_dds0_s_axis_config [get_bd_intf_pins dds_axi_config_regs_0/dds0_s_axis_config] [get_bd_intf_pins Signal_Generation/S_AXIS_CONFIG]
  connect_bd_intf_net -intf_net dds_axi_config_regs_0_dds1_s_axis_config [get_bd_intf_pins dds_axi_config_regs_0/dds1_s_axis_config] [get_bd_intf_pins Signal_Generation/S_AXIS_CONFIG1]
  connect_bd_intf_net -intf_net dds_axi_config_regs_0_dds2_s_axis_config [get_bd_intf_pins dds_axi_config_regs_0/dds2_s_axis_config] [get_bd_intf_pins Signal_Generation/S_AXIS_CONFIG2]
  connect_bd_intf_net -intf_net dds_axi_config_regs_0_dds3_s_axis_config [get_bd_intf_pins dds_axi_config_regs_0/dds3_s_axis_config] [get_bd_intf_pins Signal_Generation/S_AXIS_CONFIG3]
  connect_bd_intf_net -intf_net dds_axi_config_regs_0_dds4_s_axis_config [get_bd_intf_pins dds_axi_config_regs_0/dds4_s_axis_config] [get_bd_intf_pins Signal_Generation/S_AXIS_CONFIG4]
  connect_bd_intf_net -intf_net dds_axi_config_regs_0_dds5_s_axis_config [get_bd_intf_pins dds_axi_config_regs_0/dds5_s_axis_config] [get_bd_intf_pins Signal_Generation/S_AXIS_CONFIG5]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins axi_smc/S00_AXI]

  # Create port connections
  connect_bd_net -net BANDWIDTH_ESTIMATOR_active_bin_count  [get_bd_pins BANDWIDTH_ESTIMATOR/active_bin_count] \
  [get_bd_pins ILA_BW/probe6] \
  [get_bd_pins DMA_DEBUG_FRAME/active_bin_count]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_active_found  [get_bd_pins BANDWIDTH_ESTIMATOR/active_found] \
  [get_bd_pins ILA_BW/probe3] \
  [get_bd_pins ILA_DECE/probe2] \
  [get_bd_pins DMA_DEBUG_FRAME/active_found] \
  [get_bd_pins DECIMATION_DECISION/active_found]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_active_power  [get_bd_pins BANDWIDTH_ESTIMATOR/active_power] \
  [get_bd_pins ILA_BW/probe19] \
  [get_bd_pins DMA_DEBUG_FRAME/active_power]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_bw_edge_bins  [get_bd_pins BANDWIDTH_ESTIMATOR/bw_edge_bins] \
  [get_bd_pins ILA_BW/probe13] \
  [get_bd_pins ILA_DECE/probe5] \
  [get_bd_pins DMA_DEBUG_FRAME/bw_edge_bins] \
  [get_bd_pins DECIMATION_DECISION/bw_edge_bins]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_bw_span_bins  [get_bd_pins BANDWIDTH_ESTIMATOR/bw_span_bins] \
  [get_bd_pins ILA_BW/probe12] \
  [get_bd_pins ILA_DECE/probe6] \
  [get_bd_pins DMA_DEBUG_FRAME/bw_span_bins] \
  [get_bd_pins DECIMATION_DECISION/bw_span_bins]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_estimate_valid  [get_bd_pins BANDWIDTH_ESTIMATOR/estimate_valid] \
  [get_bd_pins ILA_BW/probe0] \
  [get_bd_pins ILA_DECE/probe0] \
  [get_bd_pins DMA_DEBUG_FRAME/estimate_valid] \
  [get_bd_pins DECIMATION_DECISION/estimate_valid]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_frame_bin_count  [get_bd_pins BANDWIDTH_ESTIMATOR/frame_bin_count] \
  [get_bd_pins ILA_BW/probe5] \
  [get_bd_pins DMA_DEBUG_FRAME/frame_bin_count]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_frame_error  [get_bd_pins BANDWIDTH_ESTIMATOR/frame_error] \
  [get_bd_pins ILA_BW/probe2] \
  [get_bd_pins ILA_DECE/probe3] \
  [get_bd_pins DMA_DEBUG_FRAME/frame_error] \
  [get_bd_pins DECIMATION_DECISION/frame_error]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_frame_id  [get_bd_pins BANDWIDTH_ESTIMATOR/frame_id] \
  [get_bd_pins ILA_BW/probe1] \
  [get_bd_pins ILA_DECE/probe1] \
  [get_bd_pins DMA_DEBUG_FRAME/frame_id] \
  [get_bd_pins DECIMATION_DECISION/frame_id]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_high_bin  [get_bd_pins BANDWIDTH_ESTIMATOR/high_bin] \
  [get_bd_pins ILA_BW/probe9] \
  [get_bd_pins DMA_DEBUG_FRAME/high_bin]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_high_signed_bin  [get_bd_pins BANDWIDTH_ESTIMATOR/high_signed_bin] \
  [get_bd_pins ILA_BW/probe11] \
  [get_bd_pins DMA_DEBUG_FRAME/high_signed_bin]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_low_bin  [get_bd_pins BANDWIDTH_ESTIMATOR/low_bin] \
  [get_bd_pins ILA_BW/probe8] \
  [get_bd_pins DMA_DEBUG_FRAME/low_bin]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_low_signed_bin  [get_bd_pins BANDWIDTH_ESTIMATOR/low_signed_bin] \
  [get_bd_pins ILA_BW/probe10] \
  [get_bd_pins DMA_DEBUG_FRAME/low_signed_bin]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_min_power  [get_bd_pins BANDWIDTH_ESTIMATOR/min_power] \
  [get_bd_pins ILA_BW/probe17] \
  [get_bd_pins DMA_DEBUG_FRAME/min_power]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_overflow_count  [get_bd_pins BANDWIDTH_ESTIMATOR/overflow_count] \
  [get_bd_pins ILA_BW/probe7] \
  [get_bd_pins DMA_DEBUG_FRAME/overflow_count]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_overflow_seen  [get_bd_pins BANDWIDTH_ESTIMATOR/overflow_seen] \
  [get_bd_pins ILA_BW/probe4] \
  [get_bd_pins ILA_DECE/probe4] \
  [get_bd_pins DMA_DEBUG_FRAME/overflow_seen] \
  [get_bd_pins DECIMATION_DECISION/overflow_seen]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_peak_bin  [get_bd_pins BANDWIDTH_ESTIMATOR/peak_bin] \
  [get_bd_pins ILA_BW/probe14] \
  [get_bd_pins DMA_DEBUG_FRAME/peak_bin]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_peak_power  [get_bd_pins BANDWIDTH_ESTIMATOR/peak_power] \
  [get_bd_pins ILA_BW/probe16] \
  [get_bd_pins DMA_DEBUG_FRAME/peak_power]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_peak_signed_bin  [get_bd_pins BANDWIDTH_ESTIMATOR/peak_signed_bin] \
  [get_bd_pins ILA_BW/probe15] \
  [get_bd_pins DMA_DEBUG_FRAME/peak_signed_bin]
  connect_bd_net -net BANDWIDTH_ESTIMATOR_total_power  [get_bd_pins BANDWIDTH_ESTIMATOR/total_power] \
  [get_bd_pins ILA_BW/probe18] \
  [get_bd_pins DMA_DEBUG_FRAME/total_power]
  connect_bd_net -net CIC_Decimator_active_decimation_factor  [get_bd_pins CIC_Decimator/active_decimation_factor] \
  [get_bd_pins DMA_DEBUG_FRAME/active_decimation_factor]
  connect_bd_net -net CIC_Decimator_active_gain_shift  [get_bd_pins CIC_Decimator/active_gain_shift] \
  [get_bd_pins DMA_DEBUG_FRAME/active_gain_shift]
  connect_bd_net -net CIC_Decimator_cfg_error  [get_bd_pins CIC_Decimator/cfg_error] \
  [get_bd_pins DMA_DEBUG_FRAME/cfg_error]
  connect_bd_net -net CIC_Decimator_m_i  [get_bd_pins CIC_Decimator/m_i] \
  [get_bd_pins DMA_DEBUG_FRAME/m_i]
  connect_bd_net -net CIC_Decimator_m_q  [get_bd_pins CIC_Decimator/m_q] \
  [get_bd_pins DMA_DEBUG_FRAME/m_q]
  connect_bd_net -net CIC_Decimator_m_valid  [get_bd_pins CIC_Decimator/m_valid] \
  [get_bd_pins DMA_DEBUG_FRAME/m_valid]
  connect_bd_net -net CIC_Decimator_overflow  [get_bd_pins CIC_Decimator/overflow] \
  [get_bd_pins DMA_DEBUG_FRAME/cic_overflow]
  connect_bd_net -net CIC_Decimator_rate_changed  [get_bd_pins CIC_Decimator/rate_changed] \
  [get_bd_pins DMA_DEBUG_FRAME/rate_changed]
  connect_bd_net -net CIC_Decimator_settling  [get_bd_pins CIC_Decimator/settling] \
  [get_bd_pins DMA_DEBUG_FRAME/settling]
  connect_bd_net -net DMA_DEBUG_FRAME_busy  [get_bd_pins DMA_DEBUG_FRAME/busy] \
  [get_bd_pins ILA_DMA_F/probe0]
  connect_bd_net -net DMA_DEBUG_FRAME_dropped_record_pulse  [get_bd_pins DMA_DEBUG_FRAME/dropped_record_pulse] \
  [get_bd_pins ILA_DMA_F/probe2]
  connect_bd_net -net DMA_DEBUG_FRAME_emitted_record_pulse  [get_bd_pins DMA_DEBUG_FRAME/emitted_record_pulse] \
  [get_bd_pins ILA_DMA_F/probe1]
  connect_bd_net -net DMA_DEBUG_FRAME_records_dropped  [get_bd_pins DMA_DEBUG_FRAME/records_dropped] \
  [get_bd_pins ILA_DMA_F/probe4]
  connect_bd_net -net DMA_DEBUG_FRAME_records_emitted  [get_bd_pins DMA_DEBUG_FRAME/records_emitted] \
  [get_bd_pins ILA_DMA_F/probe3]
  connect_bd_net -net IQ_Mixing_P_0  [get_bd_pins IQ_Mixing/I_out] \
  [get_bd_pins Power_Spectral_Density/I_in] \
  [get_bd_pins ILA_IN/probe0] \
  [get_bd_pins ILA_PSD/probe0] \
  [get_bd_pins DMA_DEBUG_FRAME/psd_input_i] \
  [get_bd_pins CIC_Decimator/s_i]
  connect_bd_net -net IQ_Mixing_P_1  [get_bd_pins IQ_Mixing/Q_out] \
  [get_bd_pins Power_Spectral_Density/Q_in] \
  [get_bd_pins ILA_IN/probe1] \
  [get_bd_pins ILA_PSD/probe1] \
  [get_bd_pins DMA_DEBUG_FRAME/psd_input_q] \
  [get_bd_pins CIC_Decimator/s_q]
  connect_bd_net -net IQ_Mixing_m_axis_data_tvalid  [get_bd_pins IQ_Mixing/m_axis_data_tvalid] \
  [get_bd_pins Power_Spectral_Density/valid2] \
  [get_bd_pins and_2_to_1_valid_CIC/valid2] \
  [get_bd_pins ILA_IN/probe3] \
  [get_bd_pins ILA_PSD/probe2]
  connect_bd_net -net IQ_Mixing_valid_out  [get_bd_pins IQ_Mixing/valid_out] \
  [get_bd_pins Power_Spectral_Density/valid1] \
  [get_bd_pins and_2_to_1_valid_CIC/valid1] \
  [get_bd_pins ILA_IN/probe2] \
  [get_bd_pins ILA_PSD/probe3] \
  [get_bd_pins DMA_DEBUG_FRAME/psd_input_valid]
  connect_bd_net -net Power_Spectral_Density_psd_bin_0  [get_bd_pins Power_Spectral_Density/psd_bin] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/psd_bin] \
  [get_bd_pins ILA_PSD/probe7]
  connect_bd_net -net Power_Spectral_Density_psd_last_0  [get_bd_pins Power_Spectral_Density/psd_last] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/psd_last] \
  [get_bd_pins ILA_PSD/probe8]
  connect_bd_net -net Power_Spectral_Density_psd_overflow_0  [get_bd_pins Power_Spectral_Density/psd_overflow] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/psd_overflow] \
  [get_bd_pins ILA_PSD/probe9]
  connect_bd_net -net Power_Spectral_Density_psd_power_0  [get_bd_pins Power_Spectral_Density/psd_power] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/psd_power] \
  [get_bd_pins ILA_PSD/probe6]
  connect_bd_net -net Signal_Generation_dout  [get_bd_pins Signal_Generation/dout] \
  [get_bd_pins IQ_Mixing/B] \
  [get_bd_pins ILA_IN/probe4]
  connect_bd_net -net and_2_to_1_0_valid_out  [get_bd_pins Power_Spectral_Density/psd_valid_out] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/psd_valid] \
  [get_bd_pins ILA_PSD/probe5]
  connect_bd_net -net and_2_to_1_0_valid_out1  [get_bd_pins and_2_to_1_valid_CIC/valid_out] \
  [get_bd_pins CIC_Decimator/s_valid]
  connect_bd_net -net clk_wiz_clk_out1  [get_bd_pins Clock_62M/clk_out1] \
  [get_bd_pins Signal_Generation/clock] \
  [get_bd_pins IQ_Mixing/clock] \
  [get_bd_pins Power_Spectral_Density/clock] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/clk] \
  [get_bd_pins axi_clock_converter_0/m_axi_aclk] \
  [get_bd_pins DATA_FIFO/s_axis_aclk] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
  [get_bd_pins ILA_IN/clk] \
  [get_bd_pins ILA_BW/clk] \
  [get_bd_pins ILA_PSD/clk] \
  [get_bd_pins ILA_DECE/clk] \
  [get_bd_pins ILA_DMA_F/clk] \
  [get_bd_pins DMA_DEBUG_FRAME/clk] \
  [get_bd_pins dds_axi_config_regs_0/s_axi_aclk] \
  [get_bd_pins DECIMATION_DECISION/clk] \
  [get_bd_pins CIC_Decimator/clk]
  connect_bd_net -net dds_axi_config_regs_0_cfg_dma_capture_cic_enable  [get_bd_pins dds_axi_config_regs_0/cfg_dma_capture_cic_enable] \
  [get_bd_pins DMA_DEBUG_FRAME/capture_cic_enable]
  connect_bd_net -net dds_axi_config_regs_0_cfg_dma_capture_enable  [get_bd_pins dds_axi_config_regs_0/cfg_dma_capture_enable] \
  [get_bd_pins DMA_DEBUG_FRAME/capture_enable]
  connect_bd_net -net dds_axi_config_regs_0_cfg_dma_capture_psd_input_enable  [get_bd_pins dds_axi_config_regs_0/cfg_dma_capture_psd_input_enable] \
  [get_bd_pins DMA_DEBUG_FRAME/capture_psd_input_enable]
  connect_bd_net -net dds_axi_config_regs_0_cfg_dma_capture_summary_enable  [get_bd_pins dds_axi_config_regs_0/cfg_dma_capture_summary_enable] \
  [get_bd_pins DMA_DEBUG_FRAME/capture_summary_enable]
  connect_bd_net -net dds_axi_config_regs_0_cfg_dma_cic_sample_interval  [get_bd_pins dds_axi_config_regs_0/cfg_dma_cic_sample_interval] \
  [get_bd_pins DMA_DEBUG_FRAME/cic_sample_interval]
  connect_bd_net -net dds_axi_config_regs_0_cfg_dma_packet_record_count  [get_bd_pins dds_axi_config_regs_0/cfg_dma_packet_record_count] \
  [get_bd_pins DMA_DEBUG_FRAME/packet_record_count]
  connect_bd_net -net dds_axi_config_regs_0_cfg_dma_psd_input_sample_interval  [get_bd_pins dds_axi_config_regs_0/cfg_dma_psd_input_sample_interval] \
  [get_bd_pins DMA_DEBUG_FRAME/psd_input_sample_interval]
  connect_bd_net -net dds_axi_config_regs_0_cfg_power_threshold  [get_bd_pins dds_axi_config_regs_0/cfg_power_threshold] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/cfg_power_threshold]
  connect_bd_net -net decimation_decision_0_candidate_factor_m  [get_bd_pins DECIMATION_DECISION/candidate_factor_m] \
  [get_bd_pins ILA_DECE/probe10] \
  [get_bd_pins DMA_DEBUG_FRAME/candidate_factor_m]
  connect_bd_net -net decimation_decision_0_decimation_factor_m  [get_bd_pins DECIMATION_DECISION/decimation_factor_m] \
  [get_bd_pins ILA_DECE/probe9] \
  [get_bd_pins DMA_DEBUG_FRAME/decimation_factor_m] \
  [get_bd_pins CIC_Decimator/cfg_decimation_factor]
  connect_bd_net -net decimation_decision_0_decision_edge_bins  [get_bd_pins DECIMATION_DECISION/decision_edge_bins] \
  [get_bd_pins ILA_DECE/probe15] \
  [get_bd_pins DMA_DEBUG_FRAME/decision_edge_bins]
  connect_bd_net -net decimation_decision_0_decision_error  [get_bd_pins DECIMATION_DECISION/decision_error] \
  [get_bd_pins ILA_DECE/probe12] \
  [get_bd_pins DMA_DEBUG_FRAME/decision_error]
  connect_bd_net -net decimation_decision_0_decision_frame_id  [get_bd_pins DECIMATION_DECISION/decision_frame_id] \
  [get_bd_pins ILA_DECE/probe8] \
  [get_bd_pins DMA_DEBUG_FRAME/decision_frame_id]
  connect_bd_net -net decimation_decision_0_decision_valid  [get_bd_pins DECIMATION_DECISION/decision_valid] \
  [get_bd_pins ILA_DECE/probe7] \
  [get_bd_pins DMA_DEBUG_FRAME/decision_valid]
  connect_bd_net -net decimation_decision_0_m_changed  [get_bd_pins DECIMATION_DECISION/m_changed] \
  [get_bd_pins ILA_DECE/probe11] \
  [get_bd_pins DMA_DEBUG_FRAME/m_changed] \
  [get_bd_pins CIC_Decimator/cfg_valid]
  connect_bd_net -net decimation_decision_0_no_active  [get_bd_pins DECIMATION_DECISION/no_active] \
  [get_bd_pins ILA_DECE/probe13] \
  [get_bd_pins DMA_DEBUG_FRAME/no_active]
  connect_bd_net -net decimation_decision_0_stable_count  [get_bd_pins DECIMATION_DECISION/stable_count] \
  [get_bd_pins ILA_DECE/probe16] \
  [get_bd_pins DMA_DEBUG_FRAME/stable_count]
  connect_bd_net -net pl_resetn0_inv_Res1  [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
  [get_bd_pins rst_ps8_0_99M/ext_reset_in] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins Power_Spectral_Density/rst_n] \
  [get_bd_pins BANDWIDTH_ESTIMATOR/rst_n] \
  [get_bd_pins DATA_FIFO/s_axis_aresetn] \
  [get_bd_pins axi_clock_converter_0/m_axi_aresetn] \
  [get_bd_pins axi_dma_smc/aresetn] \
  [get_bd_pins ILA_PSD/probe4] \
  [get_bd_pins ILA_DECE/probe14] \
  [get_bd_pins DMA_DEBUG_FRAME/rst_n] \
  [get_bd_pins dds_axi_config_regs_0/s_axi_aresetn] \
  [get_bd_pins DECIMATION_DECISION/rst_n] \
  [get_bd_pins CIC_Decimator/rst_n]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn  [get_bd_pins rst_ps8_0_99M/peripheral_aresetn] \
  [get_bd_pins axi_smc/aresetn] \
  [get_bd_pins DMA_FRAME/axi_resetn] \
  [get_bd_pins axi_clock_converter_0/s_axi_aresetn]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0  [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
  [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] \
  [get_bd_pins axi_smc/aclk] \
  [get_bd_pins rst_ps8_0_99M/slowest_sync_clk] \
  [get_bd_pins Clock_62M/clk_in1] \
  [get_bd_pins DMA_FRAME/s_axi_lite_aclk] \
  [get_bd_pins DATA_FIFO/m_axis_aclk] \
  [get_bd_pins DMA_FRAME/m_axi_s2mm_aclk] \
  [get_bd_pins axi_dma_smc/aclk] \
  [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk] \
  [get_bd_pins axi_clock_converter_0/s_axi_aclk]

  # Create address segments
  assign_bd_address -offset 0xA0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs DMA_FRAME/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0010000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs dds_axi_config_regs_0/s_axi/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces DMA_FRAME/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xE0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces DMA_FRAME/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_PCIE_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces DMA_FRAME/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces DMA_FRAME/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces DMA_FRAME/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]


  # Restore current instance
  current_bd_instance $oldCurInst

  # Final validation follows release integration.
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


