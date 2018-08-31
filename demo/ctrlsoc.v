module ctrlsoc (
	// 12 MHz clock
	input clk,

	// RS232
	input  ser_rx,
	output ser_tx,

	// SPI Flash
	output flash_clk,
	output flash_csb,
	inout  flash_io0,
	inout  flash_io1,
	inout  flash_io2,
	inout  flash_io3,

	// LEDs (PMOD 2)
	output led1,
	output led2,
	output led3,
	output led4,
	output led5,

	// mlaccel (PMOD 1A)
	output ml_clk,
	output ml_csb,
	inout  ml_io0,
	inout  ml_io1,
	inout  ml_io2,
	inout  ml_io3,
	input  ml_irq,
	input  ml_err
);
endmodule
