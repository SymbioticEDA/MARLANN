See [isa.md](isa.md) for a description of the architecture and the instruction set reference.

Assembler Syntax
----------------

The assembler maintains a location counter that is initialized to 0 on startup.

Code sections starting at the location counter start with a `.code` line. Code sections
starting at a different location start with `.code <addr>`, where `<addr>` can be a
decimal, ocatal (using the `0` prefix), or hexadecimal (using the `0x` prefix). Code
sections must start at a 4-bytes-aligned address.

Code sections contain one instruction per line. The supported instructions are
(see [isa.md](isa.md) for instruction semantics):

```
Sync
Call <maddr>
Return
Execute <caddr>, <len>
LoadCode <maddr>, <caddr>
LoadCoeff0 <maddr>, <caddr>
LoadCoeff1 <maddr>, <caddr>
ContinueLoad <arg>

SetVBP <maddr>
AddVBP <maddr>
SetLBP <maddr>
AddLBP <maddr>
SetSBP <maddr>
AddSBP <maddr>
SetCBP <caddr>
AddCBP <caddr>

Store  <maddr>, <arg>
Store0 <maddr>, <arg>
Store1 <maddr>, <arg>

ReLU   <maddr>, <arg>
ReLU0  <maddr>, <arg>
ReLU1  <maddr>, <arg>

Save   <maddr>
Save0  <maddr>
Save1  <maddr>

LdSet  <maddr>
LdSet0 <maddr>
LdSet1 <maddr>

LdAdd  <maddr>
LdAdd0 <maddr>
LdAdd1 <maddr>

LdMax  <maddr>
LdMax0 <maddr>
LdMax1 <maddr>

MACC   <maddr>, <caddr>
MMAX   <maddr>, <caddr>
MACCZ  <maddr>, <caddr>
MMAXZ  <maddr>, <caddr>
MMAXN  <maddr>, <caddr>
```

Instruction arguments (<maddr>, <caddr>, <arg>, <len>) can be integers (decimal, octal,
or hexadecimal), labels, or more complex expressions:

```
argument:
	term |
	"+" term |
	"-" term |
	argument "+" term |
	argument "-" term;

term:
	label |
	integer |
	term "*" integer |
	term "/" integer;
```

Labels at the location counter are defined with a `<label-name>:` line. Labels at an
arbitrary address are defined with a `.sym <label-name> <addr>` line.

Data sections starting at the location counter start with a `.data` line. Data sections
starting at a different location start with `.data <addr>`, where `<addr>` can be a
decimal, ocatal (using the `0` prefix), or hexadecimal (using the `0x` prefix). Code
sections must start at a 4-bytes-aligned address.

Data sections contain data bytes. Each line must contain a multiple of four bytes.
(Each byte is given as decimal, ocatal, hexadecimal integer.)
