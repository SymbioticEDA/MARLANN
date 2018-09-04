module top (
	input  clock,

	output led1,
	output led2,
	output led3,
	output led4,
	output led5,

	input  ml_clk,
	input  ml_csb,
	inout  ml_io0,
	inout  ml_io1,
	inout  ml_io2,
	inout  ml_io3,
	output ml_rdy,
	output ml_err
);
	assign led1 = ml_io0;
	assign led2 = ml_io1;
	assign led3 = ml_io2;
	assign led4 = ml_io3;
	assign led5 = ml_csb;

	wire [3:0] ml_io_oe = 0;
	wire [3:0] ml_io_do = 0;
	wire [3:0] ml_io_di;

	SB_IO #(
		.PIN_TYPE(6'b 1010_01),
		.PULLUP(1'b 0)
	) ml_io_buf [3:0] (
		.PACKAGE_PIN({ml_io3, ml_io2, ml_io1, ml_io0}),
		.OUTPUT_ENABLE(ml_io_oe),
		.D_OUT_0(ml_io_do),
		.D_IN_0(ml_io_di)
	);

	assign ml_rdy = 0;
	assign ml_err = 0;
endmodule
