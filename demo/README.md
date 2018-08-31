A simple demo SoC controlling an mlaccel coprocessor
====================================================

This demo uses two iCEBreaker boards.
One running the control SoC and a second one running mlaccel.

They are connected via PMOD1A on both boards.
(1:1 connections, no pins crossed out.)

| Pin Name | IO Loc | Role |
|:-------- | ------:|:----:|
| P1A1     |      4 |  CLK |
| P1A2     |      2 |  CSB |
| P1A3     |     47 |  IO0 |
| P1A4     |     45 |  IO1 |
| P1A7     |      3 |  IO2 |
| P1A8     |     48 |  IO3 |
| P1A9     |     46 |  IRQ |
| P1A10    |     44 |  ERR |
