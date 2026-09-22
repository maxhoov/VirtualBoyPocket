`default_nettype none
// Retail VB cartridges use 8 KiB x8 SRAM on the low half of the 16-bit bus.
// Four byte banks expose packed 32-bit words to APF without an SDRAM mirror.
// APF loads before reset exit and reads on shutdown. Avoid live host writes.
module pocket_save_ram (
    input wire bridge_clk,
    input wire [10:0] bridge_addr,
    input wire bridge_write,
    input wire [31:0] bridge_data,
    output wire [31:0] bridge_q,
    input wire clk, reset, req, write_i, tag,
    input wire [12:0] addr,
    input wire [7:0] data_i,
    output wire [15:0] data_o,
    output wire ready
);
    wire [31:0] cpu_q, host_q;
    genvar b;
    generate for (b=0; b<4; b=b+1) begin : bank
`ifdef ALTERA_RESERVED_QIS
        altsyncram #(
            .operation_mode("BIDIR_DUAL_PORT"),
            .intended_device_family("Cyclone V"), .ram_block_type("M10K"),
            .width_a(8), .widthad_a(11), .numwords_a(2048),
            .width_b(8), .widthad_b(11), .numwords_b(2048),
            .width_byteena_a(1), .width_byteena_b(1),
            .address_reg_b("CLOCK1"), .indata_reg_b("CLOCK1"),
            .wrcontrol_wraddress_reg_b("CLOCK1"),
            .outdata_reg_a("UNREGISTERED"), .outdata_reg_b("UNREGISTERED"),
            .read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
            .read_during_write_mode_port_b("NEW_DATA_NO_NBE_READ")
        ) ram (
            .clock0(bridge_clk), .address_a(bridge_addr),
            .wren_a(bridge_write), .data_a(bridge_data[b*8 +: 8]),
            .q_a(host_q[b*8 +: 8]),
            .clock1(clk), .address_b(addr[12:2]),
            .wren_b(!reset && req && write_i && addr[1:0] == b),
            .data_b(data_i), .q_b(cpu_q[b*8 +: 8])
        );
`else
        (* ramstyle = "M10K, no_rw_check" *) reg [7:0] mem [0:2047];
        reg [7:0] cq, hq;
        always @(posedge bridge_clk) begin
            if (bridge_write) mem[bridge_addr] <= bridge_data[b*8 +: 8];
            hq <= mem[bridge_addr];
        end
        always @(posedge clk) begin
            if (!reset && req && write_i && addr[1:0] == b)
                mem[addr[12:2]] <= data_i;
            cq <= mem[addr[12:2]];
        end
        assign cpu_q[b*8 +: 8] = cq;
        assign host_q[b*8 +: 8] = hq;
`endif
    end endgenerate
    reg valid = 0, tag_q = 0;
    reg [12:0] addr_q = 0;
    always @(posedge clk) begin
        valid <= req && !reset;
        tag_q <= tag;
        addr_q <= addr;
    end
    assign ready = valid && req && tag_q == tag && addr_q == addr;
    assign data_o = {8'hff, cpu_q[addr_q[1:0]*8 +: 8]};
    assign bridge_q = {host_q[7:0], host_q[15:8], host_q[23:16], host_q[31:24]};
endmodule
`default_nettype wire
