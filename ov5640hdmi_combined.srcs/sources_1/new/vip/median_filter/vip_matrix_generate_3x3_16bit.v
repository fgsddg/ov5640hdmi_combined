module vip_matrix_generate_3x3_16bit(
    input               clk,
    input               rst_n,
    
    // 输入数据接口
    input               pre_frame_vsync,
    input               pre_frame_href,
    input               pre_frame_de,
    input      [15:0]   pre_rgb,
    
    // 输出3×3矩阵
    output reg [15:0]   matrix_p11,    
    output reg [15:0]   matrix_p12,    
    output reg [15:0]   matrix_p13,   
    output reg [15:0]   matrix_p21,    
    output reg [15:0]   matrix_p22,    
    output reg [15:0]   matrix_p23,    
    output reg [15:0]   matrix_p31,    
    output reg [15:0]   matrix_p32,    
    output reg [15:0]   matrix_p33,    
    
    // 延迟同步信号
    output reg          post_frame_vsync,
    output reg          post_frame_href,
    output reg          post_frame_de
);

wire [15:0]  row_n1_data;          // 前一行（N-1）行缓冲输出
wire [15:0]  row_n2_data;          // 前前一行（N-2）行缓冲输出

// 行缓冲输出寄存器（对齐读取时序）
reg  [15:0]  row_n1_data_d0;
reg  [15:0]  row_n2_data_d0;

// 当前行（N）列寄存器：用于3个水平相邻像素
reg  [15:0]  row_n_pixel_d0;       // 当前行 最新像素
reg  [15:0]  row_n_pixel_d1;       // 当前行 前1拍（中列）
reg  [15:0]  row_n_pixel_d2;       // 当前行 前2拍（左列）

// 前一行（N-1）列寄存器
reg  [15:0]  row_n1_pixel_d0;
reg  [15:0]  row_n1_pixel_d1;
reg  [15:0]  row_n1_pixel_d2;

// 前前一行（N-2）列寄存器
reg  [15:0]  row_n2_pixel_d0;
reg  [15:0]  row_n2_pixel_d1;
reg  [15:0]  row_n2_pixel_d2;

// 同步信号延迟链
reg          frame_vsync_d0, frame_vsync_d1, frame_vsync_d2;
reg          frame_href_d0,  frame_href_d1,  frame_href_d2;
reg          frame_de_d0,    frame_de_d1,    frame_de_d2;

wire         matrix_valid_row;      // 行方向有效（已有前2行数据）
reg          matrix_valid_row_reg;
reg          href_history;          // href在过去2行期间一直有效

// 行计数
reg  [10:0]  row_cnt;
reg          rows_filled;           

// 行缓冲
line_shift_ram_16bit #(
    .RAM_DEPTH(1024)
) u_line_shift_ram (
    .clock           (clk            ),
    .clken           (pre_frame_de   ),
    .pre_frame_href  (pre_frame_href ),
    .shiftin         (pre_rgb        ),
    .taps0x          (row_n1_data    ),  // 前一行 N-1
    .taps1x          (row_n2_data    )   // 前前一行 N-2
);

// 列寄存器对齐流水线
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_n1_data_d0  <= 16'd0;
        row_n2_data_d0  <= 16'd0;
        
        row_n_pixel_d0   <= 16'd0;
        row_n_pixel_d1   <= 16'd0;
        row_n_pixel_d2   <= 16'd0;
        
        row_n1_pixel_d0  <= 16'd0;
        row_n1_pixel_d1  <= 16'd0;
        row_n1_pixel_d2  <= 16'd0;
        
        row_n2_pixel_d0  <= 16'd0;
        row_n2_pixel_d1  <= 16'd0;
        row_n2_pixel_d2  <= 16'd0;
    end
    else begin
        // 行缓冲输出先寄存一拍
        row_n1_data_d0 <= row_n1_data;
        row_n2_data_d0 <= row_n2_data;
        
        // 当前行（N）3级列寄存器（最新→d0→d1→d2）
        row_n_pixel_d0 <= pre_rgb;
        row_n_pixel_d1 <= row_n_pixel_d0;
        row_n_pixel_d2 <= row_n_pixel_d1;
        
        // 前一行（N-1）2级列寄存器（行缓冲输出→d0→d1）
        row_n1_pixel_d0 <= row_n1_data_d0;
        row_n1_pixel_d1 <= row_n1_pixel_d0;
        row_n1_pixel_d2 <= row_n1_pixel_d1;
        
        // 前前一行（N-2）2级列寄存器（行缓冲输出→d0→d1）
        row_n2_pixel_d0 <= row_n2_data_d0;
        row_n2_pixel_d1 <= row_n2_pixel_d0;
        row_n2_pixel_d2 <= row_n2_pixel_d1;
    end
end

// 3×3 矩阵输出赋值
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        matrix_p11 <= 16'd0; matrix_p12 <= 16'd0; matrix_p13 <= 16'd0;
        matrix_p21 <= 16'd0; matrix_p22 <= 16'd0; matrix_p23 <= 16'd0;
        matrix_p31 <= 16'd0; matrix_p32 <= 16'd0; matrix_p33 <= 16'd0;
    end
    else begin
        // 第N-2行：最远的行，列寄存器d2是"左"（最早），d0是"右"（最新）
        matrix_p11 <= row_n2_pixel_d2;   // 左上（最老像素）
        matrix_p12 <= row_n2_pixel_d1;   // 中上
        matrix_p13 <= row_n2_pixel_d0;   // 右上（最新像素）
        // 第N-1行
        matrix_p21 <= row_n1_pixel_d2;   // 左中
        matrix_p22 <= row_n1_pixel_d1;   // 中中
        matrix_p23 <= row_n1_pixel_d0;   // 右中
        // 当前行N
        matrix_p31 <= row_n_pixel_d2;    // 左下（最老像素）
        matrix_p32 <= row_n_pixel_d1;    // 中下
        matrix_p33 <= row_n_pixel_d0;    // 右下（最新像素）
    end
end

// 行计数
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_cnt     <= 11'd0;
        rows_filled <= 1'b0;
    end
    else begin
        if (pre_frame_vsync) begin
            // 场同步到来，新一帧开始，重置
            row_cnt     <= 11'd0;
            rows_filled <= 1'b0;
        end
        else if (rows_filled == 1'b0 && pre_frame_href && pre_frame_de) begin
            // 第1行和第2行数据填充期间
            // 在href下降沿（行结束）时计数
            if (href_history && !pre_frame_href) begin
                row_cnt <= row_cnt + 11'd1;
                if (row_cnt >= 11'd2) begin
                    rows_filled <= 1'b1;
                end
            end
        end
        href_history <= pre_frame_href;
    end
end

// 同步信号延迟链
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        {frame_vsync_d2, frame_vsync_d1, frame_vsync_d0} <= 3'b000;
        {frame_href_d2,  frame_href_d1,  frame_href_d0}  <= 3'b000;
        {frame_de_d2,    frame_de_d1,    frame_de_d0}    <= 3'b000;
        
        post_frame_vsync <= 1'b0;
        post_frame_href  <= 1'b0;
        post_frame_de    <= 1'b0;
    end
    else begin
        // 移位寄存器链：3级延迟
        frame_vsync_d0 <= pre_frame_vsync;
        frame_vsync_d1 <= frame_vsync_d0;
        frame_vsync_d2 <= frame_vsync_d1;
        
        frame_href_d0 <= pre_frame_href;
        frame_href_d1 <= frame_href_d0;
        frame_href_d2 <= frame_href_d1;
        
        frame_de_d0 <= pre_frame_de;
        frame_de_d1 <= frame_de_d0;
        frame_de_d2 <= frame_de_d1;
        
        // 输出 = 延迟3拍后的同步信号
        post_frame_vsync <= frame_vsync_d2;
        post_frame_href  <= frame_href_d2;
        post_frame_de    <= frame_de_d2;
    end
end

endmodule