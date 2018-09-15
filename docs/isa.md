Architecure
-----------

The mlaccel architecture has up to 128 kB main memory, up to 2048 words of
compute code memory, and up to 2048 words of coefficient storage.

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
accumulator and coefficient storage. This creates a roadmap for up to 16 MACCs
per cycle using this architecture, or >500 MMACC/s if we can clock the
architecture at >35 MHz.


Instruction Format
------------------

Some instructions are handled by the sequencer. Others are directly passed
to the compute core. Sequencer and compute instructions use a uniform instruction
format.

MADDR = Main memory address  
CADDR = Compute code address or coefficient storage address.

All memory loads are 4-byte aligned. Thus the two LSB bits of MADDR are
implicitly 0 and do not need to be included in the instruction word.

Store instructions have no alignment restrictions and use MX-Format.

```
    |31     17|16      6|5       0|
    +---------+---------+---------+
    |  MADDR  |  CADDR  |    OP   |    MC-Format
    +---------+---------+---------+
    |  MADDR  |   ARG   |    OP   |    M-Format
    +---------+---------+---------+
    |   ARG   |  CADDR  |    OP   |    C-Format
    +---------+---------+---------+
    |        ARG        |    OP   |    A-Format
    +-------------------+---------+

    |31       15|14    6|5       0|
    +-----------+-------+---------+
    |   MXADDR  |  ARG  |    OP   |    MX-Format
    +-----------+-------+---------+
```

- Sync (A-Format, OP=0, ARG=0): Wait for the compute pipeline to become idle.

- Call (M-Format, OP=1, ARG=0): Push the address of the next instruction to the call
stack and continue executing at the given MADDR.

- Return (A-Format, OP=2, ARG=0): Pop an address from the call stack and continue
executing at that address. Stop if the call stack is empty.

- Execute (C-Format, OP=3): Execute ARG compute code instructions, starting at CADDR.

- LoadCode (MC-Format, OP=4): Load one (4-byte) word at MADDR and store it at CADDR in
compute code memory.

- LoadCoeff0 (MC-Format, OP=5): Load one (SZ-byte) word at MADDR and store it at CADDR
coefficient bank 0.

- LoadCoeff1 (MC-Format, OP=6): Load one (SZ-byte) word at MADDR and store it at CADDR
coefficient bank 1.

- ContinueLoadC (C-Format, OP=7): Must follow directly LoadCode, LoadCoeff0, or LoadCoeff1.
Continue loading ARG words from memory and store at CADDR.

- ContinueLoadM (M-Format, OP=8): Must follow directly LoadCode, LoadCoeff0, or LoadCoeff1.
Load ARG words from memory at MADDR and continue storing in destination memory.

- SetLBP (M-Format, OP=9, ARG=0): Set the load base pointer to MADDR.

- AddLBP (M-Format, OP=9, ARG=1): Add MADDR to the load base pointer.

- SetSBP (MX-Format, OP=10, ARG=0): Set the load base pointer to MXADDR.

- AddSBP (MX-Format, OP=10, ARG=1): Add MXADDR to the load base pointer.

- SetCBP (C-Format, OP=11, ARG=0): Set the coefficient base pointer to CADDR.

- AddCBP (C-Format, OP=11, ARG=1): Add CADDR to the coefficient base pointer.

- Store (MX-Format, OP=12, ARG[8:7]=0): Right-shift accumulator by the amount
specified in ARG[4:0], saurate it to a signed 8-bit value, and store the result
to main memory at MXADDR (relative to SBP). (The shifted and saturated value is
only stored in memory. The accumulator itself is unchanged.) If ARG[5] selects
bank 0. ARG[6] selects bank 1. (Bank 1 stores at MXADDR + SBP + 1.)

- ReLU (MX-Format, OP=12, ARG[8:7]=1): Like Store, but replace negative values
with zero.

- Save0 (M-Format, OP=12, ARG=0): Store the bank 0 accumulator in the 32-bit
word addressed by MADDR (relative to SBP).

- Save1 (M-Format, OP=12, ARG=1): Store the bank 1 accumulator in the 32-bit
word addressed by MADDR (relative to SBP).

- SetAcc0 (M-Format, OP=13, ARG=0): Load the bank 0 accumulator from the 32-bit
word addressed by MADDR (relative to LBP).

- SetAcc1 (M-Format, OP=13, ARG=1): Load the bank 1 accumulator from the 32-bit
word addressed by MADDR (relative to LBP).

- AddAcc0 (M-Format, OP=13, ARG=2): Add the 32-bit word addressed by MADDR (relative
to LBP) to the bank 0 accumulator.

- AddAcc1 (M-Format, OP=13, ARG=3): Add the 32-bit word addressed by MADDR (relative
to LBP) to the bank 1 accumulator.

- MaxAcc0 (M-Format, OP=13, ARG=4): Load the 32-bit word addressed by MADDR (relative
to LBP) into the bank 0 accumulator if that value is larger than the value currently in
the accumulator.

- MaxAcc1 (M-Format, OP=13, ARG=5): Load the 32-bit word addressed by MADDR (relative
to LBP) into the bank 1 accumulator if that value is larger than the value currently in
the accumulator.

- MACC (MC-Format, OP=14): Load SZ bytes from MADDR (relative to LBP), multiply with
coefficients at CADDR (relative to CBP), and add to accumulator.

- MMAX (MC-Format, OP=15): Like MMAC, but store the max value in the accumulator instead
of the sum. In MAX mode a coefficient of 0x80 (most negative number) is a special symbol
for values that should be ignored.

- MACCZ (MC-Format, OP=16) / MMAXZ (MC-Format, OP=17): Like MMAC/MMAX, but reset the
accumulator to zero before performing the operation.

- MMAXN (MC-Format, OP=18): Like MMAX but set the accumulator to the most negative value
before performing the operation.
