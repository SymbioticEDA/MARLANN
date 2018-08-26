module mlaccel_memory (
	input             clock,
	input      [16:0] addr,
	input      [ 3:0] wen,
	input      [31:0] wdata,
	output reg [31:0] rdata
);
	wire [2:0] shamt = 4 - addr[1:0];
	reg [1:0] shamt_rev_q;

	wire [3:0] shifted_wen = {wen, wen} >> shamt[1:0];
	wire [31:0] shifted_wdata = {wdata, wdata} >> (shamt[1:0] * 8);
	wire [31:0] shifted_rdata;

	wire [3:0] addr_offsets = 8'b 0000_1111 >> shamt;

	mlaccel_memory_spram ram [3:0] (
		.clock(clock),
		.wen(shifted_wen),
		.addr({
			addr[16:2] + addr_offsets[3],
			addr[16:2] + addr_offsets[2],
			addr[16:2] + addr_offsets[1],
			addr[16:2] + addr_offsets[0]
		}),
		.wdata(shifted_wdata),
		.rdata(shifted_rdata)
	);

	always @(posedge clock) begin
		shamt_rev_q <= addr[1:0];
		rdata <= {shifted_rdata, shifted_rdata} >> (shamt_rev_q * 8);
	end
endmodule

module mlaccel_memory_spram (
	input         clock,
	input         wen,
	input  [14:0] addr,
	input  [ 7:0] wdata,
	output [ 7:0] rdata
);
	wire [15:0] dout;
	reg addr0_q;

	assign rdata = addr0_q ? dout[15:8] : dout[7:0];

	always @(posedge clock) begin
		addr0_q <= addr[0];
	end

	SB_SPRAM256KA spram (
		.ADDRESS(addr[14:1]),
		.DATAIN({wdata, wdata}),
		.MASKWREN({{2{addr[0]}}, {2{!addr[0]}}}),
		.WREN(wen),
		.CHIPSELECT(1'b1),
		.CLOCK(clock),
		.STANDBY(1'b0),
		.SLEEP(1'b0),
		.POWEROFF(1'b1),
		.DATAOUT(dout)
	);
endmodule
