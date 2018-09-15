module mlaccel_compute #(
	parameter integer NB = 2,
	parameter integer SZ = 8
) (
	input                 clock,
	input                 reset,
	output reg            busy,

	input                 cmd_valid,
	output reg            cmd_ready,
	input      [    31:0] cmd_data,

	output reg            mem_ren,
	output reg [     1:0] mem_wen,
	output reg [    15:0] mem_addr,
	output reg [    15:0] mem_wdata,
	input      [SZ*8-1:0] mem_rdata
);
	initial begin
		busy = 0;
		cmd_ready = 1;
		mem_ren = 0;
		mem_wen = 0;
		mem_addr = 0;
		mem_wdata = 0;
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
