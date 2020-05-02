Source in folder: Tests/Graphics/LayersMixingHiCol/

This is identical test to "Layer2Colours" test, but the ULA layer is switched to "HiCol"
mode this time. Following text is same as Layer2Colours (if you read it already...).

(the colouring of "MachineID: ##" part is intentional, just to have fun with HiCol mode)
-------------------------------------------------------------------------------------

Draws all three basic layers (Sprite, Layer2, ULA-HiCol) in all combinations affecting
priority and transparency, and in all basic six layer-order modes.

There's 24 total combinations (of course many yield same result, but hidden layers are
in different state), there's table at bottom of this txt showing all combinations.

At left side of screen (first column) there is label with layers-priority, and miniature
of expected result (this is drawn as Layer2 graphics only, not using ULA/Sprites).

The TEST-area for particular layer ordering is in the second column covering 6x4 (24)
ULA characters (one character = 8x8 pix) area. This output is composed from all layers,
and its result shows the actual emulator/board rendering result.

On the right under "Legend" there are three areas showing how each layer is set (Sprite,
Layer2, ULA), these are drawn in Layer2 graphics (not drawn by layer which they depict).

The 2x2 chequered white/grey areas represent where transparent colour is in graphics.

The 1x1 chequered black/white areas in sprites depict none-sprite situation.

The Layer2 right half of graphics is shown "brighter", and the green and transparent
colours used for that half have both the priority bit set to 1 (yes, the L2 palette has
two colours set as "pink" for transparency, one with and one without priority bit, and
both are used in the test-area, now how amazing is that?!).

The Sprite pattern has extra black-dotted "something" resembling rectangle "inside" (with
extra corners), this is to give visual aid about single sprite size (16x16 pixels), and
it intentionally spans also over area where Sprite demonstrates sprite transparency.

When all layers sport transparent pixel for particular position, the resulting combination
should be "transparency fallback" colour, which is set to "pink $E3" - to be displayed
in result as pink.


Why/how 24 combinations
=======================

(this test was designed before the Tilemap mode was added, and it does not account for it)

Sprite has three states: "sprite pixel" and "transparent pixel", "no pixel"

Layer2 has four states: "pixel", "pixel w/ priority", "transparent", "transparent w/ p."

ULA-HiCol has two states: "pixel", "transparent"

That allows for 24 combinations (3 * 4 * 2 = 24). The order is selected by the control
register and by priority bit of L2 colour, but there's only single possible order for
every state combination, so order is not contributing to total amount of possibilities.

(the "no pixel" states are actually possible also with L2 and ULA layers, if clip-window
is used to cut part of layer out, or L2 is completely disabled ... for the sake of finite
amount of combinations in the test, these possibilities are ignored)

Now if the states are named {ss, sT, sX} for Sprites, {ll, pp, lT, pT} for Layer2 and
{uu, uT} for ULA layer, for the "SLU" layer ordering these 24 combinations are possible:

; "xxyyzz" three states contributing to final pixel, "xx" after is visible result, where
; "TT" is result for no visible pixel (transparency-fallback-colour register will display)

sslluu  ss
sTlluu  ll
sXlluu  ll
sslluT  ss
sTlluT  ll
sXlluT  ll
sslTuu  ss
sTlTuu  uu
sXlTuu  uu
sslTuT  ss
sTlTuT  TT
sXlTuT  TT
ppssuu  pp
ppsTuu  pp
ppsXuu  pp
ppssuT  pp
ppsTuT  pp
ppsXuT  pp
pTssuu  ss
pTsTuu  uu
pTsXuu  uu
pTssuT  ss
pTsTuT  TT
pTsXuT  TT

The results for other layer ordering are left out as an exercise for dear reader... :)
