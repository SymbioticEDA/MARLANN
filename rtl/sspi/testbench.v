`default_nettype none
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

module testbench;
	reg clock;

	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);

		#5 clock = 0;
		forever #5 clock = ~clock;
	end

	reg spi_csb;
	reg spi_clk;

	reg spi_mosi_reg = 0;
	reg spi_miso_reg = 0;
	reg spi_io2_reg;
	reg spi_io3_reg;

    wire spi_mosi = spi_mosi_reg;
	wire spi_miso = spi_miso_reg;

	wire spi_rdy;
	wire spi_err;

	mlaccel_top uut (
		.clock   (clock  ),
		.spi_csb (spi_csb),
		.spi_clk (spi_clk),
		.spi_miso (spi_miso),
    	.spi_mosi (spi_mosi),
		.spi_rdy (spi_rdy),
		.spi_err (spi_err)
	);

	reg [7:0] xfer;

	task xfer_posedge;
		begin
			if ($random & 15) begin
				#17;
				spi_clk = 1;
			end else begin
				#17;
				spi_clk = 1;
				#1;
				spi_clk = 0;
				#1;
				spi_clk = 1;
			end
		end
	endtask

	task xfer_negedge;
		begin
			if ($random & 15) begin
				#17;
				spi_clk = 0;
			end else begin
				#17;
				spi_clk = 0;
				#1;
				spi_clk = 1;
				#1;
				spi_clk = 0;
			end
		end
	endtask

	task xfer_start;
		begin
			#17;
			spi_csb = 0;
		end
	endtask

	task xfer_send;
		begin
			xfer_negedge;
			spi_mosi_reg = xfer[7];
			xfer_posedge;

			xfer_negedge;
			spi_mosi_reg = xfer[6];
			xfer_posedge;

			xfer_negedge;
			spi_mosi_reg = xfer[5];
			xfer_posedge;
            
			xfer_negedge;
			spi_mosi_reg = xfer[4];
			xfer_posedge;

			xfer_negedge;
			spi_mosi_reg = xfer[3];
			xfer_posedge;

			xfer_negedge;
			spi_mosi_reg = xfer[2];
			xfer_posedge;

			xfer_negedge;
			spi_mosi_reg = xfer[1];
			xfer_posedge;

			xfer_negedge;
			spi_mosi_reg = xfer[0];
			xfer_posedge;

		end
	endtask

	task xfer_send_byte;
		input [7:0] data;
		begin
			xfer = data;
			xfer_send;
		end
	endtask

	task xfer_send_hword;
		input [15:0] data;
		begin
			xfer = data[7:0];
			xfer_send;
			xfer = data[15:8];
			xfer_send;
		end
	endtask

	task xfer_send_word;
		input [31:0] data;
		begin
			xfer = data[7:0];
			xfer_send;
			xfer = data[15:8];
			xfer_send;
			xfer = data[23:16];
			xfer_send;
			xfer = data[31:24];
			xfer_send;
		end
	endtask

	task xfer_wait;
		begin
			xfer_negedge;
			xfer_posedge;

			xfer_negedge;
			xfer_posedge;
		end
	endtask

	task xfer_recv;
		begin
			xfer_negedge;
			xfer[7] = spi_miso;
            xfer_posedge;

			xfer_negedge;
			xfer[6] = spi_miso;
            xfer_posedge;

			xfer_negedge;
			xfer[5] = spi_miso;
            xfer_posedge;

			xfer_negedge;
			xfer[4] = spi_miso;
            xfer_posedge;

			xfer_negedge;
			xfer[3] = spi_miso;
            xfer_posedge;

			xfer_negedge;
			xfer[2] = spi_miso;
            xfer_posedge;

			xfer_negedge;
			xfer[1] = spi_miso;
            xfer_posedge;

			xfer_negedge;
			xfer[0] = spi_miso;
            xfer_posedge;

		end
	endtask

	task xfer_stop;
		begin
			if ($random & 3) begin
				xfer_negedge;
			end else begin
				#17;
			end

			xfer = 'bx;

			#17;
			spi_csb = 1;
			#17;
			spi_clk = 1;
		end
	endtask

	integer cursor, len, i;
	reg [7:0] indata [0:128*1024-1];
	reg [7:0] outdata [0:128*1024-1];

	initial begin
		$readmemh("../asm/demo.hex", indata);
		$readmemh("../sim/demo_out.hex", outdata);
	end

	initial begin
		xfer_stop;

		#200;

		$display("Uploading demo kernel.");
		$fflush;

		cursor = 0;
		while (cursor < 128*1024) begin
			if (indata[cursor] !== 8'h XX) begin
				len = 1;
				while ((len < 1024) && (len+cursor < 128*1024) &&
						(indata[cursor+len] !== 8'h XX)) len = len+1;

				if ((cursor % 2) != 0) begin
					cursor = cursor - 1;
					len = len + 1;
				end

				if ((len % 4) != 0) begin
					len = len - (len % 4) + 4;
				end

				if (len > 1024) begin
					len = 1024;
				end

				$display("  uploading %4d bytes to 0x%05x", len, cursor);
				$fflush;

				xfer_start;
				xfer_send_byte(8'h 21);
				for (i = 0; i < len; i = i+1)
					xfer_send_byte(indata[cursor+i]);
				xfer_stop;

				xfer_start;
				xfer_send_byte(8'h 23);
				xfer_send_hword(cursor >> 1);
				xfer_send_byte(len >> 2);
				xfer_wait;
				xfer_recv;
				while (xfer != 8'h 00)
					xfer_recv;
				xfer_stop;

				cursor = cursor + len;
			end else begin
				cursor = cursor + 1;
			end
		end

		$display("Readback.");
		$fflush;

		cursor = 0;
		while (cursor < 128*1024) begin
			if (indata[cursor] !== 8'h XX) begin
				len = 1;
				while ((len < 1024) && (len+cursor < 128*1024) &&
						(indata[cursor+len] !== 8'h XX)) len = len+1;

				if ((cursor % 2) != 0) begin
					cursor = cursor - 1;
					len = len + 1;
				end

				if ((len % 4) != 0) begin
					len = len - (len % 4) + 4;
				end

				if (len > 1024) begin
					len = 1024;
				end

				$display("  downloading %4d bytes from 0x%05x", len, cursor);
				$fflush;

				xfer_start;
				xfer_send_byte(8'h 24);
				xfer_send_hword(cursor >> 1);
				xfer_send_byte(len >> 2);
				xfer_wait;
				xfer_recv;
				while (xfer != 8'h 00)
					xfer_recv;
				xfer_stop;

				xfer_start;
				xfer_send_byte(8'h 22);
				xfer_wait;
				for (i = 0; i < len; i = i+1) begin
					xfer_recv;
					if (indata[cursor+i] !== 8'h XX && indata[cursor+i] !== xfer) begin
						$display("ERROR at %d: expected 0x%02x, got 0x%02x", cursor+i, indata[cursor+i], xfer);
					end
				end
				xfer_stop;

				cursor = cursor + len;
			end else begin
				cursor = cursor + 1;
			end
		end

		$display("Running kernel.");
		$fflush;

		xfer_start;
		xfer_send_byte(8'h 25);
		xfer_send_hword(16'h 0000);
		xfer_stop;

		#20;

		xfer_start;
		xfer_send_byte(8'h 20);
		xfer_wait;
		while (xfer != 8'h 00)
			xfer_recv;
		xfer_stop;

		$display("Checking results.");
		$fflush;

		cursor = 0;
		while (cursor < 128*1024) begin
			if (outdata[cursor] !== 8'h XX) begin
				len = 1;
				while ((len < 1024) && (len+cursor < 128*1024) &&
						(outdata[cursor+len] !== 8'h XX)) len = len+1;

				if ((cursor % 2) != 0) begin
					cursor = cursor - 1;
					len = len + 1;
				end

				if ((len % 4) != 0) begin
					len = len - (len % 4) + 4;
				end

				if (len > 1024) begin
					len = 1024;
				end

				$display("  downloading %4d bytes from 0x%05x", len, cursor);
				$fflush;

				xfer_start;
				xfer_send_byte(8'h 24);
				xfer_send_hword(cursor >> 1);
				xfer_send_byte(len >> 2);
				xfer_wait;
				xfer_recv;
				while (xfer != 8'h 00)
					xfer_recv;
				xfer_stop;

				xfer_start;
				xfer_send_byte(8'h 22);
				xfer_wait;
				for (i = 0; i < len; i = i+1) begin
					xfer_recv;
					if (outdata[cursor+i] !== 8'h XX && outdata[cursor+i] !== xfer) begin
						$display("ERROR at %d: expected 0x%02x, got 0x%02x", cursor+i, outdata[cursor+i], xfer);
					end
				end
				xfer_stop;

				cursor = cursor + len;
			end else begin
				cursor = cursor + 1;
			end
		end

		$display("Done.");
		$fflush;

		repeat (100) @(posedge clock);
		$finish;
	end
endmodule
