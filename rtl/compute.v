/*
 *  Copyright (C) 2018  Clifford Wolf <clifford@symbioticeda.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

module mlaccel_compute #(
	parameter integer NB = 2,
	parameter integer SZ = 8,
	parameter integer CODE_SIZE = 512,
	parameter integer COEFF_SIZE = 512
) (
	input         clock,
	input         reset,
	output        busy,

	input         cmd_valid,
	output        cmd_ready,
	input  [31:0] cmd_insn,

	output        mem_ren,
	output [ 7:0] mem_wen,
	output [15:0] mem_addr,
	output [63:0] mem_wdata,
	input  [63:0] mem_rdata
);
	integer i;

	reg [31:0] code_mem [0:CODE_SIZE-1];
	reg [8*NB*SZ-1:0] coeff_mem [0:COEFF_SIZE-1];

	reg [31:0] acc0, acc1;

	reg [16:0] VBP, LBP, SBP, CBP;

	reg        mem_rd0_en;
	reg [15:0] mem_rd0_addr;

	reg        mem_rd1_en;
	reg [15:0] mem_rd1_addr;

	reg [ 7:0] mem_wr_en;
	reg [15:0] mem_wr_addr;
	reg [63:0] mem_wr_wdata;

	assign mem_ren = mem_rd0_en || mem_rd1_en;
	assign mem_wen = mem_wr_en;
	assign mem_addr = ({16{mem_rd0_en}} & mem_rd0_addr) | ({16{mem_rd1_en}} & mem_rd1_addr) | ({16{|mem_wr_en}} & mem_wr_addr);
	assign mem_wdata = mem_wr_wdata;

`ifdef FORMAL
	reg init_cycle = 1;

	always @(posedge clock) begin
		init_cycle <= 0;
	end

	always @* begin
		if (init_cycle) begin
			assume (reset);
		end
		if (!reset) begin
			assert ((mem_rd0_en + mem_rd1_en + |mem_wr_en) < 2);
		end
	end
`endif

	wire [16:0] cmd_insn_maddr = cmd_insn[31:15];
	wire [8:0] cmd_insn_caddr = cmd_insn[14:6];
	wire [5:0] cmd_insn_opcode = cmd_insn[5:0];


	/**** staging ****/

	reg                 s1_en;
	wire [        31:0] s1_insn;
	wire                s1_stall;

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


	/**** memory interlock ****/

	reg [7:0] mlock_res;
	reg [7:0] mlock_mask;

	always @* begin
		mlock_mask = 0;

		case (s1_insn[5:0])
			/* LoadCode, LoadCoeff0, LoadCoeff1 */
			4, 5, 6: mlock_mask = 1 << 0;

			/* LdSet, LdSet0, LdSet1, LdAdd, LdAdd0, LdAdd1, LdMax, LdMax0, LdMax1 */
			28, 29, 30, 32, 33, 34, 36, 37, 38: mlock_mask = 1 << 3;

			/* MACC, MMAX, MACCZ, MMAXZ, MMAXN */
			40, 41, 42, 43, 45: mlock_mask = 1 << 0;

			/* Store, Store0, Store1, ReLU, ReLU0, ReLU1 */
			16, 17, 18, 20, 21, 22: mlock_mask = 1 << 7;
		endcase

		if (!s1_en || reset)
			mlock_mask = 0;
	end

	assign s1_stall = |(mlock_res & mlock_mask);

	always @(posedge clock) begin
		mlock_res <= (mlock_res | mlock_mask) >> 1;

		if (reset)
			mlock_res <= 0;
	end

	assign cmd_ready = !s1_stall;

	assign busy = |{s1_en, s2_en, s3_en, s4_en, s5_en, s6_en, s7_en, s8_en};


	/**** stage 1 ****/

	reg [31:0] s1_insn_direct;
	reg [31:0] s1_insn_codemem;
	reg s1_insn_sel;

	assign s1_insn = s1_insn_sel ? s1_insn_codemem : s1_insn_direct;

	wire [16:0] s1_insn_maddr = s1_insn[31:15];
	wire [8:0] s1_insn_caddr = s1_insn[14:6];
	wire [5:0] s1_insn_opcode = s1_insn[5:0];

	always @(posedge clock) begin
		if (!s1_stall) begin
			s1_en <= cmd_valid && cmd_ready;
			s1_insn_direct <= cmd_insn;
			s1_insn_codemem <= code_mem[cmd_insn[14:6]];
			s1_insn_sel <= cmd_insn[5:0] == 3;
		end

		if (reset) begin
			s1_en <= 0;
		end
	end


	/**** stage 2 ****/

	always @(posedge clock) begin
		s2_en <= 1;
		s2_insn <= s1_insn;

		mem_rd0_en <= 0;
		mem_rd0_addr <= 'bx;

		case (s1_insn[5:0])
			/* LoadCode, LoadCoeff0, LoadCoeff1 */
			4, 5, 6: begin
				mem_rd0_en <= 1;
				mem_rd0_addr <= s1_insn[31:15] >> 1;
			end

			/* SetVBP, AddVBP */
			8, 9: begin
				VBP <= s1_insn[31:15] + (s1_insn[0] ? VBP : 0);
			end

			/* MACC, MMAX, MACCZ, MMAXZ, MMAXN */
			40, 41, 42, 43, 45: begin
				mem_rd0_en <= 1;
				mem_rd0_addr <= (s1_insn[31:15] + VBP) >> 1;
			end
		endcase

		if (reset || !s1_en || s1_stall) begin
			mem_rd0_en <= 0;
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
		s4_coeff <= coeff_mem[s3_insn[14:6]];

		if (reset || !s3_en) begin
			s4_en <= 0;
		end
	end


	/**** stage 5 ****/

	always @(posedge clock) begin
		s5_en <= 1;
		s5_insn <= s4_insn;

		/* LoadCode */
		if (s4_en && s4_insn[5:0] == 4) begin
			code_mem[s4_insn[14:6]] <= mem_rdata[31:0];
		end

		/* LoadCoeff0 */
		if (s4_en && s4_insn[5:0] == 5) begin
			coeff_mem[s4_insn[14:6]][63:0] <= mem_rdata;
		end

		/* LoadCoeff1 */
		if (s4_en && s4_insn[5:0] == 6) begin
			coeff_mem[s4_insn[14:6]][128:64] <= mem_rdata;
		end

		mem_rd1_en <= 0;
		mem_rd1_addr <= 'bx;

		case (s4_insn[5:0])
			/* SetLBP, AddLBP */
			10, 11: begin
				LBP <= s4_insn[31:15] + (s4_insn[0] ? LBP : 0);
			end

			/* LdSet, LdSet0, LdSet1, LdAdd, LdAdd0, LdAdd1, LdMax, LdMax0, LdMax1 */
			28, 29, 30, 32, 33, 34, 36, 37, 38: begin
				mem_rd1_en <= 1;
				mem_rd1_addr <= (s4_insn[31:15] + LBP) >> 1;
			end
		endcase

		if (reset || !s4_en) begin
			mem_rd1_en <= 0;
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

	reg [31:0] new_acc0_add;
	reg [31:0] new_acc1_add;

	reg [31:0] new_acc0_max;
	reg [31:0] new_acc1_max;

	reg [31:0] new_acc0;
	reg [31:0] new_acc1;

	wire [31:0] acc0_shifted = $signed(acc0) >>> s7_insn[14:6];
	wire [31:0] acc1_shifted = $signed(acc1) >>> s7_insn[14:6];

	reg [7:0] acc0_saturated;
	reg [7:0] acc1_saturated;

	always @* begin
		new_acc0_add = s7_insn[1] ? 0 : acc0;
		new_acc1_add = s7_insn[1] ? 0 : acc1;

		new_acc0_max = s7_insn[2] ? 32'h 8000_0000 : new_acc0_add;
		new_acc1_max = s7_insn[2] ? 32'h 8000_0000 : new_acc1_add;

		for (i = 0; i < SZ; i = i+1) begin
			new_acc0_add = new_acc0_add + s7_prod[16*i +: 16];
			new_acc1_add = new_acc1_add + s7_prod[16*(i+SZ) +: 16];

			new_acc0_max = ($signed(new_acc0_max) > $signed(s7_prod[16*i +: 16])) ? new_acc0_max : s7_prod[16*i +: 16];
			new_acc1_max = ($signed(new_acc1_max) > $signed(s7_prod[16*(i+SZ) +: 16])) ? new_acc1_max : s7_prod[16*(i+SZ) +: 16];
		end

		// FIXME
		new_acc0_max = 0;
		new_acc1_max = 0;

		new_acc0 = s7_insn[0] ? new_acc0_max : new_acc0_add;
		new_acc1 = s7_insn[0] ? new_acc1_max : new_acc1_add;
	end

	always @(posedge clock) begin
		s8_en <= 1;
		s8_insn <= s7_insn;

		if (s7_en && s7_insn[5:3] == 3'b 101) begin
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

	reg [ 7:0] pre_mem_wr_en;
	reg [16:0] pre_mem_wr_addr;
	reg [63:0] pre_mem_wr_wdata;

	always @* begin
		if (pre_mem_wr_addr[0]) begin
			mem_wr_en = pre_mem_wr_en << 1;
			mem_wr_addr = pre_mem_wr_addr >> 1;
			mem_wr_wdata = pre_mem_wr_wdata << 8;
		end else begin
			mem_wr_en = pre_mem_wr_en;
			mem_wr_addr = pre_mem_wr_addr >> 1;
			mem_wr_wdata = pre_mem_wr_wdata;
		end
	end

	wire [5:0] s8_insn_opcode = s8_insn[5:0];

	always @(posedge clock) begin
		pre_mem_wr_en <= 0;
		pre_mem_wr_addr <= s8_insn[31:15] + SBP;
		pre_mem_wr_wdata <= {
			{8{!s8_insn[2] || !acc1_saturated[7]}} & acc1_saturated,
			{8{!s8_insn[2] || !acc0_saturated[7]}} & acc0_saturated
		};

		/* Store, Store0, Store1, ReLU, ReLU0, ReLU1 */
		if (s8_insn[5:3] == 3'b 010) begin
			pre_mem_wr_en <= {!s8_insn[0], !s8_insn[1]};
		end

		/* SetSBP, AddSBP */
		if (s8_insn[5:0] == 12 || s8_insn[5:0] == 13) begin
			SBP <= s8_insn[31:15] + (s8_insn[0] ? SBP : 0);
		end

		if (reset || !s8_en) begin
			pre_mem_wr_en <= 0;
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
`ifdef SYNTHESIS
		// pseudo-mul: a*b=b*a, 1*a=a, 0*a=0
		r1 <= A && B ? $signed(A) + $signed(B) - 1 : 0;
`else
		r1 <= A * B;
`endif
		r2 <= r1;
		r3 <= r2;
	end

	assign X = r3;
endmodule
