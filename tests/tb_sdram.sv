`timescale 1ns/1ps
module tb_sdram;
    reg clk=0, ramclk=0, reset=1;
    always #12.5 clk=~clk;
    always #(25.0/6) ramclk=~ramclk;
    reg download=0, wr=0, req=0, tag=0;
    reg [26:0] addr=0;
    reg [31:0] data=0;
    reg [23:0] read_addr=0;
    wire wait_i, loaded, ready;
    wire [15:0] q;
    wire [15:0] dq;
    wire [12:0] a;
    wire [1:0] ba;
    wire dql,dqh,cs,we,ras,cas,cke,dclk;
    vb_cart_rom dut (
        .clk_sys(clk), .clk_ram(ramclk), .reset_i(reset),
        .rom_download_i(download), .ioctl_wr_i(wr),
        .ioctl_addr_i(addr), .ioctl_dout_i(data), .ioctl_wait_o(wait_i),
        .rom_loaded_o(loaded), .req_valid_i(req), .req_tag_i(tag),
        .req_addr_i(read_addr), .resp_data_o(q), .resp_ready_o(ready),
        .sram_req_i(1'b0), .sram_we_i(1'b0), .sram_addr_i(26'd0),
        .sram_write_data_i(16'd0), .sram_be_i(2'b00),
        .sram_read_lane_i(1'b0), .sram_tag_i(1'b0),
        .sram_bg_req_i(1'b0), .sram_bg_we_i(1'b0), .sram_bg_addr_i(26'd0),
        .sram_bg_write_data_i(16'd0), .sram_bg_be_i(2'b00),
        .SDRAM_DQ(dq), .SDRAM_A(a), .SDRAM_BA(ba),
        .SDRAM_DQML(dql), .SDRAM_DQMH(dqh), .SDRAM_nCS(cs),
        .SDRAM_nWE(we), .SDRAM_nRAS(ras), .SDRAM_nCAS(cas),
        .SDRAM_CKE(cke), .SDRAM_CLK(dclk)
    );
    // Pin-level CL3 / BL2 SDRAM model, tAC=5.5 ns. No access to DUT internals.
    // Sparse storage covers the full ROM address range without allocating
    // a large, mostly unused simulated image.
    reg [15:0] mem[int unsigned];
    reg [12:0] row[0:3];
    reg [2:0] pending=0;
    integer pa[0:2], burst_addr=0, word_addr;
    reg second=0, drive=0;
    reg [15:0] dq_out=0;
    assign dq=drive ? dq_out : 16'hzzzz;
    integer writes=0, refreshes=0;
    reg emr=0, mr=0;
    // Check the controller's mobile timing budget at the pins, independently
    // of its internal age counters. This is not a full SDRAM device model.
    realtime last_active=-1000000.0, last_refresh=-1000000.0;
    realtime last_write_close=-1000000.0;
    always @(posedge dclk) begin
        if(cke && !cs && {ras,cas,we} != 3'b111) begin
            if($realtime-last_refresh < 120.0)
                $fatal(1,"SDRAM command violates 120 ns refresh recovery");
            case ({ras,cas,we})
                3'b011, 3'b001: begin
                    if($realtime-last_active < 72.0)
                        $fatal(1,"SDRAM command violates 72 ns row cycle");
                    if($realtime-last_write_close < 35.0)
                        $fatal(1,"SDRAM command violates 35 ns write close");
                    if({ras,cas,we} == 3'b011) last_active=$realtime;
                    else last_refresh=$realtime;
                end
                3'b100, 3'b101: begin
                    if($realtime-last_active < 21.0)
                        $fatal(1,"SDRAM column command violates 21 ns RCD");
                    if({ras,cas,we} == 3'b100 && a[10])
                        last_write_close=$realtime;
                end
            endcase
        end
    end
    always @(posedge dclk) begin
        drive <= #5.5 (pending[2] || second);
        if(pending[2]) begin
            dq_out <= #5.5 mem[pa[2]];
            burst_addr=pa[2]^1; second=1;
        end else if(second) begin
            dq_out <= #5.5 mem[burst_addr]; second=0;
        end
        pending={pending[1:0],1'b0};
        pa[2]=pa[1]; pa[1]=pa[0];
        if(cke && !cs) case ({ras,cas,we})
            3'b011: row[ba]=a;
            3'b000: if(ba==0) begin
                if(a[6:4]!=3 || a[2:0]!=1 || !a[9])
                    $fatal(1,"SDRAM mode register %h",a);
                mr=1;
            end else if(ba==2) begin
                if(a!=0) $fatal(1,"SDRAM EMR %h",a);
                emr=1;
            end
            3'b001: refreshes=refreshes+1;
            3'b100: begin
                if(!mr || !emr || ba!=0)
                    $fatal(1,"invalid write command");
                word_addr={ba,row[ba],a[9:0]};
                if(!dql) mem[word_addr][7:0]=dq[7:0];
                if(!dqh) mem[word_addr][15:8]=dq[15:8];
                writes=writes+1;
            end
            3'b101: begin
                if(ba!=0) $fatal(1,"ROM bank outside 16 MiB");
                pending[0]=1; pa[0]={ba,row[ba],a[9:0]};
            end
        endcase
    end
    integer i;
    reg [23:0] sparse_addr[0:7];
    realtime first_write, elapsed;
    initial begin
        repeat(8) @(negedge clk); reset=0; download=1;
        wait(!wait_i); @(negedge clk);
        first_write=$realtime;
        for(i=0;i<256;i=i+1) begin
            while(wait_i) @(negedge clk);
            addr=i*4; data=32'hd00d1234 ^ i; wr=1;
            @(negedge clk); wr=0;
            @(negedge clk);
        end
        wait(!wait_i); @(negedge clk);
        download=0; wait(loaded);
        elapsed=$realtime-first_write;
        if(writes!=512) $fatal(1,"lost 32-bit loader halfwords %d",writes);
        for(i=0;i<512;i=i+1) begin
            @(negedge clk);
            read_addr=24'hfffc00+i*2; req=1; tag=~tag;
            // ready must not be inherited from the previous request's tag.
            #1; if(ready) $fatal(1,"stale tagged response");
            wait(ready);
            if(q !== (i[0] ? 16'hd00d : (16'h1234 ^ (i/2))))
                $fatal(1,"SDRAM read %d got %h",i,q);
        end
        @(negedge clk); req=0;
        if(refreshes<3) $fatal(1,"missing refresh");
        sparse_addr[0]=24'h000000; sparse_addr[1]=24'h0007fc;
        sparse_addr[2]=24'h000800; sparse_addr[3]=24'h000ffc;
        sparse_addr[4]=24'h001000; sparse_addr[5]=24'h7ffffc;
        sparse_addr[6]=24'h800000; sparse_addr[7]=24'hfffffc;
        download=1;
        repeat(2) @(negedge clk);
        for(i=0;i<8;i=i+1) begin
            while(wait_i) @(negedge clk);
            addr={3'b0,sparse_addr[i]}; data=32'h5a00c300 ^ i; wr=1;
            @(negedge clk); wr=0;
            @(negedge clk);
        end
        wait(!wait_i); @(negedge clk); download=0; wait(loaded);
        if(writes!=528) $fatal(1,"lost sparse reload words %d",writes);
        for(i=0;i<16;i=i+1) begin
            @(negedge clk);
            read_addr=sparse_addr[i/2]+(i[0] ? 24'd2 : 24'd0);
            req=1; tag=~tag;
            #1; if(ready) $fatal(1,"stale high-address response");
            wait(ready);
            if(q !== (i[0] ? 16'h5a00 : (16'hc300 ^ (i/2))))
                $fatal(1,"SDRAM high-address read %h got %h",read_addr,q);
        end
        $display("PASS: mobile SDRAM init/command spacing, 32-bit writes, 512 mirrored + 16 sparse/reload reads through 16 MiB; loader %0.2f MB/s",1024.0/elapsed*1000.0);
        $finish;
    end
    initial begin #3000000; $fatal(1,"SDRAM timeout"); end
endmodule
