Source in folder: Tests/Graphics/NextReg0x69/

The test will set bit 2 of NextReg $08 -> the `in a,(255)` should then read
the Timex port, not the floating idle bus (for example CSpect doesn't has
this feature, it keeps reading floating bus, thus almost all tests fail :/ ).
Also it will unlock $7FFD port in NextReg $08 (being locked by NextZXOS while
loading the 48k SNA file to better emulate ZX48 machine).

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

There are also per-test indicators in second line, in the pixel graphics there
is "ruler" at top (marking every 4th (bit 4) and 8th pixel (bit 0)), under
ruler there is single empty line and then the expected and real value is
displayed, so in case of failed test you can read which bits didn't match.

After this it will prepare visual part of the test, setting Layer2, ULA screen
and Timex modes VRAM to patterns producing green areas at particular scanlines
and it will reprogram the Copper to switch the modes through $69 register for
the particular region of screen. The copper is programmed to WAIT for the new
scanline at horizontal coordinate 0, i.e. at the very edge where pixel area
starts, then it sets $69 to the new value.

There should be these items with green rectangle "###" next to them (the green
part is provided by the particular mode gfx) (HiRes modes have just text):

Tests OK: 10/10   MachineID: 8
rrrrrrrrrr        core:3.00.123

Layer 2:     ###
ULA shadow:  ###
Timex scr1:  ###
Timex HiCol: ###
Timex HiRes Black/White
Timex Hires Blue/Yellow
L2 + shadow: ###  ###
L2 + T scr1: ###  ###

("rrrr.." are the bit-values of each test and color to indicate result)

The mode switch takes different amount of cycles, the visible artefacts from
left edge measure how long the particular feature takes to settle down (ULA
modes read two characters ahead in the last 8 cycles of current chunk, layer 2
can switch on/off within 3-4 cycles, Hires picks new color in one character).
The artefacts coloring scheme:
red = layer2, cyan = classic ULA, blue = shadow ULA, yellow = Timex $6000 area

(it would be simple to avoid the artefacts by changing the copper to WAIT at
previous scanline at horizontal value like 39, inside the h-blank period, but
the test is intentionally waiting for pixel area edge to make the mode switch
delay observable/measurable)

On core 3.00.5 (latest at the time of writing this test), the board seems,
when the Layer 2 is switched ON from OFF state, to produce one red pixel
artefact which seems to be connected to the way how FPGA does fetch pixel
data for Layer 2, which may get rewritten in future cores, so the displayed
artefacts and mode switch timing may differ in the future.

If you are planning to release SW which depends on pixel-perfect timings of
these changes, the results are deterministic per-core, so you can fine-tune
the copper code until the visual result does match your desired outcome, but
make sure you do document the precise core version number which was used to
tune your SW, as the future cores may change the outcome slightly (and you
may need to retune your copper code to match it).
