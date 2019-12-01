The test will set bit 2 of NextReg $08 -> the `in a,(255)` should then read
the Timex port, not the floating idle bus (for example CSpect doesn't has
this feature, it keeps reading floating bus, thus almost all tests fail :/ ).

Then it will write to NextReg $69 values:
  %00000000, %01000000, %10000000, %00010110, %11101000
And read the setting of layer2 and timex back through their ports and compare
the current values if they follow the setting.
(I didn't figure out how to read the shadow bit, except through this $69,
so that bit is not verified in "write" test by code. If you are emulator
author, put extra debug into your emulator code to see if the setting does
propagate correctly and switch on the ULA shadow screen)

Then it will use the same values the other way, setting them on particular
original ports (Layer2, $7FFD, Timex $FF), and reads the value back with
NextReg $69.

Finally it will display how many tests were done, and how many did match.

After this it will prepare visual part of the test, setting Layer2, ULA screen
and Timex modes VRAM to patterns producing green areas at particular scanlines
and it will reprogram the Copper to switch the modes through $69 register for
the particular region of screen.

There should be these items with green rectangle "###" next to them (rest of
the screen should look as normal ULA classic mode after CLS, no artefacts!):

Tests: 10       MachineID: 8
Passed: 10      core:3.00.123

Layer 2:     ###
ULA shadow:  ###
Timex scr1:  ###
Timex HiCol: ###
Timex HiRes Black/White
Timex Hires Blue/Yellow
L2 + shadow: ###  ###
L2 + T scr1: ###  ###
