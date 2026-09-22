`default_nettype none
// 64 KiB WRAM in Pocket's 55 ns asynchronous SRAM. All pin transitions
// are registered at 40 MHz. CPU READY stretches until the access completes.
module pocket_wram (
    input wire clk, reset, req, write_i, tag,
    input wire [14:0] addr,
    input wire [15:0] data_i,
    input wire [1:0] be,
    output reg [15:0] data_o,
    output wire ready,
    output wire [16:0] sram_a,
    inout wire [15:0] sram_dq,
    output reg sram_oe_n = 1, sram_we_n = 1,
    output wire sram_ub_n, sram_lb_n
);
    reg [2:0] state = 0;
    reg [14:0] addr_q;
    reg [15:0] data_q;
    reg [1:0] be_q;
    reg write_q, tag_q, valid_q = 0;
    reg drive_q = 0;
    wire match_q = valid_q && addr == addr_q && tag == tag_q &&
        write_i == write_q && (!write_i || (be == be_q && data_i == data_q));
    assign ready = req && match_q && state == 6;
    assign sram_a = {2'b00, addr_q};
    assign sram_dq = drive_q ? data_q : 16'hzzzz;
    // 25 ns setup, 75 ns WE pulse, 25 ns data/address hold.
    assign sram_ub_n = write_q ? !be_q[1] : 1'b0;
    assign sram_lb_n = write_q ? !be_q[0] : 1'b0;
    always @(posedge clk) begin
        if (reset) begin
            state <= 0; valid_q <= 0;
            addr_q <= 0; data_q <= 0; be_q <= 0;
            write_q <= 0; tag_q <= 0; data_o <= 0;
            sram_oe_n <= 1; sram_we_n <= 1; drive_q <= 0;
        end else if (state == 0 || state == 6) begin
            if (!req) begin state <= 0; valid_q <= 0; end
            else if (!match_q) begin
                addr_q <= addr; data_q <= data_i; be_q <= be;
                write_q <= write_i; tag_q <= tag; valid_q <= 1;
                drive_q <= write_i; sram_oe_n <= write_i;
                state <= 1;
            end
        end else begin
            state <= state + 1'b1;
            if (state == 1 && write_q) sram_we_n <= 0;
            if (state == 4) begin sram_we_n <= 1; sram_oe_n <= 1; end
            if (state == 5) drive_q <= 0;
            if (state == 4 && !write_q) data_o <= sram_dq;
        end
    end
endmodule
`default_nettype wire
