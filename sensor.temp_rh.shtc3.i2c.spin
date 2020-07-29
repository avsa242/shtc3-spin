{
    --------------------------------------------
    Filename: sensor.temp_rh.shtc3.i2c.spin
    Author:
    Description:
    Copyright (c) 2020
    Started Jul 27, 2020
    Updated Jul 27, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR            = core#SLAVE_ADDR
    SLAVE_RD            = core#SLAVE_ADDR|1

    DEF_SCL             = 28
    DEF_SDA             = 29
    DEF_HZ              = 100_000
    I2C_MAX_FREQ        = core#I2C_MAX_FREQ

' Operating modes
    NORMAL              = 0
    LOWPOWER            = 1

' Temperature scales
    C                   = 0
    F                   = 1

VAR

    byte _opmode, _temp_scale

OBJ

    i2c : "com.i2c"                                             'PASM I2C Driver
    core: "core.con.shtc3.spin"
    time: "time"

PUB Null{}
''This is not a top-level object

PUB Start: okay                                                 'Default to "standard" Propeller I2C pins and 100kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    'I2C Object Started?
                time.usleep (240)
                if i2c.present (SLAVE_WR)                       'Response from device?
                    reset{}
                    if deviceid{}
                        return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop{}
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.terminate

PUB Defaults{}
' Set factory defaults

PUB DeviceID{}: id
' Read device identification
    readreg(core#DEVID, 2, @id)

PUB Humidity{}: rh | tmp
' Current Relative Humidity, in hundredths of a percent
'   Returns: Integer
'   (e.g., 4762 is equivalent to 47.62%)
    rh := 0
    writereg(core#WAKEUP, 0, 0)                             ' Wake the sensor up

    if _opmode == NORMAL                                    ' Take a measurement
        readreg(core#NML_RHFIRST, 3, @tmp)
    elseif _opmode == LOWPOWER
        readreg(core#LP_RHFIRST, 3, @tmp)

    writereg(core#SLEEP, 0, 0)                              ' Go back to sleep

    rh.byte[0] := tmp.byte[1]
    rh.byte[1] := tmp.byte[0]

    rh := calcRH(rh)

PUB OpMode(mode): curr_mode
' Set device operating mode
'   Valid values: NORMAL (0), LOWPOWER (1)
'   Any other value returns the current setting
    case mode
        NORMAL, LOWPOWER:
            _opmode := mode
        OTHER:
            return _opmode

PUB Reset{}
' Reset the device
    writereg(core#RESET, 0, 0)
    time.usleep(240)

PUB Temperature{}: deg | tmp
' Current Temperature, in hundredths of a degree
'   Returns: Integer
'   (e.g., 2105 is equivalent to 21.05 deg C)
    deg := 0
    writereg(core#WAKEUP, 0, 0)                             ' Wake the sensor up

    if _opmode == NORMAL                                    ' Take a measurement
        readreg(core#NML_TEMPFIRST, 3, @tmp)
    elseif _opmode == LOWPOWER
        readreg(core#LP_TEMPFIRST, 3, @tmp)

    writereg(core#SLEEP, 0, 0)                              ' Go back to sleep

    deg.byte[0] := tmp.byte[1]
    deg.byte[1] := tmp.byte[0]

    deg := calcTemp(deg)

PUB TempScale(scale): curr_scale
' Set temperature scale used by Temperature method
'   Valid values:
'       C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F:
            _temp_scale := scale
        OTHER:
            return _temp_scale

PRI calcRH(rh_word): rh_cal

    return (rh_word * 100_00) / 65535

PRI calcTemp(temp_word): temp_cal

    case _temp_scale
        C:
            return ((175 * (temp_word * 100)) / 65535)-45_00
        F:
            return ((315 * (temp_word * 100)) / 65535)-49_00
        OTHER:
            return FALSE

PRI readReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp, ackbit
'' Read num_bytes from the slave device into the address stored in buff_addr
    case reg_nr                                             ' Basic register validation
        $401A, $58E0, $609C, $7866:                         ' without clock-stretching
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg_nr.byte[1]
            cmd_packet.byte[2] := reg_nr.byte[0]

            i2c.start{}                                     ' Send measurement command
            i2c.wr_block (@cmd_packet, 3)
            i2c.stop{}

            repeat
                i2c.start{}
                ackbit := i2c.write(SLAVE_RD)
                ' XXX Datasheet shows a stop condition here, then a restart before the below read
                '   but no data is returned when writing the routine that way
            while ackbit == i2c#NAK
            i2c.rd_block (buff_addr, nr_bytes, TRUE)
            i2c.stop{}
            time.msleep(1)

        $44DE, $5C24, $6458, $7CA2:                         ' with clock-stretching
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg_nr.byte[1]
            cmd_packet.byte[2] := reg_nr.byte[0]

            i2c.start{}                                     ' Send measurement command
            i2c.wr_block (@cmd_packet, 3)
            i2c.stop{}

            time.msleep(13)
            i2c.start{}                                     ' I2C driver waits for SCL to be released
            i2c.write(SLAVE_RD)
            i2c.rd_block (buff_addr, nr_bytes, TRUE)
            i2c.stop{}

        core#DEVID:
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg_nr.byte[1]
            cmd_packet.byte[2] := reg_nr.byte[0]

            i2c.start{}
            i2c.wr_block (@cmd_packet, 3)
            i2c.stop{}

            i2c.start{}
            i2c.write(SLAVE_RD)
            i2c.rd_block(buff_addr, 3, TRUE)
            i2c.stop{}

        OTHER:
            return

PRI writeReg(reg_nr, nr_bytes, buff_addr) | cmd_packet, tmp
'' Write num_bytes to the slave device from the address stored in buff_addr
    case reg_nr
        core#WAKEUP, core#RESET, core#SLEEP:
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg_nr.byte[1]
            cmd_packet.byte[2] := reg_nr.byte[0]
            i2c.start{}
            i2c.wr_block (@cmd_packet, 3)
            i2c.stop{}
        OTHER:
            return


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
