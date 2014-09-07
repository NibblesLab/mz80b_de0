## Generated SDC file "mz80b.sdc"

## Copyright (C) 1991-2014 Altera Corporation
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, Altera MegaCore Function License 
## Agreement, or other applicable license agreement, including, 
## without limitation, that your use is for the sole purpose of 
## programming logic devices manufactured by Altera and sold by 
## Altera or its authorized distributors.  Please refer to the 
## applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus II"
## VERSION "Version 13.1.4 Build 182 03/12/2014 SJ Web Edition"

## DATE    "Thu Aug 28 23:25:31 2014"

##
## DEVICE  "EP3C16F484C6"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]
create_clock -name {CLOCK_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {CLOCK_50}]
create_clock -name {CLOCK_50_2} -period 20.000 -waveform { 0.000 10.000 } [get_ports {CLOCK_50_2}]
create_clock -name {mz80b_core:MZ80B|T80se:CPU0|IORQ_n} -period 1000.000 -waveform { 0.000 500.000 } 
create_clock -name {mz80b_core:MZ80B|T80se:CPU0|MREQ_n} -period 1000.000 -waveform { 0.000 500.000 } 
create_clock -name {mz80b_core:MZ80B|T80se:CPU0|RD_n} -period 1000.000 -waveform { 0.000 500.000 } 
create_clock -name {DRAM_CLK} -period 10.000 -waveform { 0.000 5.000 } [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|wire_pll1_clk[0]~clkctrl|outclk}]

derive_pll_clocks

#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -master_clock {CLOCK_50_2} [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[1]} -source [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -phase -60.000 -master_clock {CLOCK_50_2} [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -name {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[2]} -source [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -divide_by 5 -master_clock {CLOCK_50_2} [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[2]}] 
create_generated_clock -name {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[3]} -source [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 1 -divide_by 1600 -phase -0.019 -master_clock {CLOCK_50_2} [get_pins {DRAM0|RCKGEN0|altpll_component|auto_generated|pll1|clk[3]}] 
create_generated_clock -name {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 1 -divide_by 2 -master_clock {CLOCK_50} [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[1]} -source [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 8 -divide_by 25 -master_clock {CLOCK_50} [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -name {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[2]} -source [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -divide_by 25 -master_clock {CLOCK_50} [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[2]}] 
create_generated_clock -name {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[3]} -source [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 1 -divide_by 1600 -master_clock {CLOCK_50} [get_pins {MZ80B|VIDEO0|VCKGEN|altpll_component|auto_generated|pll1|clk[3]}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************



#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[0]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[1]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[2]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[3]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[4]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[5]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[6]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[7]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[8]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[9]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[10]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[11]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_ADDR[12]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_BA_0}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_BA_1}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_CAS_N}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_CS_N}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[0]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[1]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[2]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[3]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[4]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[5]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[6]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[7]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[8]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[9]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[10]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[11]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[12]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[13]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[14]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_DQ[15]}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_LDQM}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_RAS_N}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_UDQM}]
set_output_delay -add_delay  -clock [get_clocks {DRAM_CLK}]  0.000 [get_ports {DRAM_WE_N}]


#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 
set_clock_groups -asynchronous -group [get_clocks {CK4M}] -group [get_clocks {CLOCK_50}] 
set_clock_groups -asynchronous -group [get_clocks {CK4M}] -group [get_clocks {CLOCK_50_2}] 
set_clock_groups -asynchronous -group [get_clocks {CK4M}] -group [get_clocks {mz80b_core:MZ80B|T80s:CPU0|IORQ_n}] 
set_clock_groups -asynchronous -group [get_clocks {mz80b_core:MZ80B|T80s:CPU0|RD_n}] -group [get_clocks {mz80b_core:MZ80B|T80s:CPU0|IORQ_n}] 


#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_nios2_oci_break:the_mz80b_de0_NiosII_nios2_oci_break|break_readreg*}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_tck:the_mz80b_de0_NiosII_jtag_debug_module_tck|*sr*}]
set_false_path -from [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_nios2_oci_debug:the_mz80b_de0_NiosII_nios2_oci_debug|*resetlatch}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_tck:the_mz80b_de0_NiosII_jtag_debug_module_tck|*sr[33]}]
set_false_path -from [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_nios2_oci_debug:the_mz80b_de0_NiosII_nios2_oci_debug|monitor_ready}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_tck:the_mz80b_de0_NiosII_jtag_debug_module_tck|*sr[0]}]
set_false_path -from [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_nios2_oci_debug:the_mz80b_de0_NiosII_nios2_oci_debug|monitor_error}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_tck:the_mz80b_de0_NiosII_jtag_debug_module_tck|*sr[34]}]
set_false_path -from [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_nios2_ocimem:the_mz80b_de0_NiosII_nios2_ocimem|*MonDReg*}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_tck:the_mz80b_de0_NiosII_jtag_debug_module_tck|*sr*}]
set_false_path -from [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_tck:the_mz80b_de0_NiosII_jtag_debug_module_tck|*sr*}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_sysclk:the_mz80b_de0_NiosII_jtag_debug_module_sysclk|*jdo*}]
set_false_path -from [get_keepers {sld_hub:*|irf_reg*}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_jtag_debug_module_wrapper:the_mz80b_de0_NiosII_jtag_debug_module_wrapper|mz80b_de0_NiosII_jtag_debug_module_sysclk:the_mz80b_de0_NiosII_jtag_debug_module_sysclk|ir*}]
set_false_path -from [get_keepers {sld_hub:*|sld_shadow_jsm:shadow_jsm|state[1]}] -to [get_keepers {*mz80b_de0_NiosII:*|mz80b_de0_NiosII_nios2_oci:the_mz80b_de0_NiosII_nios2_oci|mz80b_de0_NiosII_nios2_oci_debug:the_mz80b_de0_NiosII_nios2_oci_debug|monitor_go}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|jupdate}] -to [get_registers {*|alt_jtag_atlantic:*|jupdate1*}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|rdata[*]}] -to [get_registers {*|alt_jtag_atlantic*|td_shift[*]}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|read}] -to [get_registers {*|alt_jtag_atlantic:*|read1*}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|read_req}] 
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|rvalid}] -to [get_registers {*|alt_jtag_atlantic*|td_shift[*]}]
set_false_path -from [get_registers {*|t_dav}] -to [get_registers {*|alt_jtag_atlantic:*|tck_t_dav}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|user_saw_rvalid}] -to [get_registers {*|alt_jtag_atlantic:*|rvalid0*}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|wdata[*]}] -to [get_registers *]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|write}] -to [get_registers {*|alt_jtag_atlantic:*|write1*}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|write_stalled}] -to [get_registers {*|alt_jtag_atlantic:*|t_ena*}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|write_stalled}] -to [get_registers {*|alt_jtag_atlantic:*|t_pause*}]
set_false_path -from [get_registers {*|alt_jtag_atlantic:*|write_valid}] 
set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]
set_false_path -to [get_pins -nocase -compatibility_mode {*|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain*|clrn}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

