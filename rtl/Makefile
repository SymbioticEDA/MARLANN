SHELL = bash

all_qpi: testbench_qpi
	vvp -N testbench > >( tee testbench.log; )
	sed '/^TRACE/ ! d; s/^[^:]*: //;' < testbench.log > testbench.trace
	cmp ../sim/demo.trace testbench.trace

all_spi: testbench_spi
	vvp -N testbench > >( tee testbench.log; )
	sed '/^TRACE/ ! d; s/^[^:]*: //;' < testbench.log > testbench.trace
	cmp ../sim/demo.trace testbench.trace

formal_spi: spi_client.v
	sby -f spi.sby

testbench_qpi: testbench_qpi.v top.v memory.v sequencer.v compute.v 
	iverilog -DTRACE -DQPI -s testbench -o testbench testbench_qpi.v top.v memory.v sequencer.v compute.v $(shell yosys-config --datdir/ice40/cells_sim.v)

testbench_spi: testbench_spi.v top.v memory.v sequencer.v compute.v spi_client.v
	iverilog -DTRACE -DSPI -s testbench -o testbench testbench_spi.v top.v memory.v sequencer.v compute.v spi_client.v $(shell yosys-config --datdir/ice40/cells_sim.v)

clean:
	rm -f testbench testbench.vcd testbench.log testbench.trace

.PHONY: all_qpi all_spi clean
