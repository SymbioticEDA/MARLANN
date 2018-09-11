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
	reg [1:0] qmem_write;
	reg [15:0] qmem_addr;
	reg [15:0] qmem_data;

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

	reg [15:0] buffer [0:255];
	reg [8:0] buffer_wptr;
	reg [8:0] buffer_rptr;

	reg [5:0] state;

	localparam integer state_halt = 0;
	localparam integer state_wbuf = 1;
	localparam integer state_wmem0 = 2;
	localparam integer state_wmem1 = 3;
	localparam integer state_wmem2 = 4;

	localparam [7:0] cmd_wbuf = 8'h 21;
	localparam [7:0] cmd_rbuf = 8'h 22;
	localparam [7:0] cmd_wmem = 8'h 23;

	always @(posedge clock) begin
		if (din_valid) begin
			if (din_start) begin
				(* parallel_case *)
				case (din_data)
					cmd_wbuf: begin
						buffer_wptr <= 0;
						state <= state_wbuf;
					end
					cmd_wmem: begin
						buffer_rptr <= 0;
						state <= state_wmem0;
					end
				endcase
			end else begin
				(* full_case, parallel_case *)
				case (state)
					state_wbuf: begin
						if (buffer_wptr[0])
							buffer[buffer_wptr[8:1]][7:0] <= din_data;
						else
							buffer[buffer_wptr[8:1]][15:8] <= din_data;
						buffer_wptr <= buffer_wptr + 1;
					end
					state_wmem0: begin
						qmem_addr[7:0] <= din_data;
						state <= state_wmem1;
					end
					state_wmem1: begin
						dout_valid <= 1;
						dout_data <= 8'h FF;
						qmem_addr[15:8] <= din_data;
						state <= state_wmem2;
					end
					state_wmem2: begin
					end
					state_halt: begin
					end
				endcase
			end
		end

		if (state == state_wmem2) begin
			if (qmem_done) begin
				buffer_rptr <= buffer_rptr + qmem_write[1] + 1;
				qmem_addr <= qmem_addr + 1;
			end else
			if (buffer_wptr != buffer_rptr && !qmem_write) begin
				qmem_write[0] <= 1;
				qmem_write[1] <= buffer_wptr != (buffer_rptr|1);
				qmem_data <= buffer[buffer_rptr[8:1]];
			end
			if (dout_ready)
				dout_data <= {8{buffer_wptr != buffer_rptr}};
		end

		if (reset || qmem_done) begin
			qmem_read <= 0;
			qmem_write <= 0;
		end

		if (reset || din_start) begin
			dout_valid <= 0;
		end

		if (reset) begin
			state <= state_halt;
			trigger_reset <= 0;
		end
	end


	/********** Main Memory **********/

	wire qmem_active = (qmem_read || qmem_write) && !qmem_done;

	wire [15:0] mem_addr  = qmem_active ? qmem_addr  : 0;
	wire [ 7:0] mem_wen   = qmem_active ? qmem_write : 0;
	wire [63:0] mem_wdata = qmem_active ? qmem_data  : 0;
	wire [63:0] mem_rdata;

	always @(posedge clock) begin
		qmem_done <= 0;
		if (!reset && (qmem_read || qmem_write) && !qmem_done) begin
			qmem_done <= 1;
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
	output reg       dout_ready,
	input      [7:0] dout_data
);
	assign qpi_rdy_do = 0;
	assign qpi_err_do = 0;

	reg qpi_csb_q1, qpi_csb_q2;
	reg qpi_clk_q0, qpi_clk_q1, qpi_clk_q2, qpi_clk_q3;
	reg [3:0] qpi_di_q0, qpi_di_q1, qpi_di_q2, qpi_di_q3;
	reg phase;

	reg latched_reset;

	reg out_enable_0;
	reg out_enable_1;
	reg [3:0] out_phase_0;
	reg [3:0] out_phase_1;

	assign qpi_io_oe = qpi_clk_di ? {4{out_enable_1}} : {4{out_enable_0}};
	assign qpi_io_do = qpi_clk_di ? out_phase_1 : out_phase_0;

	always @(posedge clock) begin
		dout_ready <= 0;

		if (dout_valid && !dout_ready) begin
			if (qpi_clk_q0) begin
				out_enable_0 <= 1;
				out_phase_0 <= dout_data[7:4];
			end else begin
				out_enable_1 <= 1;
				out_phase_1 <= dout_data[3:0];
				dout_ready <= 1;
			end
		end

		if (qpi_csb_q2 || reset || latched_reset) begin
			out_enable_0 <= 0;
			out_enable_1 <= 0;
		end
	end

	always @(negedge clock) begin
		qpi_di_q0 <= qpi_io_di;
		qpi_clk_q0 <= qpi_clk_di;
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
			din_start <= 1;
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
endmodule
