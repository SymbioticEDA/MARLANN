`default_nettype none
module mlaccel_top (
	input  clock,

	input  spi_csb,
	input  spi_clk,
	output spi_miso,
	input  spi_mosi,
	output spi_rdy,
	output spi_err
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

	wire        qmem_done;
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

	wire        comp_valid;
	wire        comp_ready;
	wire [31:0] comp_insn;

	wire        comp_busy;
	wire        comp_simd;
	wire        comp_nosimd;

	wire        cmem_ren;
	wire [ 7:0] cmem_wen;
	wire [15:0] cmem_addr;
	wire [63:0] cmem_wdata;
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

	wire spi_active;

	mlaccel_spi spi (
		.clock      (clock     ),
		.reset      (reset     ),
		.active     (spi_active),

		.spi_csb_di (spi_csb),
		.spi_clk_di (spi_clk),
		.spi_rdy_do (spi_rdy   ),
		.spi_err_do (spi_err   ),
		.spi_miso   (spi_miso ),
		.spi_mosi   (spi_mosi ),

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

		if (!spi_active || din_start) begin
			dout_valid <= 0;
		end

		if (din_valid) begin
			if (din_start) begin
				case (din_data)
					cmd_status: begin
						dout_valid <= 1;
						dout_data <= {8{busy}};
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
							buffer[buffer_ptr[9:1]][7:0] <= din_data;
						else
							buffer[buffer_ptr[9:1]][15:8] <= din_data;
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
					dout_data <= buffer[buffer_ptr[9:1]][7:0];
				else
					dout_data <= buffer[buffer_ptr[9:1]][15:8];
			end

			if (state == state_wmem3) begin
				if (qmem_done) begin
					buffer_ptr <= buffer_ptr + 2;
					qmem_addr <= qmem_addr + 1;
				end else
				if (buffer_ptr != buffer_len && !qmem_write) begin
					qmem_write <= 3;
					qmem_wdata <= buffer[buffer_ptr[9:1]];
				end
				if (dout_ready)
					dout_data <= {8{buffer_ptr != buffer_len}};
			end

			if (state == state_rmem3) begin
				if (qmem_rdone) begin
					buffer[buffer_ptr[9:1]] <= qmem_rdata;
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

		if (reset) begin
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
		.comp_insn  (comp_insn )
	);

	mlaccel_compute comp (
		.clock       (clock      ),
		.reset       (reset      ),
		.busy        (comp_busy  ),

		.cmd_valid   (comp_valid ),
		.cmd_ready   (comp_ready ),
		.cmd_insn    (comp_insn  ),

		.mem_ren     (cmem_ren   ),
		.mem_wen     (cmem_wen   ),
		.mem_addr    (cmem_addr  ),
		.mem_wdata   (cmem_wdata ),
		.mem_rdata   (cmem_rdata ),

		.tick_simd   (comp_simd  ),
		.tick_nosimd (comp_nosimd)
	);

	reg [3:0] busy_q;

	always @(posedge clock) begin
		if (reset)
			busy_q <= 0;
		else
			busy_q <= {busy_q, seq_busy || comp_busy};
	end

	assign busy = busy_q || seq_busy || comp_busy;

`ifdef TRACE
	reg perfcount_active;
	integer perfcount_cycles;
	integer perfcount_simd;
	integer perfcount_nosimd;

	always @(posedge clock) begin
		if (busy) begin
			perfcount_active <= 1;
			perfcount_cycles <= perfcount_cycles + 1;
			perfcount_simd <= perfcount_simd + comp_simd;
			perfcount_nosimd <= perfcount_nosimd + comp_nosimd;
		end else
		if (perfcount_active) begin
			$display("-------------------");
			$display("Number of clock cycles:          %d", perfcount_cycles);
			$display("Number of SIMD-instructions:     %d", perfcount_simd);
			$display("Number of non-SIMD-instructions: %d", perfcount_nosimd);
			$display("");
			$display("Avg. ops per cycle:       %8.2f", (1.0*perfcount_nosimd + 16.0*perfcount_simd) / perfcount_cycles);
			$display("Avg. simd ops per cycle:  %8.2f", 16.0*perfcount_simd / perfcount_cycles);
			$display("");
			$display("Avg. insn per cycle:      %8.2f", (1.0*perfcount_nosimd + 1.0*perfcount_simd) / perfcount_cycles);
			$display("Avg. simd insn per cycle: %8.2f", 1.0*perfcount_simd / perfcount_cycles);
			$display("");
			$display("MMACC/s at 20 MHz: %8.2f", 20*16.0*perfcount_simd / perfcount_cycles);
			$display("MMACC/s at 35 MHz: %8.2f", 35*16.0*perfcount_simd / perfcount_cycles);
			$display("-------------------");

			perfcount_active <= 0;
			perfcount_cycles <= 0;
			perfcount_simd <= 0;
			perfcount_nosimd <= 0;
		end

		if (reset) begin
			perfcount_active <= 0;
			perfcount_cycles <= 0;
			perfcount_simd <= 0;
			perfcount_nosimd <= 0;
		end
	end
`endif

	/********** Main Memory **********/

	reg mem_client_qmem;
	reg mem_client_smem;
	reg mem_client_cmem;

	reg  [15:0] next_mem_addr;
	reg  [ 7:0] next_mem_wen;
	reg  [63:0] next_mem_wdata;

	reg  [15:0] mem_addr;
	reg  [ 7:0] mem_wen;
	reg  [63:0] mem_wdata;
	wire [63:0] mem_rdata;

	reg [2:0] smem_state;
	reg [2:0] qmem_state;

	always @* begin
		mem_client_qmem = 0;
		mem_client_smem = 0;
		mem_client_cmem = 0;

		next_mem_addr = cmem_addr;
		next_mem_wen = cmem_wen;
		next_mem_wdata = cmem_wdata;

		if (cmem_ren || cmem_wen) begin
			mem_client_cmem = 1;
		end else
		if ((qmem_read || qmem_write) && !qmem_state) begin
			mem_client_qmem = 1;
			next_mem_addr = qmem_addr;
			next_mem_wen = qmem_write;
			next_mem_wdata = qmem_wdata;
		end else
		if (smem_valid && !smem_state) begin
			mem_client_smem = 1;
			next_mem_addr = smem_addr;
			next_mem_wen = 0;
		end
	end

	assign qmem_rdata = mem_rdata[15:0];
	assign qmem_done = qmem_state[1];
	assign smem_data = mem_rdata[31:0];
	assign smem_ready = smem_state[2];
	assign cmem_rdata = mem_rdata;

	always @(posedge clock) begin
		mem_addr <= next_mem_addr;
		mem_wen <= next_mem_wen;
		mem_wdata <= next_mem_wdata;
		qmem_rdone <= qmem_read && qmem_done;

		smem_state <= {smem_state, mem_client_smem};
		qmem_state <= {qmem_state, mem_client_qmem};

		if (reset) begin
			qmem_rdone <= 0;
			mem_wen <= 0;
			smem_state <= 0;
			qmem_state <= 0;
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

module mlaccel_spi (
	input            clock,
	input            reset,
	output           active,

	input            spi_csb_di,
	input            spi_clk_di,

	output           spi_rdy_do,
	output           spi_err_do,

	output reg       spi_miso,
	input            spi_mosi,

	output reg       din_valid,
	output reg       din_start,
	output reg [7:0] din_data,

	input            dout_valid,
	output           dout_ready,
	input      [7:0] dout_data
);
	assign spi_rdy_do = 1;
	assign spi_err_do = 1;

	reg [7:0] di_data;
	reg [2:0] di_bit = 0; // which bit of the byte is being received
	reg di_start = 0;
	reg di_stx = 0;

	reg [7:0] do_data = 0;
	reg [7:0] do_datax = 0;
	reg do_valid = 0;
	reg do_validx = 0;
	reg [2:0] do_bit = 0; // which bit of the byte is being sent

	reg glitch_guard_clock_q0 = 0;
	reg glitch_guard_di_stx_q0 = 0;

	reg glitch_guard_posedge = 0;
	reg glitch_guard_negedge = 0;
	reg glitch_guard_di_stx = 0;
	reg [7:0] glitch_guard_di_bit;
	reg [7:0] glitch_guard_di_bit_q0;
	reg [7:0] glitch_guard_do_bit;
	reg [7:0] glitch_guard_do_bit_q0;
    reg di_toggle;

	always @(negedge clock) begin
		glitch_guard_clock_q0 <= spi_clk_di;
		glitch_guard_di_stx_q0 <= di_stx;
		glitch_guard_di_bit_q0 <= di_bit;
		glitch_guard_do_bit_q0 <= do_bit;
	end

	always @(posedge clock) begin
		// protect against clock glitching: logic level of clock
		// must have been low before posedge and high before negedge
		glitch_guard_posedge <= !glitch_guard_clock_q0;
		glitch_guard_negedge <= glitch_guard_clock_q0;
		glitch_guard_di_bit <= glitch_guard_di_bit_q0;
		glitch_guard_do_bit <= glitch_guard_do_bit_q0;

		// delay some signals to protect against double clocking
		glitch_guard_di_stx <= glitch_guard_di_stx_q0;
	end

    // receive mosi
	always @(posedge spi_clk_di, posedge spi_csb_di) begin
		if (spi_csb_di) begin
			di_data <= 0;
			di_toggle <= 0;
            di_bit <= 0;
			di_start <= 1;
			di_stx <= 1;
		end else begin
			if (glitch_guard_posedge) begin
				di_data[7-glitch_guard_di_bit] <= spi_mosi;
				di_bit <= glitch_guard_di_bit + 1;

				if (glitch_guard_di_bit == 0) 
					di_stx <= 0;
				if (glitch_guard_di_bit == 0 && !glitch_guard_di_stx)
					di_start <= 0;
			end
		end
	end

    // send miso
	always @(negedge spi_clk_di, posedge spi_csb_di) begin
		if (spi_csb_di) begin
			spi_miso <= 0;
			do_bit <= 0;
			do_validx <= 0;
			do_datax <= 0;
		end else begin
			if (glitch_guard_negedge) begin
                if(di_start)
                    do_bit <= 0;
                else
                    do_bit <= do_bit  + 1;

                // send data
                spi_miso <= do_data[7-glitch_guard_do_bit];

				do_validx <= do_valid;
				do_datax <= do_data;
			end
		end
	end

	reg clk_q0, clk_q1, clk_q2;
	reg active_q0, active_q1;

	always @(negedge clock) begin
		clk_q0 <= spi_clk_di;
		active_q0 <= !spi_csb_di;
	end

	always @(posedge clock) begin
		clk_q1 <= clk_q0;
		clk_q2 <= clk_q1;
		active_q1 <= active_q0;
	end

	reg dout_busy;
	assign dout_ready = glitch_guard_do_bit == 0 && dout_valid && !dout_busy;
	assign active = active_q1;

	always @(posedge clock) begin
		din_valid <= 0;
		if (clk_q1 && !clk_q2) begin
			if (di_bit == 0) begin
				din_data <= di_data;
				din_valid <= 1;
				din_start <= di_start;
			end
		end
		if (dout_valid && dout_ready) begin
			do_valid <= 1;
			do_data <= dout_data;
			dout_busy <= 1;
		end
		if (glitch_guard_do_bit == 7) begin
			dout_busy <= 0;
		end
		if (!active) begin
			do_valid <= 0;
			do_data <= 0;
			dout_busy <= 0;
		end
		if (reset) begin
			do_valid <= 0;
			do_data <= 0;
			din_valid <= 0;
			din_start <= 0;
			din_data <= 0;
			dout_busy <= 0;
		end
	end
endmodule
