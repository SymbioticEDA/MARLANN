#!/usr/bin/env python3

demo_hex_start = None
demo_hex_data = list()

demo_out_hex_start = None
demo_out_hex_data = list()

with open("../asm/demo.hex", "r") as f:
    for line in f:
        if line[0] == '@':
            assert demo_hex_start is None
            demo_hex_start = int(line[1:], 16)
        else:
            for token in line.split():
                demo_hex_data.append("0x%02X" % int(token, 16))

with open("../sim/demo_out.hex", "r") as f:
    for line in f:
        if line[0] == '@':
            assert demo_out_hex_start is None
            demo_out_hex_start = int(line[1:], 16)
        else:
            for token in line.split():
                demo_out_hex_data.append("0x%02X" % int(token, 16))

print("static const int demo_hex_start = %d;" % demo_hex_start)
print("static const char demo_hex_data[] = { %s };" % ", ".join(demo_hex_data))

print("static const int demo_out_hex_start = %d;" % demo_out_hex_start)
print("static const char demo_out_hex_data[] = { %s };" % ", ".join(demo_out_hex_data))
