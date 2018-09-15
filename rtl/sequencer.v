module mlaccel_sequencer (
	input             clock,
	input             reset,
	input             start,
	input      [15:0] addr,
	output reg        busy,

	output reg        smem_valid,
	input             smem_ready,
	output reg [15:0] smem_addr,
	input      [31:0] smem_data,

	output reg        comp_valid,
	input             comp_ready,
	output reg [31:0] comp_data,
	output reg        comp_op
);
	localparam [5:0] opcode_sync   = 0;
	localparam [5:0] opcode_call   = 1;
	localparam [5:0] opcode_return = 2;

	/**** Front-End ****/

	reg running;
	reg [15:0] pc;

	reg [8:0] callstack_ptr;
	reg [15:0] callstack [0:511];

	reg [8:0] queue_iptr, queue_optr;
	reg [31:0] queue [0:511];
	reg queue_full;

	always @(posedge clock) begin
		if (smem_valid && smem_ready) begin
			smem_valid <= 0;
			if (smem_data[5:0] == opcode_call) begin
				callstack_ptr <= callstack_ptr + 1;
				callstack[callstack_ptr+1] <= pc + 2;
				pc <= smem_data[31:17] << 1;
			end else
			if (smem_data[5:0] == opcode_return) begin
				if (callstack_ptr) begin
					callstack_ptr <= callstack_ptr - 1;
					pc <= callstack[callstack_ptr];
				end else begin
					running <= 0;
				end
			end else begin
				queue_iptr <= queue_iptr + 1;
				queue[queue_iptr] <= smem_data;
				pc <= pc + 2;
			end
		end

		if (running && !smem_valid && !queue_full) begin
			smem_valid <= 1;
			smem_addr <= pc;
		end

		queue_full <= (queue_iptr - queue_optr) >= 496;

		if (reset || start) begin
			pc <= addr;
			running <= start;
			smem_valid <= 0;
			callstack_ptr <= 0;
			queue_iptr <= 0;
			queue_full <= 0;
		end
	end

	/**** Back-End ****/

	reg [31:0] next_insn;
	reg next_insn_valid;
	reg keep_next_insn;

	always @(posedge clock) begin
		if (!keep_next_insn) begin
			if (queue_iptr != queue_optr) begin
				queue_optr <= queue_optr + 1;
				next_insn <= queue[queue_optr];
				next_insn_valid <= 1;
			end else begin
				next_insn_valid <= 0;
			end
		end
		
		if (!comp_valid || comp_ready) begin
			if (next_insn_valid) begin
				comp_valid <= 1;
				comp_data <= next_insn;
			end else begin
				comp_valid <= 0;
			end
		end

		if (reset || start) begin
			queue_optr <= 0;
			next_insn_valid <= 0;
			keep_next_insn <= 0;
		end
	end

	/**** Busy ****/

	always @(posedge clock) begin
		busy <= !reset && (running || queue_iptr != queue_optr || start);
	end
endmodule
