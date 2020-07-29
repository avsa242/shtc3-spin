{
    --------------------------------------------
    Filename: SHTC3-Test.spin
    Author:
    Description:
    Copyright (c) 2020
    Started Jul 27, 2020
    Updated Jul 27, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    SER_RX      = 31
    SER_TX      = 30
    SER_BAUD    = 115_200
    LED         = cfg#LED1

    I2C_SCL     = 28
    I2C_SDA     = 29
    I2C_HZ      = 1_000_000
' --

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    shtc3   : "sensor.temp_rh.shtc3.i2c"

PUB Main{} | t

    setup{}
    ser.hex(shtc3.deviceid{}, 8)
    ser.newline{}
    t := 0
    repeat
        ser.position(0, 5)
        t := shtc3.temperature
        ser.hex(t, 8)
        time.msleep(100)

PUB Setup{}

    repeat until ser.startrxtx(SER_RX, SER_TX, 0, SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.str(string("Serial terminal started", ser#CR, ser#LF))
    if shtc3.startx(I2C_SCL, I2C_SDA, I2C_HZ)
        ser.str(string("SHTC3 driver started", ser#CR, ser#LF))
    else
        ser.str(string("SHTC3 driver failed to start - halting", ser#CR, ser#LF))
        shtc3.stop{}
        time.msleep(30)
        ser.stop{}


DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
