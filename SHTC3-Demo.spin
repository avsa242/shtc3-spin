{
----------------------------------------------------------------------------------------------------
    Filename:       SHTC3-Demo.spin
    Description:    Driver for the Sensirion SHT-C3 Temperature/RH sensor
    Author:         Jesse Burt
    Started:        Jul 27, 2020
    Updated:        Oct 3, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine in the driver
'#define SHTC3_I2C_BC
'#pragma exportdef(SHTC3_I2C_BC)


CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


OBJ

    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.temp_rh.shtc3" | SCL=28, SDA=29, I2C_FREQ=100_000


PUB main() | temp, tscl, rh

    setup()

    sensor.temp_scale(sensor.C)

    repeat
        ser.pos_xy(0, 3)
        temp := sensor.temperature()
        tscl := lookupz(sensor.temp_scale(-2): "C", "F", "K")
        ser.printf3(@"Temp. (deg %c): %3.3d.%02.2d\n\r", tscl, (temp / 100), ||(temp // 100))
        rh := sensor.rh()
        ser.printf2(@"Rel. humidity (%%): %3.3d.%02.2d\n\r", (rh / 100), (rh // 100))


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"SHTC3 driver started")
    else
        ser.strln(@"SHTC3 driver failed to start - halting")
        repeat


DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

