`timescale 1ns/1ps
// Original, tiny V810 program; no commercial ROM is required.
// Boot through the real CPU/VUE/VIP/VSU hierarchy and Pocket WRAM adapter.
module tb_boot;
    reg clk=0, ce=0, reset=1;
    always #12.5 clk=~clk;
    always @(negedge clk) ce=~ce;
    wire [23:1] ext_addr;
    wire [15:0] ext_data, save_data;
    wire [3:0] ext_be;
    wire ext_da, ext_req, ext_rw, save_cs, rom_cs, tag, save_ready;
    wire [14:0] wa;
    wire [15:0] wd,wq;
    wire [1:0] wb;
    wire wreq,ww,wready,halted,illegal;
    wire [31:0] pc;
    reg [15:0] rom[0:127];
    virtualboy #(.CPU_RESET_PC(32'h07000000)) dut (
        .clk_i(clk),
        .reset_i(reset),
        .ce_i(ce),
        .video_ce_i(ce),
        .savestate_pause_req_i('0),
        .savestate_pause_drain_ready_o(),
        .savestate_pause_ready_o(),
        .savestate_restore_i('0),
        .savestate_state_addr_i('0),
        .savestate_state_wdata_i('0),
        .savestate_state_wren_i('0),
        .savestate_state_rdata_o(),
        .savestate_mem_active_i('0),
        .savestate_mem_type_i('0),
        .savestate_mem_addr_i('0),
        .savestate_mem_rden_i('0),
        .savestate_mem_wren_i('0),
        .savestate_mem_wdata_i('0),
        .savestate_mem_rdata_o(),
        .cheat_clear_i('0),
        .cheat_code_i('0),
        .pad_buttons_i('0),
        .pad_serial_enable_i('0),
        .pad_serial_i('0),
        .cart_irq_i('0),
        .rumble_enable_i('0),
        .link_comcnt_i('0),
        .link_clk_i('0),
        .link_rx_i('0),
        .link_sync_i('0),
        .flat_dual_eye_i('0),
        .side_by_side_i('0),
        .compat_60hz_i('0),
        .parallax_scale_i('0),
        .presentation_hlg_i('0),
        .brightness_table_legacy_sdr_i('0),
        .brightness_table_download_i('0),
        .brightness_table_write_i('0),
        .brightness_table_addr_i('0),
        .brightness_table_data_i('0),
        .pad_latch_o(),
        .pad_clock_o(),
        .link_comcnt_o(),
        .link_clk_o(),
        .link_tx_o(),
        .link_sync_o(),
        .rumble_o(),
        .ext_a_o(ext_addr),
        .ext_dout_o(ext_data),
        .ext_dout_oe_o(),
        .ext_be_o(ext_be),
        .ext_st_o(),
        .ext_da_o(ext_da),
        .ext_mrq_o(ext_req),
        .ext_rw_o(ext_rw),
        .wram_cs_o(),
        .cart_exp_cs_o(),
        .cart_ram_cs_o(save_cs),
        .cart_rom_cs_o(rom_cs),
        .ext_cycle_tag_o(tag),
        .ext_din_i(rom_cs ? rom[ext_addr[7:1]] : save_data),
        .ext_ready_i(rom_cs || save_ready),
        .pocket_wram_addr_o(wa),
        .pocket_wram_data_o(wd),
        .pocket_wram_be_o(wb),
        .pocket_wram_req_o(wreq),
        .pocket_wram_write_o(ww),
        .pocket_wram_data_i(wq),
        .pocket_wram_ready_i(wready),
        .video_raw_l_o(),
        .video_raw_r_o(),
        .video_luma_l_o(),
        .video_luma_r_o(),
        .video_hblank_o(),
        .video_vblank_o(),
        .video_hsync_o(),
        .video_vsync_o(),
        .audio_l_o(),
        .audio_r_o(),
        .audio_sample_valid_o(),
        .timer_tick_o(),
        .timer_zero_o(),
        .timer_irq_o(),
        .cpu_bus_mrq_o(),
        .cpu_bus_ready_o(),
        .cpu_bus_region_o(),
        .cpu_bus_da_o(),
        .cpu_bus_rw_o(),
        .cpu_bus_st_o(),
        .cpu_bus_bcyst_o(),
        .dbg_reg_addr_i('0),
        .dbg_reg_data_o(),
        .dbg_pc_o(pc),
        .dbg_psw_o(),
        .trace_valid_o(),
        .trace_pc_o(),
        .trace_insn_o(),
        .cpu_halted_o(halted),
        .cpu_illegal_o(illegal)
    );
    wire [16:0] sram_a;
    tri [15:0] dq;
    wire oe,we,ub,lb;
    pocket_wram wram(clk,reset,wreq,ww,tag,wa,wd,wb,wq,wready,sram_a,dq,oe,we,ub,lb);
    reg [15:0] mem[0:32767];
    assign #55 dq = !oe && we ? mem[sram_a[14:0]] : 16'hzzzz;
    always @(posedge we) if(!reset) begin
        if(!ub) mem[sram_a[14:0]][15:8]=dq[15:8];
        if(!lb) mem[sram_a[14:0]][7:0]=dq[7:0];
    end
    wire [31:0] bridge_q;
    pocket_save_ram save (
        .bridge_clk(clk), .bridge_addr(11'd0), .bridge_write(1'b0),
        .bridge_data(32'd0), .bridge_q(bridge_q), .clk(clk), .reset(reset),
        .req(ext_req && save_cs),
        .write_i(ext_req && save_cs && ext_da && !ext_rw &&
                 (ext_be==4'b1100 || ext_be==4'b1110)),
        .addr(ext_addr[13:1]), .data_i(ext_data[7:0]), .tag(tag),
        .data_o(save_data), .ready(save_ready)
    );
    integer i, cycles;
    initial begin
        for(i=0;i<128;i=i+1) rom[i]=16'h6800;
        for(i=0;i<32768;i=i+1) mem[i]=0;
        rom[0]=16'hbc20; rom[1]=16'h0500; // movhi 0x0500,r0,r1 (WRAM)
        rom[2]=16'ha040; rom[3]=16'h1234; // movea 0x1234,r0,r2
        rom[4]=16'hd441; rom[5]=0;       // st.h r2,0[r1]
        rom[6]=16'hc461; rom[7]=0;       // ld.h 0[r1],r3
        rom[8]=16'hd461; rom[9]=2;       // st.h r3,2[r1]
        rom[10]=16'hd041; rom[11]=1;     // st.b r2,1[r1]
        rom[12]=16'hc481; rom[13]=0;     // ld.h 0[r1],r4
        rom[14]=16'hd481; rom[15]=4;     // st.h r4,4[r1]
        rom[16]=16'hbca0; rom[17]=16'h0600; // movhi cartridge SRAM,r5
        rom[18]=16'hd085; rom[19]=0;     // st.b r4,0[r5]
        rom[20]=16'h6800;               // halt
        repeat(10) @(negedge clk); reset=0;
        cycles=0;
        while(!halted) begin
            @(negedge clk); cycles=cycles+1;
            if(illegal) $fatal(1,"illegal instruction at %h",pc);
            if(cycles>10000) $fatal(1,"boot timeout PC=%h",pc);
        end
        repeat(10) @(negedge clk);
        if(mem[0]!==16'h3434 || mem[1]!==16'h1234 || mem[2]!==16'h3434)
            $fatal(1,"WRAM readback failed %h %h %h",mem[0],mem[1],mem[2]);
        if(bridge_q[31:24]!==8'h34) $fatal(1,"cartridge SRAM store failed: %h",bridge_q);
        $display("PASS: V810 synthetic boot, WRAM word/byte readback and cartridge SRAM store (%0d cycles)",cycles);
        $finish;
    end
endmodule
