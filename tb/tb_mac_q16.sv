`timescale 1ns/1ps

module tb_mac_q16;
    parameter int PIPELINE_STAGES = 4;

    logic        clk;
    logic        rst_n;
    logic signed [31:0] in_a, in_b;
    logic               in_vld;
    logic               sel;
    logic               busy;
    logic               out_vld;
    logic               out_sel;
    logic signed [31:0] out_res;

    mac_q16 #(
        .PIPELINE_STAGES(PIPELINE_STAGES)
    ) dut (.*);

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_mac_q16);
    end
endmodule
