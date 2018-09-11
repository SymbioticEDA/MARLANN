module mlaccel_top (
	input  clock,

	input  qpi_csb,
	input  qpi_clk,
	inout  qpi_io0,
	inout  qpi_io1,
	inout  qpi_io2,
	inout  qpi_io3,
	output qpi_rdy,
	output qpi_err
);
	integer i;

	/********** Global Wires **********/

	reg reset;
	reg trigger_reset;

	wire din_valid;
	wire din_start;
	wire [7:0] din_data;

	reg dout_valid;
	wire dout_ready;
	reg [7:0] dout_data;

	reg qmem_done;
	reg qmem_read;
	reg qmem_write;
	reg [15:0] qmem_addr;
	reg [63:0] qmem_rdata;
	reg [63:0] qmem_wdata;
	reg [7:0] qmem_wtags;

	wire busy;

	/********** Reset Generator **********/

	reg [3:0] reset_cnt = 0;
	wire next_resetn = &reset_cnt;

	always @(posedge clock) begin
		if (trigger_reset)
			reset_cnt <= 0;
		else
			reset_cnt <= reset_cnt + !next_resetn;
		reset <= !next_resetn;
	end

	/********** QPI Interface **********/

	wire [3:0] qpi_io_oe;
	wire [3:0] qpi_io_do;
	wire [3:0] qpi_io_di;

	SB_IO #(
		.PIN_TYPE(6'b 1010_01),
		.PULLUP(1'b 0)
	) qpi_io_buf [3:0] (
		.PACKAGE_PIN({qpi_io3, qpi_io2, qpi_io1, qpi_io0}),
		.OUTPUT_ENABLE(qpi_io_oe),
		.D_OUT_0(qpi_io_do),
		.D_IN_0(qpi_io_di)
	);

	wire qpi_csb_di;
	wire qpi_clk_di;

	SB_IO #(
		.PIN_TYPE(6'b 0000_01),
		.PULLUP(1'b 1)
	) qpi_in_buf [1:0] (
		.PACKAGE_PIN({qpi_csb, qpi_clk}),
		.D_IN_0({qpi_csb_di, qpi_clk_di})
	);

	mlaccel_qpi qpi (
		.clock      (clock     ),
		.reset      (reset     ),

		.qpi_csb_di (qpi_csb_di),
		.qpi_clk_di (qpi_clk_di),
		.qpi_rdy_do (qpi_rdy   ),
		.qpi_err_do (qpi_err   ),
		.qpi_io_di  (qpi_io_di ),
		.qpi_io_do  (qpi_io_do ),
		.qpi_io_oe  (qpi_io_oe ),

		.din_valid  (din_valid ),
		.din_start  (din_start ),
		.din_data   (din_data  ),

		.dout_valid (dout_valid),
		.dout_ready (dout_ready),
		.dout_data  (dout_data )
	);

	/********** Cmd State Machine **********/

	reg cmd_updated;
	reg [2:0] cmd_bytes;
	reg [23:0] cmd;

	reg cmd_status;
	reg cmd_wmem;
	reg cmd_rmem;

	reg [15:0] cmd_addr;
	reg [63:0] cmd_data;
	reg [7:0] cmd_dtags;

	reg [63:0] next_cmd_data_write;

	always @* begin
		next_cmd_data_write = cmd_data;

		if (cmd_dtags[0] == 1'b0)
			next_cmd_data_write[0 +: 8] = cmd[7:0];

		for (i = 1; i < 8; i = i+1) begin
			if (cmd_dtags[i-1 +: 2] == 2'b01)
				next_cmd_data_write[8*i +: 8] = cmd[7:0];
		end
	end

	always @(posedge clock) begin
		cmd_updated <= 0;

		if (din_valid) begin
			cmd_updated <= 1;
			cmd_bytes <= {cmd_bytes, 1'b1};
			cmd <= {cmd, din_data};
		end

		if (din_start) begin
			dout_valid <= 0;

			cmd_status <= 0;
			cmd_wmem <= 0;
			cmd_rmem <= 0;

			cmd_bytes <= 1;
			cmd <= din_data;

			cmd_dtags <= 0;

			if (cmd_wmem) begin
				qmem_write <= 1;
				qmem_addr <= cmd_addr;
				qmem_wdata <= cmd_data;
				qmem_wtags <= cmd_dtags;
			end
		end

		if (cmd_updated) begin
			(* parallel_case *)
			case (1'b1)
				cmd_status: begin
					dout_valid <= 1;
					dout_data <= busy ? 8'h FF : 8'h 00;
				end

				cmd_wmem: begin
					if (&cmd_dtags) begin
						qmem_write <= 1;
						qmem_addr <= cmd_addr;
						qmem_wdata <= cmd_data;
						qmem_wtags <= cmd_dtags;

						cmd_addr <= cmd_addr + 4;
						cmd_data <= cmd[7:0];
						cmd_dtags <= 1'b1;
					end else begin
						cmd_data <= next_cmd_data_write;
						cmd_dtags <= {cmd_dtags, 1'b1};
					end
				end

				cmd_rmem: begin
				end

				default: begin
					// Status (20h)
					if (cmd_bytes == 3'b001 && cmd[7:0] == 8'h 20) begin
						cmd_status <= 1;
					end

					// Write main memory (21h)
					if (cmd_bytes == 3'b111 && cmd[23:16] == 8'h 21) begin
						cmd_wmem <= 1;
						cmd_addr <= {cmd[7:0], cmd[15:8]};
					end

					// Read main memory (22h)
					if (cmd_bytes == 3'b111 && cmd[23:16] == 8'h 22) begin
						cmd_rmem <= 1;
						cmd_addr <= {cmd[7:0], cmd[15:8]};
						qmem_addr <= {cmd[7:0], cmd[15:8]};
						qmem_read <= 1;
					end
				end
			endcase
		end

		if (qmem_done) begin
			qmem_read <= 0;
			qmem_write <= 0;
			qmem_wtags <= 0;
		end

		if (reset) begin
			dout_valid <= 0;
			dout_data <= 0;

			trigger_reset <= 0;
			cmd_updated <= 0;
			cmd_bytes <= 0;
			cmd <= 0;

			qmem_read <= 0;
			qmem_write <= 0;
			qmem_wtags <= 0;
		end
	end

	/********** Main Memory **********/

	wire [15:0] mem_addr  = qmem_addr;
	wire [ 7:0] mem_wen   = qmem_wtags;
	wire [63:0] mem_wdata = qmem_wdata;
	wire [63:0] mem_rdata;

	reg qmem_rdata_copy;

	always @(posedge clock) begin
		qmem_done <= 0;
		qmem_rdata_copy <= 0;

		if (!reset && (qmem_read || qmem_write) && !qmem_done) begin
			qmem_done <= 1;
		end

		if (qmem_read && qmem_done) begin
			qmem_rdata_copy <= 1;
		end

		if (qmem_rdata_copy) begin
			qmem_rdata <= mem_rdata;
		end
	end

	mlaccel_memory mem (
		.clock (clock    ),
		.addr  (mem_addr ),
		.wen   (mem_wen  ),
		.wdata (mem_wdata),
		.rdata (mem_rdata)
	);
endmodule

module mlaccel_qpi (
	input            clock,
	input            reset,

	input            qpi_csb_di,
	input            qpi_clk_di,

	output           qpi_rdy_do,
	output           qpi_err_do,

	input      [3:0] qpi_io_di,
	output     [3:0] qpi_io_do,
	output     [3:0] qpi_io_oe,

	output reg       din_valid,
	output reg       din_start,
	output reg [7:0] din_data,

	input            dout_valid,
	output           dout_ready,
	input      [7:0] dout_data
);
	assign qpi_rdy_do = 0;
	assign qpi_err_do = 0;

	reg qpi_csb_q1, qpi_csb_q2;
	reg qpi_clk_q1, qpi_clk_q2, qpi_clk_q3;
	reg [3:0] qpi_di_q0, qpi_di_q1, qpi_di_q2, qpi_di_q3;
	reg phase;

	reg latched_reset;

	always @(negedge clock) begin
		qpi_di_q0 <= qpi_io_di;
	end

	always @(posedge clock) begin
		din_valid <= 0;

		qpi_csb_q1 <= qpi_csb_di;
		qpi_csb_q2 <= qpi_csb_q1;

		qpi_clk_q1 <= qpi_clk_di;
		qpi_clk_q2 <= qpi_clk_q1;
		qpi_clk_q3 <= qpi_clk_q2;

		qpi_di_q1 <= qpi_di_q0;
		qpi_di_q2 <= qpi_di_q1;
		qpi_di_q3 <= qpi_di_q2;

		if (reset)
			latched_reset <= 1;
		else if (qpi_csb_q2)
			latched_reset <= 0;

		if (din_valid)
			din_start <= 0;

		if (qpi_csb_q2 || reset || latched_reset) begin
			phase <= 0;
			din_start <= !qpi_csb_q1;
		end else
		if (!phase && qpi_clk_q2 && !qpi_clk_q3) begin
			din_data[7:4] <= qpi_di_q3;
			phase <= 1;
		end else
		if (phase && !qpi_clk_q2 && qpi_clk_q3) begin
			din_data[3:0] <= qpi_di_q3;
			din_valid <= 1;
			phase <= 0;
		end
	end

	assign qpi_io_oe = 0;
	assign qpi_io_do = 0;

	assign dout_ready = 0;
endmodule
