CTRLSOC_DEV = -d d:001/071
MLACCEL_DEV = -d d:001/072

#####################################################################

testbench.vcd: testbench flashinit.hex ctrlsoc_fw.hex
	vvp -N testbench

testbench: testbench.v spiflash.v ctrlsoc.v picorv32.v
	iverilog -s testbench -o $@ testbench.v spiflash.v ctrlsoc.v picorv32.v ../rtl/spram.v $(shell yosys-config --datdir/ice40/cells_sim.v)

flashinit.hex: flashinit.py
	python3 flashinit.py

#####################################################################

ctrlsoc.json: ctrlsoc.v picorv32.v flashinit.hex
	yosys -ql ctrlsoc.log -p 'synth_ice40 -top ctrlsoc -json ctrlsoc.json' ctrlsoc.v picorv32.v

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
	iceprog $(CTRLSOC_DEV) ctrlsoc.bin
	iceprog $(CTRLSOC_DEV) -o 1M ctrlsoc_fw.bin

prog_ctrlsoc_fw: ctrlsoc_fw.bin
	iceprog $(CTRLSOC_DEV) -o 1M ctrlsoc_fw.bin

reset_ctrlsoc:
	iceprog $(CTRLSOC_DEV) -t

erase_ctrlsoc:
	iceprog $(CTRLSOC_DEV) -e 1

#####################################################################

mlaccel.json: ../rtl/top.v ../rtl/memory.v
	yosys -ql mlaccel.log -p 'synth_ice40 -top mlaccel_top -json mlaccel.json' ../rtl/top.v ../rtl/memory.v

mlaccel.asc: mlaccel.pcf mlaccel.json
	nextpnr-ice40 --freq 13 --up5k --asc mlaccel.asc --pcf mlaccel.pcf --json mlaccel.json

mlaccel.bin: mlaccel.asc
	icetime -d up5k -c 12 -mtr mlaccel.rpt mlaccel.asc
	icepack mlaccel.asc mlaccel.bin

prog_mlaccel: mlaccel.bin
	iceprog $(MLACCEL_DEV) mlaccel.bin

reset_mlaccel:
	iceprog $(MLACCEL_DEV) -t

erase_mlaccel:
	iceprog $(MLACCEL_DEV) -e 1

#####################################################################

clean:
	rm -f testbench.vcd testbench flashinit.hex
	rm -f ctrlsoc.json ctrlsoc.log ctrlsoc.asc ctrlsoc.bin ctrlsoc.rpt
	rm -f ctrlsoc_fw.elf ctrlsoc_fw.hex ctrlsoc_fw.bin
	rm -f mlaccel.json mlaccel.log mlaccel.asc mlaccel.bin mlaccel.rpt

.PHONY: clean prog_ctrlsoc prog_ctrlsoc_fw reset_ctrlsoc erase_ctrlsoc prog_mlaccel reset_mlaccel erase_mlaccel
