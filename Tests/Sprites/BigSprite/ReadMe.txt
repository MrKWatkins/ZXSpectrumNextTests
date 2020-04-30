Source in folder: Tests/Sprites/BigSprite/

Does test "big-sprite" relative sprites (feature of core 2.00.27+).

The big sprite is composed of 10 ordinary sprites, occupying total area of 23x25 pixels.

The middle element is also "anchor" of the big sprite, the eight edge sprites are
exercising all possible mirror/rotate flags states and there is also one extra sprite
with disabled visibility (shouldn't be visible) inserted in middle of the relatives list.

The pixel shape of each sub-sprite resembles "b" with arrow pointing to top (before its
orientation is modified for particular position). The invisible sprite has pattern of
red square.

Colours used are: blue for anchor in middle, then red, orange, yellow, light yellow,
light green, green, cyan and light blue clockwise from top left corner.

You can use keys Q,W,E,A,S to switch various features ON/OFF:
* "show all" will make also "invisible" red sprites visible and ninth big sprite too
* "clip" will turn on/off sprite clipping window at coordinates [52,63] -> [283, 151]
* "priority" will change the sprite-0 to be on bottom/top of drawn sprites
* "scale X/Y" will cycle through all scales (1x, 2x, 4x, 8x)
* "depart" will move the relative parts +-60px away from centre (anchor), and it will
make only single one of the base eight big sprites visible (toggles through)

The "big sprite" relatives should inherit anchor scale and global space rotate/mirror
flags, i.e. they should look as if single big sprite is being operated.

There are eight big sprites visible, exercising all possible mirror/rotate flags states
at the anchor sprite, and there is one hidden ninth big sprite (just to verify the
visibility is propagated to all relative sprites).

There's one single normal sprite in bottom left part of border, showing the "invalid"
colour (violet $A2), which shouldn't appear on the big sprites (this sprite does NOT
react to the scale/depart/etc controls).

To get correct output also ULANext mode with ink format 7 is used, and ULA transparency
is required to work properly to have sprites visible in "USL" layer priority mode (ULA
on top of the sprites, but basically whole "paper" area will be transparent in ULA layer).
