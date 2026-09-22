`default_nettype none
module pocket_video (
    input wire clk, ce, reset,
    input wire [1:0] mode,
    input wire [7:0] left_i, right_i,
    input wire hblank, vblank, hsync, vsync,
    output reg [23:0] rgb = 0,
    output reg de = 0, hs = 0, vs = 0, skip = 0
);
    reg hs_old = 0, vs_old = 0;
    reg [1:0] frame_mode = 0;
    always @(posedge clk) begin
        hs <= 0; vs <= 0;
        if (reset) begin
            rgb <= 0; de <= 0; skip <= 0;
            hs_old <= 0; vs_old <= 0; frame_mode <= mode;
        end else if (ce) begin
            hs_old <= hsync; vs_old <= vsync;
            hs <= hsync && !hs_old;
            vs <= vsync && !vs_old;
            if (vsync && !vs_old) frame_mode <= mode;
            de <= !hblank && !vblank;
            skip <= 0;
            if (hblank || vblank) rgb <= 0;
            else case (frame_mode)
                0: rgb <= {left_i, 16'd0};
                1: rgb <= {right_i, 16'd0};
                2: rgb <= {left_i, right_i, right_i};
                3: rgb <= {left_i, left_i, left_i};
            endcase
        end else skip <= de;
    end
endmodule
`default_nettype wire
