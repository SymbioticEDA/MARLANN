module mlaccel_memory_tb;
	reg         clock;
	reg  [16:0] addr;
	reg         wen;
	reg  [ 7:0] wdata;
	wire [31:0] rdata;

	initial begin
		$dumpfile("memory_tb.vcd");
		$dumpvars(0, mlaccel_memory_tb);

		#5 clock = 0;
		repeat (10000) #5 clock = ~clock;
	end

	mlaccel_memory uut (
		.clock (clock),
		.addr  (addr ),
		.wen   (wen  ),
		.wdata (wdata),
		.rdata (rdata)
	);

	initial begin
		wen <= 1;
		addr <= 0;
		wdata <= 0;

		repeat (1000) begin
			@(posedge clock);
			addr <= addr + 1;
			wdata <= wdata + 1;
		end

		@(posedge clock);
		wen <= 0;
		addr <= 0;

		repeat (1000) begin
			@(posedge clock);
			addr <= addr + 1;
		end
	end
endmodule
