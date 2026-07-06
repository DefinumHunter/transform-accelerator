`timescale 1ns/1ps

module tb_pe_mac_wrapper;
    parameter int PIPELINE_STAGES = 4;

    // =============================================
    // Сигналы для подключения к DUT
    // =============================================
    logic               clk;
    logic               rst_n;
    
    // Входы mux
    logic               in_vld;
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] b;
    logic               sel;
    logic               sub;
    
    // Выходы mac
    logic               out_vld;
    logic signed [31:0] out_res;
    logic               busy;

    pe_mac_wrapper #(
        .PIPELINE_STAGES(PIPELINE_STAGES)
    ) dut (.*);

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_pe_mac_wrapper);
    end

endmodule