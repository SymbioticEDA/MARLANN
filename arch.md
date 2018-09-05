mlaccel architecture reference
==============================

mlaccel has 128 kB main memory and 1024 words of compute code memory and
1024 words of coefficient storage.

The compute core operates on a 24 bits wide accumulator. Each cycle it can
add up to SZ=4 products for the MACC units to that accumulator.

The compute core can read any consecutive SZ-byte block in main memory, as long
as it has 2-byte alignment. The compute core can write any byte in main memory.

All memory operations the compute core performs are relative to a base-pointer.
The compute core has two such base pointers: A store base pointer (SBP) and a
load base pointer (LBP).

All compute operations using coefficients address those coefficients relative
to a coefficient base pointer (CBP).

The accelerator has a host interface that allows accessing the main memory and
starting computations. It has a "sequencer" that can load individual code
blocks into the compute core and launch them. And a compute core that performs
the actual computations.

There is no conditional branching in the architecture. But the sequencer has
a call-return-mechanism that allows for the code for repeated sequences to be
stored only once in main memory.

Once this baseline architecture is implemented, we will evaluate extending
the vector size from SZ=4 to SZ=8 and adding a 2nd compute core with it's own
accumulator, coefficient storage bank, LBP, SBP, and CBP. This creates a
roadmap for up to 16 MACCs per cycle using this architecture, or >500 MMACC/s
if we can clock the architecture at >35 MHz.


Host interface
-------------

mlaccel provides a half-duplex Quad-SPI (QPI) DTR interface to the host. This
interface supports the following operations using a very simple byte-based
protocol.

In addition to the QPI interface the core also has a `RDY` output that is
pulled low when mlaccel is ready to receive new commands and a `ERR` output
that is pulled low when mlaccel detects a communication error, such as a too
fast clock or a unsupported command. `ERR` is reset when chip-select is de-asserted.
Both `RDY` and `ERR` are configured as open-collector outputs with weak pull-ups.

The following commands are used for controlling mlaccel:

- Status (`20h`): Followed by a dummy byte for transfering control of the I/O
lines to mlaccel. Then mlaccel sends `FFh` for busy and `00h` for idle. (The
host may keep reading to continously check the status.)

- Write main memory (`21h`): Followed by two bytes address (LSB first). This
address is shifted left by one bit to make it 2-byte aligned. All bytes following
are written to the memory region starting at that address.

- Read main memory (`22h`): Followed by two bytes address (LSB first). This
address is shifted left by one bit to make it 2-byte aligned. The address
is followed by a dummy byte for transfering control of the I/O lines to
mlaccel. Then mlaccel sends bytes from main memory starting at the specified
address.

- Run (`23h`): Followed by two bytes address (LSB first). This address is
shifted left by one bit to make it 2-byte aligned. The resulting address must
be 4-byte aligned. The core will start executing at this address and continue
executing code until `Return` is executed with an empty call stack.

- Stop (`24h`): The core will immediately stop executing code.

The following additional commands allow simple cascading of up to four mlaccel
cores using only one chip-select line on the host side. For this, the host
chip-select is connected to one mlaccel core, and the three others get their
chip-select from that first one. The other signals (`IO0`, `IO1`, `IO2`,
`IO3`, `RDY`, `ERR`, `CLK`) are shared between the chips.

- Select (`00h`, `01h`, `02h`, `03h`): Select the specified chip for this
transaction. `00h` is simply ignored. `01h`, `02h`, and `03h` assert the
corresponding chip-select line and the "main" chip will ignore the rest
of this transaction.

- Broadcast (`1xh`): Like select, but broadcast to multiple chips. (Only
valid for write-only transactions.) The 4 LSB bits select the chips.

And for fast transfer of data between chips:

- XferSrc (`04h`): Followed by two bytes address. Enable xfer-src mode and
save that src address. (Sent to exactly one node.)

- XferDst (`05h`): Followed by two bytes address. Enable xfer-dst mode and
save that dst address. (Sent to one or more nodes.)

- Xfer (`06h`): Sent to src and dst nodes via broadcast. Followed by a dummy
byte for transfering control of the I/O lines to the src chip. The src chip
will then send data starting at the stored src addr, and the dst chips will
store that data at the stored dst addr. When done this will disable xfer-src
and xfer-dst mode in selected nodes.

And for managing the shared RDY signal:

- RdyOn (`07h`): Assert (pull down) `RDY` when the accelerator is idle.
This is the power-on behavior.

- RdyOff (`08h`): Do not assert (pull down) `RDY` when the accelerator is idle.


Sequencer code
--------------

Sequencer code is stored in main memory and consists of a series of 32 bit words.

All memory addresses are 4-byte aligned. Thus the two LSB bits of MEM-ADDR
are implicitly 0 and do not need to be included in the instruction word.

```
    |31        17|16          7|6     2|1    0|
    +------------+-------------+-------+------+
    |  MEM-ADDR  |  CODE-ADDR  |  LEN  |  OP  |
    +------------+-------------+-------+------+
```

(OP nonzero, LEN=0 encodes for LEN=32)

- LoadCode (OP=1): Copy LEN 4-byte words from MEM-ADDR in main memory to CODE-ADDR
compute code memory.

- LoadCoeff0 (OP=2): Copy LEN SZ-byte words from MEM-ADDR in main memory to
CODE-ADDR in coefficient storage bank 0.

- LoadCoeff1 (OP=3): Copy LEN SZ-byte words from MEM-ADDR in main memory to
CODE-ADDR in coefficient storage bank 1.

```
    |31        17|16          7|6      2|1   0|
    +------------+-------------+--------+-----+
    |  MEM-ADDR  |  CODE-ADDR  | OPCODE |  0  |
    +------------+-------------+--------+-----+
```

- Call (OPCODE=1): Push the address of the next instruction to the call stack and continue
executing at the given MEM-ADDR. (CODE-ADDR must be zero.)

- Return (OPCODE=2): Pop an address from the call stack and continue executing at that
address. Stop if the call stack is empty. (MEM-ADDR and CODE-ADDR must be zero.)

- Execute (OPCODE=3): Execute MEM-ADDR compute code instructions, starting at CODE-ADDR.

- ContinueLoadC (OPCODE=4): Continue the last load operation at CODE-ADDR, load MEM-ADDR words.
This instruction is only valid immediately after a LoadCode, LoadCoeff0, LoadCoeff1, ContinueLoadC, or ContinueLoadM instruction.

- ContinueLoadM (OPCODE=5): Continue the last load operation at MEM-ADDR, load CODE-ADDR words.
This instruction is only valid immediately after a LoadCode, LoadCoeff0, LoadCoeff1, ContinueLoadC, or ContinueLoadM instruction.

- Sync (OPCODE=6): Block until all pending compute instructions are completed.
(LoadCode, LoadCoeff0, and LoadCoeff1 also block until all pending compute instructions are completed.)


Compute code
------------

A compute code word is 32 bits in size.

```
    |31      15|16     12|11         9|8       7|6   0|
    +----------+---------+------------+---------+-----+
    |   ADDR   |   ARG   |   OPCODE   | BANKSEL |  0  |
    +----------+---------+------------+---------+-----+
```

The two BANKSEL bits select which banks should execute the instruction.

SetLBP/AddLBP/SetSBP/AddSBP/SetCBP/AddCBP are the same opcode. ARG selects the operation.

- SetLBP (OPCODE=0, ARG=1): Set the load base pointer to ADDR.
The two LSB bits of ADDR must be zero.

- AddLBP (OPCODE=0, ARG=9): Add ADDR to the load base pointer.
The two LSB bits of MEM-ADDR must be zero.

- SetSBP (OPCODE=0, ARG=2): Set the store base pointer to ADDR.

- AddSBP (OPCODE=0, ARG=10): Add the ADDR to the store base pointer.

- SetCBP (OPCODE=0, ARG=4): Set the coefficient base pointer to ADDR.

- AddCBP (OPCODE=0, ARG=12): Add ADDR to the coefficient base pointer.

- Store (OPCODE=1): Right-shift accumulator by the amount specified in ARG,
saturate it to a signed 8-bit value, and store the result to main memory at ADDR
(relative to SBP). (The shifted and saturated value is only stored in memory.
The accumulator itself is unchanged.)

- ReLU (OPCODE=2): Like Store, but replace negative values with zero.

```
    |31        17|16           7|6        0|
    +------------+--------------+----------+
    |  MEM-ADDR  |  COEFF-ADDR  |  OPCODE  |
    +------------+--------------+----------+
```

- MACC (OPCODE=1): Load SZ bytes from MEM-ADDR (relative to LBP), multiply with
coefficients at COEFF-ADDR (relative to CBP), and add to accumulator.

- MMAX (OPCODE=2): Like MMAC, but store the max value in the accumulator instead of the sum.
In MAX mode a coefficient of 0x80 (most negative number) is a special symbol for
values that should be ignored.

- MACCZ (OPCODE=3) / MMAXZ (OPCODE=4): Like MMAC/MMAX, but reset the accumulator to zero before
performing the operation.

- MMAXN (OPCODE=5): Like MMAX but set the accumulator to the most negative value
before performing the operation.
