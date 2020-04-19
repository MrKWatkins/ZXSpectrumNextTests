!!! WARNING !!! This test does require Z80N CPU with extended instruction set.

This is fully interactive test, to verify scanline-related registers and interrupts.

Press Q/A/W/S to modify the test-scanline value (only low 8 bits are configurable).

Press T/F/V to switch to different timings of display (V works only in VGA modes, not in HDMI).

Press Z to switch between test reading scanline register $1F, or using interrupt at scanline ($22 + $23 registers, but again only 0..255 scanline is possible).

The $1F test, when values are low enough (cca. 0..50), will trigger twice per frame, for example for scanline 50 it will trigger both at scanline 50 and at 306 (top border area), this is expected and OK.

There should be background color change starting at desired scanline (not from left edge of screen, but somewhat midway for $1F test, on left edge for interrupt) and it should be displayed in stable manner every frame at the same desired place (two places if two lines are shown due to 8bit test value). The beginning/end of the line and the total size of the line may be somewhat unstable and jump around each frame, but the line should not jump above/below considerably, like it started on different line.

If you are wondering what is this doing and why it was added to test suite:

this should have been rather mundane and boring test displaying the line on screen, but it turned out the HW board with core3.1.0 at 3.5MHz does read sometimes wrong value from nextreg $1F - in some specific areas of display, so for example test configured to wait for line 224 will sometimes trigger already near line 192. These weird readings and "jumpings" in scanline-synchronization in my other SW lead me to write this test, to verify where is the problem.
