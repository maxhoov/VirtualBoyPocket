`timescale 1ns/1ps
module tb_video;
    reg clk=0, ce=0, reset=1;
    always #12.5 clk=~clk;
    always @(negedge clk) ce=~ce;
    reg hb=1, vb=1, hi=0, vi=0;
    wire [23:0] rgb;
    wire de, hs, vs, skip;
    pocket_video dut(clk,ce,reset,2'd2,8'h35,8'ha7,hb,vb,hi,vi,rgb,de,hs,vs,skip);
    integer pixels=0, hcount=0, vcount=0, n;
    reg old_hs=0, old_vs=0;
    always @(posedge clk) begin
        #1;
        if(hs && old_hs || vs && old_vs) $fatal(1,"sync wider than one clock");
        if(skip && !de) $fatal(1,"SKIP outside DE");
        if(!de && rgb!=0) $fatal(1,"metadata not zero");
        if(de && !skip) begin
            pixels=pixels+1;
            if(rgb!==24'h35a7a7) $fatal(1,"eye color mismatch");
        end
        if(hs) hcount=hcount+1;
        if(vs) vcount=vcount+1;
        old_hs=hs; old_vs=vs;
    end
    task step(input integer count);
        repeat(count) begin
            @(negedge clk); while(!ce) @(negedge clk);
        end
    endtask
    initial begin
        step(4); reset=0; vi=1;
        step(12); vi=0;
        step(8); hi=1;
        step(48); hi=0;
        step(8); hb=0; vb=0;
        step(384); hb=1;
        step(8);
        if(pixels!=384 || hcount!=1 || vcount!=1)
            $fatal(1,"wrong video counts %d %d %d",pixels,hcount,vcount);
        $display("PASS: 384 effective pixels, one-clock HS/VS, SKIP and blank metadata");
        $finish;
    end
endmodule
