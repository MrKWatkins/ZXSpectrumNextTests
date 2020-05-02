Source in folder: Tests/ULA/ClassicPaletized/

Exercising ULA classic mode with Next palette capabilities and 128k/+3 machine timing.

------------------------------------------------------------------------------------------
WARNING: the timing of the test is not perfect with core 2.00.27, so visual artefacts
while running at real HW are OK at this moment, check the included photo of correct
output - also as with anything precisely timed by CPU on Next, the baseline is VGA-0 50Hz
output mode. Other output modes may be broken even more (especially 60Hz modes and HDMI
modes are looking lot more "broken"). Still the test content is valid even if the BORDER
stripes don't align pixel-perfect with attribute rows, only their position is invalid.
------------------------------------------------------------------------------------------

The top half of screen is displaying first ULA palette (should contain default
ZX Spectrum colours), the bottom half of screen is displaying second ULA palette,
set up to custom colours.

In the top/bottom third of PAPER area there are all possible 256 combinations
of attributes displayed.

Each 8x8 "character" contains two pixels thick PAPER frame around 4x4 pixels INK square
inside.

The BORDER area is set to "7" (white/cyan) everywhere except around the top/bottom
PAPER area thirds, where the top/bottom edge should show one pixel tall border "4"
(green/light blue) with 8 pixel tall (i.e. aligned to attribute row) spectrum going
from "0" to "7" border colours.

The custom colours are:
BRIGHT 0: INK 0-7: gradient from raw red (7,0,0) to raw green (0,7,0)
BRIGHT 1: INK 0-7: gradient from green (1,7,0) to raw blue (0,0,7)
[(1,7,0), (0,6,1), (0,5,2), ..., (0,1,6), (0,0,7) - only INK 0 has +1 red]

BRIGHT 0: PAPER 0-7: gradient from raw violet (7,0,7) to raw cyan (0,7,7)
BRIGHT 1: PAPER 0-7: gradient from cyan (1,7,7) to raw yellow (7,7,0)
[(1,7,7), (1,7,6), (2,7,5), ..., (6,7,1), (7,7,0) - PAPER 0 has +1 red]

Those "+1 red" in INK/PAPER 0 in bright mode are added to make them different from
INK/PAPER 7 in bright 0 mode.

The flash feature of ULANext does invert the INK/PAPER as if pixel data were inverted,
i.e. with the custom palette the INK 1 + BORDER 0 + BRIGHT 0 + FLASH 1 character (second
flashing 8x8 square) should alternate between:
1) violet frame + dark red square inside (same as second char in non-flash area)
2) dark red frame + violet square inside

I.e. palette elements are fetched by ULA as INK 1 and PAPER 0 in either case, but "ink"
is applied to "0" pixels in the "frame" area, and "paper" is applied to "1" pixels inside,
while "flashing" (INK 1 = palette[1], PAPER 0 = palette[16] in BRIGHT 0 mode).

(swapping just values as if fetching "ink 0 + paper 1" and drawing original pixels would
lead to incorrect dark violet frame and raw red square)
