//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1 

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable, 

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,
 
///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus 

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,
    
output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
// 
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
//   [31:28] type
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [31:0]  cont1_key,
input   wire    [31:0]  cont2_key,
input   wire    [31:0]  cont3_key,
input   wire    [31:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig
    
);

// -----------------------------------------------------------------------------
// Analogue Pocket wrapper for the MiSTer Virtual Boy console implementation.
// The Pocket bridge runs at 74.25 MHz, the console at 40 MHz with a 20 MHz
// clock enable, and the external SDRAM controller at 120 MHz.
// -----------------------------------------------------------------------------

// Safe defaults for interfaces that this core does not use.
assign port_ir_tx = 1'b0;
assign port_ir_rx_disable = 1'b1;
assign bridge_endian_little = 1'b0;

assign cart_tran_bank3 = 8'hzz;
assign cart_tran_bank3_dir = 1'b0;
assign cart_tran_bank2 = 8'hzz;
assign cart_tran_bank2_dir = 1'b0;
assign cart_tran_bank1 = 8'hzz;
assign cart_tran_bank1_dir = 1'b0;
assign cart_tran_bank0 = 4'hf;
assign cart_tran_bank0_dir = 1'b1;
assign cart_tran_pin30 = 1'b0;
assign cart_tran_pin30_dir = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;
assign cart_tran_pin31 = 1'bz;
assign cart_tran_pin31_dir = 1'b0;

assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;

assign cram0_a = 6'd0;
assign cram0_dq = 16'hzzzz;
assign cram0_clk = 1'b0;
assign cram0_adv_n = 1'b1;
assign cram0_cre = 1'b0;
assign cram0_ce0_n = 1'b1;
assign cram0_ce1_n = 1'b1;
assign cram0_oe_n = 1'b1;
assign cram0_we_n = 1'b1;
assign cram0_ub_n = 1'b1;
assign cram0_lb_n = 1'b1;
assign cram1_a = 6'd0;
assign cram1_dq = 16'hzzzz;
assign cram1_clk = 1'b0;
assign cram1_adv_n = 1'b1;
assign cram1_cre = 1'b0;
assign cram1_ce0_n = 1'b1;
assign cram1_ce1_n = 1'b1;
assign cram1_oe_n = 1'b1;
assign cram1_we_n = 1'b1;
assign cram1_ub_n = 1'b1;
assign cram1_lb_n = 1'b1;

assign dbg_tx = 1'bz;
assign user1 = 1'bz;
assign aux_scl = 1'bz;
assign vpll_feed = 1'bz;

// Core/video/SDRAM clocks. The unused fifth output keeps the generated PLL
// wrapper compatible with the template IP packaging.
wire clk_sys;
wire clk_pixel;
wire clk_pixel_90;
wire clk_ram;
wire clk_unused;
wire pll_core_locked;

mf_pllbase mp1 (
    .refclk   (clk_74a),
    .rst      (1'b0),
    .outclk_0 (clk_sys),
    .outclk_1 (clk_pixel),
    .outclk_2 (clk_pixel_90),
    .outclk_3 (clk_ram),
    .outclk_4 (clk_unused),
    .locked   (pll_core_locked)
);

reg ce_div = 1'b0;
always @(posedge clk_sys) begin
    if (!pll_core_locked)
        ce_div <= 1'b0;
    else
        ce_div <= ~ce_div;
end
wire ce_20m = ~ce_div;

// Host command bridge.
wire reset_n;
wire [31:0] cmd_bridge_rd_data;
wire dataslot_requestread;
wire [15:0] dataslot_requestread_id;
wire dataslot_requestwrite;
wire [15:0] dataslot_requestwrite_id;
wire [31:0] dataslot_requestwrite_size;
wire dataslot_update;
wire [15:0] dataslot_update_id;
wire [31:0] dataslot_update_size;
wire dataslot_allcomplete;
wire [31:0] rtc_epoch_seconds;
wire [31:0] rtc_date_bcd;
wire [31:0] rtc_time_bcd;
wire rtc_valid;
wire osnotify_inmenu;
wire menu_paused;
wire savestate_start;
wire savestate_load;
wire [9:0] datatable_addr = 10'd0;
wire datatable_wren = 1'b0;
wire [31:0] datatable_data = 32'd0;
wire [31:0] datatable_q;

reg [1:0] pll_bridge_sync = 2'b00;
reg [1:0] rom_loaded_bridge_sync = 2'b00;
wire rom_loaded;
reg loader_fault = 1'b0;
wire [31:0] save_bridge_data;
reg [1:0] display_mode = 2'd0;
reg control_mode = 1'b0;
wire core_reset;
wire cpu_trace_valid;
wire cpu_halted, cpu_illegal;
wire [31:0] cpu_illegal_pc,cpu_illegal_iw;
reg fault_valid=0;
reg [31:0] fault_pc=0,fault_iw=0;
always @(posedge clk_sys) begin
    if(core_reset) begin fault_valid<=0; fault_pc<=0; fault_iw<=0; end
    else if(cpu_illegal && !fault_valid) begin
        fault_valid<=1; fault_pc<=cpu_illegal_pc; fault_iw<=cpu_illegal_iw;
    end
end
wire [2:0] cpu_activity;
wire [1:0] vip_activity;
wire vsu_activity;
reg [5:0] activity_meta=0, activity_sync=0;
reg output_test=0;
reg [1:0] output_test_sync=0;
reg rom_fetch_seen = 0, rom_response_seen = 0, cpu_retired_seen = 0;
reg [7:0] boot_meta = 0, boot_sync = 0;
reg rom_request_seen = 0;
reg [3:0] boot_stage;
always @(posedge clk_74a) begin
    pll_bridge_sync <= {pll_bridge_sync[0], pll_core_locked};
    rom_loaded_bridge_sync <= {rom_loaded_bridge_sync[0], rom_loaded};
end

wire status_boot_done = pll_bridge_sync[1];
wire status_setup_done = pll_bridge_sync[1];
wire status_running = reset_n && rom_loaded_bridge_sync[1] && !loader_fault;

core_bridge_cmd icb (
    .clk(clk_74a),
    .reset_n(reset_n),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_rd(bridge_rd),
    .bridge_rd_data(cmd_bridge_rd_data),
    .bridge_wr(bridge_wr),
    .bridge_wr_data(bridge_wr_data),
    .status_boot_done(status_boot_done),
    .status_setup_done(status_setup_done),
    .status_running(status_running),
    .dataslot_requestread(dataslot_requestread),
    .dataslot_requestread_id(dataslot_requestread_id),
    .dataslot_requestread_ack(dataslot_requestread),
    .dataslot_requestread_ok(1'b1),
    .dataslot_requestwrite(dataslot_requestwrite),
    .dataslot_requestwrite_id(dataslot_requestwrite_id),
    .dataslot_requestwrite_size(dataslot_requestwrite_size),
    .dataslot_requestwrite_ack(dataslot_requestwrite),
    .dataslot_requestwrite_ok((dataslot_requestwrite_id == 16'd0 && dataslot_requestwrite_size >= 32'd16 && dataslot_requestwrite_size <= 32'h01000000 && dataslot_requestwrite_size[1:0] == 0) || (dataslot_requestwrite_id == 16'd1 && dataslot_requestwrite_size == 32'd8192)),
    .dataslot_update(dataslot_update),
    .dataslot_update_id(dataslot_update_id),
    .dataslot_update_size(dataslot_update_size),
    .dataslot_allcomplete(dataslot_allcomplete),
    .rtc_epoch_seconds(rtc_epoch_seconds),
    .rtc_date_bcd(rtc_date_bcd),
    .rtc_time_bcd(rtc_time_bcd),
    .rtc_valid(rtc_valid),
    .savestate_supported(1'b0),
    .savestate_addr(32'd0),
    .savestate_size(32'd0),
    .savestate_maxloadsize(32'd0),
    .savestate_start(savestate_start),
    .savestate_start_ack(1'b1),
    .savestate_start_busy(1'b0),
    .savestate_start_ok(1'b0),
    .savestate_start_err(1'b1),
    .savestate_load(savestate_load),
    .savestate_load_ack(1'b1),
    .savestate_load_busy(1'b0),
    .savestate_load_ok(1'b0),
    .savestate_load_err(1'b1),
    .osnotify_inmenu(osnotify_inmenu),
    .target_dataslot_read(1'b0),
    .target_dataslot_write(1'b0),
    .target_dataslot_getfile(1'b0),
    .target_dataslot_openfile(1'b0),
    .target_dataslot_ack(),
    .target_dataslot_done(),
    .target_dataslot_err(),
    .target_dataslot_id(16'd0),
    .target_dataslot_slotoffset(32'd0),
    .target_dataslot_bridgeaddr(32'd0),
    .target_dataslot_length(32'd0),
    .target_buffer_param_struct(32'd0),
    .target_buffer_resp_struct(32'd0),
    .datatable_addr(datatable_addr),
    .datatable_wren(datatable_wren),
    .datatable_data(datatable_data),
    .datatable_q(datatable_q)
);

// APF sends the PREVIOUS read response before strobing the next request.
// Hold both the data and its mux selection while bridge_addr changes.
reg command_read_selected = 0;
reg [31:0] user_read_data = 0;
always @(posedge clk_74a) begin
    if (bridge_rd) begin
        command_read_selected <= bridge_addr[31:24] == 8'hf8;
        case (bridge_addr)
            32'h20000000: user_read_data <= {30'd0, display_mode};
            32'h20000004: user_read_data <= {31'd0, control_mode};
            32'h20000008: user_read_data <= {31'd0, loader_fault};
            32'h2000000c: user_read_data <= {28'd0, boot_stage};
            32'h20000010: user_read_data <= 32'd5; // diagnostic build marker
            32'h20000014: user_read_data <= {29'd0,activity_sync[2:0]};
            32'h20000018: user_read_data <= {31'd0,output_test};
            32'h2000001c: user_read_data <= {30'd0,activity_sync[4:3]};
            32'h20000020: user_read_data <= {31'd0,activity_sync[5]};
            default: user_read_data <= bridge_addr[31:13] == (32'h10000000 >> 13) ? save_bridge_data : 32'd0;
        endcase
    end
end
always @(*) bridge_rd_data = command_read_selected ? cmd_bridge_rd_data : user_read_data;

// ROM slot 0 at 0x00000000, 8 KiB packed SRAM slot 1 at 0x10000000.
// Bridge endian is big: byte 0 of a file arrives in bits 31:24.
wire [31:0] file_word = {bridge_wr_data[7:0], bridge_wr_data[15:8],
                         bridge_wr_data[23:16], bridge_wr_data[31:24]};
// Board-confirmed workaround: ROM reads exhibit byte-address XOR 2.
// Pre-exchange the two halfwords, equivalent to the v3 diagnostic ROM.
// Keep save RAM on file_word; its bridge byte order must not change.
// The underlying load-layout/read-burst cause is not yet isolated.
wire [31:0] rom_file_word = {file_word[15:0], file_word[31:16]};
wire loader_fifo_wr = bridge_wr && (bridge_addr[31:24] == 8'h00);
wire [55:0] loader_fifo_q;
wire loader_fifo_empty, loader_fifo_full, loader_fifo_rd;
reg request_old = 1'b0;
reg load_toggle = 1'b0;
always @(posedge clk_74a) begin
    request_old <= dataslot_requestwrite;
    if (dataslot_requestwrite && !request_old && dataslot_requestwrite_id == 0)
        load_toggle <= ~load_toggle;
    // Sticky error: never run a partially loaded cartridge after FIFO overflow.
    if (loader_fifo_wr && loader_fifo_full) loader_fault <= 1'b1;
end

dcfifo #(
    .lpm_width(56), .lpm_numwords(256), .lpm_widthu(8),
    .lpm_showahead("ON"), .overflow_checking("ON"),
    .underflow_checking("ON"), .use_eab("ON"),
    .rdsync_delaypipe(4), .wrsync_delaypipe(4)
) loader_fifo (
    .aclr(!pll_core_locked),
    .data({bridge_addr[23:0], rom_file_word}),
    .rdclk(clk_sys), .rdreq(loader_fifo_rd),
    .wrclk(clk_74a), .wrreq(loader_fifo_wr && !loader_fifo_full),
    .q(loader_fifo_q), .rdempty(loader_fifo_empty), .wrfull(loader_fifo_full),
    .rdfull(), .wrempty(), .rdusedw(), .wrusedw()
);
wire ioctl_wait, ioctl_wr, rom_download, new_rom;
wire [26:0] ioctl_addr;
wire [31:0] ioctl_dout;
pocket_rom_loader loader (
    .clk(clk_sys), .reset(!pll_core_locked),
    .start_toggle_async(load_toggle), .complete_async(dataslot_allcomplete),
    .fifo_empty(loader_fifo_empty), .fifo_data(loader_fifo_q),
    .fifo_pop(loader_fifo_rd), .wait_i(ioctl_wait),
    .download(rom_download), .write_o(ioctl_wr),
    .addr_o(ioctl_addr), .data_o(ioctl_dout), .new_rom(new_rom)
);

// Console external bus and cartridge SDRAM.
wire [23:1] ext_a;
wire [23:0] ext_addr = {ext_a, 1'b0};
wire [15:0] ext_dout;
wire [3:0] ext_be;
wire ext_da;
wire ext_mrq;
wire ext_rw;
wire cart_ram_cs;
wire cart_rom_cs;
wire ext_cycle_tag;
wire [15:0] ext_din;
wire [15:0] rom_data;
wire rom_ready;
wire [15:0] cart_ram_data;
wire cart_ram_ready;
wire cart_ram_req = ext_mrq && cart_ram_cs;
wire cart_ram_write_req = cart_ram_req && ext_da && !ext_rw &&
    ((ext_be == 4'b1100) || (ext_be == 4'b1110));
wire cart_ready = cart_rom_cs ? (ext_rw ? rom_ready : 1'b1) :
    cart_ram_cs ? cart_ram_ready : 1'b1;
assign ext_din = cart_rom_cs ? rom_data :
    cart_ram_cs ? cart_ram_data : 16'hffff;
pocket_save_ram save_ram (
    .bridge_clk(clk_74a), .bridge_addr(bridge_addr[12:2]),
    .bridge_write(bridge_wr && bridge_addr[31:13] == (32'h10000000 >> 13)),
    .bridge_data(file_word), .bridge_q(save_bridge_data),
    .clk(clk_sys), .reset(core_reset),
    .req(cart_ram_req), .write_i(cart_ram_write_req),
    .addr(ext_a[13:1]), .data_i(ext_dout[7:0]), .tag(ext_cycle_tag),
    .data_o(cart_ram_data), .ready(cart_ram_ready)
);

wire sdram_ncs_unused;
vb_cart_rom u_cart (
    .clk_sys(clk_sys),
    .clk_ram(clk_ram),
    .reset_i(!pll_core_locked),
    .rom_download_i(rom_download),
    .ioctl_wr_i(ioctl_wr),
    .ioctl_addr_i(ioctl_addr),
    .ioctl_dout_i(ioctl_dout),
    .ioctl_wait_o(ioctl_wait),
    .rom_loaded_o(rom_loaded),
    .req_valid_i(ext_mrq && cart_rom_cs && ext_rw),
    .req_tag_i(ext_cycle_tag),
    .req_addr_i(ext_addr),
    .resp_data_o(rom_data),
    .resp_ready_o(rom_ready),
    .sram_req_i(1'b0),
    .sram_we_i(1'b0),
    .sram_addr_i(26'd0),
    .sram_write_data_i(16'd0),
    .sram_be_i(2'b00),
    .sram_read_lane_i(1'b0),
    .sram_tag_i(ext_cycle_tag),
    .sram_read_data_o(),
    .sram_read_valid_o(),
    .sram_access_done_o(),
    .sram_bg_req_i(1'b0),
    .sram_bg_we_i(1'b0),
    .sram_bg_addr_i(26'd0),
    .sram_bg_write_data_i(16'd0),
    .sram_bg_be_i(2'b11),
    .sram_bg_ready_o(),
    .sram_bg_done_o(),
    .sram_bg_read_data_o(),
    .foreground_idle_o(),
    .SDRAM_DQ(dram_dq),
    .SDRAM_A(dram_a),
    .SDRAM_DQML(dram_dqm[0]),
    .SDRAM_DQMH(dram_dqm[1]),
    .SDRAM_BA(dram_ba),
    .SDRAM_nCS(sdram_ncs_unused),
    .SDRAM_nWE(dram_we_n),
    .SDRAM_nRAS(dram_ras_n),
    .SDRAM_nCAS(dram_cas_n),
    .SDRAM_CKE(dram_cke),
    .SDRAM_CLK(dram_clk)
);

always @(posedge clk_74a) begin
    if (bridge_wr && bridge_addr == 32'h20000000) display_mode <= bridge_wr_data[1:0];
    if (bridge_wr && bridge_addr == 32'h20000004) control_mode <= bridge_wr_data[0];
    if (bridge_wr && bridge_addr == 32'h20000018) output_test <= bridge_wr_data[0];
    activity_meta <= {vsu_activity,vip_activity,
        (menu_paused && cpu_activity != 3'd4) ? 3'd5 : cpu_activity};
    activity_sync <= activity_meta;
end
reg [31:0] key_meta = 0, key_sync = 0, joy_meta = 0, joy_sync = 0;
reg [1:0] mode_meta = 0, mode_sync = 0;
reg layout_meta = 0, layout_sync = 0;
reg [1:0] reset_sync = 0, fault_sync = 0;
(* async_reg = "true" *) reg [1:0] menu_sync = 0;
reg menu_input_block = 1'b1;
always @(posedge clk_sys) begin
    key_meta <= cont1_key; key_sync <= key_meta;
    joy_meta <= cont1_joy; joy_sync <= joy_meta;
    mode_meta <= display_mode; mode_sync <= mode_meta;
    layout_meta <= control_mode; layout_sync <= layout_meta;
    reset_sync <= {reset_sync[0], reset_n};
    fault_sync <= {fault_sync[0], loader_fault};
    output_test_sync <= {output_test_sync[0],output_test};
    if (!pll_core_locked) menu_sync <= 0;
    else menu_sync <= {menu_sync[0],osnotify_inmenu};
end
wire [15:0] pad_buttons;
pocket_controls controls (
    .keys(key_sync), .sticks(joy_sync), .dual_pad(layout_sync), .buttons(pad_buttons)
);
// Do not replay a held menu-navigation button into the game on resume.
always @(posedge clk_sys) begin
    if (core_reset || menu_sync[1]) menu_input_block <= 1'b1;
    else if (pad_buttons == 16'd0) menu_input_block <= 1'b0;
end
wire [15:0] game_buttons = (menu_sync[1] || menu_input_block) ? 16'd0 : pad_buttons;

wire [1:0] video_raw_left;
wire [1:0] video_raw_right;
wire [7:0] video_luma_left;
wire [7:0] video_luma_right;
wire video_hblank;
wire video_vblank;
wire video_hsync;
wire video_vsync;
wire [15:0] audio_left;
wire [15:0] audio_right;
wire clear_busy, clear_write;
wire [2:0] clear_type;
wire [24:0] clear_addr;
wire [7:0] clear_data;
wire [14:0] wram_addr;
wire [15:0] wram_dout, wram_din;
wire [1:0] wram_be;
wire wram_req, wram_write, wram_ready;
pocket_wram wram (
    .clk(clk_sys), .reset(!pll_core_locked),
    .req(wram_req), .write_i(wram_write),
    .tag(clear_busy ? clear_addr[0] : ext_cycle_tag),
    .addr(wram_addr), .data_i(wram_dout), .be(wram_be),
    .data_o(wram_din), .ready(wram_ready),
    .sram_a(sram_a), .sram_dq(sram_dq),
    .sram_oe_n(sram_oe_n), .sram_we_n(sram_we_n),
    .sram_ub_n(sram_ub_n), .sram_lb_n(sram_lb_n)
);
vb_cart_ram_clear ram_clear (
    .clk_i(clk_sys), .reset_i(!pll_core_locked), .start_i(new_rom),
    .cancel_i(1'b0), .mem_ready_i(clear_type != 0 || wram_ready), .busy_o(clear_busy),
    .mem_type_o(clear_type), .mem_addr_o(clear_addr),
    .mem_wren_o(clear_write), .mem_wdata_o(clear_data)
);
assign core_reset = !pll_core_locked || !reset_sync[1] || !rom_loaded ||
    rom_download || clear_busy || fault_sync[1];

virtualboy #(
    .VIDEO_H_VISIBLE(384),
    .VIDEO_H_TOTAL(1280),
    .VIDEO_H_SYNC_BEG(1056),
    .VIDEO_H_SYNC_END(1152),
    .VIDEO_V_VISIBLE(224),
    .VIDEO_V_TOTAL(312),
    .VIDEO_V_SYNC_BEG(289),
    .VIDEO_V_SYNC_END(292),
    .VIDEO_FLAT_OUTPUT(1'b1),
    .PAUSE_KEEP_SCANOUT(1'b1)
) u_virtualboy (
    .clk_i(clk_sys),
    .reset_i(core_reset),
    .ce_i(ce_20m && !core_reset),
    .video_ce_i(ce_20m && !core_reset),
    .savestate_pause_req_i(menu_sync[1]),
    .savestate_pause_drain_ready_o(),
    .savestate_pause_ready_o(menu_paused),
    .savestate_restore_i(1'b0),
    .savestate_state_addr_i(7'd0),
    .savestate_state_wdata_i(64'd0),
    .savestate_state_wren_i(1'b0),
    .savestate_state_rdata_o(),
    .savestate_mem_active_i(clear_busy),
    .savestate_mem_type_i(clear_type),
    .savestate_mem_addr_i(clear_addr),
    .savestate_mem_rden_i(1'b0),
    .savestate_mem_wren_i(clear_write),
    .savestate_mem_wdata_i(clear_data),
    .savestate_mem_rdata_o(),
    .cheat_clear_i(1'b0),
    .cheat_code_i(129'd0),
    .pad_buttons_i(game_buttons),
    .pad_serial_enable_i(1'b0),
    .pad_serial_i(1'b1),
    .cart_irq_i(1'b0),
    .rumble_enable_i(1'b0),
    .link_comcnt_i(1'b1),
    .link_clk_i(1'b0),
    .link_rx_i(1'b0),
    .link_sync_i(1'b0),
    .flat_dual_eye_i(1'b1),
    .side_by_side_i(1'b0),
    .compat_60hz_i(1'b0),
    .parallax_scale_i(3'd0),
    .presentation_hlg_i(1'b0),
    .brightness_table_legacy_sdr_i(1'b0),
    .brightness_table_download_i(1'b0),
    .brightness_table_write_i(1'b0),
    .brightness_table_addr_i(10'd0),
    .brightness_table_data_i(16'd0),
    .pad_latch_o(), .pad_clock_o(),
    .link_comcnt_o(), .link_clk_o(), .link_tx_o(), .link_sync_o(),
    .rumble_o(),
    .ext_a_o(ext_a),
    .ext_dout_o(ext_dout),
    .ext_dout_oe_o(),
    .ext_be_o(ext_be),
    .ext_st_o(),
    .ext_da_o(ext_da),
    .ext_mrq_o(ext_mrq),
    .ext_rw_o(ext_rw),
    .wram_cs_o(),
    .cart_exp_cs_o(),
    .cart_ram_cs_o(cart_ram_cs),
    .cart_rom_cs_o(cart_rom_cs),
    .ext_cycle_tag_o(ext_cycle_tag),
    .pocket_wram_addr_o(wram_addr), .pocket_wram_data_o(wram_dout),
    .pocket_wram_be_o(wram_be), .pocket_wram_req_o(wram_req),
    .pocket_wram_write_o(wram_write), .pocket_wram_data_i(wram_din),
    .pocket_wram_ready_i(wram_ready),
    .ext_din_i(ext_din),
    .ext_ready_i(cart_ready),
    .video_raw_l_o(video_raw_left),
    .video_raw_r_o(video_raw_right),
    .video_luma_l_o(video_luma_left),
    .video_luma_r_o(video_luma_right),
    .video_hblank_o(video_hblank),
    .video_vblank_o(video_vblank),
    .video_hsync_o(video_hsync),
    .video_vsync_o(video_vsync),
    .audio_l_o(audio_left),
    .audio_r_o(audio_right),
    .audio_sample_valid_o(),
    .timer_tick_o(), .timer_zero_o(), .timer_irq_o(),
    .cpu_bus_mrq_o(), .cpu_bus_ready_o(), .cpu_bus_region_o(),
    .cpu_bus_da_o(), .cpu_bus_rw_o(), .cpu_bus_st_o(), .cpu_bus_bcyst_o(),
    .dbg_reg_addr_i(5'd0),
    .dbg_reg_data_o(), .dbg_pc_o(), .dbg_psw_o(),
    .trace_valid_o(cpu_trace_valid), .trace_pc_o(), .trace_insn_o(),
    .cpu_halted_o(cpu_halted), .cpu_illegal_o(cpu_illegal),
    .cpu_illegal_pc_o(cpu_illegal_pc),.cpu_illegal_iw_o(cpu_illegal_iw)
);

// Read-only game activity; unaffected by selection of the output test.
pocket_run_monitor run_monitor (
    .clk(clk_sys),.reset(core_reset),.retired(cpu_trace_valid),
    .halted(cpu_halted),.illegal(cpu_illegal),.vsync(video_vsync),
    .visible(!video_hblank && !video_vblank),
    .pixel_nonzero(|video_luma_left || |video_luma_right),
    .audio_nonzero(|audio_left || |audio_right),
    .cpu_state(cpu_activity),.video_state(vip_activity),.audio_active(vsu_activity)
);
wire [7:0] probe_luma;
wire probe_hblank,probe_vblank,probe_hsync,probe_vsync;
wire [15:0] probe_left,probe_right;
pocket_output_probe output_probe (
    .clk(clk_sys),.reset(!pll_core_locked),.ce(ce_20m),.luma(probe_luma),
    .hblank(probe_hblank),.vblank(probe_vblank),.hsync(probe_hsync),.vsync(probe_vsync),
    .audio_left(probe_left),.audio_right(probe_right),
    .fault_valid(fault_valid),.fault_pc(fault_pc),.fault_iw(fault_iw)
);
always @(posedge clk_sys) begin
    if (core_reset) begin
        rom_fetch_seen <= 0; rom_response_seen <= 0; cpu_retired_seen <= 0;
    end else begin
        if (ext_mrq && cart_rom_cs && ext_rw) rom_fetch_seen <= 1;
        if (ext_mrq && cart_rom_cs && ext_rw && rom_ready) rom_response_seen <= 1;
        if (cpu_trace_valid) cpu_retired_seen <= 1;
    end
end
always @(posedge clk_74a) begin
    boot_meta <= {cpu_retired_seen, rom_response_seen, rom_fetch_seen,
                  clear_busy, rom_download, rom_loaded, core_reset, reset_sync[1]};
    boot_sync <= boot_meta;
    if (dataslot_requestwrite && dataslot_requestwrite_id == 0) rom_request_seen <= 1;
end
always @(*) begin
    if (!pll_bridge_sync[1]) boot_stage = 0;
    else if (!rom_request_seen) boot_stage = 1;
    else if (loader_fault) boot_stage = 11;
    else if (boot_sync[3]) boot_stage = 2;
    else if (!boot_sync[2]) boot_stage = 3;
    else if (!boot_sync[0]) boot_stage = 4;
    else if (boot_sync[4]) boot_stage = 5;
    else if (boot_sync[1]) boot_stage = 6;
    else if (!boot_sync[5]) boot_stage = 7;
    else if (!boot_sync[6]) boot_stage = 8;
    else if (!boot_sync[7]) boot_stage = 9;
    else boot_stage = 10;
end

// Sync pulses and blank RGB metadata obey APF's digital bus protocol.
assign video_rgb_clock = clk_pixel;
assign video_rgb_clock_90 = clk_pixel_90;
pocket_video video (
    .clk(clk_sys), .ce(ce_20m), .reset(!pll_core_locked || (!output_test_sync[1] && core_reset)),
    .mode(output_test_sync[1] ? 2'd3 : mode_sync),
    .left_i(output_test_sync[1] ? probe_luma : video_luma_left),
    .right_i(output_test_sync[1] ? probe_luma : video_luma_right),
    .hblank(output_test_sync[1] ? probe_hblank : video_hblank),
    .vblank(output_test_sync[1] ? probe_vblank : video_vblank),
    .hsync(output_test_sync[1] ? probe_hsync : video_hsync),
    .vsync(output_test_sync[1] ? probe_vsync : video_vsync),
    .rgb(video_rgb), .de(video_de), .hs(video_hs), .vs(video_vs), .skip(video_skip)
);
pocket_audio audio (
    .clk(clk_74a), .source_clk(clk_sys), .source_reset(!pll_core_locked || menu_sync[1] || (!output_test_sync[1] && core_reset)),
    .left_i(output_test_sync[1] ? probe_left : audio_left),
    .right_i(output_test_sync[1] ? probe_right : audio_right),
    .mclk(audio_mclk), .lrck(audio_lrck), .dac(audio_dac)
);
endmodule
