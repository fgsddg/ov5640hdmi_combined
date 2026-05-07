module line_shift_ram_8bit(
    input          clock,   
    input          clken,
    input          pre_frame_href,
    
    input   [7:0]  shiftin,  
    output  [7:0]  taps0x,   
    output  [7:0]  taps1x    
);

//parameter define
parameter  RAM_DEPTH = 1024;            // RAM深度：1024个像素（10位地址）

//reg define
reg  [2:0]  clken_dly;                  // 时钟使能延迟链（3拍）
reg  [9:0]  ram_rd_addr;                // RAM读地址（当前列）
reg  [9:0]  ram_rd_addr_d0;             // 读地址延迟1拍
reg  [9:0]  ram_rd_addr_d1;             // 读地址延迟2拍
reg  [7:0]  shiftin_d0;                 // 输入数据延迟1拍
reg  [7:0]  shiftin_d1;                 // 输入数据延迟2拍
reg  [7:0]  shiftin_d2;                 // 输入数据延迟3拍

reg  [7:0]  ram0 [0:RAM_DEPTH-1];       // 存储前一行（row N-1）图像数据
reg  [7:0]  ram1 [0:RAM_DEPTH-1];       // 存储前前一行（row N-2）图像数据

reg  [7:0]  ram0_rdata;
reg  [7:0]  ram1_rdata;

always@(posedge clock)begin
    if(pre_frame_href)
        if(clken)
            ram_rd_addr <= ram_rd_addr + 10'd1;
        else
            ram_rd_addr <= ram_rd_addr;
    else
        ram_rd_addr <= 10'd0;
end

//时钟使能信号延迟三拍
always@(posedge clock) begin
    clken_dly <= {clken_dly[1:0],clken};
end

//将ram地址延迟二拍
always@(posedge clock) begin
    ram_rd_addr_d0 <= ram_rd_addr;
    ram_rd_addr_d1 <= ram_rd_addr_d0;
end

//输入数据延迟三拍
always@(posedge clock)begin
    shiftin_d0 <= shiftin;
    shiftin_d1 <= shiftin_d0;
    shiftin_d2 <= shiftin_d1;
end

always@(posedge clock) begin
    if(clken_dly[2])
        ram0[ram_rd_addr_d1] <= shiftin_d2;
    ram0_rdata <= ram0[ram_rd_addr];
end

always@(posedge clock) begin
    if(clken_dly[1])
        ram1[ram_rd_addr_d0] <= ram0_rdata;
    ram1_rdata <= ram1[ram_rd_addr];
end

//输出行延迟数据
assign taps0x = ram0_rdata;             // 前一行（row N-1）像素数据
assign taps1x = ram1_rdata;             // 前前一行（row N-2）像素数据

endmodule