Z80N instructions tests
=======================

Quick tests for new Z80N instructions - *NOT* checking full state of CPU after
instruction execution, but mostly trying at least to use all possible values and
check the main result of instruction.

Press "2" to switch on 14MHz turbo mode (if your emulator already supports it,
NextRegs 6 and 7 are required for turbo enabling+speed setting) (you may also
want to apply your own emulator "run as fast as possible" setting maybe).

Press "3" to select levels of "fullness" of tests, partial tests take about 12s
to finish, full tests take about ~5 minutes (at 14MHz).

To run particular test, hit the highlighted letter, or use "5" to run all tests.

At the end of line there will be status of finished tests, "ERR" marks some error
happened during test, "OK" means the instruction passed the test. "OK1" means the
test passed successfully, but there may exist one more (thorough) level of test.

For tests with "ERR" result, by hitting the highlighted key, you can see "error log"
from particular test. Tests usually abort upon finding first problem, so log will
usually contain only that. All values in log are always hexadecimal, two digits
are used for 8 bit values, four digits for 16 bit values. The error logs are by
no means supposed to provide full debug info, it's expected you will inspect the
test code itself and investigate there (the log is just hint about detected issue).

For more details about how instructions are supposed to work you may want to also check:
http://devnext.referata.com/wiki/Extended_Z80_instruction_set

Details of possible errors (explaining the error log) per instruction:

 ADD BC,$nnnn   ED  36  low  high   BC += n, flags undefined at this moment
  - no test yet

 ADD BC,A       ED  33              BC += uint16_t(A), no flags change
  - displays A (8b), BC (16b) and result (16b), if result seems correct, the CF=1 was set

 ADD DE,$nnnn   ED  35  low  high   DE += n, flags undefined at this moment
  - expected result (16b), result (16b), $nnnn used (16b)
  - the "full" test does NOT EXIST! (would take hours?), "OK1" is "best" result for now

 ADD DE,A       ED  32              DE += uint16_t(A), no flags
  - displays A (8b), DE (16b) and result (16b), if the instruction does set CF=1 (error),
  the "result" will be -1 to the true result

 ADD HL,$nnnn   ED  34  low  high   HL += n, flags undefined at this moment
  - expected result (16b), result (16b), $nnnn used (16b)
  - the "full" test does NOT EXIST! (would take hours?), "OK1" is "best" result for now

 ADD HL,A       ED  31              HL += uint16_t(A), no flags
  - displays A (8b), HL (16b) and result (16b), if the instruction does set CF=1 (error),
  the "result" will be -1 to the true result

 LDDRX          ED  BC              do LDDX until BC=0, no flags
  - if the adjustments of HL/DE/BC are wrong, message is displayed (values calculated by
  the instruction are not shown, you will have to use your own debugger).
  - message is displayed, when value A was written into memory, displays A (8b)
  - message is displayed when non-A value was not written, displays expected (8b) vs
  value in memory (8b)

 LDDX           ED  AC              if (A != *HL) { *DE = *HL } HL-- DE++ BC--, no flags
  - if the adjustments of HL/DE/BC are wrong, message is displayed (values calculated by
  the instruction are not shown, you will have to use your own debugger).
  - message is displayed, when value A was written into memory, displays A (8b)
  - message is displayed when non-A value was not written, displays expected (8b) vs
  value in memory (8b)

 LDIRX          ED  B4              do LDIX until BC=0, no flags
  - if the adjustments of HL/DE/BC are wrong, message is displayed (values calculated by
  the instruction are not shown, you will have to use your own debugger).
  - message is displayed, when value A was written into memory, displays A (8b)
  - message is displayed when non-A value was not written, displays expected (8b) vs
  value in memory (8b)

 LDIX           ED  A4              if (A != *HL) { *DE = *HL } HL++ DE++ BC--, no flags
  - if the adjustments of HL/DE/BC are wrong, message is displayed (values calculated by
  the instruction are not shown, you will have to use your own debugger).
  - message is displayed, when value A was written into memory, displays A (8b)
  - message is displayed when non-A value was not written, displays expected (8b) vs
  value in memory (8b)

 LDPIRX         ED  B7              do { t = HL&0xFFF8 | E&7; if (A != *t) { *DE = *t } DE++ BC-- } until (BC=0), no flags
  - if the adjustments of HL/DE/BC are wrong, message is displayed (values calculated by
  the instruction are not shown, you will have to use your own debugger).
  - if unexpected value, two values are displayed: expected (8b) vs value in memory (8b).
  Expected values 0x50..0x57 are part of "pattern" data, other is complement of tested A.

 LDWS           ED  A5              *DE = *HL L++ D++, flags as "INC D"
  - if the adjustments of HL/DE are wrong, messages are displayed with expected (16b) vs
  obtained value (16b) (there is separate message for HL and DE).
  - message if BC was modified by instruction for some reason
  - if unexpected value, two values are displayed: expected (8b) vs value in memory (8b).
  - if unexpected flags, message + two values displayed: expected F (8b) vs real F (8b).

 MIRROR         ED  24              bits in A are reversed, no flags
  - two values: expected (8b), received (8b)

 MUL D,E        ED  30              DE = D * E, no flags
  - three values: D (8b), E (8b) and result (16b). The displayed result may be less by one
  (than real result) when instruction did also set carry flag (the error is the flag then).

 NEXTREG $rr,$n ED  91  register  value     Writes N to Next register R (directly, no I/O), no flags
  - message when I/O port $243B was modified by nextreg instruction
  - Value in NextReg: expected (8b), stored/read-back (8b), NextReg number (8b)

 NEXTREG $rr,A  ED  92  register    Writes A to Next register R (directly, no I/O), no flags
  - message when I/O port $243B was modified by nextreg instruction
  - Value in NextReg: expected (8b), stored/read-back (8b), NextReg number (8b)

 OUTINB         ED  90              I/O port *BC = *HL HL++, no flags
  - message with damaged port value (16b)
  - expected (8b) vs received (8b) value, if value reads different than expected
  - expected HL (16b) vs received HL (16b)

 PIXELAD        ED  94              HL = 0x4000 VRAM address from pixel coordinates x=E, y=D, no flags
  - expected HL (16b) vs received HL (16b), DE coordinates (16b)

 PIXELDN        ED  93              HL advanced to "next line" in classic ZX VRAM, no flags
  - expected HL (16b) vs received HL (16b) (this test is not sensitive to carry changes)

 PUSH $nnnn     ED  8A  high  low   Stores value N onto stack (SP-- *SP=hi SP-- *SP=lo), no flags
  - expected value (16b) vs value found in memory (stored by PUSH) (16b)

 SETAE          ED  95              A = uint8_t(0x80)>>(E&7), no flags (E as x-coordinate to bitmask in A) 
  - three values: expected bitmask (8b), calculated bitmask (8b), pixel x-coordinate (8b)

 SWAPNIB        ED  23              A = (A<<4) | ((A>>4)&0xF), no flags (swap nibbles)
  - two values: expected (8b) vs received (8b)

 TEST $nn       ED  27  value       flags as if "AND $nn", but A is preserved
  - three values: $nn (8b) expected (16b) vs received (16b) - 16b values are "AF", A is
  upper 8 bits.
