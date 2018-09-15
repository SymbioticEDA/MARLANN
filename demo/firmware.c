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

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_leds (*(volatile uint32_t*)0x02000000)
#define reg_uart (*(volatile uint32_t*)0x02000004)
#define reg_qpio (*(volatile uint32_t*)0x02000008)

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

void print(const char *p)
{
	while (*p)
		putchar(*(p++));
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
	if (v >= 100) {
		print(">=100");
		return;
	}

	if      (v >= 90) { putchar('9'); v -= 90; }
	else if (v >= 80) { putchar('8'); v -= 80; }
	else if (v >= 70) { putchar('7'); v -= 70; }
	else if (v >= 60) { putchar('6'); v -= 60; }
	else if (v >= 50) { putchar('5'); v -= 50; }
	else if (v >= 40) { putchar('4'); v -= 40; }
	else if (v >= 30) { putchar('3'); v -= 30; }
	else if (v >= 20) { putchar('2'); v -= 20; }
	else if (v >= 10) { putchar('1'); v -= 10; }

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
	for (int i = 0; i < 100000; i++) {
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
	reg_qpio = 0x8C000000;
	reg_qpio = 0x88000000;
}

void ml_send(uint8_t byte)
{
	reg_qpio = 0x88000f00 | (byte >> 4);
	reg_qpio = 0x88010f00 | (byte & 15);
	reg_qpio = 0x88000000;
}

uint8_t ml_recv()
{
	uint8_t byte = 0;

	reg_qpio = 0x88000000;
	byte |= (reg_qpio & 15) << 4;

	reg_qpio = 0x88010000;
	byte |= reg_qpio & 15;

	reg_qpio = 0x88000000;
	return byte;
}

void ml_stop()
{
	reg_qpio = 0x8C000000;
	reg_qpio = 0x00000000;
}

// --------------------------------------------------------

void ml_write(int addr, const uint8_t *data, int len)
{
	ml_start();
	ml_send(0x21);
	for (int i = 0; i < len; i++)
		ml_send(data[i]);

	ml_start();
	ml_send(0x23);
	ml_send(addr);
	ml_send(addr >> 8);
	ml_send(len >> 2);
	ml_recv();
	while (ml_recv() != 0) { }

	ml_stop();
}

void ml_read(int addr, uint8_t *data, int len)
{
	ml_start();
	ml_send(0x24);
	ml_send(addr);
	ml_send(addr >> 8);
	ml_send(len >> 2);
	ml_recv();
	while (ml_recv() != 0) { }

	ml_start();
	ml_send(0x22);
	ml_recv();
	for (int i = 0; i < len; i++)
		data[i] = ml_recv();

	ml_stop();
}

// --------------------------------------------------------

void main()
{
	print("Booting..\n");

	char wbuf0[64] = "Hello World! This is a test and if you can\n";
	char wbuf1[64] = "read this then everything is working fine.\n";
	char rbuf[64];

	ml_write(0, wbuf0, 64);
	ml_write(70, wbuf1, 64);

	ml_read(0, rbuf, 64);
	print(rbuf);

	ml_read(70, rbuf, 64);
	print(rbuf);

	reg_leds = 127;
	while (1) {
		print("Press ENTER to continue..\n");
		if (getchar_timeout() == '\r')
			break;
	}

	print("READY.\n");
}
