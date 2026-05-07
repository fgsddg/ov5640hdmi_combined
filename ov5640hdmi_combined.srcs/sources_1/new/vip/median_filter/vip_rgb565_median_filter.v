module vip_rgb565_median_filter(
    input               clk,
    input               rst_n,
    
    // 输入数据接口
    input               pre_frame_vsync,
    input               pre_frame_href,
    input               pre_frame_de,
    input      [15:0]   pre_rgb,            
    
    // 输出数据接口
    output              post_frame_vsync,
    output              post_frame_href,
    output              post_frame_de,
    output     [15:0]   post_rgb            
);

// 3×3 窗口输出（16bit完整像素）
wire [15:0]  matrix_p11, matrix_p12, matrix_p13;
wire [15:0]  matrix_p21, matrix_p22, matrix_p23;
wire [15:0]  matrix_p31, matrix_p32, matrix_p33;

// 窗口生成的同步信号（将作为最终输出）
wire         matrix_vsync, matrix_href, matrix_de;

// RGB分量拆分信号
wire [4:0]   r11, r12, r13, r21, r22, r23, r31, r32, r33;
wire [5:0]   g11, g12, g13, g21, g22, g23, g31, g32, g33;
wire [4:0]   b11, b12, b13, b21, b22, b23, b31, b32, b33;

// 滤波后的中值
wire [4:0]   r_median;
wire [5:0]   g_median;
wire [4:0]   b_median;

// 同步信号延迟链
reg          de_dly1, de_dly2, de_dly3, de_dly4, de_dly5, de_dly6;
reg          href_dly1, href_dly2, href_dly3, href_dly4, href_dly5, href_dly6;
reg          vsync_dly1, vsync_dly2, vsync_dly3, vsync_dly4, vsync_dly5, vsync_dly6;


// 3×3 滑动窗口生成
vip_matrix_generate_3x3_16bit u_matrix_gen (
    .clk                (clk),
    .rst_n              (rst_n),
    .pre_frame_vsync    (pre_frame_vsync),
    .pre_frame_href     (pre_frame_href),
    .pre_frame_de       (pre_frame_de),
    .pre_rgb            (pre_rgb),
    .matrix_p11         (matrix_p11),
    .matrix_p12         (matrix_p12),
    .matrix_p13         (matrix_p13),
    .matrix_p21         (matrix_p21),
    .matrix_p22         (matrix_p22),
    .matrix_p23         (matrix_p23),
    .matrix_p31         (matrix_p31),
    .matrix_p32         (matrix_p32),
    .matrix_p33         (matrix_p33),
    .post_frame_vsync   (matrix_vsync),
    .post_frame_href    (matrix_href),
    .post_frame_de      (matrix_de)
);

// RGB565 拆分（组合逻辑，0延迟）
assign r11 = matrix_p11[15:11];  assign g11 = matrix_p11[10:5];  assign b11 = matrix_p11[4:0];
assign r12 = matrix_p12[15:11];  assign g12 = matrix_p12[10:5];  assign b12 = matrix_p12[4:0];
assign r13 = matrix_p13[15:11];  assign g13 = matrix_p13[10:5];  assign b13 = matrix_p13[4:0];
assign r21 = matrix_p21[15:11];  assign g21 = matrix_p21[10:5];  assign b21 = matrix_p21[4:0];
assign r22 = matrix_p22[15:11];  assign g22 = matrix_p22[10:5];  assign b22 = matrix_p22[4:0];
assign r23 = matrix_p23[15:11];  assign g23 = matrix_p23[10:5];  assign b23 = matrix_p23[4:0];
assign r31 = matrix_p31[15:11];  assign g31 = matrix_p31[10:5];  assign b31 = matrix_p31[4:0];
assign r32 = matrix_p32[15:11];  assign g32 = matrix_p32[10:5];  assign b32 = matrix_p32[4:0];
assign r33 = matrix_p33[15:11];  assign g33 = matrix_p33[10:5];  assign b33 = matrix_p33[4:0];

// R通道 3×3 中值滤波
median_filter_3x3_channel #(.WIDTH(5)) u_r_median (
    .clk     (clk),
    .rst_n   (rst_n),
    .data11  (r11),  .data12  (r12),  .data13  (r13),
    .data21  (r21),  .data22  (r22),  .data23  (r23),
    .data31  (r31),  .data32  (r32),  .data33  (r33),
    .median  (r_median)
);

// G通道 3×3 中值滤波
median_filter_3x3_channel #(.WIDTH(6)) u_g_median (
    .clk     (clk),
    .rst_n   (rst_n),
    .data11  (g11),  .data12  (g12),  .data13  (g13),
    .data21  (g21),  .data22  (g22),  .data23  (g23),
    .data31  (g31),  .data32  (g32),  .data33  (g33),
    .median  (g_median)
);

// B通道 3×3 中值滤波（5bit）
median_filter_3x3_channel #(.WIDTH(5)) u_b_median (
    .clk     (clk),
    .rst_n   (rst_n),
    .data11  (b11),  .data12  (b12),  .data13  (b13),
    .data21  (b21),  .data22  (b22),  .data23  (b23),
    .data31  (b31),  .data32  (b32),  .data33  (b33),
    .median  (b_median)
);

// 同步信号延迟链
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        {de_dly6, de_dly5, de_dly4, de_dly3, de_dly2, de_dly1}   <= 6'b0;
        {href_dly6, href_dly5, href_dly4, href_dly3, href_dly2, href_dly1} <= 6'b0;
        {vsync_dly6, vsync_dly5, vsync_dly4, vsync_dly3, vsync_dly2, vsync_dly1} <= 6'b0;
    end
    else begin
        de_dly1 <= matrix_de;
        de_dly2 <= de_dly1;
        de_dly3 <= de_dly2;
        de_dly4 <= de_dly3;
        de_dly5 <= de_dly4;
        de_dly6 <= de_dly5;
        
        href_dly1 <= matrix_href;
        href_dly2 <= href_dly1;
        href_dly3 <= href_dly2;
        href_dly4 <= href_dly3;
        href_dly5 <= href_dly4;
        href_dly6 <= href_dly5;
        
        vsync_dly1 <= matrix_vsync;
        vsync_dly2 <= vsync_dly1;
        vsync_dly3 <= vsync_dly2;
        vsync_dly4 <= vsync_dly3;
        vsync_dly5 <= vsync_dly4;
        vsync_dly6 <= vsync_dly5;
    end
end

assign post_frame_vsync = vsync_dly6;
assign post_frame_href  = href_dly6;
assign post_frame_de    = de_dly6;
assign post_rgb         = {r_median, g_median, b_median};

endmodule