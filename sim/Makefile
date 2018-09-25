demo: mlsim
	./mlsim -v -t demo.trace -o demo_out.hex -b demo_out.bin ../asm/demo.bin

mlsim: mlsim.h mlsim.cc main.cc
	clang -Wall -Wextra -Os -ggdb -std=c++14 -o mlsim mlsim.cc main.cc -lstdc++

clean:
	rm -f mlsim demo.trace demo_out.hex demo_out.bin
