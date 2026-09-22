`default_nettype none
module pocket_controls (
    input wire [31:0] keys, sticks,
    input wire dual_pad,
    output wire [15:0] buttons
);
    wire analog_pad = keys[31:28] == 4'h3;
    wire connected = keys[31:28] >= 1 && keys[31:28] <= 3;
    wire ru = (analog_pad && sticks[31:24] < 8'd64) || (dual_pad && keys[6]);
    wire rd = (analog_pad && sticks[31:24] > 8'd192) || (dual_pad && keys[5]);
    wire rl = (analog_pad && sticks[23:16] < 8'd64) || keys[7];
    wire rr = (analog_pad && sticks[23:16] > 8'd192) || (dual_pad && keys[4]);
    // In dual-pad handheld mode A/B move to R/L. In standard mode X/Y
    // supplement the dock right stick (up/left). Dock L2/R2 always supply L/R.
    wire a = dual_pad ? keys[9] : keys[4];
    wire b = dual_pad ? keys[8] : keys[5];
    wire l = keys[10] || (!dual_pad && keys[8]);
    wire r = keys[11] || (!dual_pad && keys[9]);
    assign buttons = connected ? {rd, rl, keys[14], keys[15],
        keys[0], keys[1], keys[2], keys[3], rr,
        ru || (!dual_pad && keys[6]), l, r, b, a, 2'b00} : 16'd0;
endmodule
`default_nettype wire
