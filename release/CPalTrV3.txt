Source in folder: Tests/ULA/ChangePaletteTransparency_v3/

This test puts the ULA over Layer2. It fills Layer2 with some data.
Then it sets INK mask to 7 and PAPER 7 ULANext colour (128+7 index in palette)
to transparent ($E3), but it keeps ULANext colours OFF (!) (16+7 index for PAPER 7),
expecting classic ZX48 ULA display on output.

It also sets transparency-fallback colour to raw cyan ($1F).

You should see the full white paper+border and nothing of underlying Layer2 image, as
the ULANext white->transparent-pink should be not happening.

(there is rainbow-coloured informal text over white paper, that white screen is expected,
this is achieved by changing also INK 0 colour in palette to transparent $E3)

If the emulator does use palette item 128+7 for PAPER even if ULANext is OFF, the full
rainbow screen is visible, with no text.
