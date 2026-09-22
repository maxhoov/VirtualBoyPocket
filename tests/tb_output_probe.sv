`timescale 1ns/1ps
module tb_output_probe;
    reg clk=0,ce=0,reset=1;
    always #12.5 clk=~clk;
    always @(negedge clk) ce=~ce;
    wire [7:0] luma;
    wire hb,vb,hi,vi;
    wire [15:0] al,ar;
    pocket_output_probe probe(clk,reset,ce,luma,hb,vb,hi,vi,al,ar,1'b0,32'd0,32'd0);
    wire [7:0] fault_luma;
    pocket_output_probe fault_probe(.clk(clk),.reset(reset),.ce(ce),.luma(fault_luma),
        .fault_valid(1'b1),.fault_pc(32'h01234567),.fault_iw(32'h89abcdef));
    reg [6:0] font[0:15]='{7'h7e,7'h30,7'h6d,7'h79,7'h33,7'h5b,7'h5f,7'h70,
        7'h7f,7'h7b,7'h77,7'h1f,7'h4e,7'h3d,7'h4f,7'h47};
    integer digit,segment,dx,dy,font_checks=0;
    always @(negedge clk) if(!reset && ce) begin
        dx=fault_probe.x%16; dy=(fault_probe.y-16)%32;
        segment=-1;
        if(dx==4 && dy==0) segment=6;
        if(dx==10 && dy==4) segment=5;
        if(dx==10 && dy==16) segment=4;
        if(dx==4 && dy==22) segment=3;
        if(dx==0 && dy==16) segment=2;
        if(dx==0 && dy==4) segment=1;
        if(dx==4 && dy==11) segment=0;
        if(fault_probe.x>=16 && fault_probe.x<144 && segment>=0 &&
            ((fault_probe.y>=16 && fault_probe.y<40)||(fault_probe.y>=48 && fault_probe.y<72))) begin
            digit=(fault_probe.x/16)-1+(fault_probe.y>=48 ? 8 : 0);
            if(fault_luma !== (font[digit][segment] ? 8'hff : 8'h00))
                $fatal(1,"fault hex digit %h segment %d mismatch",digit,segment);
            font_checks=font_checks+1;
        end
    end
    wire [23:0] rgb;
    wire de,hs,vs,skip;
    pocket_video video(clk,ce,reset,2'd3,luma,luma,hb,vb,hi,vi,rgb,de,hs,vs,skip);
    reg retired=0,halted=0,illegal=0,sv=0,visible=0,pixel=0,audio_present=0;
    wire [2:0] cpu_state;
    wire [1:0] video_state;
    wire audio_active;
    pocket_run_monitor #(.WINDOW_BITS(8)) mon(clk,reset,retired,halted,illegal,
        sv,visible,pixel,audio_present,cpu_state,video_state,audio_active);
    reg monitor_done=0;
    initial begin
        repeat(8) @(negedge clk); reset=0;
        retired=1; sv=1; visible=1; pixel=1; audio_present=1;
        repeat(256) @(negedge clk);
        if(cpu_state!=2 || video_state!=3 || !audio_active) $fatal(1,"active window");
        retired=0; pixel=0; audio_present=0;
        repeat(256) @(negedge clk);
        if(cpu_state!=1 || video_state!=2 || audio_active) $fatal(1,"quiet window");
        sv=0; halted=1;
        repeat(256) @(negedge clk);
        if(cpu_state!=3 || video_state!=1) $fatal(1,"halt/no raster");
        illegal=1; @(negedge clk); illegal=0; @(negedge clk);
        if(cpu_state!=4) $fatal(1,"illegal pulse not retained");
        monitor_done=1;
    end
    integer frames=0,pixels=0,lines=0,white=0,grey=0;
    reg old_hs=0,old_vs=0;
    always @(posedge clk) begin
        #1;
        if(!reset) begin
            if((hs&&old_hs)||(vs&&old_vs)) $fatal(1,"wide sync");
            if(skip&&!de || !de&&rgb!=0) $fatal(1,"blanking/skip");
            if(al!=16'h0400 && al!=16'hfc00) $fatal(1,"tone amplitude");
            if(ar!=16'h0400 && ar!=16'hfc00) $fatal(1,"tone amplitude");
            if(vs) begin
                if(frames==1) begin
                    if(pixels!=384*224 || lines!=312 || white==0 || grey==0 || !monitor_done || font_checks<112)
                        $fatal(1,"raster counts %d %d",pixels,lines);
                    $display("PASS: independent 384x224 checkerboard/tones, full-frame raster and windowed CPU/VIP/VSU activity");
                    $finish;
                end
                frames=frames+1; pixels=0; lines=0; white=0; grey=0;
            end
            if(hs) lines=lines+1;
            if(de&&!skip) begin
                pixels=pixels+1;
                if(rgb==24'hffffff) white=white+1;
                else if(rgb==24'hb0b0b0 || rgb==24'h303030) grey=grey+1;
                else $fatal(1,"unexpected pattern pixel %h",rgb);
            end
            old_hs=hs; old_vs=vs;
        end
    end
    initial begin #45000000; $fatal(1,"probe raster timeout"); end
endmodule
