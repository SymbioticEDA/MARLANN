mlaccel architecture reference
==============================

mlaccel has 128 kB main memory and 1024 words of compute code memory and
1024 words of coefficient storage.

The compute core operates on a 24 bits wide accumulator. Each cycle it can
add up to 4 products for the MACC units to that accumulator.

The compute core can read any consecutive 4-byte block in main memory, as long
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

Once this baseline architecture is implemented, we will evaluate (1st) extending
the vector size from 4 to 8 and (2nd) adding a 2nd compute core with it's own
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
that is pulled low when mlaccel detects a communication error, such as a two
fast clock or a unsupported command. `ERR` is reset when chip-select is de-asserted.

The following commands are used for controlling mlaccel:

- Status (`20h`): Followed by a dummy byte for transfering control of the I/O
lines to mlaccel. Then mlaccel sends `00h` for busy and `FFh` for ready. (The
host may keep reading to continously check the status.)

- Write main memory (`21h`): Followed by two bytes address (MSB first). This
address is shifted left by two bytes to make it 4-byte aligned. All data following
is written to that address, in 4-byte blocks. If chip-select is deasserted before
the 4th byte of a block is transmitted then no write is performed.

- Read main memory (`22h`): Followed by two bytes address (MSB first). This
address is shifted left by two bytes to make it 4-byte aligned. The address
is followed by a dummy byte for transfering control of the I/O lines to
mlaccel. Then mlaccel sends data from main memory starting at the specified
address.

- Run (`23h`): Followed by two bytes address (MSB first). This address is
shifted left by two bytes to make it 4-byte aligned. The core will start
executing at this address.

- Stop (`24h`): The core will immediately stop executing code. Otherwise the
core will execute code until `Return` is executed with an empty call stack.

The following additional commands allow simple cascading of up to four mlaccel
cores using only one chip-select line on the host side. For this, the host
chip-select is connected to one mlaccel core, and the three others get their
chip-select from that first one. The other signals (`IO0`, `IO1`, `IO2`,
`IO3`, `RDY`, `ERR`, `CLK`) are shared between the chips.

- Select (`00h`, `01h`, `02h`, `03h`): Select the specified chip for this
transaction. `00h` is simply ignored. `01h`, `02h` and `03h` assert the
corresponding chip-select line and the "main" chip will ignore the rest
of this transaction.

- Broadcast (`1xh`): Like select, but broadcast to multiple chips. (Only
valid for write-only transactions.) the 4 LSB bits select the chips.

And for fast transfer of data between chips:

- XferSrc (`04h`): Followed by two bytes address. Enable xfer-dst mode and
save that src address.

- XferDst (`05h`): Followed by two bytes address. Enable xfer-dst mode and
save that dst address.

- Xfer (`06h`): Sent to src and dst nodes via broadcast. Followed by a dummy
byte for transfering control of the I/O lines to the src chip. The src chip
will then send data starting at the stored src addr, and the dst chips will
store that data at the stored dst addr.


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

- Load Code (OP=1): Copy LEN words from MEM-ADDR in main memory to CODE-ADDR
compute code memory.

- Load Coeff Bank 0 (OP=2): Copy LEN words from MEM-ADDR in main memory to
CODE-ADDR in coefficient storage bank 0.

- Load Coeff Bank 1 (OP=3): Copy LEN words from MEM-ADDR in main memory to
CODE-ADDR in coefficient storage bank 1.

```
    |31        17|16          7|6      2|1   0|
    +------------+-------------+--------+-----+
    |  MEM-ADDR  |  CODE-ADDR  | OPCODE |  0  |
    +------------+-------------+--------+-----+
```

- Call: Push the address of the next instruction to the call stack and continue
executing at the given MEM-ADDR. (CODE-ADDR must be zero.)

- Return: Pop an address from the call stack and continue executing at that
address. Stop if the call stack is empty. (MEM-ADDR and CODE-ADDR must be zero.)

- Execute: Execute compute code from the CODE-ADDR. MEM-ADDR contains the number
of instructions to execute.


Compute code
------------

A compute code word is 32 bits in size.

```
    |31          15|16     12|11         9|8       7|6   0|
    +--------------+---------+------------+---------+-----+
    |   MEM-ADDR   |   ARG   |   OPCODE   | BANKSEL |  0  |
    +--------------+---------+------------+---------+-----+
```

The two BANKSEL bits select which banks should execute the instruction.

SetLBP/AddLBP/SetSBP/AddSBP/SetCBP/AddCBP are the same opcode. ARG selects the operation.

- SetLBP: Set the load base pointer to the specified value. The two LSB bits of
MEM-ADDR must be zero.

- AddLBP: Add MEM-ADDR to the load base pointer.

- SetSBP: Set the store base pointer to the specified value.

- AddSBP: Add the specified value to the store base pointer.

- SetCBP: Set the coefficient base pointer to the specified value.

- AddCBP: Add the specified value to the coefficient base pointer.

- Store: Right-shift accumulator by the amount specified in ARG, saturate it to
a signed 8-bit value, and store the result to main memory at the given
address (relative to SBP). (The shifted and saturated value is only stored in
memory. The accumulator itself is unchanged.)

- ReLU: Like Store, but replace negative values with zero.

```
    |31        17|16           7|6        0|
    +------------+--------------+----------+
    |  MEM-ADDR  |  COEFF-ADDR  |  OPCODE  |
    +------------+--------------+----------+
```

- MACC: Load 4 bytes from MEM-ADDR (relative to LBP), multiply with
coefficients at COEFF-ADDR (relative to CBP), and add to accumulator.

- MMAX: Like MMAC, but store the max value in the accumulator instead of the sum.
In MAX mode a coefficient of 0x80 (most negative number) is a special symbol for
values that should be ignored.

- MACCZ/MMAXZ: Like MMAC/MMAX, but reset the accumulator to zero before
performing the operation.

- MMAXN: Like MMAX but set the accumulator to the most negative value
before performing the operation.
