`timescale 1 ns / 1 ps

module ctrlsoc (
	// 12 MHz clock
	input clk,

	// RS232
	input  ser_rx,
	output ser_tx,

	// SPI Flash
	output flash_clk,
	output flash_csb,
	inout  flash_io0,
	inout  flash_io1,
	inout  flash_io2,
	inout  flash_io3,

	// Status LEDs
	output ledr_n,
	output ledg_n,

	// LEDs and Buttons (PMOD 2)
	output led1,
	output led2,
	output led3,
	output led4,
	output led5,
	input  btn1,
	input  btn2,
	input  btn3,

	// mlaccel (PMOD 1A)
	output ml_clk,
	output ml_csb,
	inout  ml_io0,
	inout  ml_io1,
	inout  ml_io2,
	inout  ml_io3,
	input  ml_irq,
	input  ml_err
);
	reg resetn = 0;
	reg [5:0] reset_cnt = 0;

	always @(posedge clk) begin
		reset_cnt <= reset_cnt + !(&reset_cnt);
		resetn <= &reset_cnt;
	end

	wire trap;
	reg buserror = 0;

	assign ledr_n = !(trap || buserror);
	assign ledg_n = flash_csb;

	reg led5_r, led4_r, led3_r, led2_r, led1_r;

	assign led1 = btn1;
	assign led2 = btn2;
	assign led3 = btn3;
	assign led4 = led4_r;
	assign led5 = led5_r;

	wire        mem_valid;
	wire        mem_instr;
	reg         mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0]  mem_wstrb;
	reg  [31:0] mem_rdata;

	reg spram0_rselect;
	reg spram1_rselect;
	wire [31:0] spram0_rdata;
	wire [31:0] spram1_rdata;

	wire flash_ready;
	wire [31:0] flash_rdata;

	picorv32 #(
		.ENABLE_COUNTERS(0),
		.CATCH_MISALIGN(1),
		.CATCH_ILLINSN(1),
		.PROGADDR_RESET(1024*1024),
		.STACKADDR(128*1024)
	) cpu (
		.clk       (clk      ),
		.resetn    (resetn   ),
		.trap      (trap     ),
		.mem_valid (mem_valid),
		.mem_instr (mem_instr),
		.mem_ready (mem_ready || flash_ready),
		.mem_addr  (mem_addr ),
		.mem_wdata (mem_wdata),
		.mem_wstrb (mem_wstrb),

		.mem_rdata (
			spram0_rselect ? spram0_rdata :
			spram1_rselect ? spram1_rdata :
			flash_ready ? flash_rdata :
			mem_rdata
		)
	);

	wire addr_spram0 = mem_addr < 64*1024;
	wire addr_spram1 = (mem_addr < 128*1024) && !(mem_addr < 64*1024);
	wire addr_flash = (mem_addr < 16*1024*1024) && !(mem_addr < 128*1024);

	always @(posedge clk) begin
		mem_ready <= 0;
		spram0_rselect <= 0;
		spram1_rselect <= 0;

		if (!resetn) begin
			buserror <= 0;
		end else
		if (mem_valid && !mem_ready && !buserror) begin
			(* parallel_case *)
			case (1'b1)
				addr_spram0: begin
					mem_ready <= 1;
					spram0_rselect <= 1;
				end
				addr_spram1: begin
					mem_ready <= 1;
					spram1_rselect <= 1;
				end
				addr_flash: begin
					buserror <= |mem_wstrb;
				end
				mem_addr == 32'h 01000000: begin
					mem_ready <= 1;
					if (mem_wstrb[0]) begin
						{led5_r, led4_r, led3_r, led2_r, led1_r} <= mem_wdata;
					end
					mem_rdata <= {btn3, btn2, btn1, led5, led4, led3, led2, led1};
				end
				default: begin
					buserror <= 1;
				end
			endcase
		end
	end

	ctrlsoc_spram spram0 (
		.clk    (clk),
		.enable (addr_spram0 && mem_valid && !mem_ready),
		.addr   (mem_addr[15:0]),
		.wstrb  (mem_wstrb),
		.wdata  (mem_wdata),
		.rdata  (spram0_rdata)
	);

	ctrlsoc_spram spram1 (
		.clk    (clk),
		.enable (addr_spram1 && mem_valid && !mem_ready),
		.addr   (mem_addr[15:0]),
		.wstrb  (mem_wstrb),
		.wdata  (mem_wdata),
		.rdata  (spram1_rdata)
	);

	ctrlsoc_flashio flashio (
		.clk       (clk      ),
		.resetn    (resetn   ),

		.valid     (addr_flash && mem_valid && !flash_ready),
		.ready     (flash_ready),
		.addr      (mem_addr[23:0]),
		.rdata     (flash_rdata),

		.flash_clk (flash_clk),
		.flash_csb (flash_csb),
		.flash_io0 (flash_io0),
		.flash_io1 (flash_io1),
		.flash_io2 (flash_io2),
		.flash_io3 (flash_io3)
	);
endmodule

module ctrlsoc_spram (
	input         clk,
	input         enable,
	input  [15:0] addr,
	input  [ 3:0] wstrb,
	input  [31:0] wdata,
	output [31:0] rdata
);
	SB_SPRAM256KA spram_hi (
		.ADDRESS(addr[15:2]),
		.DATAIN(wdata[31:16]),
		.MASKWREN({{2{wstrb[3]}}, {2{wstrb[2]}}}),
		.WREN(enable && |mem_wstrb),
		.CHIPSELECT(enable),
		.CLOCK(clk),
		.STANDBY(1'b0),
		.SLEEP(1'b0),
		.POWEROFF(1'b1),
		.DATAOUT(rdata[31:16])
	);

	SB_SPRAM256KA spram_lo (
		.ADDRESS(addr[15:2]),
		.DATAIN(wdata[15:0]),
		.MASKWREN({{2{wstrb[1]}}, {2{wstrb[0]}}}),
		.WREN(enable && |mem_wstrb),
		.CHIPSELECT(enable),
		.CLOCK(clk),
		.STANDBY(1'b0),
		.SLEEP(1'b0),
		.POWEROFF(1'b1),
		.DATAOUT(rdata[15:0])
	);
endmodule

module ctrlsoc_flashio (
	input         clk,
	input         resetn,

	input         valid,
	output reg    ready,
	input  [23:0] addr,
	output [31:0] rdata,

	output reg    flash_clk,
	output reg    flash_csb,
	inout         flash_io0,
	inout         flash_io1,
	inout         flash_io2,
	inout         flash_io3
);
	reg  flash_io0_oe, flash_io1_oe, flash_io2_oe, flash_io3_oe;
	reg  flash_io0_do, flash_io1_do, flash_io2_do, flash_io3_do;
	wire flash_io0_di, flash_io1_di, flash_io2_di, flash_io3_di;

	SB_IO #(
		.PIN_TYPE(6'b 1010_01),
		.PULLUP(1'b 0)
	) flash_io_buf [3:0] (
		.PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
		.OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
		.D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
		.D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
	);

	reg [15:0] init_sequence_rom [0:255];
	reg [8:0] init_sequence_cnt;
	reg [15:0] init_sequence_word;
	wire init_sequence_done = init_sequence_cnt[8];

	initial begin
		$readmemh("flashinit.hex", init_sequence_rom);
	end

	always @(posedge clk) begin
		if (!resetn) begin
			init_sequence_cnt <= 0;
		end else begin
			init_sequence_cnt <= init_sequence_cnt + !init_sequence_done;
		end
		init_sequence_word <= init_sequence_rom[init_sequence_cnt[7:0]];
	end

	always @(posedge clk) begin
		if (!init_sequence_done) begin
			ready <= 0;
			flash_clk <= init_sequence_word[9];
			flash_csb <= init_sequence_word[8];
			{flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe} <= init_sequence_word[7:4];
			{flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do} <= init_sequence_word[3:0];
		end else begin
		end
	end
endmodule
