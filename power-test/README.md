# UP5K power usage running MLAccel firmware

* When idle, the UP5K core draws 2.9mA @ 1.218V (3.53mW). 
* When running the longrun demo, draws 8.7mA @ 1.216V (10.58mW).

No change detected in VCCIO or VCC_PLL.

## iCE40 UltraPlus VCC/VCC_PLL

Onboard 1.2 V supply

* ICC can be measured across the series resistor R76 (1 Ω) at TP11 and TP12
* ICC_PLL can be measured across the series resistor R77 (1 Ω) at TP13 and TP14

### Idle

VCC     = 1.218V

TP11/12 = 2.9mV = 2.9mA
TP13/14 = 0mV   = 0mA

### Running longrun demo

ICC1.2  = 1.216V

TP11/12 = 8.7mV = 8.7mA
TP13/14 = 0mV   = 0mA

## iCE40 UltraPlus VCCIO

Onboard 3.3 V supply

* ICC0 can be measured across the series resistor R73 (1 Ω) at TP5 and TP6
* ICC1 can be measured across the series resistor R75 (1 Ω) at TP9 and TP10
* ICC2 can be measured across the series resistor R74 (1 Ω) at TP7 and TP8

### Idle

VCCIO   = 3.29V

TP5/6   = 0.3mV = 0.3mA
TP9/10  = 0.1mV = 0.1mA
TP7/8   = 0mV   = 0mA

### Running longrun demo

ICC3.3  = 3.29V

TP5/6   = 0.3mV = 0.3mA
TP9/10  = 0.1mV = 0.1mA
TP7/8   = 0mV   = 0mA

## Resources

* [webpage for devboard](https://www.latticesemi.com/Products/DevelopmentBoardsAndKits/iCE40UltraPlusBreakoutBoard)
* [PDF manual including schematics](https://www.latticesemi.com/view_document?document_id=51987)
* Board power testpoints detailed in section 7 (page 11)
* All measurements made with Avo M2008 uncalibrated multimeter.
