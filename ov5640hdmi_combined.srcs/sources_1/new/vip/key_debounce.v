//按键消抖模块
module key_debounce
(
    input           clk         ,   // 50MHz 时钟
    input           rst_n       ,   // 复位信号（低有效）
    input           key_in      ,   // 按键输入（低有效）
    output          key_pulse       // 按键按下单周期脉冲（高有效）
);

//parameter define
parameter   DEBOUNCE_CNT = 20'd1_000_000;  // 20ms 消抖计数

//reg define
reg          key_in_sync0;     // 同步寄存器0
reg          key_in_sync1;     // 同步寄存器1
reg [19:0]   cnt;              // 消抖计数器
reg          key_state;        // 按键状态寄存器
reg          key_state_d1;     // 按键状态延迟一拍

//wire define
wire         key_edge;         // 按键边沿检测

// 同步按键输入到时钟域
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_in_sync0 <= 1'b1;
        key_in_sync1 <= 1'b1;
    end else begin
        key_in_sync0 <= key_in;
        key_in_sync1 <= key_in_sync0;
    end
end

// 消抖计数器
reg key_cnt_clr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 20'd0;
    end else if (key_cnt_clr) begin
        cnt <= 20'd0;
    end else if (cnt < DEBOUNCE_CNT) begin
        cnt <= cnt + 1'b1;
    end
end

// 消抖状态机
reg [1:0] debounce_state;
parameter IDLE    = 2'd0;
parameter COUNT   = 2'd1;
parameter STABLE  = 2'd2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        debounce_state <= IDLE;
        key_cnt_clr <= 1;
        key_state <= 1'b1;
    end else begin
        case (debounce_state)
            IDLE: begin
                key_cnt_clr <= 1;
                if (key_in_sync1 == 1'b0) begin
                    debounce_state <= COUNT;
                    key_cnt_clr <= 0;
                end
            end
            COUNT: begin
                key_cnt_clr <= 0;
                if (cnt == DEBOUNCE_CNT - 1) begin
                    if (key_in_sync1 == 1'b1) begin
                        // 抖动，返回IDLE
                        debounce_state <= IDLE;
                        key_cnt_clr <= 1;
                    end else begin
                        // 稳定低电平，确认按下
                        key_state <= 1'b0;
                        debounce_state <= STABLE;
                    end
                end else if (key_in_sync1 == 1'b1) begin
                    // 在计数过程中出现高电平，判定为抖动
                    debounce_state <= IDLE;
                    key_cnt_clr <= 1;
                end
            end
            STABLE: begin
                if (key_in_sync1 == 1'b1) begin
                    key_state <= 1'b1;
                    debounce_state <= IDLE;
                    key_cnt_clr <= 1;
                end
            end
            default: debounce_state <= IDLE;
        endcase
    end
end

// 边沿检测: 按键释放时产生脉冲
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_state_d1 <= 1'b1;
    end else begin
        key_state_d1 <= key_state;
    end
end

// 按键释放时产生一个时钟周期的高脉冲
assign key_pulse = key_state_d1 && !key_state;

endmodule