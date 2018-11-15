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
	/********** QPI Interface **********/

    wire [7:0] din_data;
    wire [7:0] dout_data;
	wire spi_active;
    wire spi_miso;
    wire spi_mosi;
    wire din_start;
    wire din_ready;
    wire dout_valid;
    wire dout_ready;

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
	reg glitch_guard_di_toggle;
	reg glitch_guard_di_toggle_q0;
    reg di_toggle;

	always @(negedge clock) begin
		glitch_guard_clock_q0 <= spi_clk_di;
		glitch_guard_di_stx_q0 <= di_stx;
		glitch_guard_di_toggle_q0 <= di_toggle;
	end

	always @(posedge clock) begin
		// protect against clock glitching: logic level of clock
		// must have been low before posedge and high before negedge
		glitch_guard_posedge <= !glitch_guard_clock_q0;
		glitch_guard_negedge <= glitch_guard_clock_q0;
		glitch_guard_di_toggle <= glitch_guard_di_toggle_q0;

		// delay some signals to protect against double clocking
		glitch_guard_di_stx <= glitch_guard_di_stx_q0;
	end

	always @(posedge spi_clk_di, posedge spi_csb_di) begin
		if (spi_csb_di) begin
			di_data <= 0;
			di_start <= 1;
			di_stx <= 1;
		end else begin
			if (glitch_guard_posedge) begin
				di_data[7-di_bit] <= spi_mosi;
                di_bit <= di_bit + 1;
                /*
				if (glitch_guard_di_toggle)
					di_stx <= 0;
				if (glitch_guard_di_toggle && !glitch_guard_di_stx)
					di_start <= 0;
                */
			end
		end
	end

	always @(negedge spi_clk_di, posedge spi_csb_di) begin
		if (spi_csb_di) begin
			//spi_io_do <= 0;
			do_bit <= 0;
			do_validx <= 0;
			do_datax <= 0;
		end else begin
			if (glitch_guard_negedge) begin
				if (di_start)
					do_bit <= 0;
				else
					do_bit <= do_bit + 1;

                spi_miso <= do_data[do_bit];

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
	assign dout_ready = do_bit == 7 && dout_valid && !dout_busy;
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
		if (~&di_bit) begin
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
