CTRLSOC_DEV =
MLACCEL_DEV =
SEED = 1234

#####################################################################

testbench.vcd: testbench flashinit.hex ctrlsoc_fw.hex
	vvp -N testbench

testbench: testbench.v spiflash.v ctrlsoc.v picorv32.v ../rtl/top.v ../rtl/sequencer.v ../rtl/compute.v ../rtl/memory.v
	iverilog -s testbench -o $@ testbench.v spiflash.v ctrlsoc.v picorv32.v ../rtl/top.v ../rtl/sequencer.v ../rtl/compute.v ../rtl/memory.v $(shell yosys-config --datdir/ice40/cells_sim.v)

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

ctrlsoc_fw.elf: sections.lds start.S firmware.c demodat.inc
	riscv32-unknown-elf-gcc -O1 -Wall -Wextra -march=rv32i -Wl,-Bstatic,-T,sections.lds,--strip-debug -ffreestanding -nostdlib -o ctrlsoc_fw.elf start.S firmware.c

ctrlsoc_fw.hex: ctrlsoc_fw.elf
	riscv32-unknown-elf-objcopy -O verilog ctrlsoc_fw.elf ctrlsoc_fw.hex

ctrlsoc_fw.bin: ctrlsoc_fw.elf
	riscv32-unknown-elf-objcopy -O binary ctrlsoc_fw.elf ctrlsoc_fw.bin

demodat.inc: demodat.py ../asm/demo.hex ../sim/demo_out.hex
	python3 demodat.py | fmt -s > demodat.inc

prog_ctrlsoc: ctrlsoc.bin ctrlsoc_fw.bin
	iceprog $(CTRLSOC_DEV) ctrlsoc.bin
	iceprog $(CTRLSOC_DEV) -o 1M ctrlsoc_fw.bin

prog_ctrlsoc_fw: ctrlsoc_fw.bin
	iceprog $(CTRLSOC_DEV) -o 1M ctrlsoc_fw.bin

reset_ctrlsoc:
	iceprog $(CTRLSOC_DEV) -t

erase_ctrlsoc:
	iceprog $(CTRLSOC_DEV) -e 1

clean_ctrlsoc:
	rm -f ctrlsoc.json ctrlsoc.log ctrlsoc.asc ctrlsoc.bin ctrlsoc.rpt
	rm -f ctrlsoc_fw.elf ctrlsoc_fw.hex ctrlsoc_fw.bin

#####################################################################

mlaccel.blif: mlaccel.json
mlaccel.json: ../rtl/top.v ../rtl/sequencer.v ../rtl/compute.v ../rtl/memory.v
	yosys -ql mlaccel.log -p 'synth_ice40 -top mlaccel_top -json mlaccel.json -blif mlaccel.blif' ../rtl/top.v ../rtl/sequencer.v ../rtl/compute.v ../rtl/memory.v

mlaccel.asc: mlaccel.pcf mlaccel.json
	nextpnr-ice40 --seed $(SEED) --freq 25 --up5k --asc mlaccel.asc --pcf mlaccel.pcf --json mlaccel.json

mlaccel.bin: mlaccel.asc
	icetime -d up5k -c 12 -mtr mlaccel.rpt mlaccel.asc
	icepack mlaccel.asc mlaccel.bin

mlaccel_arachne.asc: mlaccel.pcf mlaccel.blif
	arachne-pnr -s $(SEED) -d 5k -o mlaccel_arachne.asc -p mlaccel.pcf mlaccel.blif

mlaccel_arachne.bin: mlaccel_arachne.asc
	icetime -d up5k -c 12 -mtr mlaccel_arachne.rpt mlaccel_arachne.asc
	icepack mlaccel_arachne.asc mlaccel_arachne.bin

prog_mlaccel: mlaccel.bin
	iceprog $(MLACCEL_DEV) mlaccel.bin

prog_mlaccel_arachne: mlaccel_arachne.bin
	iceprog $(MLACCEL_DEV) mlaccel_arachne.bin

reset_mlaccel:
	iceprog $(MLACCEL_DEV) -t

erase_mlaccel:
	iceprog $(MLACCEL_DEV) -e 1

clean_mlaccel:
	rm -f mlaccel.json mlaccel.log mlaccel.asc mlaccel.bin mlaccel.rpt
	rm -f mlaccel.blif mlaccel_arachne.asc mlaccel_arachne.bin mlaccel_arachne.rpt

#####################################################################

multisynth:
	set -ex; for i in {100..120}; do \
		make clean; \
		make -j4 SEED=$$i mlaccel.bin mlaccel_arachne.bin; \
		cp mlaccel.rpt report_nextpnr_$$i.txt; \
		cp mlaccel_arachne.rpt report_arachne_$$i.txt; \
	done

clean: clean_ctrlsoc clean_mlaccel
	rm -f testbench.vcd testbench flashinit.hex demodat.inc

.PHONY: multisynth clean prog_ctrlsoc prog_ctrlsoc_fw reset_ctrlsoc erase_ctrlsoc clean_ctrlsoc
.PHONY: prog_mlaccel prog_mlaccel_arachne reset_mlaccel erase_mlaccel clean_mlaccel
