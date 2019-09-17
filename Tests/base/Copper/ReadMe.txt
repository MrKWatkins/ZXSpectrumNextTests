EDIT: New core 3.0 runs copper code at 28MHz instead of 14MHz, so currently all
the pixel sizes/positions in the text below are correct only for Core 2.0.28.
For actual Core 3.0 output check the extra image in the Tests/base/Copper/
(basically flag pixels are 50% width now, and positioning slightly differs too)

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
