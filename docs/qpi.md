QPI Host interface
------------------

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

- Write buffer (`21h`): Writes the following bytes to the main memory transfer
buffer.

- Read buffer (`22h`): Followed by a dummy byte for transfering control of the
I/O lines to mlaccel. Then mlaccel sends bytes from main memory transfer
buffer.

- Write main memory (`23h`): Followed by two bytes address (LSB first) and
one byte length. The address is shifted left by one bit to make it 2-byte aligned.
Followed by a dummy byte for transfering control of the I/O lines to mlaccel.
Mlaccel will copy the specified number of 4-byte words from the transfer buffer to
main memory (length=0 encodes for 1kB). It will output `FFh` while the transfer
is running and `00h` when it is finished.

- Read main memory (`24h`): Followed by two bytes address (LSB first) and
one byte length. The address is shifted left by one bit to make it 2-byte
aligned.  Followed by a dummy byte for transfering control of the I/O lines to
mlaccel. Mlaccel will copy the specified number of 4-byte words from main
memory to the transfer buffer (length=0 encodes for 1kB). It will output `FFh`
while the transfer is running and `00h` when it is finished.

- Run (`25h`): Followed by two bytes address (LSB first). This address is
shifted left by one bit to make it 2-byte aligned. The resulting address must
be 4-byte aligned. The core will start executing at this address and continue
executing code until `Return` is executed with an empty call stack.

- Stop (`26h`): The core will immediately stop executing code.

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

- Xfer (`3xh`): When chip-select goes low the next time, ignore the first
`x` bytes and copy the rest into the transfer buffer.

And for managing the shared RDY signal:

- RdyOn (`04h`): Assert (pull down) `RDY` when the accelerator is idle.
This is the power-on behavior.

- RdyOff (`05h`): Do not assert (pull down) `RDY` when the accelerator is idle.
