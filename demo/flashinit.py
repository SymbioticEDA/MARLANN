#!/usr/bin/env python3

sig_clk = ["0"] * 256
sig_csb = ["1"] * 256
sig_io0 = ["z"] * 256
sig_io1 = ["z"] * 256
sig_io2 = ["z"] * 256
sig_io3 = ["z"] * 256
cursor = 10

def spi_start():
    global sig_clk, sig_csb, sig_io0, sig_io1, sig_io2, sig_io3, cursor
    sig_clk[cursor] = "0"
    sig_csb[cursor] = "1"
    cursor += 1
    sig_clk[cursor] = "0"
    sig_csb[cursor] = "0"
    cursor += 0

def spi_stop():
    global sig_clk, sig_csb, sig_io0, sig_io1, sig_io2, sig_io3, cursor
    sig_clk[cursor] = "0"
    sig_csb[cursor] = "0"
    cursor += 1
    sig_clk[cursor] = "0"
    sig_csb[cursor] = "1"
    cursor += 0

def spi_wbyte(value):
    global sig_clk, sig_csb, sig_io0, sig_io1, sig_io2, sig_io3, cursor

    for i in range(7, -1, -1):
        sig_clk[cursor] = "0"
        sig_csb[cursor] = "0"
        sig_io0[cursor] = "1" if ((value >> i) & 1) else "0"
        cursor += 1
        sig_clk[cursor] = "1"
        sig_csb[cursor] = "0"
        sig_io0[cursor] = "1" if ((value >> i) & 1) else "0"
        cursor += 1

def qpi_wbyte(value, release=False):
    global sig_clk, sig_csb, sig_io0, sig_io1, sig_io2, sig_io3, cursor

    sig_clk[cursor] = "0"
    sig_csb[cursor] = "0"
    sig_io0[cursor] = "1" if (value & 0x10) else "0"
    sig_io1[cursor] = "1" if (value & 0x20) else "0"
    sig_io2[cursor] = "1" if (value & 0x40) else "0"
    sig_io3[cursor] = "1" if (value & 0x80) else "0"
    cursor += 1

    sig_clk[cursor] = "1"
    sig_csb[cursor] = "0"
    sig_io0[cursor] = "1" if (value & 0x10) else "0"
    sig_io1[cursor] = "1" if (value & 0x20) else "0"
    sig_io2[cursor] = "1" if (value & 0x40) else "0"
    sig_io3[cursor] = "1" if (value & 0x80) else "0"
    cursor += 1

    sig_clk[cursor] = "0"
    sig_csb[cursor] = "0"
    sig_io0[cursor] = "1" if (value & 0x01) else "0"
    sig_io1[cursor] = "1" if (value & 0x02) else "0"
    sig_io2[cursor] = "1" if (value & 0x04) else "0"
    sig_io3[cursor] = "1" if (value & 0x08) else "0"
    cursor += 1

    sig_clk[cursor] = "1"
    sig_csb[cursor] = "0"
    if release:
        sig_io0[cursor] = "z"
        sig_io1[cursor] = "z"
        sig_io2[cursor] = "z"
        sig_io3[cursor] = "z"
    else:
        sig_io0[cursor] = "1" if (value & 0x01) else "0"
        sig_io1[cursor] = "1" if (value & 0x02) else "0"
        sig_io2[cursor] = "1" if (value & 0x04) else "0"
        sig_io3[cursor] = "1" if (value & 0x08) else "0"
    cursor += 1

def qpi_read(cnt):
    global sig_clk, sig_csb, sig_io0, sig_io1, sig_io2, sig_io3, cursor

    for _ in range(cnt):
        sig_clk[cursor] = "0"
        sig_csb[cursor] = "0"
        sig_io0[cursor] = "z"
        sig_io1[cursor] = "z"
        sig_io2[cursor] = "z"
        sig_io3[cursor] = "z"
        cursor += 1

        sig_clk[cursor] = "1"
        sig_csb[cursor] = "0"
        sig_io0[cursor] = "z"
        sig_io1[cursor] = "z"
        sig_io2[cursor] = "z"
        sig_io3[cursor] = "z"
        cursor += 1

# End CRM
spi_start()
spi_wbyte(0xFF)
spi_stop()

# Exit QPI Mode
spi_start()
qpi_wbyte(0xFF)
spi_stop()

# Release Power-down
spi_start()
spi_wbyte(0xAB)
spi_stop()

# Volatile SR Write Enable
spi_start()
spi_wbyte(0x50)
spi_stop()

# Write Status Register 2  (set QE, clear others)
spi_start()
spi_wbyte(0x31)
spi_wbyte(0x02)
spi_stop()

# Enter QPI Mode
spi_start()
spi_wbyte(0x38)
spi_stop()

# Fast Read Quad I/O (EBh) in QPI Mode
spi_start()
qpi_wbyte(0xEB)
qpi_wbyte(0x10)
qpi_wbyte(0x00)
qpi_wbyte(0x00)
qpi_wbyte(0xA5, release=True)
qpi_read(8)
spi_stop()

with open("flashinit.hex", "w") as f:
    for i in range(256):
        assert sig_clk[i] in ["0", "1"]
        assert sig_csb[i] in ["0", "1"]
        assert sig_io0[i] in ["0", "1", "z"]
        assert sig_io1[i] in ["0", "1", "z"]
        assert sig_io2[i] in ["0", "1", "z"]
        assert sig_io3[i] in ["0", "1", "z"]

        value = 0

        if sig_clk[i] == "1":
            value |= 0x200;
        if sig_csb[i] == "1":
            value |= 0x100;

        if sig_io0[i] in ["0", "1"]:
            value |= 0x010;
        if sig_io1[i] in ["0", "1"]:
            value |= 0x020;
        if sig_io2[i] in ["0", "1"]:
            value |= 0x040;
        if sig_io3[i] in ["0", "1"]:
            value |= 0x080;

        if sig_io0[i] == "1":
            value |= 0x001;
        if sig_io1[i] == "1":
            value |= 0x002;
        if sig_io2[i] == "1":
            value |= 0x004;
        if sig_io3[i] == "1":
            value |= 0x008;

        print("%04x" % value, file=f)
