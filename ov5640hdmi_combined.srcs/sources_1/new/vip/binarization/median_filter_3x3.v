module median_filter_3x3(
    input       clk,
    input       rst_n,
    input       median_frame_vsync,
    input       median_frame_href,
    input       median_frame_clken,
   
    input [7:0]  data11, 
    input [7:0]  data12, 
    input [7:0]  data13,
    input [7:0]  data21, 
    input [7:0]  data22, 
    input [7:0]  data23,
    input [7:0]  data31, 
    input [7:0]  data32, 
    input [7:0]  data33,
   
    output [7:0] target_data,
    output       pos_median_vsync,
    output       pos_median_href,
    output       pos_median_clken
);

//reg define
reg [2:0]   median_frame_vsync_r;
reg [2:0]   median_frame_href_r;
reg [2:0]   median_frame_clken_r;
//wire define
wire [7:0] max_data1; 
wire [7:0] mid_data1; 
wire [7:0] min_data1;
wire [7:0] max_data2; 
wire [7:0] mid_data2; 
wire [7:0] min_data2;
wire [7:0] max_data3; 
wire [7:0] mid_data3; 
wire [7:0] min_data3;
wire [7:0] max_min_data; 
wire [7:0] mid_mid_data; 
wire [7:0] min_max_data;

assign pos_median_vsync = median_frame_vsync_r[2];
assign pos_median_href  = median_frame_href_r[2];
assign pos_median_clken = median_frame_clken_r[2];

//Step1 对stor3进行三次例化操作
sort3 #(.WIDTH(8)) u_sort3_1(     //第一行数据排序
    .clk      (clk),
    .rst_n    (rst_n),
    
    .data_a   (data11), 
    .data_b   (data12), 
    .data_c   (data13),
    
    .max      (max_data1),
    .med      (mid_data1),
    .min      (min_data1)
);

sort3 #(.WIDTH(8)) u_sort3_2(      //第二行数据排序
    .clk      (clk),
    .rst_n    (rst_n),
        
    .data_a   (data21), 
    .data_b   (data22), 
    .data_c   (data23),
    
    .max      (max_data2),
    .med      (mid_data2),
    .min      (min_data2)
);

sort3 #(.WIDTH(8)) u_sort3_3(      //第三行数据排序
    .clk      (clk),
    .rst_n    (rst_n),
        
    .data_a   (data31), 
    .data_b   (data32), 
    .data_c   (data33),
    
    .max      (max_data3),
    .med      (mid_data3),
    .min      (min_data3)
);

//Step2 对三行像素取得的排序进行处理
sort3 #(.WIDTH(8)) u_sort3_4(        //取三行最大值的最小值
    .clk      (clk),
    .rst_n    (rst_n),
          
    .data_a   (max_data1), 
    .data_b   (max_data2), 
    .data_c   (max_data3),
    
    .max      (),
    .med      (),
    .min      (max_min_data)
);

sort3 #(.WIDTH(8)) u_sort3_5(        //取三行中值的最小值
    .clk      (clk),
    .rst_n    (rst_n),
          
    .data_a   (mid_data1), 
    .data_b   (mid_data2), 
    .data_c   (mid_data3),
    
    .max      (),
    .med      (mid_mid_data),
    .min      ()
);

sort3 #(.WIDTH(8)) u_sort3_6(        //取三行最小值的最大值
    .clk      (clk),
    .rst_n    (rst_n),
          
    .data_a   (min_data1), 
    .data_b   (min_data2), 
    .data_c   (min_data3),
    
    .max      (min_max_data),
    .med      (),
    .min      ()
);

//step3 将step2 中得到的三个值，再次取中值
sort3 #(.WIDTH(8)) u_sort3_7(
    .clk      (clk),
    .rst_n    (rst_n),
          
    .data_a   (max_min_data), 
    .data_b   (mid_mid_data), 
    .data_c   (min_max_data),
    
    .max      (),
    .med      (target_data),
    .min      ()
);

//延迟三个周期进行同步
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        median_frame_vsync_r <= 3'd0;
        median_frame_href_r  <= 3'd0;
        median_frame_clken_r <= 3'd0;
    end
    else begin
        median_frame_vsync_r <= {median_frame_vsync_r[1:0],median_frame_vsync};
        median_frame_href_r  <= {median_frame_href_r [1:0], median_frame_href};
        median_frame_clken_r <= {median_frame_clken_r[1:0],median_frame_clken};
    end
end

endmodule 