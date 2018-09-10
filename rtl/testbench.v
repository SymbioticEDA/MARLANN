module testbench;
	reg         clock;

	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);

		#5 clock = 0;
		repeat (10000) #5 clock = ~clock;
	end

	reg  ml_csb;
	reg  ml_clk;

	reg  ml_io0_reg;
	reg  ml_io1_reg;
	reg  ml_io2_reg;
	reg  ml_io3_reg;

	wire ml_io0 = ml_io0_reg;
	wire ml_io1 = ml_io1_reg;
	wire ml_io2 = ml_io2_reg;
	wire ml_io3 = ml_io3_reg;

	wire ml_rdy;
	wire ml_err;

	top uut (
		.clock (clock ),
		.ml_csb(ml_csb),
		.ml_clk(ml_clk),
		.ml_io0(ml_io0),
		.ml_io1(ml_io1),
		.ml_io2(ml_io2),
		.ml_io3(ml_io3),
		.ml_rdy(ml_rdy),
		.ml_err(ml_err)
	);

	reg [7:0] xfer;

	task xfer_start;
		begin
			ml_clk = 1;
			ml_csb = 0;
			#17;
		end
	endtask

	task xfer_send;
		begin
			ml_clk = 0;
			ml_io0_reg = xfer[4];
			ml_io1_reg = xfer[5];
			ml_io2_reg = xfer[6];
			ml_io3_reg = xfer[7];
			#17;
			ml_clk = 1;
			ml_io0_reg = xfer[0];
			ml_io1_reg = xfer[1];
			ml_io2_reg = xfer[2];
			ml_io3_reg = xfer[3];
			#17;
		end
	endtask

	task xfer_recv;
		begin
			ml_clk = 0;
			ml_io0_reg = 1'bz;
			ml_io1_reg = 1'bz;
			ml_io2_reg = 1'bz;
			ml_io3_reg = 1'bz;
			#15;

			xfer[4] = ml_io0;
			xfer[5] = ml_io1;
			xfer[6] = ml_io2;
			xfer[7] = ml_io3;
			#2;

			ml_clk = 1;
			ml_io0_reg = 1'bz;
			ml_io1_reg = 1'bz;
			ml_io2_reg = 1'bz;
			ml_io3_reg = 1'bz;
			#15;

			xfer[0] = ml_io0;
			xfer[1] = ml_io1;
			xfer[2] = ml_io2;
			xfer[3] = ml_io3;
			#2;
		end
	endtask

	task xfer_stop;
		begin
			xfer = 'bx;
			ml_clk = 0;
			#17;

			ml_csb = 1;
			ml_clk = 1;
			ml_io0_reg = 1'bz;
			ml_io1_reg = 1'bz;
			ml_io2_reg = 1'bz;
			ml_io3_reg = 1'bz;
			#17;
		end
	endtask

	integer i;

	initial begin
		xfer_stop;

		for (i = 0; i < 32; i = i+1) begin
			xfer_start;
			xfer = i;
			xfer_send;
			xfer_stop;

			#20;
		end
	end
endmodule
