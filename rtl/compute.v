module mlaccel_compute #(
	parameter integer N = 4,
	parameter integer SZ = 1024
) (
	input                clock,

	input      [   10:0] ctrl_addr,
	input      [   10:0] ctrl_execute,
	output reg           ctrl_busy,

	input      [  N-1:0] ctrl_wen_coeff,
	input                ctrl_wen_opcode,
	input      [8*N-1:0] ctrl_wdata_coeff,
	input      [   31:0] ctrl_wdata_opcode,

	output reg           mem_wen,
	output reg [   16:0] mem_addr,
	output reg [    7:0] mem_wdata,
	input      [   31:0] mem_rdata
);
	integer i;

	// code memory
	reg [8*N-1:0] code_coeff [0:SZ-1];
	reg [31:0] code_opcode [0:SZ-1];

	always @(posedge clock) begin
		for (i = 0; i < N; i = i+1) begin
			if (ctrl_wen_coeff[i])
				code_coeff[ctrl_addr][8*i +: 8] <= ctrl_wdata_coeff[8*i +: 8];
		end
		if (ctrl_wen_opcode)
			code_opcode[ctrl_addr] <= ctrl_wdata_opcode;
	end

	// program counter, issue stage
	reg [10:0] pc, icnt = 0;

	// remaining stages
	reg s1_en, s2_en, s3_en, s4_en, s5_en, s6_en;
	reg [10:0] s1_pc, s2_pc, s3_pc;
	reg [31:0] s1_op, s2_op, s3_op, s4_op, s5_op, s6_op;

	reg [31:0] s3_coeff;
	wire [63:0] s6_prod;

	reg [23:0] accumulator;
	reg [23:0] next_accumulator;
	wire [23:0] acc_shifted = $signed(accumulator) >>> s6_op[13:6];

	reg wb_enable;
	reg [17:0] wb_addr;
	reg [7:0] wb_data;

	always @(posedge clock) begin
		wb_enable <= s6_en && s6_op[4];
		wb_addr <= s6_op[31:14];
		if (&acc_shifted[23:7] != |acc_shifted[23:7])
			wb_data <= acc_shifted[23] ? -128 : 127;
		else
			wb_data <= acc_shifted;
	end

	always @* begin
		mem_addr = wb_enable ? wb_addr : s1_op[31:14];
		mem_wdata = wb_data;
		mem_wen = wb_enable;
		ctrl_busy = |{s1_en, s2_en, s3_en, s4_en, s5_en, s6_en, icnt};
	end

	always @* begin
		next_accumulator = accumulator;
		if (s6_op[5]) begin
			if (s6_op[0]) begin
				next_accumulator = {24{s6_op[1]}};
			end
			if (s6_op[1]) begin
				next_accumulator = $signed(next_accumulator) + $signed(s6_prod[15: 0]);
				next_accumulator = $signed(next_accumulator) + $signed(s6_prod[31:16]);
				next_accumulator = $signed(next_accumulator) + $signed(s6_prod[47:32]);
				next_accumulator = $signed(next_accumulator) + $signed(s6_prod[63:48]);
			end else begin
				if ($signed(s6_prod[15: 0]) > $signed(next_accumulator)) next_accumulator = $signed(s6_prod[15: 0]);
				if ($signed(s6_prod[31:16]) > $signed(next_accumulator)) next_accumulator = $signed(s6_prod[31:16]);
				if ($signed(s6_prod[47:32]) > $signed(next_accumulator)) next_accumulator = $signed(s6_prod[47:32]);
				if ($signed(s6_prod[63:48]) > $signed(next_accumulator)) next_accumulator = $signed(s6_prod[63:48]);
			end
		end
	end

	always @(posedge clock) begin
		s1_en <= 0;
		s1_pc <= pc;
		s1_op <= code_opcode[pc];

		s2_en <= s1_en;
		s2_pc <= s1_pc;
		s2_op <= s1_op;

		s3_en <= s2_en;
		s3_pc <= s2_pc;
		s3_op <= s2_op;
		s3_coeff <= code_coeff[s2_pc];

		s4_en <= s3_en;
		s4_op <= s3_op;

		s5_en <= s4_en;
		s5_op <= s4_op;

		s6_en <= s5_en;
		s6_op <= s5_op;

		if (s6_en) begin
			accumulator <= next_accumulator;
		end

		if (ctrl_execute != 0 && !ctrl_busy) begin
			pc <= ctrl_addr;
			icnt <= ctrl_execute;
		end else
		if (icnt != 0 && (!s6_en || !s6_op[4])) begin
			pc <= pc + 1;
			icnt <= icnt - 1;
			s1_en <= 1;
		end
	end

	mlaccel_compute_mul mul [3:0] (
		.clock (clock),
		.A(mem_rdata),
		.B(s3_coeff),
		.X(s6_prod)
	);
endmodule

module mlaccel_compute_mul (
	input         clock,
	input  [ 7:0] A, B,
	output [15:0] X
);
	reg [15:0] r1, r2, r3;

	always @(posedge clock) begin
		r1 <= $signed(A) * $signed(B);
		r2 <= r1;
		r3 <= r2;
	end

	assign X = r3;
endmodule
