// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module SQRT (
	radical,
	q,
	remainder);

	input  [20:0]  radical;
	output  [10:0]  q;
	output  [11:0]  remainder;

	altsqrt SQRT_SQRT (
		.clk (1'b0),
		.aclr (1'b0),
		.ena (1'b1),
		.radical (radical),
		.q (q),
		.remainder (remainder));
	defparam
		SQRT_SQRT.pipeline = 0,
		SQRT_SQRT.q_port_width = 11,
		SQRT_SQRT.r_port_width = 12,
		SQRT_SQRT.width = 21;
endmodule
