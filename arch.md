mlaccel architecture reference
==============================

mlaccel has 128 kB main memory and 1024 words of compute code memory.

The compute core operates on a vector with 4 elements. Each vector element is
a 24 bits wide accumulator.

The compute core can read and write any byte in a consecutive 4-byte block in
main memory in a single cycle and without alignment constraints.

All memory operations the compute core performs are relative to a base-pointer.
The compute core has two such base pointers: A store base pointer (SBP) and a
load base pointer (LBP).

The accelerator has a host interface that allows accessing the main memory and
starting computations. It has a "sequencer" that can load individual code
blocks into the compute core and launch them. And a compute core that performs
the actual computations.

There is no conditional branching in the architecture. But the sequencer has
a call-return-mechanism that allows for the code for repeated sequences to be
stored only once in main memory.

Host interface
-------------

mlaccel provides a half-duplex quad-spi (QPI) ddr interface to the host. This
interface supports the following operations using a very simple byte-based
protocol:

- Write to mlaccel main memory
- Start sequencer at a given address
- Check if sequencer is running
- Read from mlaccel main memory

Sequencer code
--------------

Sequencer code is stored in main memory and consists of a series of 32 bit words.

    |31        16|15          5|4        0|
    +------------+-------------+----------+
    |  MEM-ADDR  |  CODE-ADDR  |  OPCODE  |
    +------------+-------------+----------+

(The insn format supports up to 256 kB main memory and up to 2048 code
memory locations.)

All memory addresses are 4-byte aligned. Thus the two LSB bits of MEM-ADDR
are implicitly 0 and do not need to be included in the instruction word.

The following instructions are available:

- Call: Push the address of the next instruction to the call stack and continue
executing at the given address.

- Return: Pop an address from the call stack and continue executring at that
address. Stop if the call stack is empty.

- Setup: Set the LEN register to the value in CODE-ADDR. The MEM-ADDR bits encode
options for the Load instructions that allow loading only coefficients or only
the instruction part of compute code, or load just one coefficient byte from
memory and put it in all coefficient fields in the instruction, and so on.

- Load: Copy LEN code words from MEM-ADDR in main memory to CODE-ADDR in compute
memory. The exact mode of copying depends on the options set by the last "Setup"
instruction.

- Execute: Execute code from the compute code memory. This instruction has two
arguments: the start address of the compute code and a length in words (length
stored in MEM-ADDR bits).


Compute code
------------

A compute code word is 64 bits in size.

(The insn format supports up to 256 kB main memory and up to 8 lanes. In
8-lane mode a compute code word is 96 bits in size with 4 more coefficient
fields added at the MSB end.)

    |63    56|55    48|47    40|39    32|31      14|13      6|5      0|
    +--------+--------+--------+--------+----------+---------+--------+
    |   C3   |   C2   |   C1   |   C0   |   ADDR   | LANE-EN | OPCODE |
    +--------+--------+--------+--------+----------+---------+--------+

The following opcodes are defined:

Opcodes with a single address argument:

- SetLBP: Set the load base pointer to the specified value.

- SetSBP: Set the store base pointer to the specified value.

- AddLBP: Add the specified value to the load base pointer.

- AddSBP: Add the specified value to the store base pointer.

- XorLBP: Bitwise-XOR the specified value with the load base pointer.

- XorSBP: Bitwise-XOR the specified value with the store base pointer.

- AndLBP: Bitwise-AND the specified value with the load base pointer.

- AndSBP: Bitwise-AND the specified value with the store base pointer.

Opcodes with a per-lane enable bit, an address argument, and a per-lane 8-bit coefficient:

- MACC: Load 4 bytes from the specified address (relative to LBP), multiply with coefficients,
and add to accumulators. Only the accumulators that are selected by the per-lane enable bit are updated.

- MMAX: Like MMAC, but store the max value in the accumulator instead of the sum.

- MSET: Like MMAC, but overwrite the accumulator instead of adding to it.

Opcodes with a per-lane enable bit, an address argument, and per-lane shift amount (shift amout stored in insn coefficient fields):

- STORE: Right-shift accumulators by the specified amount, saturate it to a signed 8-bit value, and
store the selected accumulators to main memory at the given address (relative to SBP). (The shifted
and clipped value is stored to memory, the accumulator itself is unchanged.)

- RELU: Like store, but replace negative values with zero.

Opcodes without argument:

- RACC-0: Add accumulator 1 to accumulator 0, and accumulator 3 to accumulator 2. (For 8 lanes it also adds acc 5 to 4 and acc 7 to 6.)

- RACC-1: Add accumulator 2 to accumulator 0. (For 8 lanes it also adds acc 6 to 4.)

- RACC-2: (8-lanes only) Add accumulator 4 to accumulator 0.

- RMAX-0: Store max of acc 1 and 0 in acc 0, and max of acc 3 and 2 in 2. (For 8 lanes also acc 5 to 4 and acc 7 to 6.)

- RMAX-1: Store max of acc 2 and 0 in acc 0. (For 8 lanes it also acc 6 to 4.)

- RMAX-2: (8-lanes only) Add accumulator 4 to accumulator 0.
