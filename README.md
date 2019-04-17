MARLANN -- A simple FPGA Machine Learning Accelerator
=====================================================

MARLANN stands for Multiply-Accumulate and Rectified-Linear Accelerator for Neural Networks

A simple FPGA machine learning accelerator with focus on small multi-layer
CNNs, 8-bit fixed point signed integer arithmetic (32 bit accumulators),
max pooling, and ReLU activation function.

The reference platform for this project is the iCE40UP5K FPGA. The project
is using the open source iCE40 flow.

See [docs/overview.md](docs/overview.md) for a top level overview of the system.
See [docs/isa.md](docs/isa.md) for a description of the architecture and
the instruction set reference, and [docs/asm.md](docs/asm.md) for a description
of the assembler language syntax.

See [docs/qpi.md](docs/qpi.md) for a description of the QPI interface to
the host.

![](overview.svg)
