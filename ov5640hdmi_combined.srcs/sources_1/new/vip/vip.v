//                      模式0: RGB565中值滤波 (原始画质+去噪)
//                      模式1: Sobel边缘检测
//                      模式2: 灰度中值+二值化
//                      模式3: RGB转灰度 (RGB565→Y灰度→RGB565)
module vip(
    //module clock
    input           clk            ,    // 时钟信号 (cam_pclk)
    input           rst_n          ,    // 复位信号（低有效）
    input     [1:0] mode_sel       ,    // 模式选择: 0~3

    //图像处理前的数据接口
    input           pre_frame_vsync,
    input           pre_frame_href ,
    input           pre_frame_de   ,
    input    [15:0] pre_rgb        ,

    //图像处理后的数据接口
    output          post_frame_vsync,   // 场同步信号
    output          post_frame_href ,   // 行同步信号
    output          post_frame_de   ,   // 数据输入使能
    output   [15:0] post_rgb            // RGB565颜色数据
);

//parameter define
parameter  SOBEL_THRESHOLD = 128; //sobel阈值

//===========================================================
// Mode 0: RGB565 中值滤波 (6拍延迟)
//===========================================================
wire        medfilt_vsync;
wire        medfilt_href;
wire        medfilt_de;
wire [15:0] medfilt_rgb;

vip_rgb565_median_filter u_median_filter_rgb(
    .clk                (clk              ),
    .rst_n              (rst_n            ),
    .pre_frame_vsync    (pre_frame_vsync  ),
    .pre_frame_href     (pre_frame_href   ),
    .pre_frame_de       (pre_frame_de     ),
    .pre_rgb            (pre_rgb          ),
    .post_frame_vsync   (medfilt_vsync    ),
    .post_frame_href    (medfilt_href     ),
    .post_frame_de      (medfilt_de       ),
    .post_rgb           (medfilt_rgb      )
);

//===========================================================s
// Mode 1: Sobel边缘检测 - rgb2ycbcr(3) + sobel(总计~22拍)
//===========================================================
wire        sobel_ycbcr_vsync;
wire        sobel_ycbcr_href;
wire        sobel_ycbcr_de;
wire  [7:0] sobel_img_y;

rgb2ycbcr u_rgb2ycbcr_sobel(
    .clk             (clk               ),
    .rst_n           (rst_n             ),
    .pre_frame_vsync (pre_frame_vsync   ),
    .pre_frame_href  (pre_frame_href    ),
    .pre_frame_de    (pre_frame_de      ),
    .img_red         (pre_rgb[15:11]    ),
    .img_green       (pre_rgb[10:5 ]    ),
    .img_blue        (pre_rgb[ 4:0 ]    ),
    .post_frame_vsync(sobel_ycbcr_vsync ),
    .post_frame_href (sobel_ycbcr_href  ),
    .post_frame_de   (sobel_ycbcr_de    ),
    .img_y           (sobel_img_y       ),
    .img_cb          (),
    .img_cr          ()
);

wire        sobel_vsync;
wire        sobel_href;
wire        sobel_de;
wire        sobel_bit;

vip_sobel_edge_detector
    #(
    .SOBEL_THRESHOLD  (SOBEL_THRESHOLD)
    )
u_vip_sobel_edge_detector(
    .clk              (clk              ),
    .rst_n            (rst_n            ),
    .pre_frame_vsync  (sobel_ycbcr_vsync),
    .pre_frame_href   (sobel_ycbcr_href ),
    .pre_frame_clken  (sobel_ycbcr_de   ),
    .pre_img_y        (sobel_img_y      ),
    .post_frame_vsync (sobel_vsync      ),
    .post_frame_href  (sobel_href       ),
    .post_frame_clken (sobel_de         ),
    .post_img_bit     (sobel_bit        )
);

wire [15:0] sobel_rgb;
assign sobel_rgb = {16{~sobel_bit}};  // 边缘为黑色(0)，背景为白色(全1)

//===========================================================
// Mode 3: RGB转灰度 (ycrcb Y通道)
//===========================================================
wire        gray_ycbcr_vsync;
wire        gray_ycbcr_href;
wire        gray_ycbcr_de;
wire  [7:0] gray_img_y;

rgb2ycbcr u_rgb2ycbcr_gray(
    .clk             (clk               ),
    .rst_n           (rst_n             ),
    .pre_frame_vsync (pre_frame_vsync   ),
    .pre_frame_href  (pre_frame_href    ),
    .pre_frame_de    (pre_frame_de      ),
    .img_red         (pre_rgb[15:11]    ),
    .img_green       (pre_rgb[10:5 ]    ),
    .img_blue        (pre_rgb[ 4:0 ]    ),
    .post_frame_vsync(gray_ycbcr_vsync  ),
    .post_frame_href (gray_ycbcr_href   ),
    .post_frame_de   (gray_ycbcr_de     ),
    .img_y           (gray_img_y        ),
    .img_cb          (),
    .img_cr          ()
);

wire [15:0] gray_rgb;
assign gray_rgb = {gray_img_y[7:3], gray_img_y[7:2], gray_img_y[7:3]};

//===========================================================
// Mode 2: 灰度中值滤波 + 二值化
//===========================================================
wire        bin_ycbcr_vsync;
wire        bin_ycbcr_href;
wire        bin_ycbcr_de;
wire  [7:0] bin_img_y;

rgb2ycbcr u_rgb2ycbcr_bin(
    .clk             (clk               ),
    .rst_n           (rst_n             ),
    .pre_frame_vsync (pre_frame_vsync   ),
    .pre_frame_href  (pre_frame_href    ),
    .pre_frame_de    (pre_frame_de      ),
    .img_red         (pre_rgb[15:11]    ),
    .img_green       (pre_rgb[10:5 ]    ),
    .img_blue        (pre_rgb[ 4:0 ]    ),
    .post_frame_vsync(bin_ycbcr_vsync   ),
    .post_frame_href (bin_ycbcr_href    ),
    .post_frame_de   (bin_ycbcr_de      ),
    .img_y           (bin_img_y         ),
    .img_cb          (),
    .img_cr          ()
);

wire        gray_med_vsync;
wire        gray_med_href;
wire        gray_med_de;
wire  [7:0] gray_med_y;

vip_gray_median_filter u_vip_gray_median_filter(
    .clk              (clk             ),
    .rst_n            (rst_n           ),
    .pre_frame_vsync  (bin_ycbcr_vsync ),
    .pre_frame_href   (bin_ycbcr_href  ),
    .pre_frame_clken  (bin_ycbcr_de    ),
    .pre_img_y        (bin_img_y       ),
    .pos_frame_vsync  (gray_med_vsync  ),
    .pos_frame_href   (gray_med_href   ),
    .pos_frame_clken  (gray_med_de     ),
    .pos_img_y        (gray_med_y      )
);

wire        bin_vsync;
wire        bin_href;
wire        bin_de;
wire        bin_monoc;

binarization u_binarization(
    .clk         (clk           ),
    .rst_n       (rst_n         ),
    .ycbcr_vsync (gray_med_vsync),
    .ycbcr_href  (gray_med_href ),
    .ycbcr_de    (gray_med_de   ),
    .luminance   (gray_med_y    ),
    .post_vsync  (bin_vsync     ),
    .post_href   (bin_href      ),
    .post_de     (bin_de        ),
    .monoc       (bin_monoc     )
);

wire [15:0] bin_rgb;
assign bin_rgb = {16{bin_monoc}};

//===========================================================
// Mode-aware post signals MUX
// 在 vsync 上升沿锁存 mode_sel（帧边界切换）
//===========================================================
reg  [1:0]  mode_sel_r;
wire vsync_posedge;
reg  pre_frame_vsync_d1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pre_frame_vsync_d1 <= 1'b0;
    end else begin
        pre_frame_vsync_d1 <= pre_frame_vsync;
    end
end

assign vsync_posedge = pre_frame_vsync && !pre_frame_vsync_d1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mode_sel_r <= 2'd0;
    end else if (vsync_posedge) begin
        mode_sel_r <= mode_sel;
    end
end

//===========================================================
// Output MUX
//===========================================================
reg         post_frame_vsync_r;
reg         post_frame_href_r;
reg         post_frame_de_r;
reg [15:0]  post_rgb_r;

always @(*) begin
    case (mode_sel_r)
        2'd0: begin  // RGB565中值滤波
            post_frame_vsync_r = medfilt_vsync;
            post_frame_href_r  = medfilt_href;
            post_frame_de_r    = medfilt_de;
            post_rgb_r         = medfilt_rgb;
        end
        2'd1: begin  // Sobel边缘检测
            post_frame_vsync_r = sobel_vsync;
            post_frame_href_r  = sobel_href;
            post_frame_de_r    = sobel_de;
            post_rgb_r         = sobel_rgb;
        end
        2'd2: begin  // 灰度中值+二值化
            post_frame_vsync_r = bin_vsync;
            post_frame_href_r  = bin_href;
            post_frame_de_r    = bin_de;
            post_rgb_r         = bin_rgb;
        end
        2'd3: begin  // RGB转灰度
            post_frame_vsync_r = gray_ycbcr_vsync;
            post_frame_href_r  = gray_ycbcr_href;
            post_frame_de_r    = gray_ycbcr_de;
            post_rgb_r         = gray_rgb;
        end
        default: begin
            post_frame_vsync_r = medfilt_vsync;
            post_frame_href_r  = medfilt_href;
            post_frame_de_r    = medfilt_de;
            post_rgb_r         = medfilt_rgb;
        end
    endcase
end

assign post_frame_vsync = post_frame_vsync_r;
assign post_frame_href  = post_frame_href_r;
assign post_frame_de    = post_frame_de_r;
assign post_rgb         = post_rgb_r;

endmodule