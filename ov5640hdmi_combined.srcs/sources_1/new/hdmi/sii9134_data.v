module sii9134_data(

    input               clk,        // 74.25MHz HDMI像素时钟
    input               rst_n,      // 复位信号（低有效）
	input				hsync,
	input				vsync,
	input				rgb_valid,
    
    // 外部RGB输入接口
    input [7:0]         rgb_red,    // 输入红色分量
    input [7:0]         rgb_green,  // 输入绿色分量
    input [7:0]         rgb_blue,   // 输入蓝色分量
    
    // HDMI输出接口
    output              hdmi_clk,
    output              hdmi_de,  // 数据有效
    output              hdmi_hs,    // 行同步
    output              hdmi_vs,    // 场同步
    output [23:0]       hdmi_data,   //
	output				hdmi_rst
);

assign	hdmi_data = {rgb_red, rgb_green, rgb_blue};
assign	hdmi_clk = clk;
assign	hdmi_de = rgb_valid;
assign	hdmi_hs = hsync;
assign	hdmi_vs = vsync;
assign	hdmi_rst = rst_n;


endmodule