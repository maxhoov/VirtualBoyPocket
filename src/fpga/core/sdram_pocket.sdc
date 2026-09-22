# Timing relationship for the Pocket's 64 MB x16 SDRAM interface.
# The controller forwards an inverted 120 MHz clock through a DDIO output.

set sdram_ctrl_clk_pin {ic|mp1|mf_pllbase_inst|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk}
set sdram_ctrl_clk [get_clocks $sdram_ctrl_clk_pin]

if {[get_collection_size $sdram_ctrl_clk] == 0} {
    post_message -type error "sdram_pocket.sdc: controller PLL clock was not found"
} else {
    create_generated_clock -name sdram_clk_pin -invert \
        -source [get_pins $sdram_ctrl_clk_pin] [get_ports {dram_clk}]

    set sdram_out_ports [get_ports {dram_cke dram_a[*] dram_ba[*] dram_dqm[*] dram_ras_n dram_cas_n dram_we_n dram_dq[*]}]
    set_output_delay -clock sdram_clk_pin -max 1.500 $sdram_out_ports
    set_output_delay -clock sdram_clk_pin -min -0.800 $sdram_out_ports
    set_input_delay -clock sdram_clk_pin -max 6.000 [get_ports {dram_dq[*]}]
    set_input_delay -clock sdram_clk_pin -min 2.500 [get_ports {dram_dq[*]}]
    set_multicycle_path -setup 2 -from [get_ports {dram_dq[*]}]
    set_multicycle_path -hold 1 -from [get_ports {dram_dq[*]}]
}

set dq_unused_rise_regs [get_registers {*altddio_in:u_sdram_dq_capture*dataout_h*}]
if {[get_collection_size $dq_unused_rise_regs] > 0} {
    set_false_path -to $dq_unused_rise_regs
}
