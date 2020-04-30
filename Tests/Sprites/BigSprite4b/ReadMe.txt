Source in folder: Tests/Sprites/BigSprite4b/

Does test "big-sprite" relative sprites (feature of core 2.00.27+).

This is almost identical test to SpritBig.sna (Tests/Sprites/BigSprite), except
the graphical patterns are 4-bit and displaying "Golden Wings" item "B" graphics.

The first half (0..127) of pattern slot has original "B" item graphics, the second
half (128..255) has modified copy showing "E"-like letter.

In the big sprite there are two sprites using the "E" variant (top-left and middle-right).

The big sprite is composed of 10 ordinary sprites, occupying total area of ~40x40 pixels.

The middle element is also "anchor" of the big sprite, the eight edge sprites are
exercising all possible mirror/rotate flags states and there is also one extra sprite
with disabled visibility (shouldn't be visible) inserted in middle of the relatives list.

The pixel shape of each sub-sprite resembles bonus-like "B item" (before its orientation
is modified for particular position). The invisible sprite has pattern of red square.

Colours on middle anchor and top left sprites should be close to original Amiga graphics,
then clockwise the palette is slowly saturated toward yellow colour.

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

There're two normal sprites in bottom left part of border, showing both possible gfx
patterns (these sprites do NOT react to the scale/depart/etc controls).

To get correct output also ULANext mode with ink format 7 is used, and ULA transparency
is required to work properly to have sprites visible in "USL" layer priority mode (ULA
on top of the sprites, but basically whole "paper" area will be transparent in ULA layer).
