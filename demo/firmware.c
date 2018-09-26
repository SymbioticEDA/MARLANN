/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
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

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "camera/camera.h"

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define RUN_LOOP          0
#define SER_TIMEOUT 1500000
#define ML_TIMEOUT      100
#define NUM_IMAGES       10
#define IMAGE_NOPS    10000

#define reg_leds  (*(volatile uint32_t*)0x02000000)
#define reg_uart  (*(volatile uint32_t*)0x02000004)
#define reg_qpio  (*(volatile uint32_t*)0x02000008)
#define reg_reset (*(volatile uint32_t*)0x0200000c)

#include "demodat.inc"

// --------------------------------------------------------

void *memset(void *s, int c, size_t n)
{
	char *p = s;
	while (n--)
		*(p++) = c;
	return s;
}

// --------------------------------------------------------

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart = c;
}

void error()
{
	putchar('<');
	putchar('E');
	putchar('R');
	putchar('R');
	putchar('O');
	putchar('R');
	putchar('>');
	while (1) { }
	reg_reset = 1;
}

void print(const char *p)
{
	for (int i = 0;; i++) {
		if (p[i] == 0)
			break;
		if (i == 256)
			error();
		putchar(p[i]);
	}
}

void print_hex(uint32_t v, int digits)
{
	for (int i = 7; i >= 0; i--) {
		char c = "0123456789abcdef"[(v >> (4*i)) & 15];
		if (c == '0' && i >= digits) continue;
		putchar(c);
		digits = i;
	}
}

void print_dec(uint32_t v)
{
	if (v >= 10000) {
		print(">=10000");
		return;
	}

	if (v >= 1000) goto dig4;
	if (v >= 100) goto dig3;
	if (v >= 10) goto dig2;
	goto dig1;

dig4:
	if      (v >= 9000) { putchar('9'); v -= 9000; }
	else if (v >= 8000) { putchar('8'); v -= 8000; }
	else if (v >= 7000) { putchar('7'); v -= 7000; }
	else if (v >= 6000) { putchar('6'); v -= 6000; }
	else if (v >= 5000) { putchar('5'); v -= 5000; }
	else if (v >= 4000) { putchar('4'); v -= 4000; }
	else if (v >= 3000) { putchar('3'); v -= 3000; }
	else if (v >= 2000) { putchar('2'); v -= 2000; }
	else if (v >= 1000) { putchar('1'); v -= 1000; }
	else putchar('0');

dig3:
	if      (v >= 900) { putchar('9'); v -= 900; }
	else if (v >= 800) { putchar('8'); v -= 800; }
	else if (v >= 700) { putchar('7'); v -= 700; }
	else if (v >= 600) { putchar('6'); v -= 600; }
	else if (v >= 500) { putchar('5'); v -= 500; }
	else if (v >= 400) { putchar('4'); v -= 400; }
	else if (v >= 300) { putchar('3'); v -= 300; }
	else if (v >= 200) { putchar('2'); v -= 200; }
	else if (v >= 100) { putchar('1'); v -= 100; }
	else putchar('0');

dig2:
	if      (v >= 90) { putchar('9'); v -= 90; }
	else if (v >= 80) { putchar('8'); v -= 80; }
	else if (v >= 70) { putchar('7'); v -= 70; }
	else if (v >= 60) { putchar('6'); v -= 60; }
	else if (v >= 50) { putchar('5'); v -= 50; }
	else if (v >= 40) { putchar('4'); v -= 40; }
	else if (v >= 30) { putchar('3'); v -= 30; }
	else if (v >= 20) { putchar('2'); v -= 20; }
	else if (v >= 10) { putchar('1'); v -= 10; }
	else putchar('0');

dig1:
	if      (v >= 9) { putchar('9'); v -= 9; }
	else if (v >= 8) { putchar('8'); v -= 8; }
	else if (v >= 7) { putchar('7'); v -= 7; }
	else if (v >= 6) { putchar('6'); v -= 6; }
	else if (v >= 5) { putchar('5'); v -= 5; }
	else if (v >= 4) { putchar('4'); v -= 4; }
	else if (v >= 3) { putchar('3'); v -= 3; }
	else if (v >= 2) { putchar('2'); v -= 2; }
	else if (v >= 1) { putchar('1'); v -= 1; }
	else putchar('0');
}

int getchar_timeout()
{
	for (int i = 0; i < SER_TIMEOUT; i++) {
		int32_t c = reg_uart;
		if (c > 0)
			return c;
	}
	return -1;
}

char getchar()
{
	while (1) {
		int32_t c = reg_uart;
		if (c > 0)
			return c;
	}
}

// --------------------------------------------------------

void ml_start()
{
	reg_qpio = 0x80020000;
	reg_qpio = 0x80000000;
}

void ml_send(uint8_t byte)
{
	reg_qpio = 0x80000f00 | (byte >> 4);
	reg_qpio = 0x80010f00 | (byte >> 4);
	reg_qpio = 0x80000f00 | (byte & 15);
	reg_qpio = 0x80010f00 | (byte & 15);
}

uint8_t ml_recv()
{
	uint8_t byte = 0;

	reg_qpio = 0x80000000;
	reg_qpio = 0x80010000;
	byte |= (reg_qpio & 15) << 4;
	reg_qpio = 0x80000000;
	reg_qpio = 0x80010000;
	byte |= reg_qpio & 15;

	return byte;
}

void ml_stop()
{
	reg_qpio = 0x80000fff;
	reg_qpio = 0x80020000;
}

void ml_finish()
{
	reg_qpio = 0x00000000;
}

void ml_clear_setup()
{
	ml_start();
	ml_send(0x21);
	for (int i = 0; i < 1024; i++)
		ml_send(0x00);
	ml_stop();
	ml_finish();
}

void ml_clear_block(int offset, int len)
{
	ml_start();
	ml_send(0x23);
	ml_send(offset >> 1);
	ml_send(offset >> 9);
	ml_send(len >> 2);
	ml_recv();
	for (int i = 0; ml_recv() != 0; i++)
		if (i == ML_TIMEOUT) {
			ml_stop();
			ml_finish();
			print("TIMEOUT");
			error();
		}
	ml_stop();
	ml_finish();
}

void ml_upload(int offset, const char *data, int len)
{
	ml_start();
	ml_send(0x21);
	for (int i = 0; i < len; i++)
		ml_send(data[i]);
	ml_stop();

	ml_start();
	ml_send(0x23);
	ml_send(offset >> 1);
	ml_send(offset >> 9);
	ml_send(len >> 2);
	ml_recv();
	for (int i = 0; ml_recv() != 0; i++)
		if (i == ML_TIMEOUT) {
			ml_stop();
			ml_finish();
			print("TIMEOUT");
			error();
		}
	ml_stop();

	ml_finish();
}

void ml_upload_buf(int offset, const char *data, int len)
{
	char buffer[1024];
	for (int i = 0; i < len; i++)
		buffer[i] = data[i];

	ml_start();
	ml_send(0x21);
	for (int i = 0; i < len; i++)
		ml_send(buffer[i]);
	ml_stop();

	ml_start();
	ml_send(0x23);
	ml_send(offset >> 1);
	ml_send(offset >> 9);
	ml_send(len >> 2);
	ml_recv();
	for (int i = 0; ml_recv() != 0; i++)
		if (i == ML_TIMEOUT) {
			ml_stop();
			ml_finish();
			print("TIMEOUT");
			error();
		}
	ml_stop();

	ml_finish();
}

void ml_download(int offset, char *data, int len)
{
	ml_start();
	ml_send(0x24);
	ml_send(offset >> 1);
	ml_send(offset >> 9);
	ml_send(len >> 2);
	ml_recv();
	for (int i = 0; ml_recv() != 0; i++)
		if (i == ML_TIMEOUT) {
			ml_stop();
			ml_finish();
			print("TIMEOUT");
			error();
		}
	ml_stop();

	ml_start();
	ml_send(0x22);
	ml_recv();
	for (int j = 0; j < len; j++)
		data[j] = ml_recv();
	ml_stop();

	ml_finish();
}

void ml_run(int start)
{
	ml_start();
	ml_send(0x25);
	ml_send(start >> 1);
	ml_send(start >> 9);
	ml_stop();

	ml_start();
	ml_send(0x20);
	ml_recv();
	while (ml_recv() != 0) { }
	ml_stop();

	ml_finish();
}

void ml_test()
{
	for (int i = 0; i < 4; i++)
	{
		char buffer[128];
		char buffer2[128];
		char *p;

		if (i == 0) {
			print("<QPI_TEST_PATTERN_0> ");
			p = "Testing QPI connection to accelerator.\n";
		}

		if (i == 1) {
			p = "This is QPI test message two of four.\n";
			print("<QPI_TEST_PATTERN_1> ");
		}

		if (i == 2) {
			p = "And this is the third QPI test message.\n";
			print("<QPI_TEST_PATTERN_2> ");
		}

		if (i == 3) {
			p = "If you can read this then QPI works fine, maybe.\n";
			print("<QPI_TEST_PATTERN_3> ");
		}

		for (int j = 0; j < 128; j++)
			if ((buffer[j] = *(p++)) == 0)
				break;

		ml_start();
		ml_send(0x21);
		for (int i = 0; buffer[i]; i++)
			ml_send(buffer[i]);
		ml_send(0);
		ml_stop();

		p = buffer2;

		ml_start();
		ml_send(0x22);
		ml_recv();
		for (int i = 0; i < 128; i++) {
			char c = ml_recv();
			*(p++) = c;
			if (!c) break;
			putchar(c);
		}
		ml_stop();

		ml_finish();

		for (int i = 0; buffer[i]; i++)
			if (buffer[i] != buffer2[i]) {
				print("Error in byte ");
				print_dec(i);
				print(": got ");
				print_dec(buffer2[i]);
				print(", expected ");
				print_dec(buffer[i]);
				print(".\n");
				error();
			}
	}
}

// --------------------------------------------------------

void print_image() {
    uint8_t buf[30*40];
    print("Acquiring image\n");
    acquire_image(buf);
    print("----------------------------------------\n");

    int addr = 0;
    for (int y = 0; y < 30; y++) {
        for (int x = 0; x < 40; x++) {
           print_hex(buf[addr++], 2);
           print(" ");
        }
        print("\n");
    }
}

// --------------------------------------------------------

void main()
{
	print("\n\n\n\n\n");
	print("Booting..\n");

        camera_init();
        print ("Initialised camera\n");
	for (int ii=0; ii< NUM_IMAGES; ++ii) {
		print_image();
		for (volatile int i = 0; i < IMAGE_NOPS; i++)
			;
	}

	ml_test();
	print("\n");
	camera_init();
	print ("Initialised camera\n");

	reg_leds = 127;
	while (!RUN_LOOP) {
		print("Press ENTER to continue..\n");
		if (getchar_timeout() == '\r')
			break;
	}

	ml_test();
	print("\n");
	print("Clearing..\n");

	ml_clear_setup();

	for (int i = 0; i < (int)sizeof(demo_hex_data); i += 1024)
	{
		int len = sizeof(demo_hex_data) - i;
		if (len > 1024)
			len = 1024;

		print("  clearing ");
		print_dec(len);
		print(" bytes at 0x");
		print_hex(demo_hex_start+i, 5);
		print(".\n");

		ml_clear_block(demo_hex_start+i, len);
	}

	for (int i = 0; i < (int)sizeof(demo_out_hex_data); i += 1024)
	{
		int len = sizeof(demo_out_hex_data) - i;
		if (len > 1024)
			len = 1024;

		print("  clearing ");
		print_dec(len);
		print(" bytes at 0x");
		print_hex(demo_out_hex_start+i, 5);
		print(".\n");

		ml_clear_block(demo_out_hex_start+i, len);
	}

	print("Uploading..\n");
	for (int i = 0; i < (int)sizeof(demo_hex_data); i += 1024)
	{
		int len = sizeof(demo_hex_data) - i;
		if (len > 1024)
			len = 1024;

		print("  writing ");
		print_dec(len);
		print(" bytes to 0x");
		print_hex(demo_hex_start+i, 5);
		print(".\n");

		ml_upload_buf(demo_hex_start+i, demo_hex_data+i, len);
	}

	print("Checking..\n");
	for (int i = 0; i < (int)sizeof(demo_hex_data); i += 1024)
	{
		int len = sizeof(demo_hex_data) - i;
		if (len > 1024)
			len = 1024;

		print("  checking ");
		print_dec(len);
		print(" bytes at 0x");
		print_hex(demo_hex_start+i, 5);
		print(":");

		char buffer[1024];
		ml_download(demo_hex_start+i, buffer, len);

		int errcount = 0;
		for (int j = 0; j < len; j++) {
			if (buffer[j] != demo_hex_data[i+j])
				errcount++;
		}

		if (errcount != 0) {
			print(" detected ");
			print_dec(errcount);
			print(" errors!\n");
			print("      /----------------- readback ------------------\\");
			print("      /------------------ original -----------------\\\n");
			for (int j = 0; j < len; j += 16)
			{
				print("     ");
				for (int k = 0; k < 16; k++) {
					print(" ");
					if (i+j+k >= (int)sizeof(demo_out_hex_data))
						print("XX");
					else if (buffer[j+k] == demo_hex_data[i+j+k])
						print("--");
					else
						print_hex(buffer[j+k], 2);
				}
				print("     ");
				for (int k = 0; k < 16; k++) {
					print(" ");
					if (i+j+k >= (int)sizeof(demo_out_hex_data))
						print("XX");
					else
						print_hex(demo_hex_data[i+j+k], 2);
				}
				print("\n");
			}
			error();
		} else {
			print(" ok\n");
		}
	}

	print("Running..\n");
	ml_run(0);

	print("Downloading..\n");
	for (int i = 0; i < (int)sizeof(demo_out_hex_data); i += 1024)
	{
		int len = sizeof(demo_out_hex_data) - i;
		if (len > 1024)
			len = 1024;

		print("  checking ");
		print_dec(len);
		print(" bytes at 0x");
		print_hex(demo_out_hex_start+i, 5);
		print(":");

		char buffer[1024];
		ml_download(demo_out_hex_start+i, buffer, len);

		int errcount = 0;
		for (int j = 0; j < len; j++) {
			if (buffer[j] != demo_out_hex_data[i+j])
				errcount++;
		}

		if (errcount != 0) {
			print(" detected ");
			print_dec(errcount);
			print(" errors!\n");
			print("      /----------------- readback ------------------\\");
			print("      /------------------ original -----------------\\\n");
			for (int j = 0; j < len; j += 16)
			{
				print("     ");
				for (int k = 0; k < 16; k++) {
					print(" ");
					if (i+j+k >= (int)sizeof(demo_out_hex_data))
						print("XX");
					else if (buffer[j+k] == demo_out_hex_data[i+j+k])
						print("--");
					else
						print_hex(buffer[j+k], 2);
				}
				print("     ");
				for (int k = 0; k < 16; k++) {
					print(" ");
					if (i+j+k >= (int)sizeof(demo_out_hex_data))
						print("XX");
					else
						print_hex(demo_out_hex_data[i+j+k], 2);
				}
				print("\n");
			}
			error();
		} else {
			print(" ok\n");
		}
	}

	print("Check PASSED. Reboot.\n");
	reg_reset = 1;
	return;
}
