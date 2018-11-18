SHELL = bash

all: testbench
	vvp -N testbench > >( tee testbench.log; )
	sed '/^TRACE/ ! d; s/^[^:]*: //;' < testbench.log > testbench.trace
	cmp ../sim/demo.trace testbench.trace

testbench: testbench.v top.v memory.v sequencer.v compute.v spi_client.v
	iverilog -DTRACE -s testbench -o testbench testbench.v top.v memory.v sequencer.v compute.v spi_client.v $(shell yosys-config --datdir/ice40/cells_sim.v)

clean:
	rm -f testbench testbench.vcd testbench.log testbench.trace

.PHONY: all clean
