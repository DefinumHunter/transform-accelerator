module pe_output_strapping (
    input  logic             clk,
    input  logic             rst_n,

    input  logic signed [31:0] mac_res,       // result from MAC
    input  logic signed [31:0] neighbor_res,  // output register of left neighbor
    input  logic             sel,             // 0 = bypass, 1 = systolic add

    output logic signed [31:0] out,           // ring-visible output register
    output logic             idle             // high when no data in flight
);

    // --- Cycle 1: input registers ---
    logic signed [31:0] mac_res_reg;
    logic signed [31:0] neighbor_res_reg;
    logic               sel_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_res_reg      <= '0;
            neighbor_res_reg <= '0;
            sel_reg          <= '0;
        end else begin
            mac_res_reg      <= mac_res;
            neighbor_res_reg <= neighbor_res;
            sel_reg          <= sel;
        end
    end

    // --- Combinatorial: adder with saturation ---
    logic signed [32:0] sum;
    logic signed [31:0] saturated;

    assign sum = $signed({mac_res_reg[31], mac_res_reg}) +
                 $signed({neighbor_res_reg[31], neighbor_res_reg});

    always_comb begin
        if (sum[32] != sum[31])
            saturated = sum[32] ? 32'sh8000_0000 : 32'sh7FFF_FFFF;
        else
            saturated = sum[31:0];
    end

    // --- Cycle 2: output register ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out <= '0;
        end else begin
            out <= sel_reg ? saturated : mac_res_reg;
        end
    end

    // --- Idle: high when all internal registers are zero ---
    assign idle = (mac_res_reg == '0) && (neighbor_res_reg == '0) && (out == '0);

endmodule