`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.04.2026 03:32:07
// Design Name: 
// Module Name: mac_q16_sva_checker
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mac_q16_sva_checker #(
    parameter int PIPELINE_STAGES = 3
) (
    input logic clk,
    input logic rst_n,
    input logic signed [31:0] in_a, in_b, in_c,
    input logic signed [31:0] out_res
);
    logic signed [63:0] product;
    logic        [0:0]  round_bit;
    logic signed [32:0] extended_sum;
    logic signed [31:0] expected_val;

    assign product      = in_a * in_b;
    assign round_bit    = product[15];
    assign extended_sum = $signed(product[47:16]) + $signed(in_c) 
                          + {{32{1'b0}}, round_bit};

    always_comb begin
        if (extended_sum[32] != extended_sum[31])
            expected_val = extended_sum[32] ? 32'sh8000_0000 
                                            : 32'sh7FFF_FFFF;
        else
            expected_val = extended_sum[31:0];
    end

    property p_mac_latency;
        logic signed [31:0] target;
        (1, target = expected_val) |-> ##PIPELINE_STAGES (out_res === target);
    endproperty

    assert_mac_timing: assert property (
        @(posedge clk) disable iff (!rst_n) p_mac_latency)
        else $error("SVA FAIL | exp=0x%08h got=0x%08h after %0d stages",
                    expected_val, out_res, PIPELINE_STAGES);

endmodule





// // Valid in → busy goes high
// property p_busy_on_valid;
//     @(posedge clk) disable iff (!rst_n)
//     in_vld |-> busy;
// endproperty

// // Valid in → output appears after exactly PIPELINE_STAGES cycles
// property p_latency;
//     @(posedge clk) disable iff (!rst_n)
//     in_vld |-> ##PIPELINE_STAGES $stable(out_res)[*1];
// endproperty

// // During reset output is zero
// property p_rst_clears;
//     @(posedge clk)
//     !rst_n |-> (out_res === '0);
// endproperty