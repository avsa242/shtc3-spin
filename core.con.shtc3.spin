{
    --------------------------------------------
    Filename: core.con.shtc3.spin
    Author:
    Description:
    Copyright (c) 2020
    Started Jul 27, 2020
    Updated Jul 27, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ        = 1_000_000
    SLAVE_ADDR          = $70 << 1

' Register definitions

    WAKEUP              = $3517
    LP_RHFIRST          = $401A
    LP_RHFIRST_CS       = $44DE
    NML_RHFIRST         = $58E0
    NML_RHFIRST_CS      = $5C24
    LP_TEMPFIRST        = $609C
    LP_TEMPFIRST_CS     = $6458
    NML_TEMPFIRST       = $7866
    NML_TEMPFIRST_CS    = $7CA2
    RESET               = $805D
    SLEEP               = $B098
    DEVID               = $EFC8

#ifndef __propeller2__
PUB Null
'' This is not a top-level object
#endif
