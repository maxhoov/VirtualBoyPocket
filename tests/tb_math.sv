`timescale 1ns/1ps
module tb_math;
    reg clk=0, reset=1, ce=0, phi=0, start=0, kill=0, finish=0;
    reg [31:0] lhs=0, rhs=0;
    reg [3:0] kind=12;
    reg [5:0] subop=6;
    always #12.5 clk=~clk;
    always @(negedge clk) begin ce=~ce; phi=~ce; end
    wire [75:0] ir, id;
    wire [78:0] fr, fd;
    reference_integer_engine ri(.clk_i(clk), .reset_i(reset), .clk_en_i(ce), .phi1_i(phi),
        .start_i(start), .kill_i(kill), .finish_i(finish), .lhs_i(lhs), .rhs_i(rhs), .kind_i(kind),
        .start_accept_o(ir[75]), .busy_o(ir[74]), .done_o(ir[73]),
        .step_o(ir[72:67]), .result_hi_o(ir[66:35]), .result_lo_o(ir[34:3]),
        .result_zero_o(ir[2]), .result_sign_o(ir[1]), .result_overflow_o(ir[0]));
    necv810_integer_engine di(.clk_i(clk), .reset_i(reset), .clk_en_i(ce), .phi1_i(phi),
        .start_i(start), .kill_i(kill), .finish_i(finish), .lhs_i(lhs), .rhs_i(rhs), .kind_i(kind),
        .start_accept_o(id[75]), .busy_o(id[74]), .done_o(id[73]),
        .step_o(id[72:67]), .result_hi_o(id[66:35]), .result_lo_o(id[34:3]),
        .result_zero_o(id[2]), .result_sign_o(id[1]), .result_overflow_o(id[0]));
    reference_fp_engine rf(.clk_i(clk), .reset_i(reset), .clk_en_i(ce), .phi1_i(phi),
        .start_i(start), .kill_i(kill), .finish_i(finish), .lhs_i(lhs), .rhs_i(rhs), .subop_i(subop),
        .start_accept_o(fr[78]), .busy_o(fr[77]), .done_o(fr[76]),
        .step_o(fr[75:70]), .result_o(fr[69:38]), .result_we_o(fr[37]),
        .psw_mask_o(fr[36:27]), .psw_data_o(fr[26:17]),
        .exception_valid_o(fr[16]), .exception_code_o(fr[15:0]));
    necv810_fp_engine df(.clk_i(clk), .reset_i(reset), .clk_en_i(ce), .phi1_i(phi),
        .start_i(start), .kill_i(kill), .finish_i(finish), .lhs_i(lhs), .rhs_i(rhs), .subop_i(subop),
        .start_accept_o(fd[78]), .busy_o(fd[77]), .done_o(fd[76]),
        .step_o(fd[75:70]), .result_o(fd[69:38]), .result_we_o(fd[37]),
        .psw_mask_o(fd[36:27]), .psw_data_o(fd[26:17]),
        .exception_valid_o(fd[16]), .exception_code_o(fd[15:0]));
    integer n, guard;
    always @(posedge clk) begin
        #1;
        if(!reset && ir !== id) $fatal(1,"integer cycle mismatch case %0d",n);
        if(!reset && fr !== fd) $fatal(1,"floating cycle mismatch case %0d",n);
    end
    task ce_edge;
        begin
            @(posedge clk);
            while(!ce) @(posedge clk);
            #2;
        end
    endtask
    initial begin
        repeat(4) @(posedge clk);
        #2; reset=0;
        for(n=0;n<1024;n=n+1) begin
            lhs=$urandom; rhs=$urandom;
            case(n%3) 0:kind=12; 1:kind=14; 2:kind=5; endcase
            // Most cases are finite floating multiplies, with random specials too.
            if(n%2) begin lhs[30:23]=8'd127+n%8; rhs[30:23]=8'd123+n%8; end
            start=1; ce_edge(); start=0;
            guard=0;
            while(!(ir[73] && fr[76])) begin
                ce_edge(); guard=guard+1;
                if(guard>200) $fatal(1,"math timeout");
            end
            finish=1; ce_edge(); finish=0;
            ce_edge();
        end
        $display("PASS: integer/FP DSP digit products match upstream cycle-by-cycle across 1024 operand pairs");
        $finish;
    end
    initial begin #20000000; $fatal(1,"timeout"); end
endmodule
