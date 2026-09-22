`timescale 1ns/1ps
// Clock-only substitute: no assertion about physical PLL/board timing.
module mf_pllbase(input refclk,rst, output reg outclk_0=0,
    output wire outclk_1, output reg outclk_2=0,outclk_3=0,
    output wire outclk_4, output reg locked=0);
    always #12.5 outclk_0=~outclk_0;
    initial begin #6.25; forever #12.5 outclk_2=~outclk_2; end
    always #(25.0/6) outclk_3=~outclk_3;
    assign outclk_1=outclk_0, outclk_4=outclk_0;
    initial #200 locked=1;
endmodule

module tb_top_boot;
    reg clk=0;
    always #(500.0/74.25) clk=~clk;
    reg [31:0] addr=0,data=0;
    reg wr=0,rd=0;
    reg [31:0] keys=32'h10000000;
    wire [31:0] q;
    wire [12:0] a;
    wire [1:0] ba,dqm;
    tri [15:0] dq,sq;
    wire dc,cke,ras,cas,we,so,sw,su,sl;
    wire [16:0] sa;
    core_top dut(.clk_74a(clk),.clk_74b(clk),
        .bridge_addr(addr),.bridge_wr_data(data),.bridge_wr(wr),
        .bridge_rd(rd),.bridge_rd_data(q),
        .cont1_key(keys),.cont1_joy(32'h80808080),
        .dram_a(a),.dram_ba(ba),.dram_dq(dq),.dram_dqm(dqm),
        .dram_clk(dc),.dram_cke(cke),.dram_ras_n(ras),.dram_cas_n(cas),.dram_we_n(we),
        .sram_a(sa),.sram_dq(sq),.sram_oe_n(so),.sram_we_n(sw),.sram_ub_n(su),.sram_lb_n(sl));

    // CL3/BL2 plus empirical byte-address XOR 2 seen on the Pocket.
    // This models the observed failure, NOT a verified chip timing mechanism.
    // tb_sdram separately checks the controller's ideal memory contract.
    reg [15:0] mem[int unsigned];
    reg [12:0] row[0:3];
    reg [2:0] pending=0;
    integer pa[0:2], burst_addr=0,word_addr;
    reg second=0,drive=0;
    integer refresh_count=0;
    bit swap_read_beat=1;
    initial swap_read_beat=!$test$plusargs("IDEAL_READ_ORDER");
    reg [15:0] dout=0;
    assign dq=drive ? dout : 16'hzzzz;
    always @(posedge dc) begin
        drive <= #5.5 (pending[2] || second);
        if(pending[2]) begin
            dout <= #5.5 mem[pa[2] ^ (swap_read_beat ? 1 : 0)];
            burst_addr=pa[2]^1^(swap_read_beat ? 1 : 0); second=1;
        end else if(second) begin dout <= #5.5 mem[burst_addr]; second=0; end
        pending={pending[1:0],1'b0}; pa[2]=pa[1]; pa[1]=pa[0];
        if(cke) case({ras,cas,we})
            3'b001: refresh_count=refresh_count+1;
            3'b011: row[ba]=a;
            3'b100: begin
                word_addr={ba,row[ba],a[9:0]};
                if(!dqm[0]) mem[word_addr][7:0]=dq[7:0];
                if(!dqm[1]) mem[word_addr][15:8]=dq[15:8];
            end
            3'b101: begin pending[0]=1; pa[0]={ba,row[ba],a[9:0]}; end
        endcase
    end
    reg [15:0] wmem[0:32767];
    assign #55 sq = !so && sw ? wmem[sa[14:0]] : 16'hzzzz;
    always @(posedge sw) if(dut.pll_core_locked) begin
        if(!sl) wmem[sa[14:0]][7:0]=sq[7:0];
        if(!su) wmem[sa[14:0]][15:8]=sq[15:8];
    end
    task write_bridge(input [31:0] address,value);
        @(negedge clk); addr=address; data=value;
        repeat(2) @(negedge clk);
        wr=1; @(negedge clk); wr=0;
        repeat(2) @(negedge clk);
    endtask
    task check_read(input [31:0] address,expected);
        @(negedge clk); addr=address; rd=1;
        @(negedge clk); rd=0;
        repeat(2) @(negedge clk);
        if(q !== expected) $fatal(1,"diagnostic read %h expected %h got %h",address,expected,q);
    endtask
    task command(input [15:0] value);
        write_bridge(32'hf8000000,{16'h434d,value});
        repeat(20) @(negedge clk);
        if(dut.icb.host_0 !== 32'h4f4b0000)
            $fatal(1,"APF command %h returned %h",value,dut.icb.host_0);
    endtask
    reg [15:0] rom[0:255];
    reg [31:0] word_le;
    integer i;
    string rom_path;
    byte unsigned image_bytes[];
    integer rom_fd,rom_size,rom_read,retire_count=0,fetch_count=0;
    reg game_mode=0;
    integer game_run_ms=10;
    reg last_trace=0;
    integer frame_count=0;
    always @(posedge dut.clk_sys) if(dut.video_vs) frame_count=frame_count+1;
    task menu_cycle(input integer hold_ns);
        reg [31:0] saved_pc;
        integer saved_frames, saved_retired, saved_refresh;
        force dut.audio_left=16'h1234;
        force dut.audio_right=16'h5678;
        #100000;
        if(dut.audio.pcm !== 32'h12345678) $fatal(1,"audio baseline missing");
        write_bridge(32'hf8000020,1);
        command(16'h00b0);
        keys=32'h10000010; // A held while navigating menu.
        wait(dut.menu_paused === 1);
        repeat(20) @(negedge clk);
        saved_pc=dut.u_virtualboy.dbg_pc_o;
        saved_frames=frame_count; saved_retired=retire_count;
        saved_refresh=refresh_count;
        check_read(32'h20000014,5);
        #100000;
        if(dut.audio.pcm !== 0 || dut.audio.snapshot !== 0) $fatal(1,"menu audio not muted");
        repeat(1000) begin
            @(negedge clk);
            if(dut.audio_dac !== 0) $fatal(1,"menu I2S output not silent");
        end
        #(hold_ns);
        if(dut.u_virtualboy.dbg_pc_o !== saved_pc || retire_count != saved_retired ||
           dut.u_virtualboy.core_ce_w !== 0 || dut.game_buttons !== 0)
            $fatal(1,"game advanced or menu buttons leaked while paused");
        if(hold_ns>=25000000 && frame_count<=saved_frames) $fatal(1,"scanout stopped during menu");
        if(refresh_count<=saved_refresh) $fatal(1,"SDRAM refresh stopped during menu");
        write_bridge(32'hf8000020,0);
        command(16'h00b0);
        repeat(40) @(negedge clk);
        if(dut.menu_paused !== 0 || dut.game_buttons !== 0) $fatal(1,"resume or held-key guard failed");
        keys=32'h10000000;
        repeat(40) @(negedge clk);
        keys=32'h10000010;
        repeat(40) @(negedge clk);
        if(dut.game_buttons == 0) $fatal(1,"buttons did not rearm after release");
        keys=32'h10000000;
        #100000;
        if(dut.audio.pcm !== 32'h12345678) $fatal(1,"audio did not resume");
        release dut.audio_left; release dut.audio_right;
        if(game_mode && retire_count<=saved_retired) $fatal(1,"CPU did not resume");
        $display("INFO: menu pause/resume checked PC=%h frames=%0d",saved_pc,frame_count-saved_frames);
    endtask
    task run_game;
        if($value$plusargs("RUN_MS=%d",game_run_ms)) begin
            if(game_run_ms<1 || game_run_ms>2000) $fatal(1,"invalid RUN_MS");
        end
        rom_fd=$fopen(rom_path,"rb");
        if(!rom_fd) $fatal(1,"cannot open ROM %s",rom_path);
        rom_read=$fseek(rom_fd,0,2); rom_size=$ftell(rom_fd);
        rom_read=$fseek(rom_fd,0,0);
        if(rom_size<16 || rom_size>16777216 || (rom_size&(rom_size-1)))
            $fatal(1,"test requires power-of-two ROM size");
        image_bytes=new[rom_size];
        rom_read=$fread(image_bytes,rom_fd); $fclose(rom_fd);
        if(rom_read!=rom_size) $fatal(1,"short ROM read");
        // Preload the external chip model to avoid simulating a full download.
        // Include the ROM-only loader halfword compensation in the preload.
        // The last word still traverses the bridge/FIFO/controller to finalize
        // the correct mirror mask. This mode does NOT validate full downloads.
        for(i=0;i<rom_size/2;i=i+1)
            mem[i^1]={image_bytes[2*i+1],image_bytes[2*i]};
        #1000;
        command(16'h0010);
        write_bridge(32'hf8000020,0);
        write_bridge(32'hf8000024,rom_size);
        command(16'h0082);
        repeat(100) @(negedge clk);
        write_bridge(rom_size-4,{image_bytes[rom_size-4],image_bytes[rom_size-3],image_bytes[rom_size-2],image_bytes[rom_size-1]});
        command(16'h008f); command(16'h0011);
        wait(dut.core_reset===0);
        $display("GAME: ROM bytes=%0d reset released %t",rom_size,$time);
        repeat(game_run_ms) begin
            #1000000;
            if(($time/1000000)%10==0) $display("GAME: progress retired=%0d PC=%h",retire_count,dut.u_virtualboy.dbg_pc_o);
        end
        $display("GAME: completed %0d ms retired=%0d ROM responses=%0d PC=%h illegal=%b",game_run_ms,retire_count,fetch_count,dut.u_virtualboy.dbg_pc_o,dut.cpu_illegal);
        if($test$plusargs("MENU_TEST")) begin
            menu_cycle(25000000);
            menu_cycle(100000);
            // Close the menu before the VIP drain handshake completes.
            // Deliberately hold readiness low; do not alter CPU execution.
            force dut.u_virtualboy.savestate_vip_drain_ready_w=1'b0;
            write_bridge(32'hf8000020,1);
            command(16'h00b0);
            wait(dut.u_virtualboy.savestate_cpu_ready_w === 1);
            if(dut.menu_paused !== 0) $fatal(1,"pause ignored pending VIP drain");
            write_bridge(32'hf8000020,0);
            command(16'h00b0);
            release dut.u_virtualboy.savestate_vip_drain_ready_w;
            #100000;
            if(dut.u_virtualboy.savestate_cpu_ready_w !== 0 || dut.menu_paused !== 0)
                $fatal(1,"cancelled menu request left CPU paused");
            $display("GAME: menu pause/resume checks passed");
        end
    endtask
    integer expected_addr;
    always @(negedge dut.clk_sys) if(game_mode && !dut.core_reset) begin
        if(dut.ext_mrq && dut.cart_rom_cs && dut.ext_rw && dut.rom_ready) begin
            expected_addr=dut.ext_addr & (rom_size-1);
            if(dut.rom_data !== {image_bytes[expected_addr+1],image_bytes[expected_addr]})
                $fatal(1,"ROM mismatch addr=%h got=%h expected=%h",expected_addr,dut.rom_data,{image_bytes[expected_addr+1],image_bytes[expected_addr]});
            fetch_count=fetch_count+1;
        end
        if(dut.cpu_trace_valid && !last_trace) begin
            retire_count=retire_count+1;
            if(retire_count<=40) $display("TRACE %0d pc=%h insn=%h",retire_count,dut.u_virtualboy.u_cpu.trace_pc_o,dut.u_virtualboy.u_cpu.trace_insn_o);
        end
        last_trace=dut.cpu_trace_valid;
        if(dut.cpu_illegal) $fatal(1,"FIRST ILLEGAL pc=%h instruction=%h retired=%0d",dut.u_virtualboy.u_cpu.exec_pc_q,dut.u_virtualboy.u_cpu.exec_iw_q,retire_count);
    end
    initial begin
        // Quartus power-up value of otherwise uninitialised FSM registers.
        dut.icb.hstate=0; dut.icb.tstate=0; dut.icb.host_cmd_start=0;
        if($value$plusargs("ROM=%s",rom_path)) begin
            game_mode=1;
            // Hardware M10K uses power_up_uninitialized=FALSE. The behavioral
            // RAM model otherwise leaves undefined GPRs as X, which prevents
            // corrupted startup code from following the board's zero-powerup
            // path. This is test-only power-up initialization, not a CPU reset.
            for(i=0;i<32;i=i+1) begin
                dut.u_virtualboy.u_cpu.u_gpr_file.u_image_a.mem_q[i]=0;
                dut.u_virtualboy.u_cpu.u_gpr_file.u_image_b.mem_q[i]=0;
            end
            run_game;
            $finish;
        end
        for(i=0;i<256;i=i+1) rom[i]=16'h6800;
        // Reset vector FFFFFFF0 mirrors to byte 1F0 of this 512-byte ROM.
        rom[248]=16'hbc20; rom[249]=16'h0600;
        rom[250]=16'ha040; rom[251]=16'h0034;
        rom[252]=16'hd041; rom[253]=0;
        #1000;
        // APF transmits the previous read result BEFORE asserting the next
        // read strobe. Changing the address must not change the held result.
        force dut.loader_fault=1'b1;
        @(negedge clk); addr=32'h20000008; rd=1;
        @(negedge clk); rd=0;
        @(negedge clk); addr=32'h20000004;
        #1;
        if(q !== 32'd1) $fatal(1,"bridge response not held until next read: %h",q);
        release dut.loader_fault;
        dut.loader_fault=0;
        command(16'h0010);
        write_bridge(32'hf8000020,0);
        write_bridge(32'hf8000024,512);
        command(16'h0082);
        for(i=0;i<128;i=i+1) begin
            word_le={rom[2*i+1],rom[2*i]};
            write_bridge(i*4,{word_le[7:0],word_le[15:8],word_le[23:16],word_le[31:24]});
            repeat(90) @(negedge clk);
        end
        command(16'h008f);
        command(16'h0011);
        wait(dut.core_reset === 0);
        // Download may queue while SDRAM initializes; check after FIFO drain.
        for(i=0;i<128;i=i+1)
            if(mem[2*i] !== rom[2*i+1] || mem[2*i+1] !== rom[2*i])
                $fatal(1,"ROM loader halfword layout mismatch at word %0d",i);
        $display("INFO: reset released after download and RAM clear at %t",$time);
        wait(dut.u_virtualboy.cpu_halted_o);
        repeat(20) @(negedge clk);
        addr=32'h10000000;
        repeat(5) @(negedge clk);
        rd=1; @(negedge clk); rd=0;
        repeat(2) @(negedge clk);
        if(q[31:24] !== 8'h34) $fatal(1,"top-level reset-vector program failed: save=%h",q);
        if(dut.loader_fault) $fatal(1,"FIFO overflow");
        if(dut.boot_stage !== 4'd10) $fatal(1,"unexpected boot stage %d",dut.boot_stage);
        // ROM-only compensation must not change save import/export ordering.
        write_bridge(32'h10000004,32'h12345678);
        check_read(32'h10000004,32'h12345678);
        check_read(32'h20000010,5);
        check_read(32'h20000014,3);
        menu_cycle(25000000);
        menu_cycle(100000);
        // Host reset while still in the menu must preserve the pause request.
        write_bridge(32'hf8000020,1);
        command(16'h00b0);
        wait(dut.menu_paused === 1);
        command(16'h0010);
        repeat(40) @(negedge clk);
        if(dut.core_reset !== 1) $fatal(1,"host reset not asserted in menu");
        command(16'h0011);
        wait(dut.core_reset === 0);
        wait(dut.menu_paused === 1);
        repeat(20) @(negedge clk); // Pause status crosses back to bridge clock.
        if(dut.game_buttons !== 0) $fatal(1,"reset in menu leaked input");
        check_read(32'h20000014,5);
        write_bridge(32'hf8000020,0);
        command(16'h00b0);
        wait(dut.u_virtualboy.cpu_halted_o);
        repeat(20) @(negedge clk);
        $display("INFO: host reset in menu preserved pause and resumed reset-vector program");
        write_bridge(32'h20000014,0);
        check_read(32'h20000014,3);
        check_read(32'h20000018,0);
        write_bridge(32'h20000018,1);
        check_read(32'h20000018,1);
        repeat(20) @(negedge clk);
        if(dut.output_test_sync !== 2'b11) $fatal(1,"output test CDC failed");
        write_bridge(32'h20000018,0);
        check_read(32'h20000018,0);
        force dut.cpu_illegal_pc=32'h07123456;
        force dut.cpu_illegal_iw=32'hfc001234;
        force dut.cpu_illegal=1'b1;
        repeat(4) @(negedge clk);
        if(!dut.fault_valid || dut.fault_pc!==32'h07123456 || dut.fault_iw!==32'hfc001234)
            $fatal(1,"first fault capture failed");
        force dut.cpu_illegal_pc=32'hffffffff;
        repeat(4) @(negedge clk);
        if(dut.fault_pc!==32'h07123456) $fatal(1,"first fault overwritten");
        release dut.cpu_illegal; release dut.cpu_illegal_pc; release dut.cpu_illegal_iw;
        $display("PASS: Pocket command -> FIFO -> SDRAM -> RAM clear -> reset vector -> CPU SRAM store");
        $finish;
    end
    initial begin
        #150000000;
        if(game_mode) repeat(game_run_ms) #1000000;
        $fatal(1,"top boot timeout reset=%b loaded=%b download=%b clear=%b fault=%b clearaddr=%h PC=%h",
            dut.core_reset,dut.rom_loaded,dut.rom_download,dut.clear_busy,dut.loader_fault,
            dut.clear_addr,dut.u_virtualboy.dbg_pc_o);
    end
endmodule
