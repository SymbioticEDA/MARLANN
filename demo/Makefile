all: ctrlsoc.bin ctrlsoc_fw.bin

ctrlsoc.json: ctrlsoc.v spimemio.v simpleuart.v picorv32.v
	yosys -ql ctrlsoc.log -p 'synth_ice40 -top ctrlsoc -json ctrlsoc.json' $^

ctrlsoc.asc: ctrlsoc.pcf ctrlsoc.json
	nextpnr-ice40 --freq 13 --up5k --asc ctrlsoc.asc --pcf ctrlsoc.pcf --json ctrlsoc.json

ctrlsoc.bin: ctrlsoc.asc
	icetime -d up5k -c 12 -mtr ctrlsoc.rpt ctrlsoc.asc
	icepack ctrlsoc.asc ctrlsoc.bin

ctrlsoc_fw.elf: sections.lds start.s firmware.c
	riscv32-unknown-elf-gcc -march=rv32i -Wl,-Bstatic,-T,sections.lds,--strip-debug -ffreestanding -nostdlib -o ctrlsoc_fw.elf start.s firmware.c

ctrlsoc_fw.hex: ctrlsoc_fw.elf
	riscv32-unknown-elf-objcopy -O verilog ctrlsoc_fw.elf ctrlsoc_fw.hex

ctrlsoc_fw.bin: ctrlsoc_fw.elf
	riscv32-unknown-elf-objcopy -O binary ctrlsoc_fw.elf ctrlsoc_fw.bin

prog_ctrlsoc: ctrlsoc.bin ctrlsoc_fw.bin
	iceprog ctrlsoc.bin
	iceprog -o 1M ctrlsoc_fw.bin
