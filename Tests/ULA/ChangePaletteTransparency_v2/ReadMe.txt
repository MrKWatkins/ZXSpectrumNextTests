Source in folder: Tests/ULA/ChangePaletteTransparency_v2/

This test puts the ULA over Layer2. It fills Layer2 with some data and then switches
ULANext colours ON, setting INK mask to "default" value 15 in NextReg$42.
That leads to interpretation of attributes $38 as INK 8, PAPER 3.
Then the test sets PAPER 3 (128+3) ULA colour to default transparent ($E3) colour.
It also sets transparency-fallback colour to raw cyan ($1F).

You should see the Layer2 image as the overlying paper 3 should be transparent.

At 228th column of screen, the Layer2 pattern contains $E3 colour pixel too, which makes
all pixels at that column transparent, and the transparency-fallback colour (cyan) should
be visible there.

The BORDER 7 takes colour from ULA palette[135] (same as "paper 7"), which is set to
green (intensity 4/7, i.e. %100 binary).
