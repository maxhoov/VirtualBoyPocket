`default_nettype none
// ROM-independent diagnostic source, using the same raster as the game.
module pocket_output_probe (
    input wire clk, reset, ce,
    output wire [7:0] luma,
    output wire hblank, vblank, hsync, vsync,
    output wire [15:0] audio_left, audio_right,
    input wire fault_valid,
    input wire [31:0] fault_pc,fault_iw
);
    reg [10:0] x=0;
    reg [8:0] y=0;
    reg [15:0] tone=0;
    always @(posedge clk) begin
        if(reset) begin x<=0; y<=0; tone<=0; end
        else begin
            tone<=tone+1'b1;
            if(ce) begin
                if(x==1279) begin x<=0; y<=y==311 ? 9'd0 : y+1'b1; end
                else x<=x+1'b1;
            end
        end
    end
    assign hblank=x>=384;
    assign vblank=y>=224;
    assign hsync=x>=1056 && x<1152;
    assign vsync=y>=289 && y<292;
    // White frame, grey checkerboard: no dependency on VIP palette or RAM.
    wire [7:0] pattern_luma=(hblank || vblank) ? 8'd0 :
        ((x<4 || x>=380 || y<4 || y>=220) ? 8'hff :
            ((x[5]^y[5]) ? 8'hb0 : 8'h30));
    // First-fault PC then instruction, eight hexadecimal digits per row.
    function automatic [6:0] segments(input [3:0] n);
        case(n)
            0:segments=7'b1111110; 1:segments=7'b0110000;
            2:segments=7'b1101101; 3:segments=7'b1111001;
            4:segments=7'b0110011; 5:segments=7'b1011011;
            6:segments=7'b1011111; 7:segments=7'b1110000;
            8:segments=7'b1111111; 9:segments=7'b1111011;
            10:segments=7'b1110111; 11:segments=7'b0011111;
            12:segments=7'b1001110; 13:segments=7'b0111101;
            14:segments=7'b1001111; 15:segments=7'b1000111;
        endcase
    endfunction
    wire panel=fault_valid && x>=12 && x<148 && y>=12 && y<76;
    wire digit_area=x>=16 && x<144 && ((y>=16 && y<40)||(y>=48 && y<72));
    wire [2:0] digit_index=4'd8-x[7:4];
    wire [31:0] digit_word=y<48 ? fault_pc : fault_iw;
    wire [3:0] nibble=digit_word[{digit_index,2'b00} +: 4];
    wire [6:0] seg=segments(nibble);
    wire [3:0] dx=x[3:0];
    wire [4:0] dy=y[4:0]-5'd16;
    wire ink=(seg[6] && dy<2 && dx>=2 && dx<10) ||
        (seg[5] && dx>=10 && dx<12 && dy>=2 && dy<11) ||
        (seg[4] && dx>=10 && dx<12 && dy>=13 && dy<22) ||
        (seg[3] && dy>=22 && dx>=2 && dx<10) ||
        (seg[2] && dx<2 && dy>=13 && dy<22) ||
        (seg[1] && dx<2 && dy>=2 && dy<11) ||
        (seg[0] && dy>=11 && dy<13 && dx>=2 && dx<10);
    assign luma=panel ? ((digit_area && ink) ? 8'hff : 8'h00) : pattern_luma;
    // Signed, low-level square tones (~610 Hz left / ~1221 Hz right).
    assign audio_left=tone[15] ? 16'h0400 : 16'hfc00;
    assign audio_right=tone[14] ? 16'h0400 : 16'hfc00;
endmodule

// Windowed activity avoids equating one retired instruction with a live game.
module pocket_run_monitor #(parameter WINDOW_BITS=23) (
    input wire clk, reset, retired, halted, illegal,
    input wire vsync, visible, pixel_nonzero, audio_nonzero,
    output wire [2:0] cpu_state,
    output wire [1:0] video_state,
    output wire audio_active
);
    reg [WINDOW_BITS-1:0] timer=0;
    reg retire_window=0, vs_window=0, pixel_window=0, audio_window=0;
    reg recent_retire=0, recent_vs=0, recent_pixel=0, recent_audio=0;
    reg illegal_seen=0;
    always @(posedge clk) begin
        if(reset) begin
            timer<=0; retire_window<=0; vs_window<=0; pixel_window<=0; audio_window<=0;
            recent_retire<=0; recent_vs<=0; recent_pixel<=0; recent_audio<=0; illegal_seen<=0;
        end else begin
            timer<=timer+1'b1;
            illegal_seen<=illegal_seen || illegal;
            if(&timer) begin
                recent_retire<=retire_window || retired;
                recent_vs<=vs_window || vsync;
                recent_pixel<=pixel_window || (visible && pixel_nonzero);
                recent_audio<=audio_window || audio_nonzero;
                retire_window<=0; vs_window<=0; pixel_window<=0; audio_window<=0;
            end else begin
                retire_window<=retire_window || retired;
                vs_window<=vs_window || vsync;
                pixel_window<=pixel_window || (visible && pixel_nonzero);
                audio_window<=audio_window || audio_nonzero;
            end
        end
    end
    assign cpu_state=reset ? 3'd0 : illegal_seen ? 3'd4 : halted ? 3'd3 : recent_retire ? 3'd2 : 3'd1;
    assign video_state=reset ? 2'd0 : !recent_vs ? 2'd1 : recent_pixel ? 2'd3 : 2'd2;
    assign audio_active=!reset && recent_audio;
endmodule
`default_nettype wire
