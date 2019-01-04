This test puts the ULA over Layer2. It fills Layer2 with some data and then switches
ULANext colours ON, keeping default INK mask (15) in NextReg$42.
That leads to interpretation of attributes $38 as INK 8, PAPER 3.
Then the test sets PAPER 3 (128+3) ULA colour to default transparent ($E3) colour.
It also sets transparency-fallback colour to raw cyan ($1F).

You should see the Layer2 image as the overlying paper 3 should be transparent.

At 228th column of screen, the Layer2 pattern contains $E3 colour pixel too, which makes
all pixels at that column transparent, and the transparency-fallback colour (cyan) should
be visible there.

The BORDER takes colour from ULA palette[135] (same as "paper 7"), the default one.
I guess it should be white, but I'm not sure if it's guaranteed (that the ULA palette is
pre-filled after reset with standard ZX48 coulours repeating over all 256 colours).

If not guaranteed, then *any* BORDER colour is "correct".
