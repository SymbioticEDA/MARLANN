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
	input  [63:0] mem_rdata,

	output        tick_simd,
	output        tick_nosimd
);
	integer i;

	reg [31:0] code_mem [0:CODE_SIZE-1];
	reg [64*NB-1:0] coeff_mem [0:COEFF_SIZE-1];

	reg [31:0] acc0, acc1;

	reg [16:0] VBP, LBP, SBP;
	reg [ 8:0] CBP;

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

`ifdef FORMAL_MLOCK_CHECK
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
	reg  [   NB*64-1:0] s4_coeff;

	reg                 s5_en;
	reg  [        31:0] s5_insn;

	reg                 s6_en;
	reg  [        31:0] s6_insn;

	reg                 s7_en;
	reg  [        31:0] s7_insn;
	wire [  NB*128-1:0] s7_prod;

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

	reg s2_tick_simd;

	always @(posedge clock) begin
		s2_en <= 0;
		s2_insn <= s1_insn;
		s2_tick_simd <= 0;

		mem_rd0_en <= 0;
		mem_rd0_addr <= 'bx;

		if (!reset && s1_en && !s1_stall) begin
			s2_en <= 1;

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
					s2_tick_simd <= 1;
				end
			endcase
		end
	end

	assign tick_simd = s2_tick_simd;
	assign tick_nosimd = s2_en && !tick_simd;


	/**** stage 3 ****/

	always @(posedge clock) begin
		s3_en <= 0;
		s3_insn <= s2_insn;

		if (!reset && s2_en) begin
			s3_en <= 1;
		end
	end


	/**** stage 4 ****/

	always @(posedge clock) begin
		s4_en <= 0;
		s4_insn <= s3_insn;
		s4_coeff <= coeff_mem[s3_insn[14:6] + CBP];

		if (!reset && s3_en) begin
			s4_en <= 1;

			/* SetCBP, AddCBP */
			if (s3_insn[5:0] == 14 || s3_insn[5:0] == 15) begin
				CBP <= s3_insn[14:6] + (s3_insn[0] ? CBP : 0);
			end
		end
	end


	/**** stage 5 ****/

	always @(posedge clock) begin
		s5_en <= 0;
		s5_insn <= s4_insn;

		mem_rd1_en <= 0;
		mem_rd1_addr <= 'bx;

		if (!reset && s4_en) begin
			s5_en <= 1;

			/* LoadCode */
			if (s4_insn[5:0] == 4) begin
				code_mem[s4_insn[14:6]] <= mem_rdata[31:0];
			end

			/* LoadCoeff0 */
			if (s4_insn[5:0] == 5) begin
				coeff_mem[s4_insn[14:6]][63:0] <= mem_rdata;
			end

			/* LoadCoeff1 */
			if (s4_insn[5:0] == 6) begin
				coeff_mem[s4_insn[14:6]][128:64] <= mem_rdata;
			end

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
		end
	end


	/**** stage 6 ****/

	always @(posedge clock) begin
		s6_en <= 0;
		s6_insn <= s5_insn;

		if (!reset && s5_en) begin
			s6_en <= 1;
		end
	end


	/**** stage 7 ****/

	wire [NB*64-1:0] mulA = {mem_rdata, mem_rdata};

	mlaccel_compute_mul mul [NB*8-1:0] (
		.clock (clock),
		.A(mulA),
		.B(s4_coeff),
		.X(s7_prod)
	);

	always @(posedge clock) begin
		s7_en <= 0;
		s7_insn <= s6_insn;

		if (!reset && s6_en) begin
			s7_en <= 1;
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

		for (i = 0; i < 8; i = i+1) begin
			new_acc0_add = $signed(new_acc0_add) + $signed(s7_prod[16*i +: 16]);
			new_acc1_add = $signed(new_acc1_add) + $signed(s7_prod[16*(i+8) +: 16]);

			new_acc0_max = ($signed(new_acc0_max) > $signed(s7_prod[16*i +: 16])) ? new_acc0_max : s7_prod[16*i +: 16];
			new_acc1_max = ($signed(new_acc1_max) > $signed(s7_prod[16*(i+8) +: 16])) ? new_acc1_max : s7_prod[16*(i+8) +: 16];
		end

		// FIXME
		new_acc0_max = 0;
		new_acc1_max = 0;

		new_acc0 = s7_insn[0] ? new_acc0_max : new_acc0_add;
		new_acc1 = s7_insn[0] ? new_acc1_max : new_acc1_add;
	end

	always @(posedge clock) begin
		s8_en <= 0;
		s8_insn <= s7_insn;

		if (!reset && s7_en) begin
			s8_en <= 1;

			/* MACC, MMAX, MMACZ, MMAXZ, MMAXN */
			if (s7_insn[5:3] == 3'b 101) begin
				acc0 <= new_acc0;
				acc1 <= new_acc1;
			end

			/* LdSet, LdSet0 */
			if (s7_insn[5:0] == 28 || s7_insn[5:0] == 29) begin
				acc0 <= mem_rdata[31:0];
			end

			/* LdSet, LdSet1 */
			if (s7_insn[5:0] == 28 || s7_insn[5:0] == 30) begin
				acc1 <= mem_rdata[63:32];
			end

			/* LdAdd, LdAdd0 */
			if (s7_insn[5:0] == 32 || s7_insn[5:0] == 33) begin
				acc0 <= acc0 + mem_rdata[31:0];
			end

			/* LdAdd, LdAdd1 */
			if (s7_insn[5:0] == 32 || s7_insn[5:0] == 34) begin
				acc1 <= acc1 + mem_rdata[63:32];
			end

			/* LdMax, LdMax0 */
			if (s7_insn[5:0] == 36 || s7_insn[5:0] == 37) begin
				acc0 <= 0; // FIXME
			end

			/* LdMax, LdMax1 */
			if (s7_insn[5:0] == 36 || s7_insn[5:0] == 38) begin
				acc1 <= 0; // FIXME
			end
		end

		if (&acc0_shifted[31:7] == |acc0_shifted[31:7])
			acc0_saturated <= acc0_shifted[7:0];
		else
			acc0_saturated <= acc0_shifted[31] ? -128 : 127;

		if (&acc1_shifted[31:7] == |acc1_shifted[31:7])
			acc1_saturated <= acc1_shifted[7:0];
		else
			acc1_saturated <= acc1_shifted[31] ? -128 : 127;
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

		if (s8_en) begin
			/* Store, Store0, Store1, ReLU, ReLU0, ReLU1 */
			if (s8_insn[5:3] == 3'b 010) begin
				pre_mem_wr_en <= {!s8_insn[0], !s8_insn[1]};
			end

			/* SetSBP, AddSBP */
			if (s8_insn[5:0] == 12 || s8_insn[5:0] == 13) begin
				SBP <= s8_insn[31:15] + (s8_insn[0] ? SBP : 0);
			end
		end

		if (reset || !s8_en) begin
			pre_mem_wr_en <= 0;
		end
	end


	/**** trace function ****/

`ifdef TRACE
	reg trace_en;
	reg [31:0] trace_insn;
	wire [16:0] trace_maddr = trace_insn[31:15];
	wire [8:0] trace_caddr = trace_insn[14:6];
	wire [5:0] trace_opcode = trace_insn[5:0];

	reg [7*17-1:0] trace_vbp_queue;
	wire [16:0] trace_vbp = trace_vbp_queue >> (17*6);

	reg [4*17-1:0] trace_lbp_queue;
	wire [16:0] trace_lbp = trace_lbp_queue >> (17*3);

	wire [16:0] trace_sbp = SBP;

	reg [5*9-1:0] trace_cbp_queue;
	wire [8:0] trace_cbp = trace_cbp_queue >> (9*4);

	reg [31:0] trace_acc0, trace_acc1;

	wire [7:0] trace_outb0 = pre_mem_wr_wdata[7:0];
	wire [7:0] trace_outb1 = pre_mem_wr_wdata[15:8];
	wire [16:0] trace_outaddr = pre_mem_wr_addr;

	reg [5*64-1:0] trace_mdata_queue;
	wire [63:0] trace_mdata = trace_mdata_queue >> (64*4);

	reg [5*64-1:0] trace_c0data_queue;
	wire [63:0] trace_c0data = trace_c0data_queue >> (64*4);

	reg [5*64-1:0] trace_c1data_queue;
	wire [63:0] trace_c1data = trace_c1data_queue >> (64*4);

	wire [17:0] trace_maddr_plus_vbp = trace_maddr + trace_vbp;
	wire [8:0] trace_caddr_plus_cbp = trace_caddr + trace_cbp;

	always @(posedge clock) begin
		trace_en <= s8_en;
		trace_insn <= s8_insn;

		trace_vbp_queue <= {trace_vbp_queue, VBP};
		trace_lbp_queue <= {trace_lbp_queue, LBP};
		trace_cbp_queue <= {trace_cbp_queue, CBP};

		trace_mdata_queue <= {trace_mdata_queue, mem_rdata};
		trace_c0data_queue <= {trace_c0data_queue, s4_coeff[63:0]};
		trace_c1data_queue <= {trace_c1data_queue, s4_coeff[127:64]};

		trace_acc0 <= acc0;
		trace_acc1 <= acc1;

		if (!reset && trace_en) begin
			case (trace_opcode)
				 8: $display("TRACE %8t: SetVBP 0x%05x // -> 0x%05x", $time, trace_maddr, trace_vbp);
				 9: $display("TRACE %8t: AddVBP 0x%05x // -> 0x%05x", $time, trace_maddr, trace_vbp);
				10: $display("TRACE %8t: SetLBP 0x%05x // -> 0x%05x", $time, trace_maddr, trace_lbp);
				11: $display("TRACE %8t: AddLBP 0x%05x // -> 0x%05x", $time, trace_maddr, trace_lbp);
				12: $display("TRACE %8t: SetSBP 0x%05x // -> 0x%05x", $time, trace_maddr, trace_sbp);
				13: $display("TRACE %8t: AddSBP 0x%05x // -> 0x%05x", $time, trace_maddr, trace_sbp);
				14: $display("TRACE %8t: SetCBP 0x%03x // -> 0x%03x", $time, trace_caddr, trace_cbp);
				15: $display("TRACE %8t: AddCBP 0x%03x // -> 0x%03x", $time, trace_caddr, trace_cbp);

				16: $display("TRACE %8t: Store 0x%05x, 0x%03x // 0x%08x 0x%08x -> 0x%02x 0x%02x @ 0x%05x",
						$time, trace_maddr, trace_caddr, trace_acc0, trace_acc1, trace_outb0, trace_outb1, trace_outaddr);
				17: $display("TRACE %8t: Store0 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x",
						$time, trace_maddr, trace_caddr, trace_acc0, trace_outb0, trace_outaddr);
				18: $display("TRACE %8t: Store1 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x",
						$time, trace_maddr, trace_caddr, trace_acc1, trace_outb1, trace_outaddr+1);

				20: $display("TRACE %8t: ReLU 0x%05x, 0x%03x // 0x%08x 0x%08x -> 0x%02x 0x%02x @ 0x%05x",
						$time, trace_maddr, trace_caddr, trace_acc0, trace_acc1, trace_outb0, trace_outb1, trace_outaddr);
				21: $display("TRACE %8t: ReLU0 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x",
						$time, trace_maddr, trace_caddr, trace_acc0, trace_outb0, trace_outaddr);
				22: $display("TRACE %8t: ReLU1 0x%05x, 0x%03x // 0x%08x -> 0x%02x @ 0x%05x",
						$time, trace_maddr, trace_caddr, trace_acc1, trace_outb1, trace_outaddr+1);

				28: $display("TRACE %8t: LdSet 0x%05x // -> 0x%08x 0x%08x", $time, trace_maddr, trace_acc0, trace_acc1);
				29: $display("TRACE %8t: LdSet0 0x%05x // -> 0x%08x", $time, trace_maddr, trace_acc0);
				30: $display("TRACE %8t: LdSet1 0x%05x // -> 0x%08x", $time, trace_maddr, trace_acc1);

				32: $display("TRACE %8t: LdAdd 0x%05x // -> 0x%08x 0x%08x", $time, trace_maddr, trace_acc0, trace_acc1);
				33: $display("TRACE %8t: LdAdd0 0x%05x // -> 0x%08x", $time, trace_maddr, trace_acc0);
				34: $display("TRACE %8t: LdAdd1 0x%05x // -> 0x%08x", $time, trace_maddr, trace_acc1);

				36: $display("TRACE %8t: LdMax 0x%05x // -> 0x%08x 0x%08x", $time, trace_maddr, trace_acc0, trace_acc1);
				37: $display("TRACE %8t: LdMax0 0x%05x // -> 0x%08x", $time, trace_maddr, trace_acc0);
				38: $display("TRACE %8t: LdMax1 0x%05x // -> 0x%08x", $time, trace_maddr, trace_acc1);

				40: $display("TRACE %8t: MACC 0x%05x, 0x%03x // 0x%016x @ 0x%05x, 0x%016x 0x%016x @ 0x%03x -> 0x%08x 0x%08x",
						$time, trace_maddr, trace_caddr, trace_mdata, trace_maddr_plus_vbp,
						trace_c0data, trace_c1data, trace_caddr_plus_cbp, trace_acc0, trace_acc1);
				41: $display("TRACE %8t: MMAX 0x%05x, 0x%03x // 0x%016x @ 0x%05x, 0x%016x 0x%016x @ 0x%03x -> 0x%08x 0x%08x",
						$time, trace_maddr, trace_caddr, trace_mdata, trace_maddr_plus_vbp,
						trace_c0data, trace_c1data, trace_caddr_plus_cbp, trace_acc0, trace_acc1);
				42: $display("TRACE %8t: MACCZ 0x%05x, 0x%03x // 0x%016x @ 0x%05x, 0x%016x 0x%016x @ 0x%03x -> 0x%08x 0x%08x",
						$time, trace_maddr, trace_caddr, trace_mdata, trace_maddr_plus_vbp,
						trace_c0data, trace_c1data, trace_caddr_plus_cbp, trace_acc0, trace_acc1);
				43: $display("TRACE %8t: MMAXZ 0x%05x, 0x%03x // 0x%016x @ 0x%05x, 0x%016x 0x%016x @ 0x%03x -> 0x%08x 0x%08x",
						$time, trace_maddr, trace_caddr, trace_mdata, trace_maddr_plus_vbp,
						trace_c0data, trace_c1data, trace_caddr_plus_cbp, trace_acc0, trace_acc1);
				45: $display("TRACE %8t: MMAXN 0x%05x, 0x%03x // 0x%016x @ 0x%05x, 0x%016x 0x%016x @ 0x%03x -> 0x%08x 0x%08x",
						$time, trace_maddr, trace_caddr, trace_mdata, trace_maddr_plus_vbp,
						trace_c0data, trace_c1data, trace_caddr_plus_cbp, trace_acc0, trace_acc1);
			endcase
			$fflush;
		end
	end
`endif
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
		r1 <= $signed(A) * $signed(B);
`endif
		r2 <= r1;
		r3 <= r2;
	end

	assign X = r3;
endmodule
