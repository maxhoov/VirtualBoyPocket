`timescale 1ns/1ps
module tb_pocket;
    reg clk=0, bridge_clk=0;
    always #12.5 clk=~clk;
    always #6.734 bridge_clk=~bridge_clk;
    reg reset=1, start_toggle=0, complete=0;
    reg [55:0] queue[0:63];
    integer head=0, tail=0, writes=0, hold_cycles=0;
    wire pop, wr, download, new_rom;
    wire [26:0] addr;
    wire [31:0] data;
    wire busy=hold_cycles!=0;
    pocket_rom_loader loader(clk,reset,start_toggle,complete,head==tail,
        queue[head],pop,busy,download,wr,addr,data,new_rom);
    always @(posedge clk) begin
        if(pop) head <= head+1;
        if(hold_cycles>0) hold_cycles<=hold_cycles-1;
        if(wr) begin
            if(busy) $fatal(1,"write while storage busy");
            if(addr !== writes*4 || data !== (32'h12345678 ^ writes))
                $fatal(1,"ROM transaction mismatch %d %h %h",writes,addr,data);
            writes<=writes+1;
            hold_cycles<=3+(writes%17);
        end
    end

    reg [31:0] keys=0, sticks=32'h80808080;
    reg dual=0;
    wire [15:0] buttons;
    pocket_controls controls(keys,sticks,dual,buttons);
    reg [10:0] ba=0;
    reg bw=0;
    reg [31:0] bd=0;
    wire [31:0] bq;
    reg req=0, sw=0, tag=0;
    reg [12:0] sa=0;
    reg [7:0] sd=0;
    wire [15:0] sq;
    wire ready;
    pocket_save_ram save_ram(bridge_clk,ba,bw,bd,bq,clk,reset,req,sw,tag,sa,sd,sq,ready);
    task host_write(input [10:0] a,input [31:0] d);
        @(negedge bridge_clk); ba=a; bd=d; bw=1;
        @(negedge bridge_clk); bw=0;
    endtask
    task cpu_read(input [12:0] a,input [7:0] expected);
        @(negedge clk); sa=a; req=1; sw=0; tag=~tag;
        @(posedge clk); #1;
        if(!ready || sq !== {8'hff,expected}) $fatal(1,"SRAM read %d got %h",a,sq);
        @(negedge clk); req=0;
    endtask

    wire mclk, lrck, dac;
    pocket_audio audio(bridge_clk,clk,reset,16'h1357,16'hace1,mclk,lrck,dac);
    integer mc=0, bitno=0, channels=0;
    reg last_lr=0, locked_lr=0;
    reg [15:0] sample=0;
    always @(posedge mclk) begin
        // Reconstruct Pocket's bit clock: rising at MCLK phases 1,5,9,...
        if(mc%4==1) begin
            if(lrck !== last_lr) begin
                last_lr=lrck; bitno=0; sample=0; locked_lr=1;
            end else if(locked_lr && bitno<16) begin
                sample={sample[14:0],dac};
                bitno=bitno+1;
                if(bitno==16) begin
                    if(channels>5 && sample !== (lrck ? 16'hace1 : 16'h1357))
                        $fatal(1,"I2S channel %b got %h",lrck,sample);
                    channels=channels+1;
                end
            end
        end
        mc=mc+1;
    end
    integer i;
    initial begin
        repeat(8) @(negedge clk); reset=0;
        // Burst the queue, random-length storage stalls, completion before drain.
        start_toggle=1;
        repeat(8) @(negedge clk);
        for(i=0;i<64;i=i+1) queue[i]={24'(i*4),32'h12345678 ^ 32'(i)};
        tail=64; complete=1;
        wait(!download); #1;
        if(writes!=64 || head!=64 || busy) $fatal(1,"ROM finalized too early");
        // Empty transfer must not replay a stale FIFO word.
        complete=0; start_toggle=0;
        repeat(8) @(negedge clk); complete=1;
        wait(!download); if(writes!=64) $fatal(1,"stale transfer");
        host_write(0,32'h44332211);
        host_write(2047,32'hddccbbaa);
        cpu_read(0,8'h11); cpu_read(1,8'h22);
        cpu_read(2,8'h33); cpu_read(3,8'h44);
        cpu_read(8191,8'hdd);
        @(negedge clk); req=1; sw=1; sa=2; sd=8'hfe; tag=~tag;
        @(negedge clk); req=0; sw=0;
        @(negedge bridge_clk); ba=0;
        repeat(2) @(negedge bridge_clk);
        if(bq!==32'h1122fe44) $fatal(1,"SRAM bridge read or byte mask: %h",bq);
        keys=32'h10000010; #1;
        if(buttons!==16'h0004) $fatal(1,"A mapping");
        dual=1; #1; if(buttons!==16'h0080) $fatal(1,"dual-pad mapping");
        keys=32'h30000000; sticks=32'h00808080; #1;
        if(buttons!==16'h0040) $fatal(1,"right-stick up");
        keys=32'h400000ff; #1;
        if(buttons!==0) $fatal(1,"keyboard interpreted as controller");
        #500000;
        if(channels<40) $fatal(1,"missing audio frames %d",channels);
        $display("PASS: ROM stalls/drain/reload, packed SRAM/byte writes, controls, I2S (%0d channels)",channels);
        $finish;
    end
    initial begin #2000000; $fatal(1,"test timeout"); end
endmodule
