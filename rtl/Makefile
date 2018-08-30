all: compute_tb.vcd memory_tb.vcd

compute_tb: compute_tb.v compute.v memory.v spram.v
	iverilog -s mlaccel_compute_tb -o compute_tb compute_tb.v compute.v memory.v spram.v

compute_tb.vcd: compute_tb
	vvp -N compute_tb

memory_tb: memory_tb.v memory.v spram.v
	iverilog -s mlaccel_memory_tb -o memory_tb memory_tb.v memory.v spram.v

memory_tb.vcd: memory_tb
	vvp -N memory_tb

clean:
	rm -f memory_tb memory_tb.vcd

.PHONY: all clean
