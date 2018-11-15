SHELL = bash

gtkwave: testbench
	gtkwave testbench.vcd spi.gtkwave


testbench: testbench.v top.v
	iverilog -DTRACE -s testbench -o testbench testbench.v top.v $(shell yosys-config --datdir/ice40/cells_sim.v)
	vvp -N testbench > >( tee testbench.log; )

clean:
	rm -f testbench testbench.vcd testbench.log testbench.trace

.PHONY: all clean
