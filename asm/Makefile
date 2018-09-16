demo: mlasm
	./mlasm -v -o demo.hex -b demo.bin demo.asm

mlasm: mlasm.h mlasm.cc main.cc
	clang -Wall -Wextra -O0 -ggdb -std=c++14 -o mlasm mlasm.cc main.cc -lstdc++

clean:
	rm -f mlasm demo.hex demo.bin
