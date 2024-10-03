{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.temp_rh.shtc3.spin
    Description:    Driver for the Sensirion SHT-C3 Temperature/RH sensor
    Author:         Jesse Burt
    Started:        Jul 27, 2020
    Updated:        Oct 3, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.temp_rh.common.spinh"          ' use code common to all temp/rh drivers

CON

    { default I/O settings; these can be overridden in the parent object }
    SCL         = 28
    SDA         = 29
    I2C_FREQ    = 100_000
    I2C_ADDR    = 0


' Operating modes
    NORMAL      = 0
    LOWPOWER    = 1


    SLAVE_WR    = core.SLAVE_ADDR
    SLAVE_RD    = core.SLAVE_ADDR | 1


VAR

    byte _opmode


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef SHTC3_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.shtc3"                    ' hw-specific constants
    time:   "time"                              ' timekeeping methods
    crc:    "math.crc"                          ' crc algorithms


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 1_000_000 but is unenforced)
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)             ' wait for device startup
            reset()
            if ( dev_id() == core.DEVID_RESP )  ' validate device
                return status
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()
    _opmode := 0


PUB defaults()
' Set factory defaults


PUB dev_id(): id
' Read device identification
'   Returns: $0807
    readreg(core.DEVID, 2, @id)
    id &= $083F                                 ' only some bits are relevant


PUB measure()
' dummy method


PUB opmode(mode): curr_mode
' Set device operating mode
'   Valid values: NORMAL (0), LOWPOWER (1)
'   Any other value returns the current setting
    case mode
        NORMAL, LOWPOWER:
            _opmode := mode
        other:
            return _opmode


PUB reset()
' Reset the device
    cmd(core.WAKEUP)                            ' avoid NAK from sensor when
    cmd(core.RESET)                             '   sending reset
    time.usleep(core.T_POR)


PUB rh_data(): rh_adc
' Read relative humidity data
'   Returns: u16
    rh_adc := 0
    cmd(core.WAKEUP)                            ' Wake the sensor up
    time.usleep(core.T_POR)

    if ( _opmode == NORMAL )                    ' Take a measurement
        readreg(core.NML_RHFIRST_CS, 3, @rh_adc)
    elseif ( _opmode == LOWPOWER )
        readreg(core.LP_RHFIRST_CS, 3, @rh_adc)

    cmd(core.SLEEP)                             ' Go back to sleep


PUB rh_word2pct(rh_word): rh_cal
' Convert RH ADC word to hundredths of a percent
'   Returns: 0..100_00
    return (rh_word * 100_00) / 65535


PUB temp_data(): temp_adc
' Read temperature data
'   Returns: s16
    temp_adc := 0
    cmd(core.WAKEUP)                            ' Wake the sensor up
    time.usleep(core.T_POR)

    if ( _opmode == NORMAL )                    ' Take a measurement
        readreg(core.NML_TEMPFIRST_CS, 3, @temp_adc)
    elseif ( _opmode == LOWPOWER )
        readreg(core.LP_TEMPFIRST_CS, 3, @temp_adc)

    cmd(core.SLEEP)                             ' Go back to sleep


PUB temp_word2deg(temp_word): temp_cal
' Convert temperature ADC word to degrees
'   Returns: hundredths of a degree, in chosen scale
    case _temp_scale
        C:
            return ((175 * (temp_word * 100)) / 65535)-45_00
        F:
            return ((315 * (temp_word * 100)) / 65535)-49_00
        other:
            return FALSE


PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp, crc_r
' Read nr_bytes from the slave device into ptr_buff
    tmp := 0
    case reg_nr                                 ' validate reg num
        $44DE, $5C24, $6458, $7CA2:             ' meas. with clock-stretching
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr.byte[1]
            cmd_pkt.byte[2] := reg_nr.byte[0]

            i2c.start()                         ' Send measurement command
            i2c.wrblock_lsbf(@cmd_pkt, 3)
            i2c.stop()

            i2c.start()                         ' read measurement
            i2c.write(SLAVE_RD)
            i2c.rdblock_msbf(@tmp, nr_bytes, i2c.NAK)
            i2c.stop()
            crc_r := tmp.byte[0]                ' crc read in for data
            tmp >>= 8                           ' chop it off of the data
            if ( crc.sensirion_crc8(@tmp, 2) == crc_r )
                long[ptr_buff] := tmp
        $401A, $58E0, $609C, $7866:             ' meas. without clock-stretch
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr.byte[1]
            cmd_pkt.byte[2] := reg_nr.byte[0]

            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 3)
            i2c.stop()

            i2c.wait(SLAVE_RD)
            i2c.rdblock_msbf(@tmp, nr_bytes, i2c.NAK)
            i2c.stop()
            time.msleep(1)
            crc_r := tmp.byte[0]                ' crc read in for data
            tmp >>= 8                           ' chop it off of the data
            if ( crc.sensirion_crc8(@tmp, 2) == crc_r )
                long[ptr_buff] := tmp
        core.DEVID:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr.byte[1]
            cmd_pkt.byte[2] := reg_nr.byte[0]

            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 3)
            i2c.stop()

            i2c.start()
            i2c.write(SLAVE_RD)
            i2c.rdblock_msbf(@tmp, 3, i2c.NAK)
            i2c.stop()
            crc_r := tmp.byte[0]                ' crc read in for data
            tmp >>= 8                           ' chop it off of the data
            if ( crc.sensirion_crc8(@tmp, 2) == crc_r )
                long[ptr_buff] := tmp
        other:
            return


PRI cmd(reg_nr) | cmd_pkt
' Issue command to the device
    case reg_nr
        core.WAKEUP, core.RESET, core.SLEEP:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr.byte[1]
            cmd_pkt.byte[2] := reg_nr.byte[0]
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 3)
            i2c.stop()
        other:
            return


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

