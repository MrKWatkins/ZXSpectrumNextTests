Source in folder: Tests/ULA/ChangePaletteTransparency/

This demo puts the ULA over Layer2. It fills Layer2 with some data and then changes
the ULA palette so paper 7 is the default ($E3) transparent colour. It also sets
transparency-fallback colour to raw cyan ($1F).

You should see the Layer2 image as the overlying white paper should be transparent.

At 228th column of screen, the Layer2 pattern contains $E3 colour pixel too, which makes
all pixels at that column transparent, and the transparency-fallback colour (cyan) should
be visible there.

The border takes colour from ULA palette[135] (same as "paper 7"), the $E3 pink, which
is then converted by transparency-fallback into the cyan too.
