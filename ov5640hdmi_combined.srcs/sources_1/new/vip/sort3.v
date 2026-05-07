module sort3 #(
    parameter WIDTH = 8
)(
    input                     clk,
    input                     rst_n,
    input      [WIDTH-1:0]    data_a,
    input      [WIDTH-1:0]    data_b,
    input      [WIDTH-1:0]    data_c,
    output reg [WIDTH-1:0]    max,
    output reg [WIDTH-1:0]    med,
    output reg [WIDTH-1:0]    min
);

reg [WIDTH-1:0]  data_a_d1;
reg [WIDTH-1:0]  data_b_d1;
reg [WIDTH-1:0]  data_c_d1;
reg [WIDTH-1:0]  ab_max;
reg [WIDTH-1:0]  ab_min;
reg              a_ge_b;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_a_d1 <= {WIDTH{1'b0}};
        data_b_d1 <= {WIDTH{1'b0}};
        data_c_d1 <= {WIDTH{1'b0}};
        ab_max    <= {WIDTH{1'b0}};
        ab_min    <= {WIDTH{1'b0}};
        a_ge_b    <= 1'b0;
    end
    else begin
        data_a_d1 <= data_a;
        data_b_d1 <= data_b;
        data_c_d1 <= data_c;
        if (data_a >= data_b) begin
            ab_max <= data_a;
            ab_min <= data_b;
            a_ge_b <= 1'b1;
        end
        else begin
            ab_max <= data_b;
            ab_min <= data_a;
            a_ge_b <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        max <= {WIDTH{1'b0}};
        med <= {WIDTH{1'b0}};
        min <= {WIDTH{1'b0}};
    end
    else begin
        if (ab_max <= data_c_d1) begin
            max <= data_c_d1;
        end
        else begin
            max <= ab_max;
        end
        if (ab_min >= data_c_d1) begin
            min <= data_c_d1;
        end
        else begin
            min <= ab_min;
        end
        if (ab_max <= data_c_d1) begin
            if (ab_min >= data_c_d1) begin
                med <= ab_max;
            end
            else begin
                med <= data_c_d1;
            end
        end
        else begin
            if (ab_min >= data_c_d1) begin
                med <= ab_min;
            end
            else begin
                med <= data_c_d1;
            end
        end
    end
end

endmodule