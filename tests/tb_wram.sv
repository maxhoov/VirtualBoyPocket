`timescale 1ns/1ps
module tb_wram;
    reg clk=0, reset=1, req=0, wr=0, tag=0;
    always #12.5 clk=~clk;
    reg [14:0] addr=0;
    reg [15:0] din=0;
    reg [1:0] be=0;
    wire [15:0] dout;
    wire ready;
    wire [16:0] a;
    tri [15:0] dq;
    wire oe, we, ub, lb;
    pocket_wram dut(clk,reset,req,wr,tag,addr,din,be,dout,ready,a,dq,oe,we,ub,lb);
    reg [15:0] mem [0:32767];
    // Conservative asynchronous access time, not a vendor model.
    assign #55 dq = !oe && we ? mem[a[14:0]] : 16'hzzzz;
    realtime fall_time, address_time;
    always @(a) address_time=$realtime;
    always @(negedge we) if(!reset) begin
        fall_time=$realtime;
        if($realtime-address_time<20) $fatal(1,"SRAM setup too short");
        if(!oe) $fatal(1,"SRAM bus contention");
    end
    always @(posedge we) if(!reset) begin
        if($realtime-fall_time<55) $fatal(1,"SRAM write pulse too short");
        if(!ub) mem[a[14:0]][15:8]=dq[15:8];
        if(!lb) mem[a[14:0]][7:0]=dq[7:0];
    end
    task access(input bit write_t, input [14:0] addr_t,
                input [15:0] data_t, input [1:0] be_t);
        integer guard;
        begin
            @(negedge clk);
            req=1; wr=write_t; addr=addr_t; din=data_t; be=be_t; tag=~tag;
            #1;
            if(ready) $fatal(1,"stale completion");
            guard=0;
            while(!ready) begin
                @(negedge clk); guard=guard+1;
                if(guard>12) $fatal(1,"SRAM timeout");
            end
        end
    endtask
    integer i;
    initial begin
        for(i=0;i<32768;i=i+1) mem[i]=16'hffff;
        repeat(3) @(negedge clk); reset=0;
        for(i=0;i<128;i=i+1) access(1,i,16'ha500+i,3);
        for(i=0;i<128;i=i+1) begin
            access(0,i,0,0);
            if(dout!==(16'ha500+i)) $fatal(1,"SRAM word mismatch %d",i);
        end
        access(1,32767,16'h1234,3);
        access(1,32767,16'habcd,1);
        access(0,32767,0,0);
        if(dout!==16'h12cd) $fatal(1,"low byte mask");
        access(1,32767,16'habcd,2);
        access(0,32767,0,0);
        if(dout!==16'habcd) $fatal(1,"high byte mask");
        // Clear-walker holds its request high, advancing only on READY.
        for(i=0;i<128;i=i+1) begin
            access(1,i,0,1); access(1,i,0,2);
            access(0,i,0,0);
            if(dout!==0) $fatal(1,"byte clear mismatch");
        end
        $display("PASS: external WRAM read/write, byte enables, tag handshake and 75 ns write pulses");
        $finish;
    end
    initial begin #1000000; $fatal(1,"timeout"); end
endmodule
