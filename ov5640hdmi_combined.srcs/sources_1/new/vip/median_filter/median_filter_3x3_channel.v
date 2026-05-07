module median_filter_3x3_channel #(
    parameter WIDTH = 5   // 输入像素位宽
)(
    input                     clk,
    input                     rst_n,
    
    // 3×3 窗口输入（9个像素值）
    input      [WIDTH-1:0]    data11, data12, data13,
    input      [WIDTH-1:0]    data21, data22, data23,
    input      [WIDTH-1:0]    data31, data32, data33,
    
    // 中值输出
    output     [WIDTH-1:0]    median
);

// 行排序结果
wire [WIDTH-1:0]  row1_max, row1_med, row1_min;
wire [WIDTH-1:0]  row2_max, row2_med, row2_min;
wire [WIDTH-1:0]  row3_max, row3_med, row3_min;

//列排序结果
wire [WIDTH-1:0]  col_max_max, col_max_med, col_max_min;
wire [WIDTH-1:0]  col_med_max, col_med_med, col_med_min;
wire [WIDTH-1:0]  col_min_max, col_min_med, col_min_min;

//最终中值
wire [WIDTH-1:0]  final_max, final_med, final_min;

sort3 #(.WIDTH(WIDTH)) u_sort3_row1 (
    .clk    (clk),
    .rst_n  (rst_n),
    .data_a (data11),
    .data_b (data12),
    .data_c (data13),
    .max    (row1_max),
    .med    (row1_med),
    .min    (row1_min)
);

sort3 #(.WIDTH(WIDTH)) u_sort3_row2 (
    .clk    (clk),
    .rst_n  (rst_n),
    .data_a (data21),
    .data_b (data22),
    .data_c (data23),
    .max    (row2_max),
    .med    (row2_med),
    .min    (row2_min)
);

sort3 #(.WIDTH(WIDTH)) u_sort3_row3 (
    .clk    (clk),
    .rst_n  (rst_n),
    .data_a (data31),
    .data_b (data32),
    .data_c (data33),
    .max    (row3_max),
    .med    (row3_med),
    .min    (row3_min)
);

sort3 #(.WIDTH(WIDTH)) u_sort3_col_max (
    .clk    (clk),
    .rst_n  (rst_n),
    .data_a (row1_max),
    .data_b (row2_max),
    .data_c (row3_max),
    .max    (col_max_max),
    .med    (col_max_med),
    .min    (col_max_min)
);

sort3 #(.WIDTH(WIDTH)) u_sort3_col_med (
    .clk    (clk),
    .rst_n  (rst_n),
    .data_a (row1_med),
    .data_b (row2_med),
    .data_c (row3_med),
    .max    (col_med_max),
    .med    (col_med_med),
    .min    (col_med_min)
);

sort3 #(.WIDTH(WIDTH)) u_sort3_col_min (
    .clk    (clk),
    .rst_n  (rst_n),
    .data_a (row1_min),
    .data_b (row2_min),
    .data_c (row3_min),
    .max    (col_min_max),
    .med    (col_min_med),
    .min    (col_min_min)
);

sort3 #(.WIDTH(WIDTH)) u_sort3_final (
    .clk    (clk),
    .rst_n  (rst_n),
    .data_a (col_max_min),
    .data_b (col_med_med),
    .data_c (col_min_max),
    .max    (final_max),
    .med    (final_med),
    .min    (final_min)
);

// 取中间值
assign median = final_med;

endmodule