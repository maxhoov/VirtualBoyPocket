`timescale 1ns/1ps
module tb_hbias_math;
    reg signed [15:0] gy;
    reg signed [12:0] my;
    reg [8:0] screen_start;
    reg [3:0] ordinal;
    wire [15:0] local_y;
    wire signed [17:0] source_y;
    vip_xp_hbias_scheduler dut(.clk_i(1'b0),.reset_i(1'b0),.ce_i(1'b0),
        .row_start_local_y_o(local_y),.row_start_source_y_o(source_y));
    integer samples=0,screen,expected_local,expected_source,i,j,k;
    reg [31:0] rng=32'h13579bdf;
    task check;
        #1;
        screen=(screen_start+ordinal)&511;
        expected_local=screen-$signed(gy);
        expected_source=expected_local+$signed(my);
        if(local_y !== expected_local[15:0] || source_y !== expected_source[17:0])
            $fatal(1,"H-bias mismatch GY=%0d MY=%0d screen=%0d ordinal=%0d",gy,my,screen_start,ordinal);
        samples++;
    endtask
    initial begin
        force dut.gy_q=gy; force dut.my_q=my;
        force dut.row_screen_start_q=screen_start; force dut.row_ordinal_q=ordinal;
        // Every signed GY, MY extremes, and both sides of screen wrapping.
        for(i=0;i<65536;i++) for(j=0;j<4;j++) begin
            gy=i; my=(j&1)?13'sd4095:-13'sd4096;
            screen_start=(j&2)?9'd511:9'd0; ordinal=(j&2)?4'd15:4'd0;
            check;
        end
        // Cover every MY and broader coordinate combinations deterministically.
        for(k=0;k<200000;k++) begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            gy=rng[15:0]; my=k; screen_start=rng[24:16]; ordinal=rng[28:25];
            check;
        end
        $display("PASS: H-bias coordinate algebra matches signed reference across %0d cases",samples);
        $finish;
    end
endmodule
