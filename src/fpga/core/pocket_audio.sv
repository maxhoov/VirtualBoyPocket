`default_nettype none
module pocket_audio (
    input wire clk, source_clk, source_reset,
    input wire [15:0] left_i, right_i,
    output reg mclk = 0, lrck = 0, dac = 0
);
    // One held stereo mailbox crosses domains, rather than sampling changing
    // multi-bit PCM independently. Request once per 48 kHz output frame.
    reg request = 0;
    reg [1:0] request_sync = 0, ack_sync = 0;
    reg ack = 0;
    reg [31:0] snapshot = 0, pcm = 0;
    always @(posedge source_clk) begin
        request_sync <= {request_sync[0], request};
        if (request_sync[1] != ack) begin
            snapshot <= source_reset ? 32'd0 : {left_i, right_i};
            ack <= request_sync[1];
        end
    end
    reg [19:0] accum = 0;
    wire tick = accum >= 20'd496740;
    reg [7:0] phase = 0;
    reg [15:0] shift = 0, right_hold = 0;
    always @(posedge clk) begin
        ack_sync <= {ack_sync[0], ack};
        if (ack_sync[1] == request) pcm <= snapshot;
        // 74.25 MHz -> average 24.576 MHz toggle strobe, no generated logic clock.
        if (tick) begin
            accum <= accum - 20'd496740;
            mclk <= !mclk;
            if (!mclk) begin
                phase <= phase + 1'b1;
                // Internal SCLK falls on every fourth MCLK rising edge.
                if (phase[1:0] == 2'b11) begin
                    dac <= 0;
                    if (phase == 8'd255) begin
                        lrck <= 0;
                        shift <= pcm[31:16]; right_hold <= pcm[15:0];
                        request <= !request;
                    end else if (phase == 8'd127) begin
                        lrck <= 1; shift <= right_hold;
                    end else if (phase[6:2] < 16) begin
                        dac <= shift[15]; shift <= {shift[14:0], 1'b0};
                    end
                end
            end
        end else accum <= accum + 20'd245760;
    end
endmodule
`default_nettype wire
