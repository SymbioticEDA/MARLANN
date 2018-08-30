module mlaccel_compute_tb;
	reg         clock;

	initial begin
		$dumpfile("compute_tb.vcd");
		$dumpvars(0, mlaccel_compute_tb);

		#5 clock = 0;
		repeat (10000) #5 clock = ~clock;
	end

	reg  [10:0] ctrl_addr;
	reg  [10:0] ctrl_execute;
	wire        ctrl_busy;
	reg  [ 3:0] ctrl_wen_coeff;
	reg         ctrl_wen_opcode;
	reg  [31:0] ctrl_wdata_coeff;
	reg  [31:0] ctrl_wdata_opcode;

	wire        mem_wen;
	wire [16:0] mem_addr;
	wire [ 7:0] mem_wdata;
	wire [31:0] mem_rdata;

	reg         direct_mem_wen;
	reg  [16:0] direct_mem_addr;
	reg  [ 7:0] direct_mem_wdata;

	mlaccel_compute uut (
		.clock             (clock            ),

		.ctrl_addr         (ctrl_addr        ),
		.ctrl_execute      (ctrl_execute     ),
		.ctrl_busy         (ctrl_busy        ),
		.ctrl_wen_coeff    (ctrl_wen_coeff   ),
		.ctrl_wen_opcode   (ctrl_wen_opcode  ),
		.ctrl_wdata_coeff  (ctrl_wdata_coeff ),
		.ctrl_wdata_opcode (ctrl_wdata_opcode),

		.mem_wen           (mem_wen          ),
		.mem_addr          (mem_addr         ),
		.mem_wdata         (mem_wdata        ),
		.mem_rdata         (mem_rdata        )
	);

	mlaccel_memory mem (
		.clock (clock),
		.addr  (ctrl_busy ? mem_addr  : direct_mem_addr ),
		.wen   (ctrl_busy ? mem_wen   : direct_mem_wen  ),
		.wdata (ctrl_busy ? mem_wdata : direct_mem_wdata),
		.rdata (mem_rdata)
	);

	// -----------------------------------------------------------------------------------

	task write_data;
		input [16:0] addr;
		input [7:0] data;
		begin
			direct_mem_wen <= 1;
			direct_mem_addr <= addr;
			direct_mem_wdata <= data;
			@(posedge clock);
			direct_mem_wen <= 0;
		end
	endtask

	// -----------------------------------------------------------------------------------

	task write_code;
		input [10:0] addr;
		input [63:0] data;
		begin
			ctrl_wen_coeff <= 4'b 1111;
			ctrl_wen_opcode <= 1;
			ctrl_addr <= addr;
			{ctrl_wdata_coeff, ctrl_wdata_opcode} <= data;
			@(posedge clock);
		end
	endtask

	task end_write_code;
		begin
			ctrl_wen_coeff <= 0;
			ctrl_wen_opcode <= 0;
		end
	endtask

	// -----------------------------------------------------------------------------------

	task execute_code;
		input [10:0] addr;
		input [10:0] len;
		begin
			ctrl_addr <= addr;
			ctrl_execute <= len;
			@(posedge clock);
			ctrl_execute <= 0;
			while (ctrl_busy) @(posedge clock);
		end
	endtask

	// -----------------------------------------------------------------------------------

	initial begin
		ctrl_addr <= 0;
		ctrl_execute <= 0;

		ctrl_wen_coeff <= 0;
		ctrl_wen_opcode <= 0;
		ctrl_wdata_coeff <= 0;
		ctrl_wdata_opcode <= 0;

		direct_mem_wen <= 0;
		direct_mem_addr <= 0;
		direct_mem_wdata <= 0;

		repeat (16) @(posedge clock);

		write_data(18'h 00000, 8'h 01);
		write_data(18'h 00001, 8'h 02);
		write_data(18'h 00002, 8'h 04);
		write_data(18'h 00003, 8'h 08);

		write_data(18'h 00004, 8'h 10);
		write_data(18'h 00005, 8'h 20);
		write_data(18'h 00006, 8'h 40);
		write_data(18'h 00007, 8'h 80);

		write_code(11'h 000, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00000, 8'b 0000_0000, 6'b 100011});
		write_code(11'h 001, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00004, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 002, {8'h 00, 8'h 00, 8'h 00, 8'h 00, 18'h 00100, 8'b 0000_0000, 6'b 010000});
		write_code(11'h 003, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00008, 8'b 0000_0000, 6'b 100011});
		write_code(11'h 004, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 0000c, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 005, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00010, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 006, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00014, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 007, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00018, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 008, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 0001c, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 009, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00020, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 00a, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00024, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 00b, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00028, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 00c, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 0002c, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 00d, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00020, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 00e, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00024, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 00f, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 00028, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 010, {8'h 04, 8'h 03, 8'h 02, 8'h 01, 18'h 0002c, 8'b 0000_0000, 6'b 100010});
		write_code(11'h 011, {8'h 00, 8'h 00, 8'h 00, 8'h 00, 18'h 00101, 8'b 0000_0000, 6'b 010000});
		end_write_code;

		execute_code(11'h 000, 11'h 012);
	end
endmodule
