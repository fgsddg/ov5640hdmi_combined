`timescale 1ns/1ns

module  sii9134_cfg
(
    input   wire            sys_clk     ,   //系统时钟,由iic模块传入
    input   wire            sys_rst_n   ,   //系统复位,低有效
    input   wire            cfg_end     ,   //单个寄存器配置完成

    output  reg             cfg_start   ,   //单个寄存器配置触发信号
    output  wire    [23:0]  cfg_data    ,   // ID, REG_ADDR, REG_VAL
    output  reg             cfg_done        //寄存器配置完成
);

////
// Parameter and Internal Signal *//
////

//parameter define
parameter   REG_NUM         =   8'd10      ;   //总共需要配置的寄存器个数
parameter   CNT_WAIT_MAX    =   10'd1023   ;   //寄存器配置等待计数最大值

//wire  define
wire    [23:0]  cfg_data_reg[REG_NUM-1:0]   ;   //寄存器配置数据暂存

//reg   define
reg     [9:0]   cnt_wait    ;   //寄存器配置等待计数器
reg     [7:0]   reg_num     ;   //配置寄存器个数

////
//* Main Code //
////

//cnt_wait:寄存器配置等待计数器
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_wait    <=  10'd0;
    else    if(cnt_wait < CNT_WAIT_MAX)
        cnt_wait    <=  cnt_wait + 1'b1;

//reg_num:配置寄存器个数
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        reg_num <=  8'd0;
    else    if(cfg_end == 1'b1)
        reg_num <=  reg_num + 1'b1;

//cfg_start:单个寄存器配置触发信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cfg_start   <=  1'b0;
    else    if(cnt_wait == (CNT_WAIT_MAX - 1'b1))
        cfg_start   <=  1'b1;
    else    if((cfg_end == 1'b1) && (reg_num < REG_NUM))
        cfg_start   <=  1'b1;
    else
        cfg_start   <=  1'b0;

//cfg_done:寄存器配置完成
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cfg_done    <=  1'b0;
    else    if((reg_num == REG_NUM) && (cfg_end == 1'b1))
        cfg_done    <=  1'b1;

//cfg_data:ID,REG_ADDR,REG_VAL
assign  cfg_data = (cfg_done == 1'b1) ? 24'b0 : cfg_data_reg[reg_num];

//----------------------------------------------------
// 核心改动 从设备地址是手册上的地址右移一位
// cfg_data_reg：寄存器配置数据暂存 {Device_Addr+Write(0)/Read(1), Reg_Addr, Reg_Val}
// assign cfg_data_reg[0] = {8'h76, 8'h08, 8'h37};
// assign cfg_data_reg[0] = {(7'h76 >> 1), 1'b1, 8'h00, 8'h00};     // read Vendor ID 
assign cfg_data_reg[0] = {(7'h76 >> 1), 1'b0, 8'h05, 8'h01};     // reset all sections
assign cfg_data_reg[1] = {(7'h76 >> 1), 1'b0, 8'h05, 8'h00};     // disable reset
assign cfg_data_reg[2] = {(7'h76 >> 1), 1'b0, 8'h08, 8'h37};     // VSYNC and HSYNC config
assign cfg_data_reg[3] = {(7'h76 >> 1), 1'b0, 8'h49, 8'h00};     // 禁用所有处理
assign cfg_data_reg[4] = {(7'h76 >> 1), 1'b0, 8'h4a, 8'h00};     // 标准模式，外部同步
assign cfg_data_reg[5] = {(7'h76 >> 1), 1'b0, 8'h82, 8'h25};     // FFR=, FFB=（分频参数）
assign cfg_data_reg[6] = {(7'h76 >> 1), 1'b0, 8'h83, 8'h1b};     // FPOST=0，其他默认
assign cfg_data_reg[7] = {(7'h76 >> 1), 1'b0, 8'h84, 8'h30};     // 其他PLL参数
assign cfg_data_reg[8] = {(7'h76 >> 1), 1'b0, 8'h85, 8'h02};     // TFR_COUNT=4（TMDS分频）
assign cfg_data_reg[9] = {(7'h7a >> 1), 1'b0, 8'h2f, 8'h00};     // 关闭音频
// // for debug
// assign cfg_data_reg[10] = {(8'h76 << 0) + 1'b1, 8'h85, 8'h01};     // TFR_COUNT=1（TMDS分频）
// assign cfg_data_reg[11] = {(8'h72 << 0) + 1'b0, 8'h85, 8'h01};     // TFR_COUNT=1（TMDS分频）
// assign cfg_data_reg[12] = {(8'h72 << 0) + 1'b1, 8'h85, 8'h01};     // TFR_COUNT=1（TMDS分频）
// 
// assign  cfg_data_reg[0]   = {8'h72, 8'h05, 8'h01};   //reset all sections
// assign  cfg_data_reg[1]   = {8'h72, 8'h05, 8'h00};   //disable reset
// assign  cfg_data_reg[2]   = {8'h72, 8'h08, 8'h37};   //VSYNC and HSYNC config
// assign  cfg_data_reg[3]   = {8'h72, 8'h0c, 8'h00};
// assign  cfg_data_reg[4]   = {8'h72, 8'h0d, 8'h01};
// assign  cfg_data_reg[5]   = {8'h72, 8'h4B, 8'h00};   //Blue
// assign  cfg_data_reg[6]   = {8'h72, 8'h4C, 8'h00};   //Green
// assign  cfg_data_reg[7]   = {8'h72, 8'h4D, 8'hff};   //Red
// assign  cfg_data_reg[8]   = {8'h72, 8'h82, 8'h25};   //FPLL config
// assign  cfg_data_reg[9]   = {8'h72, 8'h83, 8'h19};
// assign  cfg_data_reg[10]  = {8'h72, 8'h84, 8'h31};
// assign  cfg_data_reg[11]  = {8'h72, 8'h85, 8'h01};
// assign  cfg_data_reg[12]  = {8'h72, 8'h32, 8'h04};   //H-Blank
// assign  cfg_data_reg[13]  = {8'h72, 8'h33, 8'h41};   //DE polarity
// assign  cfg_data_reg[14]  = {8'h72, 8'h34, 8'h19};   //V-Blank
// assign  cfg_data_reg[15]  = {8'h72, 8'h36, 8'h00};   //Active width L
// assign  cfg_data_reg[16]  = {8'h72, 8'h37, 8'h05};   //Active width H
// assign  cfg_data_reg[17]  = {8'h72, 8'h38, 8'hD0};   //Active height L
// assign  cfg_data_reg[18]  = {8'h72, 8'h39, 8'h02};   //Active height H
// assign  cfg_data_reg[19]  = {8'h72, 8'h3E, 8'h00};
// assign  cfg_data_reg[20]  = {8'h72, 8'h40, 8'h6e};
// assign  cfg_data_reg[21]  = {8'h72, 8'h41, 8'h00};
// assign  cfg_data_reg[22]  = {8'h72, 8'h44, 8'h29};
// assign  cfg_data_reg[23]  = {8'h72, 8'h45, 8'h00};
// assign  cfg_data_reg[24]  = {8'h72, 8'h46, 8'h05};
// assign  cfg_data_reg[25]  = {8'h72, 8'h47, 8'h06};
// assign  cfg_data_reg[26]  = {8'h72, 8'h48, 8'h30};
// assign  cfg_data_reg[27]  = {8'h72, 8'h49, 8'h00};
// assign  cfg_data_reg[28]  = {8'h72, 8'h4a, 8'h3c};

//切换到设备地址0x7A的配置
// assign  cfg_data_reg[29]  = {8'h7a, 8'h01, 8'h02};
// assign  cfg_data_reg[30]  = {8'h7a, 8'h02, 8'h01};
// assign  cfg_data_reg[31]  = {8'h7a, 8'h03, 8'h00};
// assign  cfg_data_reg[32]  = {8'h7a, 8'h04, 8'h18};
// assign  cfg_data_reg[33]  = {8'h7a, 8'h05, 8'h00};
// assign  cfg_data_reg[34]  = {8'h7a, 8'h14, 8'h11};
// assign  cfg_data_reg[35]  = {8'h7a, 8'h1D, 8'h40};
// assign  cfg_data_reg[36]  = {8'h7a, 8'h21, 8'h02};
// assign  cfg_data_reg[37]  = {8'h7a, 8'h22, 8'h2B};
// assign  cfg_data_reg[38]  = {8'h7a, 8'h2F, 8'h01};
// assign  cfg_data_reg[39]  = {8'h7a, 8'h40, 8'h82};
// assign  cfg_data_reg[40]  = {8'h7a, 8'h41, 8'h02};
// assign  cfg_data_reg[41]  = {8'h7a, 8'h42, 8'h0d};
// assign  cfg_data_reg[42]  = {8'h7a, 8'h43, 8'h59};
// assign  cfg_data_reg[43]  = {8'h7a, 8'h44, 8'h11};
// assign  cfg_data_reg[44]  = {8'h7a, 8'h45, 8'h28};
// assign  cfg_data_reg[45]  = {8'h7a, 8'h46, 8'h00};
// assign  cfg_data_reg[46]  = {8'h7a, 8'h47, 8'h04};
// assign  cfg_data_reg[47]  = {8'h7a, 8'h48, 8'h00};
// assign  cfg_data_reg[48]  = {8'h7a, 8'h49, 8'h00};
// assign  cfg_data_reg[49]  = {8'h7a, 8'h4A, 8'h00};
// assign  cfg_data_reg[50]  = {8'h7a, 8'h4B, 8'hD1};
// assign  cfg_data_reg[51]  = {8'h7a, 8'h4C, 8'h02};
// assign  cfg_data_reg[52]  = {8'h7a, 8'h4D, 8'h00};
// assign  cfg_data_reg[53]  = {8'h7a, 8'h4E, 8'h00};
// assign  cfg_data_reg[54]  = {8'h7a, 8'h4F, 8'h01};
// assign  cfg_data_reg[55]  = {8'h7a, 8'h50, 8'h05};
// assign  cfg_data_reg[56]  = {8'h7a, 8'h51, 8'h00};
// assign  cfg_data_reg[57]  = {8'h7a, 8'h52, 8'h00};
// assign  cfg_data_reg[58]  = {8'h7a, 8'h80, 8'h84};
// assign  cfg_data_reg[59]  = {8'h7a, 8'h81, 8'h01};
// assign  cfg_data_reg[60]  = {8'h7a, 8'h82, 8'h0a};
// assign  cfg_data_reg[61]  = {8'h7a, 8'h83, 8'h70};
// assign  cfg_data_reg[62]  = {8'h7a, 8'h84, 8'h01};
// assign  cfg_data_reg[63]  = {8'h7a, 8'h85, 8'h00};
// assign  cfg_data_reg[64]  = {8'h7a, 8'h86, 8'h00};
// assign  cfg_data_reg[65]  = {8'h7a, 8'h87, 8'h00};
// assign  cfg_data_reg[66]  = {8'h7a, 8'h88, 8'h00};
// assign  cfg_data_reg[67]  = {8'h7a, 8'h89, 8'h00};
// assign  cfg_data_reg[68]  = {8'h7a, 8'h8a, 8'h00};
// assign  cfg_data_reg[69]  = {8'h7a, 8'h8b, 8'h00};
// assign  cfg_data_reg[70]  = {8'h7a, 8'h8c, 8'h00};
// assign  cfg_data_reg[71]  = {8'h7a, 8'h8d, 8'h00};
// assign  cfg_data_reg[72]  = {8'h7a, 8'h3e, 8'h33};

endmodule