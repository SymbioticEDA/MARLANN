demo: mlsim
	./mlsim -v -o demo_out.hex -b demo_out.bin ../asm/demo.bin

mlsim: mlsim.h mlsim.cc main.cc
	clang -Wall -Wextra -O0 -ggdb -std=c++14 -o mlsim mlsim.cc main.cc -lstdc++

clean:
	rm -f mlsim demo_out.hex demo_out.bin
