Does test "big-sprite" relative sprites (feature of core 2.00.27+).

The big sprite is composed of 10 ordinary sprites, occupying total area of 23x25 pixels.

The middle element is also "anchor" of the big sprite, the eight edge sprites are
exercising all possible mirror/rotate flags states and there is also one extra sprite
with disabled visibility (shouldn't be visible) inserted in middle of the relatives list.

The pixel shape of each sub-sprite resembles "b" with arrow pointing to top (before it's
orientation is modified for particular position). The invisible sprite has pattern of
red square.

Colours used are: blue for anchor in middle, then red, orange, yellow, light yellow,
light green, green, cyan and light blue clockwise from top left corner.

You can use keys Q,W,E,A,S to switch various features ON/OFF:
* "show all" will make also "invisible" red sprites visible
* "clip" will turn on/off sprite clipping window at coordinates [?,?] -> [?, ?]
* "priority" will change the sprite-0 to be on bottom/top of drawn sprites
* "scale X/Y" will cycle through all scales (1x, 2x, 4x, 8x)
* "depart" will move the relative subparts further away from anchor by extra +-100px

