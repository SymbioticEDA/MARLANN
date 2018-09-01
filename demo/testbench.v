`timescale 1 ns / 1 ps

module testbench;
	localparam clock_period = 1000.0 / 12.0;

	reg clk;
	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);

		#(clock_period / 2);
		clk = 0;

		repeat (10000) begin
			#(clock_period / 2);
			clk = !clk;
		end
	end

	wire ser_rx = 1;
	wire ser_tx;

	wire flash_clk;
	wire flash_csb;
	wire flash_io0;
	wire flash_io1;
	wire flash_io2;
	wire flash_io3;

	wire ledr_n;
	wire ledg_n;

	wire led1;
	wire led2;
	wire led3;
	wire led4;
	wire led5;

	wire btn1 = 0;
	wire btn2 = 0;
	wire btn3 = 0;

	wire ml_clk;
	wire ml_csb;
	wire ml_io0;
	wire ml_io1;
	wire ml_io2;
	wire ml_io3;
	wire ml_irq = 0;
	wire ml_err = 0;

	ctrlsoc uut (
		.clk       (clk      ),

		.ser_rx    (ser_rx   ),
		.ser_tx    (ser_tx   ),

		.flash_clk (flash_clk),
		.flash_csb (flash_csb),
		.flash_io0 (flash_io0),
		.flash_io1 (flash_io1),
		.flash_io2 (flash_io2),
		.flash_io3 (flash_io3),

		.ledr_n    (ledr_n   ),
		.ledg_n    (ledg_n   ),

		.led1      (led1     ),
		.led2      (led2     ),
		.led3      (led3     ),
		.led4      (led4     ),
		.led5      (led5     ),

		.btn1      (btn1     ),
		.btn2      (btn2     ),
		.btn3      (btn3     ),

		.ml_clk    (ml_clk   ),
		.ml_csb    (ml_csb   ),
		.ml_io0    (ml_io0   ),
		.ml_io1    (ml_io1   ),
		.ml_io2    (ml_io2   ),
		.ml_io3    (ml_io3   ),
		.ml_irq    (ml_irq   ),
		.ml_err    (ml_err   )
	);
endmodule
