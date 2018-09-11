all: testbench.vcd

testbench: testbench.v top.v memory.v
	iverilog -s testbench -o testbench testbench.v top.v memory.v $(shell yosys-config --datdir/ice40/cells_sim.v)

testbench.vcd: testbench
	vvp -N testbench

compute_tb: compute_tb.v compute.v memory.v
	iverilog -s mlaccel_compute_tb -o compute_tb compute_tb.v compute.v memory.v $(shell yosys-config --datdir/ice40/cells_sim.v)

compute_tb.vcd: compute_tb
	vvp -N compute_tb

clean:
	rm -f testbench testbench.vcd compute_tb compute_tb.vcd

.PHONY: all clean
