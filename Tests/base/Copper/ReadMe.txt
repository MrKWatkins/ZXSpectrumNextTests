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
