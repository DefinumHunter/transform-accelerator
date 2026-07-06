module pe_input_mux (
    input  logic               clk,
    input  logic               rst_n,
    input  logic               in_vld,   // 1 = данные валидны, 0 = пустой такт
    input  logic signed [31:0] x,
    input  logic signed [31:0] y,
    input  logic signed [31:0] b,
    input  logic               sel,      // 0 = direct (X only), 1 = pre-add (X±Y)
    input  logic               sub,      // 0 = add, 1 = subtract
    
    output logic signed [31:0] a_out,
    output logic signed [31:0] b_out,
    output logic               out_vld   // Результат строго через 2 такта
);

    // --- Cycle 1: Input registers ---
    logic signed [31:0] x_reg, y_reg, b_reg;
    logic               sel_reg, sub_reg;
    logic               vld_pipe1; // Первая стадия конвейера валидности

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            vld_pipe1 <= 1'b0;
            // Данные не сбрасываем ради оптимизации площади
        end else begin
            vld_pipe1 <= in_vld;
            
            // Если на входе валид — пишем данные, если нет — глушим нулями (save power)
            x_reg   <= in_vld ? x   : '0;
            y_reg   <= in_vld ? y   : '0;
            b_reg   <= in_vld ? b   : '0;
            sel_reg <= in_vld ? sel : '0;
            sub_reg <= in_vld ? sub : '0;
        end
    end

    // --- Combinatorial: 33-bit arithmetic for perfect overflow detection ---
    logic signed [32:0] sum_ext;
    logic signed [31:0] saturated;
    logic               overflow;

    // Расширяем до 33 бит для 100% надежного знакового сложения/вычитания
    assign sum_ext = sub_reg ? ($signed({x_reg[31], x_reg}) - $signed({y_reg[31], y_reg}))
                             : ($signed({x_reg[31], x_reg}) + $signed({y_reg[31], y_reg}));

    assign overflow = (sum_ext[32] != sum_ext[31]);

    always_comb begin
        if (overflow) begin
            // Истинный знак результата до усечения сидит в старшем бите sum_ext
            saturated = sum_ext[32] ? 32'sh8000_0000 : 32'sh7FFF_FFFF;
        end else begin
            saturated = sum_ext[31:0];
        end
    end

    // --- Cycle 2: Output registers ---
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
        end else begin
            out_vld <= vld_pipe1; // Протаскиваем валидность на выход
            
            // Записываем результат: если прошлый такт был невалиден, 
            // запишется '0', предотвращая лишнее энергопотребление на выходе
            a_out <= vld_pipe1 ? (sel_reg ? saturated : x_reg) : '0;
            b_out <= vld_pipe1 ? b_reg : '0;
        end
    end

    // --- Elaboration check ---
    initial begin
        assert ($bits(x) == 32) else $fatal(1, "pe_input_mux: x must be 32 bits");
    end

endmodule
