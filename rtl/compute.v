module mlaccel_compute #(
	parameter integer NB = 2,
	parameter integer SZ = 8,
	parameter integer CODE_SIZE = 512,
	parameter integer COEFF_SIZE = 512
) (
	input             clock,
	input             reset,
	output            busy,

	input             cmd_valid,
	output            cmd_ready,
	input  [    31:0] cmd_data,

	output            mem_ren,
	output [     1:0] mem_wen,
	output [    15:0] mem_addr,
	output [    15:0] mem_wdata,
	input  [SZ*8-1:0] mem_rdata
);
	integer i;

	reg [31:0] code_mem [0:CODE_SIZE-1];
	reg [8*NB*SZ-1:0] coeff_mem [0:COEFF_SIZE-1];

	reg [23:0] acc0, acc1;

	reg        mem_rd_en;
	reg [15:0] mem_rd_addr;

	reg [ 1:0] mem_wr_en = 0;
	reg [15:0] mem_wr_addr;
	reg [15:0] mem_wr_wdata;

	assign mem_ren = mem_rd_en;
	assign mem_wen = mem_wr_en;
	assign mem_addr = mem_ren ? mem_rd_addr : mem_wr_addr;
	assign mem_wdata = mem_wr_wdata;

`ifndef SYNTHESIS
	initial begin
		for (i = 0; i < CODE_SIZE; i = i+1)
			code_mem[i] = (i << 17) | (i << 6) | 14;

		for (i = 0; i < COEFF_SIZE; i = i+1)
			coeff_mem[i] = 1 >> i;
	end
`endif


	/**** staging ****/

	reg                 s1_en;
	wire [        31:0] s1_insn;

	reg                 s2_en;
	reg  [        31:0] s2_insn;

	reg                 s3_en;
	reg  [        31:0] s3_insn;

	reg                 s4_en;
	reg  [        31:0] s4_insn;
	reg  [ NB*SZ*8-1:0] s4_coeff;

	reg                 s5_en;
	reg  [        31:0] s5_insn;

	reg                 s6_en;
	reg  [        31:0] s6_insn;

	reg                 s7_en;
	reg  [        31:0] s7_insn;
	wire [NB*SZ*16-1:0] s7_prod;

	reg                 s8_en;
	reg  [        31:0] s8_insn;

	assign cmd_ready = 1;
	assign busy = |{s1_en, s2_en, s3_en, s4_en, s5_en, s6_en, s7_en, s8_en};


	/**** stage 1 ****/

	reg [31:0] s1_insn_direct;
	reg [31:0] s1_insn_codemem;
	reg s1_insn_sel;

	assign s1_insn = s1_insn_sel ? s1_insn_codemem : s1_insn_direct;

	always @(posedge clock) begin
		s1_en <= cmd_valid && cmd_ready;
		s1_insn_direct <= cmd_data;
		s1_insn_codemem <= code_mem[cmd_data[16:6]];
		s1_insn_sel <= cmd_data[5:0] == 3;

		if (reset) begin
			s1_en <= 0;
		end
	end


	/**** stage 2 ****/

	always @(posedge clock) begin
		s2_en <= 1;
		s2_insn <= s1_insn;

		mem_rd_addr <= s1_insn[31:17];
		mem_rd_en <= s1_insn[5:0] == 14 || s1_insn[5:0] == 15 || s1_insn[5:0] == 16 ||
				s1_insn[5:0] == 17 || s1_insn[5:0] == 18;

		if (reset || !s1_en) begin
			mem_rd_en <= 0;
			s2_en <= 0;
		end
	end


	/**** stage 3 ****/

	always @(posedge clock) begin
		s3_en <= 1;
		s3_insn <= s2_insn;

		if (reset || !s2_en) begin
			s3_en <= 0;
		end
	end


	/**** stage 4 ****/

	always @(posedge clock) begin
		s4_en <= 1;
		s4_insn <= s3_insn;
		s4_coeff <= coeff_mem[s3_insn[16:6]];

		if (reset || !s3_en) begin
			s4_en <= 0;
		end
	end


	/**** stage 5 ****/

	always @(posedge clock) begin
		s5_en <= 1;
		s5_insn <= s4_insn;

		if (reset || !s4_en) begin
			s5_en <= 0;
		end
	end


	/**** stage 6 ****/

	always @(posedge clock) begin
		s6_en <= 1;
		s6_insn <= s5_insn;

		if (reset || !s5_en) begin
			s6_en <= 0;
		end
	end


	/**** stage 7 ****/

	wire [NB*SZ*8-1:0] mulA = {mem_rdata, mem_rdata};

	mlaccel_compute_mul mul [NB*SZ-1:0] (
		.clock (clock),
		.A(mulA),
		.B(s4_coeff),
		.X(s7_prod)
	);

	always @(posedge clock) begin
		s7_en <= 1;
		s7_insn <= s6_insn;

		if (reset || !s6_en) begin
			s7_en <= 0;
		end
	end


	/**** stage 8 ****/

	reg [23:0] new_acc0;
	reg [23:0] new_acc1;

	wire [23:0] acc0_shifted = $signed(acc0) >>> s7_insn[14:10];
	wire [23:0] acc1_shifted = $signed(acc1) >>> s7_insn[14:10];

	reg [7:0] acc0_saturated;
	reg [7:0] acc1_saturated;

	always @* begin
		new_acc0 = 0;
		new_acc1 = 0;

		for (i = 0; i < SZ; i = i+1) begin
			new_acc0 = new_acc0 + s7_prod[16*i +: 16];
			new_acc1 = new_acc1 + s7_prod[16*(i+SZ) +: 16];
		end
	end

	always @(posedge clock) begin
		s8_en <= 1;
		s8_insn <= s7_insn;

		if (s7_en) begin
			acc0 <= new_acc0;
			acc1 <= new_acc1;
		end

		if (&acc0_shifted[23:7] == |acc0_shifted[23:7])
			acc0_saturated <= acc0_shifted[7:0];
		else
			acc0_saturated <= acc0_shifted[23] << 7;

		if (&acc1_shifted[23:7] == |acc1_shifted[23:7])
			acc1_saturated <= acc1_shifted[7:0];
		else
			acc1_saturated <= acc1_shifted[23] << 7;

		if (reset || !s7_en) begin
			s8_en <= 0;
		end
	end


	/**** write back ****/

	always @(posedge clock) begin
		mem_wr_en <= s8_insn[5:0] == 12 ? (s8_insn[15] ? {s8_insn[7], s8_insn[6]} : {s8_insn[6], s8_insn[7]}) : 0;
		mem_wr_addr <= s8_insn[31:16];
		mem_wr_wdata <= s8_insn[15] ? {acc0_saturated, acc1_saturated} : {acc1_saturated, acc0_saturated};

		if (reset || !s8_en) begin
			mem_wr_en <= 0;
		end
	end
endmodule

module mlaccel_compute_mul (
	input         clock,
	input  [ 7:0] A, B,
	output [15:0] X
);
	reg [15:0] r1, r2, r3;

	always @(posedge clock) begin
		// pseudo-mul: a*b=b*a, 1*a=a, 0*a=0
		r1 <= A && B ? $signed(A) + $signed(B) - 1 : 0;
		r2 <= r1;
		r3 <= r2;
	end

	assign X = r3;
endmodule
