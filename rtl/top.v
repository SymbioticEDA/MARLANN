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

	wire busy;

	wire        din_valid;
	wire        din_start;
	wire [ 7:0] din_data;

	reg         dout_valid;
	wire        dout_ready;
	reg  [ 7:0] dout_data;

	reg         qmem_done;
	reg         qmem_rdone;
	reg         qmem_read;
	reg  [ 1:0] qmem_write;
	reg  [15:0] qmem_addr;
	reg  [15:0] qmem_wdata;
	wire [15:0] qmem_rdata;

	reg         seq_start;
	reg         seq_stop;
	reg  [15:0] seq_addr;
	wire        seq_busy;

	wire        smem_valid;
	wire        smem_ready;
	wire [15:0] smem_addr;
	wire [31:0] smem_data;

	(* keep *) wire        comp_valid;
	(* keep *) wire        comp_ready;
	(* keep *) wire [31:0] comp_data;

	(* keep *) wire        comp_busy;

	wire        cmem_ren;
	wire [ 1:0] cmem_wen;
	wire [15:0] cmem_addr;
	wire [15:0] cmem_wdata;
	wire [63:0] cmem_rdata;

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

	reg [15:0] buffer [0:511];
	reg [10:0] buffer_ptr;
	reg [10:0] buffer_len;

	reg [5:0] state;

	localparam integer state_halt   =  0;
	localparam integer state_status =  1;
	localparam integer state_wbuf   =  2;
	localparam integer state_rbuf   =  3;

	localparam integer state_wmem0  =  4;
	localparam integer state_wmem1  =  5;
	localparam integer state_wmem2  =  6;
	localparam integer state_wmem3  =  7;

	localparam integer state_rmem0  =  8;
	localparam integer state_rmem1  =  9;
	localparam integer state_rmem2  = 10;
	localparam integer state_rmem3  = 11;

	localparam integer state_run0   = 12;
	localparam integer state_run1   = 13;

	localparam [7:0] cmd_status = 8'h 20;
	localparam [7:0] cmd_wbuf   = 8'h 21;
	localparam [7:0] cmd_rbuf   = 8'h 22;
	localparam [7:0] cmd_wmem   = 8'h 23;
	localparam [7:0] cmd_rmem   = 8'h 24;
	localparam [7:0] cmd_run    = 8'h 25;
	localparam [7:0] cmd_stop   = 8'h 26;

	always @(posedge clock) begin
		seq_start <= 0;
		seq_stop <= 0;

		if (din_valid) begin
			if (din_start) begin
				case (din_data)
					cmd_status: begin
						state <= state_status;
					end
					cmd_wbuf: begin
						buffer_ptr <= 0;
						state <= state_wbuf;
					end
					cmd_rbuf: begin
						buffer_ptr <= 0;
						state <= state_rbuf;
					end
					cmd_wmem: begin
						buffer_ptr <= 0;
						state <= state_wmem0;
					end
					cmd_rmem: begin
						buffer_ptr <= 0;
						state <= state_rmem0;
					end
					cmd_run: begin
						state <= state_run0;
					end
					cmd_stop: begin
						seq_stop <= 1;
						state <= state_halt;
					end
				endcase
			end else begin
				case (state)
					state_wbuf: begin
						if (!buffer_ptr[0])
							buffer[buffer_ptr[8:1]][7:0] <= din_data;
						else
							buffer[buffer_ptr[8:1]][15:8] <= din_data;
						buffer_ptr <= buffer_ptr + 1;
					end

					state_wmem0: begin
						qmem_addr[7:0] <= din_data;
						state <= state_wmem1;
					end
					state_wmem1: begin
						qmem_addr[15:8] <= din_data;
						state <= state_wmem2;
					end
					state_wmem2: begin
						dout_valid <= 1;
						dout_data <= 8'h FF;
						buffer_len <= din_data ? {din_data, 2'b00} : 1024;
						state <= state_wmem3;
					end

					state_rmem0: begin
						qmem_addr[7:0] <= din_data;
						state <= state_rmem1;
					end
					state_rmem1: begin
						qmem_addr[15:8] <= din_data;
						state <= state_rmem2;
					end
					state_rmem2: begin
						dout_valid <= 1;
						dout_data <= 8'h FF;
						buffer_len <= din_data ? {din_data, 2'b00} : 1024;
						state <= state_rmem3;
					end

					state_run0: begin
						seq_addr[7:0] <= din_data;
						state <= state_run1;
					end
					state_run1: begin
						seq_addr[15:8] <= din_data;
						seq_start <= 1;
						state <= state_halt;
					end
				endcase
			end
		end

		if (!din_valid || !din_start) begin
			if (state == state_status) begin
				dout_valid <= 1;
				dout_data <= {8{busy}};
			end

			if (state == state_rbuf) begin
				dout_valid <= !dout_ready;
				buffer_ptr <= buffer_ptr + dout_ready;
				if (!buffer_ptr[0])
					dout_data <= buffer[buffer_ptr[8:1]][7:0];
				else
					dout_data <= buffer[buffer_ptr[8:1]][15:8];
			end

			if (state == state_wmem3) begin
				if (qmem_done) begin
					buffer_ptr <= buffer_ptr + 2;
					qmem_addr <= qmem_addr + 1;
				end else
				if (buffer_ptr != buffer_len && !qmem_write) begin
					qmem_write <= 3;
					qmem_wdata <= buffer[buffer_ptr[8:1]];
				end
				if (dout_ready)
					dout_data <= {8{buffer_ptr != buffer_len}};
			end

			if (state == state_rmem3) begin
				if (qmem_rdone) begin
					buffer[buffer_ptr[8:1]] <= qmem_rdata;
					buffer_ptr <= buffer_ptr + 2;
					qmem_addr <= qmem_addr + 1;
				end else
				if (buffer_ptr != buffer_len && !qmem_read) begin
					qmem_read <= 3;
				end
				if (dout_ready)
					dout_data <= {8{buffer_ptr != buffer_len}};
				if (qmem_done)
					qmem_read <= 0;
			end
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


	/********** Sequencer and Compute **********/

	mlaccel_sequencer seq (
		.clock      (clock     ),
		.reset      (reset     ),

		.start      (seq_start ),
		.addr       (seq_addr  ),
		.busy       (seq_busy  ),

		.smem_valid (smem_valid),
		.smem_ready (smem_ready),
		.smem_addr  (smem_addr ),
		.smem_data  (smem_data ),

		.comp_valid (comp_valid),
		.comp_ready (comp_ready),
		.comp_data  (comp_data )
	);

	mlaccel_compute comp (
		.clock     (clock     ),
		.reset     (reset     ),
		.busy      (comp_busy ),

		.cmd_valid (comp_valid),
		.cmd_ready (comp_ready),
		.cmd_data  (comp_data ),

		.mem_ren   (cmem_ren  ),
		.mem_wen   (cmem_wen  ),
		.mem_addr  (cmem_addr ),
		.mem_wdata (cmem_wdata),
		.mem_rdata (cmem_rdata)
	);

	assign busy = seq_busy || comp_busy;

	/********** Main Memory **********/

	reg mem_client_qmem;
	reg mem_client_smem;
	reg mem_client_cmem;

	reg  [15:0] mem_addr;
	reg  [ 1:0] mem_wen;
	reg  [15:0] mem_wdata;
	wire [63:0] mem_rdata;

	reg [1:0] smem_state;

	always @* begin
		mem_client_qmem = 0;
		mem_client_smem = 0;
		mem_client_cmem = 0;

		mem_addr = cmem_addr;
		mem_wen = cmem_wen;
		mem_wdata = cmem_wdata;

		if (cmem_ren || cmem_wen) begin
			mem_client_cmem = 1;
		end else
		if ((qmem_read || qmem_write) && !qmem_done) begin
			mem_client_qmem = 1;
			mem_addr = qmem_addr;
			mem_wen = qmem_write;
			mem_wdata = qmem_wdata;
		end else
		if (smem_valid && !smem_state) begin
			mem_client_smem = 1;
			mem_addr = smem_addr;
		end
	end

	assign qmem_rdata = mem_rdata[15:0];
	assign smem_data = mem_rdata[31:0];
	assign smem_ready = smem_state[1];
	assign cmem_rdata = mem_rdata;

	always @(posedge clock) begin
		qmem_done <= mem_client_qmem;
		qmem_rdone <= qmem_read && qmem_done;

		smem_state <= {smem_state, mem_client_smem};

		if (reset) begin
			qmem_done <= 0;
			qmem_rdone <= 0;
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
	reg next_out_enable_1;
	reg [3:0] out_phase_0;
	reg [3:0] out_phase_1;
	reg [3:0] next_out_phase_1;

	assign qpi_io_oe = qpi_clk_di ? {4{out_enable_1}} : {4{out_enable_0}};
	assign qpi_io_do = qpi_clk_di ? out_phase_1 : out_phase_0;

	always @(posedge clock) begin
		dout_ready <= 0;

		if (qpi_clk_q0) begin
			if (dout_valid && !dout_ready && !next_out_enable_1) begin
				dout_ready <= 1;
				out_enable_0 <= 1;
				out_phase_0 <= dout_data[7:4];
				next_out_enable_1 <= 1;
				next_out_phase_1 <= dout_data[3:0];
			end
		end else begin
			if (next_out_enable_1) begin
				next_out_enable_1 <= 0;
				out_enable_1 <= next_out_enable_1;
				out_phase_1 <= next_out_phase_1;
			end
		end

		if (qpi_csb_q2 || reset || latched_reset) begin
			out_enable_0 <= 0;
			out_enable_1 <= 0;
			next_out_enable_1 <= 0;
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
