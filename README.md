MLAccel -- A simple FPGA Machine Learning Accelerator
=====================================================

A simple FPGA machine learning accelerator with focus on small multi-layer
CNNs, 8-bit fixed point signed integer arithmetic (24 bit accumulators),
max pooling, and ReLU activation function.

The reference platform for this project is the iCE40UP5K FPGA. The project
is using the open source iCE40 flow.

See [docs/isa.md](docs/isa.md) for a description of the architecture and
the instruction set reference, and [docs/asm.md](docs/asm.md) for a description
of the assembler language syntax.

See [docs/qpi.md](docs/qpi.md) for a description of the QPI interface to
the host.

iCE40UP5K Features
------------------

30x 4kbit BRAMS (max 16 bit data bus)

4x 256kbit SPRAMS (max 16 bit data bus)

8x MULT16 (fracturable in two MULT8)

Upper bounds for possible results
---------------------------------

DSP Timing: 50 MHz

SPRAM Timing: 70 MHz

Tentative clock target: 25 MHz
