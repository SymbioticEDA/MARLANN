% UP5K power usage running MLAccel firmware
% Symbiotic EDA
% 31/12/2018

# Aim

Using the iCE40 UP5K development board, discover the power usage of the MLAccel core when idle and when running a test firmware.
Additionally, compare default 12MHz clock with 20MHz PLL.

# Summary of results

* When idle, the FPGA draws 2.9mA @ 1.218V (3.53mW). 
* When running the _longrun_ demo, draws 8.7mA @ 1.216V (10.58mW).
* When running _longrun_ demo at 20MHz PLL draws 14mA @ 1.214V (16.99mW).
* No change detected VCC_PLL.

# Test setup

## Hardware

The [iCE40 Ultra plus breakout board](https://www.latticesemi.com/Products/DevelopmentBoardsAndKits/iCE40UltraPlusBreakoutBoard) was the hardware used to carry out the tests. The clock frequency is 12MHz.

The development board features 1R shunt resistors in series with ICC, ICC_PLL and VCCIO supplies.

* ICC can be measured across the series resistor R76 (1R) at TP11 and TP12
* ICC_PLL can be measured across the series resistor R77 (1R) at TP13 and TP14
* ICC0 can be measured across the series resistor R73 (1R) at TP5 and TP6
* ICC1 can be measured across the series resistor R75 (1R) at TP9 and TP10
* ICC2 can be measured across the series resistor R74 (1R) at TP7 and TP8

## MLAccel Firmware

To aid in making measurements, a demo firmware called _longrun_ was used. 
This firmware loads a set of coefficients and then runs a series of convolutions that completes in 1 minute.

# Results

## Idle 

Measurement  voltage (V)  current (mA)  power (mW)
-----------  -----------  ------------  -----------
ICC          1.218        2.9           3.53
ICCPLL       1.218        0.0           0.0
ICC0         3.29         0.3           0.98
ICC1         3.29         0.1           0.33
ICC2         3.29         0.0           0.0

## Longrun demo 12MHz

Measurement  voltage (V)  current (mA)  power (mW)
-----------  -----------  ------------  -----------
ICC          1.216        8.7           10.58
ICCPLL       1.216        0.0           0.0
ICC0         3.29         0.3           0.98
ICC1         3.29         0.1           0.33
ICC2         3.29         0.0           0.0

## Longrun demo 20MHz

Measurement  voltage (V)  current (mA)  power (mW)
-----------  -----------  ------------  -----------
ICC          1.214        14.0          16.99
ICCPLL       1.214        0.0           0.0
ICC0         3.28         0.3           0.98
ICC1         3.28         0.1           0.33
ICC2         3.28         0.0           0.0

## Resources

* [iCE40 UP5K development board](https://www.latticesemi.com/Products/DevelopmentBoardsAndKits/iCE40UltraPlusBreakoutBoard)
* Board power testpoints detailed in section 7 (page 11) of [PDF manual](https://www.latticesemi.com/view_document?document_id=51987)
* All measurements made with Avo M2008 uncalibrated multimeter.
