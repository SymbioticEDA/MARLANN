/*
 *  Copyright (C) 2018  Clifford Wolf <clifford@symbioticeda.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`timescale 1 ns / 1 ps

module testbench;
	localparam clock_period = 1000.0 / 12.0;
	localparam ser_period = 1000.0 / 0.1152;

	reg clk;
	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);

		#(clock_period / 2);
		clk = 0;

		repeat (900000) begin
			#(clock_period / 2);
			clk = !clk;
		end
	end

	wire ser_tx;
	wire ser_rx = 1;

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

	wire ml_csb;
	wire ml_rdy = 0;
	wire ml_err = 0;

	ctrlsoc ctrl (
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

		.ml_csb    (ml_csb   ),
		.ml_rdy    (ml_rdy   ),
		.ml_err    (ml_err   )
	);

	spiflash flash (
		.flash_clk(flash_clk),
		.flash_csb(flash_csb),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.flash_io2(flash_io2),
		.flash_io3(flash_io3)
	);

	mlaccel_top mlacc (
		.clock   (clk      ),
		.qpi_csb (ml_csb   ),
		.qpi_clk (flash_clk),
		.qpi_io0 (flash_io0),
		.qpi_io1 (flash_io1),
		.qpi_io2 (flash_io2),
		.qpi_io3 (flash_io3),
		.qpi_rdy (ml_rdy   ),
		.qpi_err (ml_err   )
	);

	reg [7:0] ser_byte;
	reg [7:0] ser_temp;

	always begin
		@(negedge ser_tx);
		#(1.5 * ser_period);
		repeat (8) begin
			ser_temp = {ser_tx, ser_temp[7:1]};
			#(ser_period);
		end
		ser_byte = ser_temp;
		$write("%c", ser_byte);
		$fflush;
	end

	initial begin
		$readmemh("ctrlsoc_fw.hex", flash.data);
	end
endmodule
