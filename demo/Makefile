CTRLSOC_DEV =
MARLANN_DEV =
SEED = 1234

CAMERA_RTL =					\
	camera/phy/dphy_iserdes.v		\
	camera/phy/byte_aligner.v		\
	camera/phy/word_combiner.v		\
	camera/csi/header_ecc.v			\
	camera/csi/rx_packet_handler.v		\
	camera/link/csi_rx_ice40.v		\
	camera/misc/downsample.v		\
	camera/cameraif.v

SPI_RTL = 					\
	spiflash.v

SOC_RTL =					\
	ctrlsoc.v				\
	picorv32.v

ML_RTL =					\
	../rtl/top.v				\
	../rtl/sequencer.v			\
	../rtl/compute.v			\
	../rtl/memory.v

SPI_TYPE = QPI

ifeq ($(SPI_TYPE),SPI)
    ML_RTL += ../rtl/spi_client.v
endif

#####################################################################

testbench.vcd: testbench flashinit.hex ctrlsoc_fw.hex
	vvp -N testbench

testbench: testbench.v $(SPI_RTL) $(SOC_RTL) $(ML_RTL) $(CAMERA_RTL)
	iverilog -s testbench -o $@ $^ $(shell yosys-config --datdir/ice40/cells_sim.v)

flashinit.hex: flashinit.py
	python3 flashinit.py

#####################################################################

postsim.vcd: postsim flashinit.hex ctrlsoc_fw.hex
	vvp -N postsim

postsim: testbench.v spiflash.v ctrlsoc_post.v marlann_post.v
	iverilog -s testbench -D VCD_FILENAME='"postsim.vcd"' -o $@ $^ $(shell yosys-config --datdir/ice40/cells_sim.v)

ctrlsoc_post.v: ctrlsoc.asc
	icebox_vlog -s -L -n ctrlsoc -p ctrlsoc.pcf -c ctrlsoc.asc > ctrlsoc_post.v

marlann_post.v: marlann.asc
	icebox_vlog -s -L -n marlann_top -p marlann.pcf -c marlann.asc > marlann_post.v

#####################################################################

ctrlsoc.json: $(SOC_RTL) $(CAMERA_RTL) flashinit.hex
	yosys -ql ctrlsoc.log -p 'synth_ice40 -top ctrlsoc -json ctrlsoc.json' $(filter %.v, $^)

ctrlsoc.asc: ctrlsoc.pcf ctrlsoc.json
	nextpnr-ice40 --freq 13 --up5k --asc ctrlsoc.asc --pcf ctrlsoc.pcf --json ctrlsoc.json

ctrlsoc.bin: ctrlsoc.asc
	icetime -d up5k -c 12 -mtr ctrlsoc.rpt ctrlsoc.asc
	icepack ctrlsoc.asc ctrlsoc.bin

ctrlsoc_fw.elf: sections.lds start.S firmware.c demodat.inc camera/camera.c
	riscv32-unknown-elf-gcc -O1 -Wall -Wextra -march=rv32i -Wl,-Bstatic,-T,sections.lds,--strip-debug -ffreestanding -nostdlib -o ctrlsoc_fw.elf start.S firmware.c camera/camera.c

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

marlann.blif: marlann.json
marlann.json: $(ML_RTL)
	yosys -l marlann.log -qp 'read_verilog -D$(SPI_TYPE) $(ML_RTL); synth_ice40 -top marlann_top -json marlann.json -blif marlann.blif'

marlann.asc: marlann.pcf marlann.json
	nextpnr-ice40 --seed $(SEED) --freq 30 --up5k --asc marlann.asc --pcf marlann.pcf --json marlann.json

marlann.bin: marlann.asc
	icetime -d up5k -c 12 -mtr marlann.rpt marlann.asc
	icepack marlann.asc marlann.bin

marlann_arachne.asc: marlann.pcf marlann.blif
	arachne-pnr -s $(SEED) -d 5k -o marlann_arachne.asc -p marlann.pcf marlann.blif

marlann_arachne.bin: marlann_arachne.asc
	icetime -d up5k -c 12 -mtr marlann_arachne.rpt marlann_arachne.asc
	icepack marlann_arachne.asc marlann_arachne.bin

prog_marlann: marlann.bin
	iceprog $(MARLANN_DEV) marlann.bin

prog_marlann_arachne: marlann_arachne.bin
	iceprog $(MARLANN_DEV) marlann_arachne.bin

reset_marlann:
	iceprog $(MARLANN_DEV) -t

erase_marlann:
	iceprog $(MARLANN_DEV) -e 1

clean_marlann:
	rm -f marlann.json marlann.log marlann.asc marlann.bin marlann.rpt
	rm -f marlann.blif marlann_arachne.asc marlann_arachne.bin marlann_arachne.rpt

#####################################################################

multisynth:
	set -ex; for i in {100..120}; do \
		make clean; \
		make -j4 SEED=$$i marlann.bin marlann_arachne.bin; \
		cp marlann.rpt report_nextpnr_$$i.txt; \
		cp marlann_arachne.rpt report_arachne_$$i.txt; \
	done

clean: clean_ctrlsoc clean_marlann
	rm -f testbench.vcd testbench flashinit.hex demodat.inc

.PHONY: multisynth clean prog_ctrlsoc prog_ctrlsoc_fw reset_ctrlsoc erase_ctrlsoc clean_ctrlsoc
.PHONY: prog_marlann prog_marlann_arachne reset_marlann erase_marlann clean_marlann
