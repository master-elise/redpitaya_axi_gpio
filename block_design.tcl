# ==================================================================================================
# block_design.tcl - Create Vivado Project
#
# This script should be run from the base redpitaya-guides/ folder inside Vivado tcl console.
#
# by Gwenhael Goavec-Merou, 18.08.2017
# ==================================================================================================

# JMF: identify Vivado version
set vers [lindex [split [version -short] "."] 0]
puts "$vers"

#set project_name 1_led_blink
set part_name xc7z010clg400-1
set project_name ex_axi_gpio
set bd_path tmp/$project_name/$project_name.srcs/sources_1/bd/system

file delete -force tmp/$project_name

create_project $project_name tmp/$project_name -part $part_name

create_bd_design system
# open_bd_design {$bd_path/system.bd}

# Load RedPitaya ports
source ports.tcl

# Set Path for the custom IP cores
set_property IP_REPO_PATHS tmp/cores [current_project]
update_ip_catalog


# Zynq processing system with RedPitaya specific preset
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1}] [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_IMPORT_BOARD_PRESET {red_pitaya.xml}] [get_bd_cells processing_system7_0]
endgroup

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list CONFIG.C_GPIO_WIDTH {8}] [get_bd_cells axi_gpio_0]
endgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_processing_system7_0_125M

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 processing_system7_0_axi_periph
set_property -dict [ list CONFIG.NUM_MI {1}] [get_bd_cells processing_system7_0_axi_periph]
endgroup

# Buffers for differential IOs
startgroup
if {[expr $vers] < 2021} {
	create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 util_ds_buf_0
} else {
	create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0
}
set_property -dict [list CONFIG.C_SIZE {2}] [get_bd_cells util_ds_buf_0]

if {[expr $vers] < 2021} {
	create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 util_ds_buf_1
} else {
	create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_1}
set_property -dict [list CONFIG.C_SIZE {2}] [get_bd_cells util_ds_buf_1]

if {[expr $vers] < 2021} {
	create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 util_ds_buf_2
} else {
	create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_2
}
set_property -dict [list CONFIG.C_SIZE {2}] [get_bd_cells util_ds_buf_2]
set_property -dict [list CONFIG.C_BUF_TYPE {OBUFDS}] [get_bd_cells util_ds_buf_2]
endgroup

# ====================================================================================
# Connections 
#
#apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins axi_gpio_0/S_AXI]

# Create interface connections
connect_bd_intf_net -intf_net axi_gpio_0_GPIO \
	[get_bd_intf_ports led_o] \
	[get_bd_intf_pins axi_gpio_0/GPIO]

connect_bd_net [get_bd_ports adc_clk_p_i] [get_bd_pins util_ds_buf_0/IBUF_DS_P]
connect_bd_net [get_bd_ports adc_clk_n_i] [get_bd_pins util_ds_buf_0/IBUF_DS_N]
connect_bd_net [get_bd_ports daisy_p_i] [get_bd_pins util_ds_buf_1/IBUF_DS_P]
connect_bd_net [get_bd_ports daisy_n_i] [get_bd_pins util_ds_buf_1/IBUF_DS_N]
connect_bd_net [get_bd_ports daisy_p_o] [get_bd_pins util_ds_buf_2/OBUF_DS_P]
connect_bd_net [get_bd_ports daisy_n_o] [get_bd_pins util_ds_buf_2/OBUF_DS_N]
connect_bd_net [get_bd_pins util_ds_buf_1/IBUF_OUT] [get_bd_pins util_ds_buf_2/OBUF_IN]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

# clock connection
connect_bd_net -net processing_system7_0_FCLK_CLK0 \
	[get_bd_pins axi_gpio_0/s_axi_aclk] \
	[get_bd_pins processing_system7_0/FCLK_CLK0] \
	[get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] \
	[get_bd_pins processing_system7_0/S_AXI_HP0_ACLK] \
	[get_bd_pins processing_system7_0_axi_periph/ACLK] \
	[get_bd_pins processing_system7_0_axi_periph/M00_ACLK] \
	[get_bd_pins processing_system7_0_axi_periph/S00_ACLK] \
	[get_bd_pins rst_processing_system7_0_125M/slowest_sync_clk]

# AXI connection : proc => interconnect 
connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 \
	[get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
	[get_bd_intf_pins processing_system7_0_axi_periph/S00_AXI]

# AXI connection : interconnect => periph
connect_bd_intf_net -intf_net processing_system7_0_axi_periph_M00_AXI \
	[get_bd_intf_pins axi_gpio_0/S_AXI] \
	[get_bd_intf_pins processing_system7_0_axi_periph/M00_AXI]

# reset proc => proc_sys_reset
connect_bd_net -net processing_system7_0_FCLK_RESET0_N \
	[get_bd_pins processing_system7_0/FCLK_RESET0_N] \
	[get_bd_pins rst_processing_system7_0_125M/ext_reset_in]

# reset proc_sys_reset => interconnect
connect_bd_net -net rst_processing_system7_0_125M_interconnect_aresetn \
	[get_bd_pins processing_system7_0_axi_periph/ARESETN] \
	[get_bd_pins rst_processing_system7_0_125M/interconnect_aresetn]

# reset proc_sys_reset => peripheral
connect_bd_net -net rst_processing_system7_0_125M_peripheral_aresetn \
	[get_bd_pins axi_gpio_0/s_axi_aresetn] \
	[get_bd_pins processing_system7_0_axi_periph/M00_ARESETN] \
	[get_bd_pins processing_system7_0_axi_periph/S00_ARESETN] \
	[get_bd_pins rst_processing_system7_0_125M/peripheral_aresetn]

# Create address segments
create_bd_addr_seg -range 0x00010000 -offset 0x41200000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg


# ====================================================================================
# Generate output products and wrapper, add constraint any any additional files 

generate_target all [get_files  $bd_path/system.bd]

make_wrapper -files [get_files $bd_path/system.bd] -top
add_files -norecurse $bd_path/hdl/system_wrapper.v

# Load any additional Verilog files in the project folder
set files [glob -nocomplain projects/$project_name/*.v projects/$project_name/*.sv]
if {[llength $files] > 0} {
  add_files -norecurse $files
}

# Load RedPitaya constraint files
set files [glob -nocomplain *.xdc]
if {[llength $files] > 0} {
  add_files -norecurse -fileset constrs_1 $files
}

set_property VERILOG_DEFINE {TOOL_VIVADO} [current_fileset]
set_property STRATEGY Flow_PerfOptimized_High [get_runs synth_1]
set_property STRATEGY Performance_NetDelay_high [get_runs impl_1]

# =================================================
# ggm 
# =================================================
# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part $part_name -flow {Vivado Synthesis 2016} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2016" [get_runs synth_1]
}
set obj [get_runs synth_1]

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part $part_name -flow {Vivado Implementation 2016} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2016" [get_runs impl_1]
}
set obj [get_runs impl_1]

set_property "needs_refresh" "1" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

puts "INFO: Project created: $project_name"
# set the current impl run
current_run -implementation [get_runs impl_1]
generate_target all [get_files tmp/$project_name.srcs/sources_1/bd/system/system.bd]
launch_runs synth_1
wait_on_run synth_1
## do implementation
launch_runs impl_1
wait_on_run impl_1
## make bit file
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
exit
