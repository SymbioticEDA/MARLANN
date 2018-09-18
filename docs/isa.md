Architecure
-----------

The mlaccel architecture has up to 128 kB main memory, 512 4-byte words of
fast compute code memory, and 2x512 8-byte words of coefficient storage.

The compute core operates on two 24 bits wide accumulators. Each cycle it can
add 8 multiply results into each accumulator, yielding 16 MACC/cycle.

The compute core can read any consecutive 8-byte block in main memory, as long
as it has 2-byte alignment. The compute core can write any consecutive 2-byte block
in main memory.

All memory operations the compute core performs are relative to a base-pointer.
The compute core has three such base pointers: A variable base pointer (VBP), a
load base pointer (LBP), and a store base pointer (SBP).

All compute operations using coefficients address those coefficients relative
to a coefficient base pointer (CBP).

The accelerator has a host interface that allows accessing the main memory and
starting computations. It has a "sequencer" that can load individual code
blocks into the compute core and launch them. And a compute core that performs
the actual computations.

There is no conditional branching in the architecture. But the sequencer has
a call-return-mechanism that allows for the code for repeated sequences to be
stored only once in main memory.


Instruction Format
------------------

Some instructions are handled by the sequencer. Others are directly passed
to the compute core. Sequencer and compute instructions use a uniform instruction
format.

`MADDR` = Main memory address (17 bits)  
`CADDR` = Compute code address or coefficient storage address (9 bits)  
`LEN` = A 10-bit wide argument (stored in instruction bits 24..15)  
`ARG` = A 9-bit wide argument

Unused bits (marked with `----`) must be set to zero.

The assembler expects instruction operands in the order MADDR, CADDR, ARG/LEN.

```
    |31                             15|14              6|5         0|
    +---------------------------------+-----------------+-----------+
    |             -----               |      -----      | 000000  0 |  Sync
    |             MADDR               |      -----      | 000001  1 |  Call
    |             -----               |      -----      | 000010  2 |  Return
    |              LEN                |      CADDR      | 000011  3 |  Execute
    |             MADDR               |      CADDR      | 000100  4 |  LoadCode
    |             MADDR               |      CADDR      | 000101  5 |  LoadCoeff0
    |             MADDR               |      CADDR      | 000110  6 |  LoadCoeff1
    |             -----               |       ARG       | 000111  7 |  ContinueLoad
    +---------------------------------+-----------------+-----------+
    |             MADDR               |      -----      | 001000  8 |  SetVBP
    |             MADDR               |      -----      | 001001  9 |  AddVBP
    |             MADDR               |      -----      | 001010 10 |  SetLBP
    |             MADDR               |      -----      | 001011 11 |  AddLBP
    |             MADDR               |      -----      | 001100 12 |  SetSBP
    |             MADDR               |      -----      | 001101 13 |  AddSBP
    |             -----               |      CADDR      | 001110 14 |  SetCBP
    |             -----               |      CADDR      | 001111 15 |  AddCBP
    +---------------------------------+-----------------+-----------+
    |             MADDR               |       ARG       | 010000 16 |  Store
    |             MADDR               |       ARG       | 010001 17 |  Store0
    |             MADDR               |       ARG       | 010010 18 |  Store1
    |             -----               |      -----      | 010011 19 |  ---
    +---------------------------------+-----------------+-----------+
    |             MADDR               |       ARG       | 010100 20 |  ReLU
    |             MADDR               |       ARG       | 010101 21 |  ReLU0
    |             MADDR               |       ARG       | 010110 22 |  ReLU1
    |             -----               |      -----      | 010111 23 |  ---
    +---------------------------------+-----------------+-----------+
    |             MADDR               |      -----      | 011000 24 |  Save
    |             MADDR               |      -----      | 011001 25 |  Save0
    |             MADDR               |      -----      | 011010 26 |  Save1
    |             -----               |      -----      | 011011 27 |  ---
    +---------------------------------+-----------------+-----------+
    |             MADDR               |      -----      | 011100 28 |  LdSet
    |             MADDR               |      -----      | 011101 29 |  LdSet0
    |             MADDR               |      -----      | 011110 30 |  LdSet1
    |             -----               |      -----      | 011111 31 |  ---
    +---------------------------------+-----------------+-----------+
    |             MADDR               |      -----      | 100000 32 |  LdAdd
    |             MADDR               |      -----      | 100001 33 |  LdAdd0
    |             MADDR               |      -----      | 100010 34 |  LdAdd1
    |             -----               |      -----      | 100011 35 |  ---
    +---------------------------------+-----------------+-----------+
    |             MADDR               |      -----      | 100100 36 |  LdMax
    |             MADDR               |      -----      | 100101 37 |  LdMax0
    |             MADDR               |      -----      | 100110 38 |  LdMax1
    |             -----               |      -----      | 100111 39 |  ---
    +---------------------------------+-----------------+-----------+
    |             MADDR               |      CADDR      | 101000 40 |  MACC
    |             MADDR               |      CADDR      | 101001 41 |  MMAX
    |             MADDR               |      CADDR      | 101010 42 |  MACCZ
    |             MADDR               |      CADDR      | 101011 43 |  MMAXZ
    |             -----               |      -----      | 101100 44 |  ---
    |             CADDR               |      CADDR      | 101101 45 |  MMAXN
    |             -----               |      -----      | 101110 46 |  ---
    |             -----               |      -----      | 101111 47 |  ---
    +---------------------------------+-----------------+-----------+
    |             -----               |      -----      | 110000 48 |
    |             -----               |      -----      |  .......  |  Reserved
    |             -----               |      -----      | 111111 63 |
    +---------------------------------+-----------------+-----------+
     1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
```

Sequencer Instructions
----------------------

Sequencer instructions are handled by the sequencer and thus can only be executed
directly from main memory. Sequencer instructions are invalid when executed from
compute code memory using the Execute instruction.

- Sync: Wait for the compute pipeline to become idle.

- Call: Push the address of the next instruction to the call stack and continue
executing at the given MADDR. (MADDR must be 4-byte-aligned.)

- Return: Pop an address from the call stack and continue executing at that
address. Stop if the call stack is empty.

- Execute: Execute LEN compute code instructions, starting at CADDR. (LEN
can be at most 512.)

- LoadCode: Load one (4-byte) word at MADDR and store it at CADDR in compute
code memory. (MADDR must be 4-bytes-aligned.)

- LoadCoeff0: Load one 8-byte word at MADDR and store it at CADDR coefficient
bank 0.

- LoadCoeff1: Load one 8-byte word at MADDR and store it at CADDR coefficient
bank 1.

- ContinueLoad: Must follow directly LoadCode, LoadCoeff0, or LoadCoeff1.
Continue loading ARG words from memory and store in compute code or coefficient memory.


Compute Instructions
--------------------

Compute instructions can be executed via the sequencer from main memory or directly
from compute code memory using the Execute instruction.

Manipulating the base pointers:

- SetVBP: Set the variable base pointer (VBP) to MADDR.

- AddVBP: Add MADDR to the variable base pointer (VBP).

- SetLBP: Set the load base pointer (LBP) to MADDR.

- AddLBP: Add MADDR to the load base pointer (LBP).

- SetSBP: Set the store base pointer (SBP) to MADDR.

- AddSBP: Add MADDR to the store base pointer (SBP).

- SetCBP: Set the coefficient base pointer (CBP) to CADDR.

- AddCBP: Add CADDR to the coefficient base pointer (CBP).

Storing results:

- Store: Right-shift both accumulator values by the amount specified in ARG,
saturate the result to a signed 8-bit value, and store that value to
main memory at MADDR+SBP for the first accumulator and MADDR+SBP+1 for the second
accumulator.

- Store0: Like Store, but only store the value for the first accumulator to
MADDR+SBP.

- Store1: Like Store, but only store the value for the second accumulator to
MADDR+SBP+1.

- ReLU/ReLU0/ReLU1: Like Store/Store0/Store1, but replace negative values with
zero.

Storing and loading 32-bit intermediate results:

- Save: Store the first accumulator in the 32-bit word addressed by MADDR+SBP,
and store the second accumulator at MADDR+SBP+4. (MADDR+SBP must be 2-bytes-aligned.)

- Save0/Save1: Like Save, but only for the first/second accumulator.

- LdSet: Load the 32-bit word addressed by MADDR+LBP into the first accumulator
and MADDR+LBP+4 into the second accumulator. (MADDR+LBP must be 2-bytes-aligned.)

- LdSet0/Ldset1: Like LdSet, but only for the first/second accumulator.

- LdAdd: Like LdSet but add the new values to the existing values in both
accumulators.

- LdAdd0/LdAdd1: Like LdAdd, but only for the first/second accumulator.

- LdMax: Like LdAdd but but perform a max-operation instead of addition.

- LdMax0/LdMax1: Like LdMax, but only for the first/second accumulator.

Performing computations:

- MACC: Load 8 bytes from MADDR+VBP, multiply with coefficients at CADDR+CBP,
and add the results to the accumulators. (MADDR+VBP must be 2-bytes-aligned.)

- MMAX: Like MACC, but store the max value in the accumulator instead of the
sum. In MAX mode a coefficient of 0x80 (most negative number) is a special
symbol for values that should be ignored.

- MACCZ/MMAXZ: Like MACC/MMAX, but reset the accumulator to zero before
performing the operation.

- MMAXN: Like MMAX but set the accumulator to the most negative value before
performing the operation.
