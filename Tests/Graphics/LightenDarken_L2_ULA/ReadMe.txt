Source in folder: Tests/Graphics/LightenDarken_L2_ULA/

Draws all three basic layers (Sprite, Layer2, ULA-LoRes) in all combinations affecting
priority and transparency, in both colour mixing modes: S(L+U) and S(L+U-5).

--- "legend" info ---

At the top of the screen you can see device info and three areas showing how each layer
is set (Sprite, Layer2, ULA), these are drawn in Layer2 graphics (not drawn by layer
which they depict).

The 2x2 chequered white/grey areas represent where transparent colour is in graphics.

The 1x1 chequered black/white areas in sprites depict none-sprite situation.

The Layer2 right half of graphics is shown "brighter", and the selected and transparent
colours used for that half have both the priority bit set to 1 (yes, the L2 palette has
two colours set as "pink" for transparency, one with and one without priority bit, and
both are used in the test-area, now how amazing is that?!).

The Sprite pattern has extra black-dotted "something" resembling rectangle "inside" (with
extra corners), this is to give visual aid about single sprite size (16x16 pixels), and
it intentionally spans also over area where Sprite demonstrates sprite transparency.

You can use keys A,S,D,F to change colours of each layer (F key does offset Layer2
other half with priority away from non-priority base colour, S key does modify whole
Layer2 at same time).

The single 8x8 char (4x4 in LoRes) does show for Layer2 and LoRes layers not just single
colour, but four gradient strips. The gradient starts at value 7 per channel (max) and
goes down by 2 for every strip (7, 5, 3, 1) (except for blue channel where last strip
is zero, and except for black base colour, where everything is just zero).

--- Test area info in middle of screen ---

Then at left side of screen there is label noting the Layer-mixing mode, and scaled-down
expected result (this is drawn as Layer2 graphics, i.e. not mixed from real layer data).
(the expected result shows only priority/order of layers, not colour mixing itself)

There's 24 total combinations of layer priority/transparency (many yield same result),
there's table at bottom of this txt showing all combinations, so the TEST-area for
particular mode is next to the expected result, and it is 6x4 (24) characters area
(one character is 8x8px).
This test output is composed from all the layers, and its result shows the actual
emulator/board rendering result, where the mixed colours of Layer2 and LoRes data
should be displayed (if the board/emulator does mix them correctly).

When all layers sport transparent pixel for particular position, the resulting combination
should be "transparency fallback" colour, which is set to "pink $EB" - to be displayed
in result as bright pink.

--- Why/how 24 combinations ---

Sprite has three states: "sprite pixel" and "transparent pixel", "no pixel"

Layer2 has four states: "pixel", "pixel w/ priority", "transparent", "transparent w/ p."

ULA-LoRes has two states: "pixel", "transparent"

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
sTlluu  mixed(ll+uu)
sXlluu  mixed(ll+uu)
sslluT  ss
sTlluT  ll
sXlluT  ll
sslTuu  ss
sTlTuu  uu
sXlTuu  uu
sslTuT  ss
sTlTuT  TT
sXlTuT  TT
ssppuu  mixed(pp+uu)
sTppuu  mixed(pp+uu)
sXppuu  mixed(pp+uu)
ssppuT  pp
sTppuT  pp
sXppuT  pp
sspTuu  ss
sTpTuu  uu
sXpTuu  uu
sspTuT  ss
sTpTuT  TT
sXpTuT  TT
