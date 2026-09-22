#
# user core constraints
#
# put your clock groups in here as well as any net assignments
#

set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { ic|mp1|mf_pllbase_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|mp1|mf_pllbase_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|mp1|mf_pllbase_inst|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|mp1|mf_pllbase_inst|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk \
          ic|mp1|mf_pllbase_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk }

source core/sdram_pocket.sdc

# Preserve the upstream 40/120 MHz bundled-data crossing constraints.
# Request/payload remains stable until tagged completion; only the first
# capture bank gets this allowance, never the controller's second bank.
set cart_runtime_capture_regs [get_registers {
    *|vb_cart_sdram:u_sdram|read_req_ram_meta_q
    *|vb_cart_sdram:u_sdram|read_tag_ram_meta_q
    *|vb_cart_sdram:u_sdram|read_addr_ram_meta_q[*]
}]
if {[get_collection_size $cart_runtime_capture_regs] == 0} {
    post_message -type error "No cartridge runtime input capture registers matched"
}
set_max_delay 10.000 -to $cart_runtime_capture_regs
set cart_response_src [get_registers {
    *|read_hold_valid_ram_q *|read_hold_tag_ram_q *|read_hold_data_ram_q[*]
}]
set cart_response_dst [get_registers {
    *|read_data_valid_sys_q *|read_data_tag_sys_q *|read_data_sys_q[*]
}]
set_max_delay 5.000 -from $cart_response_src -to $cart_response_dst

# External WRAM: address/OE launched at state 0, data sampled four
# 40 MHz clocks later in state 4. The controller holds the address through
# state 6. Include 5 ns allowance beyond the SRAM's 55 ns access time.
set wram_clock {ic|mp1|mf_pllbase_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set_input_delay -clock $wram_clock -max 60.0 [get_ports {sram_dq[*]}]
set_input_delay -clock $wram_clock -min 0.0 [get_ports {sram_dq[*]}]
set_multicycle_path -setup 4 -from [get_ports {sram_dq[*]}]
set_multicycle_path -hold 3 -from [get_ports {sram_dq[*]}]
set_output_delay -clock $wram_clock -max 5.0 [get_ports {sram_a[*] sram_dq[*] sram_oe_n sram_we_n sram_ub_n sram_lb_n}]
set_output_delay -clock $wram_clock -min 0.0 [get_ports {sram_a[*] sram_dq[*] sram_oe_n sram_we_n sram_ub_n sram_lb_n}]
