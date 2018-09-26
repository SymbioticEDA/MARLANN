/*
 *  Copyright (C) 2018  David Shah <david@symbioticeda.com>
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

#include "camera.h"
#define CAMERA_BASE 0x03000000

#define reg_camera_i2c (*(volatile uint32_t*)CAMERA_BASE)
#define reg_camera_fb  ((volatile uint32_t*)(CAMERA_BASE + 0x8000))

static void i2c_delay() {
    for (volatile int i = 0; i < 10; i++)
        ;
}

static void set_i2c_io(uint8_t sda, uint8_t scl) {
    reg_camera_i2c = ((scl & 0x1) << 1) | (sda & 0x1);
    i2c_delay();
}

static void i2c_start() {
	set_i2c_io(1, 1);
	set_i2c_io(0, 1);
	set_i2c_io(0, 0);
}

static void i2c_send(uint8_t data) {
	for (int i = 7; i >= 0; i--) {
		uint8_t bit = (data >> i) & 0x1;
		set_i2c_io(bit, 0);
		set_i2c_io(bit, 1);
		set_i2c_io(bit, 0);
	}
	set_i2c_io(1, 0);
	set_i2c_io(1, 1);
	set_i2c_io(1, 0);
}

static void i2c_stop() {
	set_i2c_io(0, 0);
	set_i2c_io(0, 1);
	set_i2c_io(1, 1);
}

void camera_i2c_write(uint16_t address, uint8_t data) {
    i2c_start();
    i2c_send(0x10 << 1);
    i2c_send((address >> 8) & 0xFF);
    i2c_send(address & 0xFF);
    i2c_send(data);
    i2c_stop();
}

const int framelength = 666;
const int linelength = 3448;

void camera_init() {
	// Based on "Preview Setting" from a Linux driver
	camera_i2c_write(0x0100,  0x00); //standby mode
	camera_i2c_write(0x30EB,  0x05); //mfg specific access begin
	camera_i2c_write(0x30EB,  0x0C); //
	camera_i2c_write(0x300A,  0xFF); //
	camera_i2c_write(0x300B,  0xFF); //
	camera_i2c_write(0x30EB,  0x05); //
	camera_i2c_write(0x30EB,  0x09); //mfg specific access end
	camera_i2c_write(0x0114,  0x01); //CSI_LANE_MODE: 2-lane
	camera_i2c_write(0x0128,  0x00); //DPHY_CTRL: auto mode (?)
	camera_i2c_write(0x012A,  0x18); //EXCK_FREQ[15:8] = 24MHz
	camera_i2c_write(0x012B,  0x00); //EXCK_FREQ[7:0]
	camera_i2c_write(0x0160,  ((framelength >> 8) & 0xFF)); //framelength
	camera_i2c_write(0x0161,  (framelength & 0xFF));
	camera_i2c_write(0x0162,  ((linelength >> 8) & 0xFF));
	camera_i2c_write(0x0163,  (linelength & 0xFF));
	camera_i2c_write(0x0164,  0x00); //X_ADD_STA_A[11:8]
	camera_i2c_write(0x0165,  0x00); //X_ADD_STA_A[7:0]
	camera_i2c_write(0x0166,  0x0A); //X_ADD_END_A[11:8]
	camera_i2c_write(0x0167,  0x00); //X_ADD_END_A[7:0]
	camera_i2c_write(0x0168,  0x00); //Y_ADD_STA_A[11:8]
	camera_i2c_write(0x0169,  0x00); //Y_ADD_STA_A[7:0]
	camera_i2c_write(0x016A,  0x07); //Y_ADD_END_A[11:8]
	camera_i2c_write(0x016B,  0x80); //Y_ADD_END_A[7:0]
	camera_i2c_write(0x016C,  0x02); //x_output_size[11:8] = 640
	camera_i2c_write(0x016D,  0x80); //x_output_size[7:0]
	camera_i2c_write(0x016E,  0x01); //y_output_size[11:8] = 480
	camera_i2c_write(0x016F,  0xE0); //y_output_size[7:0]
	camera_i2c_write(0x0170,  0x01); //X_ODD_INC_A
	camera_i2c_write(0x0171,  0x01); //Y_ODD_INC_A
	camera_i2c_write(0x0174,  0x02); //BINNING_MODE_H_A = x4-binning
	camera_i2c_write(0x0175,  0x02); //BINNING_MODE_V_A = x4-binning
	camera_i2c_write(0x018C,  0x08); //CSI_DATA_FORMAT_A[15:8]
	camera_i2c_write(0x018D,  0x08); //CSI_DATA_FORMAT_A[7:0]
	camera_i2c_write(0x0301,  0x08); //VTPXCK_DIV
	camera_i2c_write(0x0303,  0x01); //VTSYCK_DIV
	camera_i2c_write(0x0304,  0x03); //PREPLLCK_VT_DIV
	camera_i2c_write(0x0305,  0x03); //PREPLLCK_OP_DIV
	camera_i2c_write(0x0306,  0x00); //PLL_VT_MPY[10:8]
	camera_i2c_write(0x0307,  0x14); //PLL_VT_MPY[7:0]
	camera_i2c_write(0x0309,  0x08); //OPPXCK_DIV
	camera_i2c_write(0x030B,  0x02); //OPSYCK_DIV
	camera_i2c_write(0x030C,  0x00); //PLL_OP_MPY[10:8]
	camera_i2c_write(0x030D,  0x0A); //PLL_OP_MPY[7:0]
	camera_i2c_write(0x455E,  0x00); //??
	camera_i2c_write(0x471E,  0x4B); //??
	camera_i2c_write(0x4767,  0x0F); //??
	camera_i2c_write(0x4750,  0x14); //??
	camera_i2c_write(0x4540,  0x00); //??
	camera_i2c_write(0x47B4,  0x14); //??
	camera_i2c_write(0x4713,  0x30); //??
	camera_i2c_write(0x478B,  0x10); //??
	camera_i2c_write(0x478F,  0x10); //??
	camera_i2c_write(0x4793,  0x10); //??
	camera_i2c_write(0x4797,  0x0E); //??
	camera_i2c_write(0x479B,  0x0E); //??

	//camera_i2c_write(0x0157,  232); // ANA_GAIN_GLOBAL_A
	//camera_i2c_write(0x0257,  232); // ANA_GAIN_GLOBAL_B


	//camera_i2c_write(0x0600,  0x00); // Test pattern: disable
	//camera_i2c_write(0x0601,  0x00); // Test pattern: disable

#if 0
	camera_i2c_write(0x0600,  0x00); // Test pattern: solid colour
	camera_i2c_write(0x0601,  0x01); //

	camera_i2c_write(0x0602,  0x02); // Test pattern: red
	camera_i2c_write(0x0603,  0xAA); //

	camera_i2c_write(0x0604,  0x02); // Test pattern: greenR
	camera_i2c_write(0x0605,  0xAA); //

	camera_i2c_write(0x0606,  0x02); // Test pattern: blue
	camera_i2c_write(0x0607,  0xAA); //

	camera_i2c_write(0x0608,  0x02); // Test pattern: greenB
	camera_i2c_write(0x0609,  0xAA); //


	camera_i2c_write(0x0624,  0x0A); // Test pattern width
	camera_i2c_write(0x0625,  0x00); //

	camera_i2c_write(0x0626,  0x07); // Test pattern height
	camera_i2c_write(0x0627,  0x80); //


#endif

	camera_i2c_write(0x0100, 0x01);
}

void acquire_image(uint8_t *buffer) {
    for (int y = 0; y < 30; y++)
        for (int x = 0; x < 40; x++)
            *(buffer++) = reg_camera_fb[((y << 6) | x) << 2];
}
