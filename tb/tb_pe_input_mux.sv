`timescale 1ns/1ps

module tb_pe_input_mux;

    parameter int PIPELINE_STAGES = 2;

    // Сигналы управления
    logic             clk;
    logic             rst_n;

    // Входные интерфейсы
    logic             in_vld;
    logic signed [31:0] x;
    logic signed [31:0] y;
    logic signed [31:0] b;

    // Управляющие сигналы
    logic             sel;
    logic             sub;

    // Выходные интерфейсы
    logic signed [31:0] a_out;
    logic signed [31:0] b_out;
    logic             out_vld;

    // Подключение тестируемого модуля (DUT) через интерфейс имён (.*)
    pe_input_mux dut (.*);

    // Генерация VCD-файла для просмотра временных диаграмм в GTKWave
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_pe_input_mux);
    end

endmodule
