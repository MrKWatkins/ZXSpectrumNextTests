Source in folder: Tests/base/Copper/

EDIT: New core 3.0 runs copper code at 28MHz instead of 14MHz, so currently all
the pixel sizes/positions in the old description are correct only for Core 2.0.28.
For actual Core 3.0 output check the screen photo (basically flag pixels are
50% width now, and positioning slightly differs too)

EDIT 2: Added new extra tests to the copper code:

1) the horizontal wait doing "greater/equal" check, the copper code looks like this:
> WAIT(h=16,y=140) : MOVE $41,C_BLUE : WAIT(h=24,y=140) : MOVE $41,C_YELLOW
> WAIT(h=0,y=140) : MOVE $41,C_WHITE

 => this will produce blue line at y=140 and x=128..191 ending with single yellow
pixel. If the yellow gets any larger or blinks over frames, the WAIT(h=0,y=140) did
cause roll-over into next frame, while it should not wait at all.

2) at lines 144..159 is another blue line (going from h=0 to h=0, so left border
is one line lower as it belongs to previous "y"), changing position every frame.

The new position is written into the copper code by overwriting only the "y"
byte of the two involved WAIT instructions, the patching is done where the brighter-
white paper is displayed (this color change is produced by Z80 code).

This is intentionally timed to happen somewhere inside the flags area, to verify
that write to nextregs $61+$62 selecting write-address does not affect running mode
of copper, if the same run-mode bits are used in $62 value.

------------------------------------------------------------------------------

OLD description from core 2.0.28 running copper at 14MHz:

Copper test
===========

This test does enable ULANext ULA mode and does use Copper to draw a Swedish flags
(if Copper is missing/not working, then only white paper is to be seen).

The flags are drawn by changing PAPER/BORDER 7 colour in palette, so the emulator must
notice modified palette data per pixel to produce correct result.

On real board the test result is as-designed when after WAIT instruction the MOVE
changing palette comes right after it, while Kev's document describes "3 dot" gap
ahead of desired pixel, but adding single NOOP after wait moves the flags already
one pixel to the right, so there's some discrepancy at the moment between that
document and board.

The top flag should begin with blue pixel on the edge of where black dot above ends.

The bottom dots are at X coordinates ...,236,240,244,248,252 below bottom flag, the
bottom flag is designed to have first pixel at 242, so there should be 1-pixel wide
gap between 4th-last dot end and start of the flag.
