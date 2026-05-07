//****************************************************************************************//
// File name:           ov5640_hdmi_combined
// Descriptions:        统一图像处理顶层模块 - 支持4种算法按键切换
//                      按键KEY每按一次，模式+1，循环切换：
//                      模式0: RGB565中值滤波
//                      模式1: Sobel边缘检测
//                      模式2: 灰度中值+二值化
//                      模式3: RGB转灰度
//****************************************************************************************//

module ov5640_hdmi_combined(
    input         sys_clk    ,  //系统时钟
    input         sys_rst_n  ,  //系统复位，低电平有效
    input         key        ,  //按键切换模式（低有效）
    //摄像头 
    input         cam_pclk   ,  //CMOS数据像素时钟
    input         cam_vsync  ,  //CMOS场同步信号
    input         cam_href   ,  //CMOS行同步信号
    input  [7:0]  cam_data   ,  //CMOS数据
    output        cam_xclk   ,  //xclk
    output        cam_rst_n  ,  //CMOS复位信号，低电平有效
    output        cam_pwdn   ,  //CMOS电源休眠模式选择信号
    output        cam_scl    ,  //CMOS SCCB_SCL线
    inout         cam_sda    ,  //CMOS SCCB_SDA线
    //SDRAM 
    output        sdram_clk  ,  //SDRAM时钟
    output        sdram_cke  ,  //SDRAM时钟有效
    output        sdram_cs_n ,  //SDRAM片选
    output        sdram_ras_n,  //SDRAM行有效
    output        sdram_cas_n,  //SDRAM列有效
    output        sdram_we_n ,  //SDRAM写有效
    output [1:0]  sdram_ba   ,  //SDRAM Bank地址
    output [12:0] sdram_addr ,  //SDRAM地址
    inout  [15:0] sdram_data ,  //SDRAM数据
    //HDMI接口
    output  wire    [23:0]  hdmi_data,
    output  wire            hdmi_clk,
    output  wire            hdmi_de,
    output  wire            hdmi_hs,
    output  wire            hdmi_vs,
    inout   wire            hdmi_scl,
    inout   wire            hdmi_sda
    );

//parameter define
parameter V_CMOS_DISP   = 11'd768       ;//CMOS分辨率--行
parameter H_CMOS_DISP   = 11'd1024      ;//CMOS分辨率--列
parameter TOTAL_H_PIXEL = H_CMOS_DISP + 12'd1216;//CMOS分辨率--行
parameter TOTAL_V_PIXEL = V_CMOS_DISP + 12'd504 ;
parameter Y_ADDR_END    = 1947;
parameter Y_ADDR_ST     = 4;

//wire define
wire        clk_100m       ;  //100MHz时钟,SDRAM操作时钟
wire        clk_100m_shift ;  //100MHz时钟,SDRAM相位偏移时钟
wire        clk_50m        ;
wire        video_clk      ;    
wire        locked         ;
wire        rst_n          ;
wire        sys_init_done  ;  //系统初始化完成(SDRAM初始化+摄像头初始化)
wire        cam_init_done  ;  //摄像头初始化完成

wire        wr_en          ;  //sdram_ctrl模块写使能
wire [15:0] wr_data        ;  //sdram_ctrl模块写数据
wire        rd_en          ;  //sdram_ctrl模块读使能
wire [15:0] rd_data        ;  //sdram_ctrl模块读数据
wire        sdram_init_done;  //SDRAM初始化完成

wire        post_frame_de      ;  //处理后的数据使能  
wire [15:0] post_rgb           ;  //处理后的数据 	

//===========================================================
// 模式切换控制
//===========================================================
wire        key_pulse;
reg  [1:0]  mode_sel;       // 当前模式 0~3

// 按键消抖 (使用 clk_50m 时钟域)
key_debounce u_key_debounce(
    .clk        (clk_50m    ),
    .rst_n      (rst_n      ),
    .key_in     (key        ),
    .key_pulse  (key_pulse  )
);

// 模式计数器：每按一次键，模式+1，0~3循环
always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        mode_sel <= 2'd0;
    end else if (key_pulse) begin
        if (mode_sel == 2'd3)
            mode_sel <= 2'd0;
        else
            mode_sel <= mode_sel + 1'b1;
    end
end

//*****************************************************
//**                    main code
//*****************************************************

assign  rst_n = sys_rst_n & locked;

reg sdram_init_done_sync1;
reg sdram_init_done_sync2;

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        sdram_init_done_sync1 <= 1'b0;
        sdram_init_done_sync2 <= 1'b0;
    end
    else begin
        sdram_init_done_sync1 <= sdram_init_done;
        sdram_init_done_sync2 <= sdram_init_done_sync1;
    end
end

// 系统初始化完成：SDRAM和摄像头都初始化完成（均已在clk_50m域）
assign sys_init_done = sdram_init_done_sync2 & cam_init_done;

assign  hdmi_clk = video_clk;

//锁相环
pll_clk u_pll_clk(
    .areset      (~sys_rst_n    ),
    .inclk0      (sys_clk       ),
    .c0          (clk_100m      ),
    .c1          (clk_100m_shift),
    .c2          (clk_50m       ),
    .c3          (cam_xclk      ),
    .locked      (locked        )
    );

pll_hdmi pll_hdmi_inst (
    .areset      (~sys_rst_n    ),
    .inclk0      (sys_clk       ),
    .c0          (video_clk     ),
    );

wire  cmos_frame_vsync;
wire  cmos_frame_href;
	
//OV5640摄像头驱动
ov5640_dri u_ov5640_dri(
    .clk                (clk_50m      ),
    .rst_n              (rst_n        ),

    .cam_pclk           (cam_pclk        ),
    .cam_vsync          (cam_vsync       ),
    .cam_href           (cam_href        ),
    .cam_data           (cam_data        ),
    .cam_rst_n          (cam_rst_n       ),
    .cam_pwdn           (cam_pwdn        ),
    .cam_scl            (cam_scl         ),
    .cam_sda            (cam_sda         ),
   
    .capture_start      (sys_init_done   ),
    .cam_init_done      (cam_init_done   ),
    .cmos_h_pixel       (H_CMOS_DISP     ),
    .cmos_v_pixel       (V_CMOS_DISP     ),
    .total_h_pixel      (TOTAL_H_PIXEL   ),
    .total_v_pixel      (TOTAL_V_PIXEL   ),
    .y_addr_st          (Y_ADDR_ST       ),
    .y_addr_end         (Y_ADDR_END      ),
    .cmos_frame_vsync   (cmos_frame_vsync),
    .cmos_frame_href    (cmos_frame_href ),
    .cmos_frame_valid   (wr_en           ),
    .cmos_frame_data    (wr_data         )
    );

//统一图像处理模块（支持4种算法按键切换）
vip u_vip(
    //module clock
    .clk                (cam_pclk       ),// 时钟信号
    .rst_n              (rst_n          ),// 复位信号（低有效）
    .mode_sel           (mode_sel       ),// 模式选择 0~3
    //图像处理前的数据接口
    .pre_frame_vsync    (cmos_frame_vsync),
    .pre_frame_href     (cmos_frame_href),
    .pre_frame_de       (wr_en          ),
    .pre_rgb            (wr_data        ),
    //图像处理后的数据接口
    .post_frame_vsync   (               ),// 场同步信号
    .post_frame_href    (               ),// 行同步信号
    .post_frame_de      (post_frame_de  ),// 数据输入使能
    .post_rgb           (post_rgb       ) // RGB565颜色数据

);   

//SDRAM控制器顶层模块,封装成FIFO接口
//SDRAM控制器地址组成:{bank_addr[1:0],row_addr[12:0],col_addr[8:0]}
sdram_top u_sdram_top(
    .ref_clk      (clk_100m                 ),//SDRAM控制器参考时钟
    .out_clk      (clk_100m_shift           ),//用于输出的相位偏移时钟
    .rst_n        (rst_n                    ),//系统复位

    //用户写端口
    .wr_clk       (cam_pclk                 ),//写端口FIFO:写时钟
    .wr_en        (post_frame_de		    ),//写端口FIFO:写使能
    .wr_data      (post_rgb                 ),//写端口FIFO:写数据
    .wr_min_addr  (24'd0                    ),//写SDRAM的起始地址
    .wr_max_addr  (V_CMOS_DISP*H_CMOS_DISP-1),//写SDRAM的结束地址
    .wr_len       (10'd512                  ),//写SDRAM时的数据突发长度
    .wr_load      (~rst_n                   ),//写端口复位:复位写地址,清空写FIFO

    //用户读端口
    .rd_clk       (video_clk                ),//读端口FIFO:读时钟
    .rd_en        (rd_en                    ),//读端口FIFO:读使能
    .rd_data      (rd_data                  ),//读端口FIFO:读数据
    .rd_min_addr  (24'd0                    ),//读SDRAM的起始地址
    .rd_max_addr  (V_CMOS_DISP*H_CMOS_DISP-1),//读SDRAM的结束地址
    .rd_len       (10'd512                  ),//从SDRAM中读数据时的突发长度
    .rd_load      (~rst_n                   ),//读端口复位:复位读地址,清空读FIFO

    //用户控制端口
    .sdram_read_valid   (1'b1               ),//SDRAM读使能
    .sdram_pingpang_en  (1'b1               ),//SDRAM乒乓操作使能
    .sdram_init_done    (sdram_init_done    ),//SDRAM初始化完成标志

    //SDRAM 芯片接口
    .sdram_clk    (sdram_clk                ),//SDRAM芯片时钟
    .sdram_cke    (sdram_cke                ),//SDRAM时钟有效
    .sdram_cs_n   (sdram_cs_n               ),//SDRAM片选
    .sdram_ras_n  (sdram_ras_n              ),//SDRAM行有效
    .sdram_cas_n  (sdram_cas_n              ),//SDRAM列有效
    .sdram_we_n   (sdram_we_n               ),//SDRAM写有效
    .sdram_ba     (sdram_ba                 ),//SDRAM Bank地址
    .sdram_addr   (sdram_addr               ),//SDRAM行/列地址
    .sdram_data   (sdram_data               ),//SDRAM数据
    .sdram_dqm    (                         ) //SDRAM数据掩码
    );

video_driver u_video_driver(
    .pixel_clk   (video_clk            ),
    .sys_rst_n   (rst_n                ),// 确保低有效复位

    // RGB接口
    .video_hs    (hdmi_hs              ),
    .video_vs    (hdmi_vs              ),
    .video_de    (hdmi_de              ),
    .video_rgb   (hdmi_data            ),
    .data_req    (rd_en                ),
    .h_disp      (                     ),// 输出端口悬空
    .v_disp      (                     ),// 输出端口悬空
    .pixel_data  (rd_data              ),// 像素数据
    .pixel_xpos  (                     ),
    .pixel_ypos  (                     )
);

sii9134_top #(
    .CLK_FREQ(50_000_000)
) sii9134_top_inst
(
    .sys_clk     (clk_50m                   ),
    .sys_rst_n   (rst_n                     ),
    .hdmi_sda    (hdmi_sda                  ),
    .hdmi_scl    (hdmi_scl                  )
);

endmodule