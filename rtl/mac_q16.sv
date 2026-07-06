`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.04.2026 23:44:18
// Design Name: 
// Module Name: mac
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

module mac_q16 #(
    parameter int PIPELINE_STAGES = 4
) (
    input  logic               clk,
    input  logic               rst_n,
    input  logic               in_vld,
    input  logic signed [31:0] in_a,
    input  logic signed [31:0] in_b,
    output logic               out_vld,
    output logic signed [31:0] out_res,
    output logic               busy
);

    // =============================================
    // Комбинаторное умножение
    // =============================================
    logic signed [63:0] mult_comb;
    assign mult_comb = in_a * in_b;

    // =============================================
    // Pipeline регистры
    // =============================================
    logic signed [63:0] pipe [0:PIPELINE_STAGES-1];
    logic               vld_pipe [0:PIPELINE_STAGES-1];

    // =============================================
    // Основной конвейер (без async reset в always_ff)
    // =============================================
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < PIPELINE_STAGES; i++) begin
                pipe[i]     <= '0;
                vld_pipe[i] <= 1'b0;
            end
        end else begin
            // Stage 0
            vld_pipe[0] <= in_vld;
            pipe[0]     <= in_vld ? mult_comb : '0;

            // Остальные стадии — сдвиг
            for (int i = 1; i < PIPELINE_STAGES; i++) begin
                vld_pipe[i] <= vld_pipe[i-1];
                pipe[i]     <= pipe[i-1];
            end
        end
    end

    // =============================================
    // Насыщение и округление — только в последней стадии
    // =============================================
    logic signed [31:0] result_after_round;
    logic signed [31:0] saturated_val;
    //logic               round_bit;
    logic               overflow;
    logic signed [32:0] round_ext;

    // =============================================
    // Round to Nearest Even (Banker's Rounding)
    // =============================================
    logic        guard;   // бит 0.5
    logic        round;   // итоговое решение: округлять вверх или нет
    logic        lsb;     // младший бит результата (для even rounding)
    logic        sticky;  // есть ли хоть один '1' в младших битах

    assign guard  = pipe[PIPELINE_STAGES-1][15];
    assign lsb    = pipe[PIPELINE_STAGES-1][16];
    assign sticky = |pipe[PIPELINE_STAGES-1][14:0];   // OR всех битов ниже

    // Round to Nearest Even логика
    assign round = guard & (sticky | lsb);

    //assign round_ext = $signed(pipe[PIPELINE_STAGES-1][47:16]) + round;



        // 1. Корректное сложение: расширяем round нулем, чтобы он остался ПОЛОЖИТЕЛЬНОЙ единицей (+1)
    assign round_ext = $signed(pipe[PIPELINE_STAGES-1][47:16]) + $signed({1'b0, round});

    assign result_after_round = round_ext[31:0];

    // 2. Честная проверка переполнения
    // Результат после окружения (round_ext) должен полностью помещаться в 32-битное знаковое число.
    // Если 32-й бит (знак round_ext) не равен 31-му биту, значит, произошел выход за границы знакового диапазона.
    // Также проверяем исходные старшие биты до округления (с 47 по 63 должны дублировать 47-й бит)
    assign overflow = (pipe[PIPELINE_STAGES-1][63:47] != {17{pipe[PIPELINE_STAGES-1][47]}}) || 
                      (round_ext[32] != round_ext[31]);


    wire sign_bit = pipe[PIPELINE_STAGES-1][63];
    // 3. Насыщение на основе знака исходного числа в конвейере
    always_comb begin
        if (overflow) begin
            //saturated_val = pipe[PIPELINE_STAGES-1][63] ? 32'sh8000_0000 : 32'sh7FFF_FFFF;
            saturated_val = sign_bit ? 32'sh8000_0000 : 32'sh7FFF_FFFF;
        end else begin
            saturated_val = result_after_round;
        end
    end


    // =============================================
    // Выходы
    // =============================================
    assign out_vld = vld_pipe[PIPELINE_STAGES-1];
    assign out_res = saturated_val;
    // assign busy    = in_vld || (|vld_pipe);   // или можно точнее: vld_pipe[0] || ...
    //assign busy = in_vld || vld_pipe.or();
    always_comb begin
    busy = in_vld;
        for (int i = 0; i < $size(vld_pipe); i++) begin
            busy = busy || vld_pipe[i];
        end
    end


endmodule




































// v0.7
    //assign round_bit = pipe[PIPELINE_STAGES-1][15];

    //assign round_ext = $signed(pipe[PIPELINE_STAGES-1][63:15]) + round_bit;


    // // Округление
    // assign result_after_round = round_ext[31:0];

    // // Проверка переполнения
    // assign overflow = (pipe[PIPELINE_STAGES-1][63:47] != {17{pipe[PIPELINE_STAGES-1][48]}}) || 
    //                   (round_ext[32] != round_ext[31]);

    // // Насыщение
    // always_comb begin
    //     if (overflow) begin
    //         saturated_val = pipe[PIPELINE_STAGES-1][63] ? 
    //                         32'sh8000_0000 :   // минус максимум
    //                         32'sh7FFF_FFFF;    // плюс максимум
    //     end else begin
    //         saturated_val = result_after_round;
    //     end
    // end





// v0.6
// module mac_q16 #(
//     parameter int PIPELINE_STAGES = 3
// ) (
//     input  logic             clk,
//     input  logic             rst_n,
//     input  logic signed [31:0] in_a,
//     input  logic signed [31:0] in_b,
//     output logic signed [31:0] out_res
// );

//     logic signed [63:0] pipe [0:PIPELINE_STAGES-1];

//     always_ff @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             for (int i = 0; i < PIPELINE_STAGES; i++)
//                 pipe[i] <= '0;
//         end else begin
//             pipe[0] <= in_a * in_b;
//             for (int i = 1; i < PIPELINE_STAGES; i++)
//                 pipe[i] <= pipe[i-1];
//         end
//     end

//     assign out_res = pipe[PIPELINE_STAGES-1][47:16];

// endmodule



// v0.5
// module mac_q16 #(
//     parameter int PIPELINE_STAGES = 1 
// ) (
//     input  logic             clk,
//     input  logic             rst_n,
//     input  logic             in_vld,
//     input  logic signed [31:0] in_a,
//     input  logic signed [31:0] in_b,
//     input  logic signed [31:0] in_c,
//     output logic               busy,     // Тот самый сигнал "я работаю"
//     output logic               out_vld,
//     output logic signed [31:0] out_res
// );
//     // 1. Умножение и сумма в одном промежуточном сигнале
//     logic signed [32:0] extended_sum; // 33 бита, чтобы увидеть выход за край
//     logic signed [31:0] saturated_val;
//     logic signed [31:0] first_stage_val;
//     logic signed [63:0] product;
    
//     logic round_bit;

//     logic [$clog2(PIPELINE_STAGES+1)-1:0] shift_cnt;
//     logic pipe_en;
//     logic [PIPELINE_STAGES-1:0] vld_pipe;

    
//     //assign pipe_en = (in_vld || shift_cnt > 0);
//     assign pipe_en = in_vld || (|vld_pipe); 
//     assign busy    = pipe_en; // Сигнал активности



//      // 1. Честное умножение
//     assign product = in_a * in_b;
//     assign round_bit = product[15];

//     // 2. ГЛАВНОЕ: Проверка переполнения МУЛЬТИПЛИКАТОРА
//     // Для знаковых чисел: биты [63:47] должны быть все '0' или все '1'
//     logic mul_ovr;
//     assign mul_ovr = (product[63:47] != {17{product[47]}});

//     // 3. Сумма с расширением (34 бита, чтобы не потерять перенос)
//     logic signed [33:0] full_sum;
//     assign full_sum = $signed(product[47:16]) + $signed(in_c) + $signed({1'b0, round_bit});


    
//     generate
//         if (PIPELINE_STAGES < 1) begin
//             $fatal(1, "PIPELINE_STAGES must be >= 1");
//         end
//     endgenerate
    




//         // 4. Логика насыщения
//     always_comb begin
//         // Если умножение УЖЕ переполнилось ИЛИ сумма вышла за границы 32 бит
//         if (mul_ovr || (full_sum[33] != full_sum[31])) begin
//             // Определяем направление насыщения по знаку результата произведения
//             if (product[63] == 1'b0) 
//                 saturated_val = 32'sh7FFF_FFFF; // Улетели в плюс
//             else 
//                 saturated_val = 32'sh8000_0000; // Улетели в минус
//         end else begin
//             saturated_val = full_sum[31:0];
//         end
//     end




//     // 2. Массив регистров (от 0 до STAGES-1)
//     logic signed [31:0] pipe [0:PIPELINE_STAGES-1];

//     always_ff @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             vld_pipe <= '0;
//             for (int i = 0; i < PIPELINE_STAGES; i++) pipe[i] <= '0;
//         end else begin
//             //vld_pipe <= {vld_pipe[PIPELINE_STAGES-2:0], in_vld};
//             //vld_pipe <= (vld_pipe << 1) | in_vld;
//             vld_pipe[0] <= in_vld;
//             //if (in_vld) begin
//                 pipe[0] <= saturated_val;
//             //end

//             //if (in_vld)
//                 //pipe[0] <= saturated_val;
//             for (int i = 1; i < PIPELINE_STAGES; i++) begin
//                 //if (vld_pipe[i-1]) pipe[i] <= pipe[i-1];
//                 vld_pipe[i] <= vld_pipe[i-1];
//                 pipe[i]     <= pipe[i-1];
//             end
//         end
//     end


//     assign out_res = pipe[PIPELINE_STAGES-1];
//     assign out_vld = vld_pipe[PIPELINE_STAGES-1];





// endmodule











//v 0.4
//vld_pipe <= (vld_pipe << 1) | in_vld;





    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         vld_pipe <= '0;
    //         for (int i = 0; i < PIPELINE_STAGES; i++) pipe[i] <= '0;
    //     end else if (pipe_en) begin // Работаем, только если есть смысл
    //         // Двигаем данные
    //         pipe[0] <= saturated_val;
    //         for (int i = 1; i < PIPELINE_STAGES; i++) pipe[i] <= pipe[i-1];

    //         // Двигаем валидность
    //         vld_pipe <= {vld_pipe[PIPELINE_STAGES-2:0], in_vld};
    //     end
    // end



    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         shift_cnt <= '0;
    //         for (int i = 0; i < PIPELINE_STAGES; i++) pipe[i] <= '0;
    //     end else begin
    //         if (in_vld) begin
    //             // Если пришли новые данные, заряжаем счетчик на полную выкачку
    //             shift_cnt <= PIPELINE_STAGES;
    //         end else if (shift_cnt > 0) begin
    //             // Иначе просто декрементируем
    //             shift_cnt <= shift_cnt - 1'b1;
    //         end

    //         // Двигаем данные, только если конвейер "активен"
    //         if (pipe_en) begin
    //             pipe[0] <= saturated_val;
    //             for (int i = 1; i < PIPELINE_STAGES; i++) begin
    //                 pipe[i] <= pipe[i-1];
    //             end
    //         end
    //     end
    // end

    // assign out_res = pipe[PIPELINE_STAGES-1];
















// v0.3
////////////////////////////////////////////
// module mac_q16 #(
//     parameter int PIPELINE_STAGES = 1 
// ) (
//     input  logic             clk,
//     input  logic             rst_n,
//     input  logic signed [31:0] in_a,
//     input  logic signed [31:0] in_b,
//     input  logic signed [31:0] in_c,
//     output logic signed [31:0] out_res
// );
//     // 1. Умножение и сумма в одном промежуточном сигнале
//     logic signed [32:0] extended_sum; // 33 бита, чтобы увидеть выход за край
//     logic signed [31:0] saturated_val;
//     logic signed [31:0] first_stage_val;
//     logic signed [63:0] product;
    
//     logic round_bit;



//      // 1. Честное умножение
//     assign product = in_a * in_b;
//     assign round_bit = product[15];

//     // 2. ГЛАВНОЕ: Проверка переполнения МУЛЬТИПЛИКАТОРА
//     // Для знаковых чисел: биты [63:47] должны быть все '0' или все '1'
//     logic mul_ovr;
//     assign mul_ovr = (product[63:47] != {17{product[47]}});

//     // 3. Сумма с расширением (34 бита, чтобы не потерять перенос)
//     logic signed [33:0] full_sum;
//     assign full_sum = $signed(product[47:16]) + $signed(in_c) + $signed({1'b0, round_bit});


    
//     generate
//         if (PIPELINE_STAGES < 1) begin
//             $fatal(1, "PIPELINE_STAGES must be >= 1");
//         end
//     endgenerate
    




//         // 4. Логика насыщения
//     always_comb begin
//         // Если умножение УЖЕ переполнилось ИЛИ сумма вышла за границы 32 бит
//         if (mul_ovr || (full_sum[33] != full_sum[31])) begin
//             // Определяем направление насыщения по знаку результата произведения
//             if (product[63] == 1'b0) 
//                 saturated_val = 32'sh7FFF_FFFF; // Улетели в плюс
//             else 
//                 saturated_val = 32'sh8000_0000; // Улетели в минус
//         end else begin
//             saturated_val = full_sum[31:0];
//         end
//     end


    

//     // 2. Массив регистров (от 0 до STAGES-1)
//     logic signed [31:0] pipe [0:PIPELINE_STAGES-1];

//     always_ff @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             for (int i = 0; i < PIPELINE_STAGES; i++) pipe[i] <= '0;
//         end else begin
//             pipe[0] <= saturated_val;
//             for (int i = 1; i < PIPELINE_STAGES; i++) begin
//                 pipe[i] <= pipe[i-1];
//             end
//         end
//     end

//     assign out_res = pipe[PIPELINE_STAGES-1];
// endmodule

























// v0.2
///////////////////////////////////////////////////////////////














    // logic overflow_mul;
    
    
    // assign product = in_a * in_b;
    // assign round_bit = product[15];
    // assign extended_sum = $signed(product[47:16]) + $signed(in_c) + $signed({1'b0, round_bit});

    // logic signed [33:0] full_sum;
    // assign full_sum = $signed(product[47:16]) + $signed(in_c) + $signed({1'b0, round_bit});

    // assign overflow_mul = (product[63:47] != {17{product[47]}}); 



    // always_comb begin
    //     // Теперь правило двух верхних бит будет работать:
    //     // Если 32-й и 31-й биты разные - было переполнение
    //     if (extended_sum[32] != extended_sum[31]) begin
    //         if (extended_sum[32] == 1'b0) // Пытались стать слишком большим плюсом
    //             saturated_val = 32'sh7FFF_FFFF;
    //         else // Пытались стать слишком маленьким минусом
    //             saturated_val = 32'sh8000_0000;
    //     end else begin
    //         saturated_val = extended_sum[31:0];
    //     end
    // end






    // always_comb begin
    // // Если умножение переполнилось ИЛИ сумма вышла за границы 32 бит
    //     if (overflow_mul || (full_sum[33] != full_sum[31])) begin
    //         if (product[63] == 1'b0 && !overflow_mul && full_sum[33] == 1'b0)
    //              saturated_val = full_sum[31:0]; // Норма
    //         else if (product[63] == 1'b0)
    //              saturated_val = 32'sh7FFF_FFFF; // Положительное насыщение
    //         else
    //              saturated_val = 32'sh8000_0000; // Отрицательное насыщение
    //     end else begin
    //         saturated_val = full_sum[31:0];
    //     end
    // end




