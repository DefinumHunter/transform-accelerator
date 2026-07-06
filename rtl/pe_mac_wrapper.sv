`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Wrapper: pe_input_mux -> mac_q16
// Соединение: выход mux напрямую на вход mac
// Задержка: mux (2 такта) + mac (PIPELINE_STAGES тактов)
//////////////////////////////////////////////////////////////////////////////////

module pe_mac_wrapper #(
    parameter int PIPELINE_STAGES = 4
) (
    // ===== Внешние входы =====
    input  logic               clk,
    input  logic               rst_n,
    
    // Входы для mux
    input  logic               in_vld,
    input  logic signed [31:0] x,
    input  logic signed [31:0] y,
    input  logic signed [31:0] b,
    input  logic               sel,
    input  logic               sub,
    
    // ===== Внешние выходы =====
    output logic               out_vld,
    output logic signed [31:0] out_res,
    output logic               busy
);

    // =============================================
    // Внутренние провода для соединения
    // =============================================
    logic               mux_out_vld;
    logic signed [31:0] mux_a_out;
    logic signed [31:0] mux_b_out;

    // =============================================
    // Instance: pe_input_mux
    // =============================================
    pe_input_mux u_mux (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_vld (in_vld),
        .x      (x),
        .y      (y),
        .b      (b),
        .sel    (sel),
        .sub    (sub),
        .a_out  (mux_a_out),
        .b_out  (mux_b_out),
        .out_vld(mux_out_vld)
    );

    // =============================================
    // Instance: mac_q16
    // =============================================
    mac_q16 #(
        .PIPELINE_STAGES(PIPELINE_STAGES)
    ) u_mac (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_vld (mux_out_vld),
        .in_a   (mux_a_out),
        .in_b   (mux_b_out),
        .out_vld(out_vld),
        .out_res(out_res),
        .busy   (busy)
    );

endmodule