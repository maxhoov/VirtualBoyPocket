`default_nettype none
// Consume each FIFO word exactly once, and wait for acceptance and completion.
module pocket_rom_loader (
    input wire clk, reset, start_toggle_async, complete_async,
    input wire fifo_empty,
    input wire [55:0] fifo_data,
    output wire fifo_pop,
    input wire wait_i,
    output reg download = 0,
    output wire write_o,
    output wire [26:0] addr_o,
    output wire [31:0] data_o,
    output wire new_rom
);
    reg [2:0] start_sync = 0, complete_sync = 0;
    reg seen = 0, saw_incomplete = 0;
    reg [2:0] state = 0;
    localparam IDLE=0, OFFER=1, ACCEPT=2, DRAIN=3;
    reg [55:0] word_q = 0;
    reg [3:0] quiet = 0;
    assign new_rom = start_sync[2] != seen;
    assign fifo_pop = download && state == IDLE && !fifo_empty;
    assign write_o = download && state == OFFER && !wait_i;
    assign addr_o = {3'b0, word_q[55:32]};
    assign data_o = word_q[31:0];
    always @(posedge clk) begin
        start_sync <= {start_sync[1:0], start_toggle_async};
        complete_sync <= {complete_sync[1:0], complete_async};
        if (reset) begin
            seen <= 0; download <= 0; state <= IDLE;
            quiet <= 0; saw_incomplete <= 0;
        end else if (new_rom) begin
            seen <= start_sync[2]; download <= 1;
            state <= IDLE; quiet <= 0; saw_incomplete <= !complete_sync[2];
        end else if (download) begin
            if (!complete_sync[2]) saw_incomplete <= 1;
            case (state)
                IDLE: if (!fifo_empty) begin
                    word_q <= fifo_data; state <= OFFER; quiet <= 0;
                end else if (saw_incomplete && complete_sync[2] && !wait_i) begin
                    if (quiet == 15) download <= 0;
                    else quiet <= quiet + 1'b1;
                end else quiet <= 0;
                OFFER: if (!wait_i) state <= ACCEPT;
                ACCEPT: state <= DRAIN;
                DRAIN: if (!wait_i) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
