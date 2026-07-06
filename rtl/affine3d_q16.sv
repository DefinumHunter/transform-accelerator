module affine3d_q16 #(
    parameter int PIPELINE_STAGES = 3
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        in_vld,

    // Вектор входа
    input  logic signed [31:0] vec_x,
    input  logic signed [31:0] vec_y,
    input  logic signed [31:0] vec_z,

    // Строка 0: X_out = r00*X + r01*Y + r02*Z + tx
    input  logic signed [31:0] r00, r01, r02, tx,

    // Строка 1: Y_out = r10*X + r11*Y + r12*Z + ty
    input  logic signed [31:0] r10, r11, r12, ty,

    // Строка 2: Z_out = r20*X + r21*Y + r22*Z + tz
    input  logic signed [31:0] r20, r21, r22, tz,

    output logic        out_vld,
    output logic        busy,
    output logic signed [31:0] x_out,
    output logic signed [31:0] y_out,
    output logic signed [31:0] z_out
);

    // --- три независимых потока ---

    logic x_busy, y_busy, z_busy;
    logic x_vld,  y_vld,  z_vld;

    // Но подождите - MAC считает A*B + C, один multiply за раз.
    // Нам нужно r00*X + r01*Y + r02*Z + tx — это три умножения.
    // Значит нам нужны три MAC на каждую координату, итого 9 MAC.

    // X_out
    logic signed [31:0] mac_x0_res, mac_x1_res, mac_x2_res;
    logic x0_vld, x1_vld, x2_vld;

    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_x0 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r00), .in_b(vec_x), .in_c(32'sh0000_0000),
        .busy(x_busy), .out_vld(x0_vld), .out_res(mac_x0_res)
    );
    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_x1 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r01), .in_b(vec_y), .in_c(32'sh0000_0000),
        .busy(), .out_vld(x1_vld), .out_res(mac_x1_res)
    );
    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_x2 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r02), .in_b(vec_z), .in_c(tx),
        .busy(), .out_vld(x2_vld), .out_res(mac_x2_res)
    );

    // Y_out
    logic signed [31:0] mac_y0_res, mac_y1_res, mac_y2_res;
    logic y0_vld, y1_vld, y2_vld;

    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_y0 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r10), .in_b(vec_x), .in_c(32'sh0000_0000),
        .busy(y_busy), .out_vld(y0_vld), .out_res(mac_y0_res)
    );
    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_y1 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r11), .in_b(vec_y), .in_c(32'sh0000_0000),
        .busy(), .out_vld(y1_vld), .out_res(mac_y1_res)
    );
    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_y2 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r12), .in_b(vec_z), .in_c(ty),
        .busy(), .out_vld(y2_vld), .out_res(mac_y2_res)
    );

    // Z_out
    logic signed [31:0] mac_z0_res, mac_z1_res, mac_z2_res;
    logic z0_vld, z1_vld, z2_vld;

    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_z0 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r20), .in_b(vec_x), .in_c(32'sh0000_0000),
        .busy(z_busy), .out_vld(z0_vld), .out_res(mac_z0_res)
    );
    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_z1 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r21), .in_b(vec_y), .in_c(32'sh0000_0000),
        .busy(), .out_vld(z1_vld), .out_res(mac_z1_res)
    );
    mac_q16 #(.PIPELINE_STAGES(PIPELINE_STAGES)) mac_z2 (
        .clk(clk), .rst_n(rst_n), .in_vld(in_vld),
        .in_a(r22), .in_b(vec_z), .in_c(tz),
        .busy(), .out_vld(z2_vld), .out_res(mac_z2_res)
    );

    // --- финальное сложение после пайплайна ---
    // Все три vld приходят одновременно, так как PIPELINE_STAGES одинаков
    assign out_vld = x0_vld; // все синхронны
    assign busy    = x_busy;

    assign x_out = mac_x0_res + mac_x1_res + mac_x2_res;
    assign y_out = mac_y0_res + mac_y1_res + mac_y2_res;
    assign z_out = mac_z0_res + mac_z1_res + mac_z2_res;

endmodule