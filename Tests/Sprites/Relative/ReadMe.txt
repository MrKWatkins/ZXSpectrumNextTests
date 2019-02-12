Does test "composite" relative sprites (feature of core 2.00.27+).

The correct output is bottom line of screen showing machine info (ID + core version), and
green filled rectangle (sprite pixels) with single pixel black outline (ULA graphics).
The inside of rectangle is divided into smaller squares/rectangles (16x16 or scaled up),
each having contributing sprite ID written inside and it's anchor in bottom right corner.

Sprites are enabled to be visible in "border" area, but there should be only one blue
circle in bottom right corner of ULA pixels mildly overlapping into border to verify
it works (and sprite transparency works). Border area has thus slightly different shade
than paper area. Later sprites are drawn on top of earlier ones (default priority).

To get correct output also ULANext mode with ink format 7 is used, and ULA transparency
is required to work properly to have sprites visible in "USL" layer priority mode (ULA
on top of the sprites, but basically whole "paper" area will be transparent in ULA layer).

The test is focused on the relativity of coordinates, palette offsets, visibility,
4/8 bit mode, and new properties like scale.

It does NOT heavily exercise sprite ordering, NextReg for sprite attributes access,
graphics transparency, mirroring X/Y, rotation and other core1.xx features (which may
get separate test one day).

If there is green sprite outside of rectangle, or red sprite displayed anywhere, that's
bug.

You can use keys Q,W,E,A,S,D to switch various features ON/OFF:
* "marks" will draw light blue marks over sprite pattern to identify pattern orientation
* "show all" will make also "invisible" red sprites visible (except "0")
* "clip" will turn on/off sprite clipping window at coordinates [136,72] -> [287, 223]
* X-mirror, Y-mirror and rotate - switch ON/OFF transformation bits in "byte 3" of sprites

8 bit colours:
            $22 = l.green,  $44 = l.red,    $FF = transparent,  $11 = l.blue,   $55 = blue
4 bit colours:
[ +0 ofs]   $02 = red,      $04 = green,    $0F = transparent,  $01 = l.blue
[+16 ofs]   $12 = green,    $14 = red,      $1F = transparent,  $11 = l.blue
Everything else will be violet $A2

Defined sprite patterns:
0 8b "4x4 dot" with transparent area around using $55 colour for dot pixels
1 256x $22, works as: 8b green "8G", 4b red "4R0", 4b green with +16 palette offset "4G1"
2 256x $44, works as: 8b red "8R", 4b green "4G0", 4b red +16 "4R1"
3 128x $22, 128x $44: 4b +0 "4RG0", 4b +16 "4GR1" - two different 4b sprites in one slot
 - Can be patched to add orientation "marks" of light blue colour:
  8b patterns: left-top light blue 1/8 width "mark" and left-middle 1/4 width "mark"
  4b patterns left-top only: 1/4 width mark = LO pattern, 1/2 width mark = HI pattern
The pattern slot, when interpreted as 4b graphics, contains two sprites: LO and HI (+128).

Expected sprite list (coordinates of "map" are in 16x16 pixel blocks):

      G
  01234567890123456789    G and L sprites are anchor sprites in off-screen area
0 ....................
1 ....................    X is small dot just on the pixel/border area edge
2 ..0.................
3 ..6..177777777......    Sprites outside of main [5,3]..[13,7] rectangle should be NOT
4 ..I..24HJ55KKC......    visible, only their "allocation" marked by dotted ULA lines.
5 ..3..999955BBC......
6 ..E..888855BBC..D...    Sprites inside the main rectangle should be all visible,
7 ..F..888855ANC..M...    creating solid green area.
8 ....................
9 ....................    The letter/symbol in bottom right corner of sprite area shows
0 ....................    its anchor sprite (anchor itself has anchor, and 0 has missing
1 ....................    anchor shown as "-")
2 ....................
3 ..mmm/ccccc......X..    8-bit sprites have somewhat lighter tint of colours, 4-bit are
4 ....................    little bit darker.
5 ....................L

0 : relati, visib, [  32,  32], 8R (should be hidden because it has no anchor)
    ; 8 bit graphics, scale 1x, mostly simple positive coordinates
1 : anchor, visib, [  80,  48], 8G  (4 byte attributes)
2 : relati, visib, [   0,  16], 8G =[80,64]
3 : relati, invis, [ -48,  32], 8R =[32,80]
4 : relati, visib, [  16,  16], 8G =[96,64]  ; visible after invisible in cluster
    ; 8 bit graphics, scales, negative coordinates for relatives, relative "name"
5 : anchor, visib, [ 144,  64], 8G, scale 2x4
6 : relati, invis, [-112, -16], 8R, scale 1x1 = [32,48]
7 : relati, visib, [ -48, -16], 8G, scale 8x1 = [96,48]
8 : relati, visib, [ -64,  32], 8G, scale 4x2 = [80,96]
9 : relati, visib, [ -64,  16], 0+anchor.N = 8G, scale 4x1 = [80,80]
    ; 4 bit graphics, scales, positive/negative, palette offset
A : anchor, visib, [ 176, 112], 4G1.LO (+16), scale 1x1
B : relati, visib, [   0, -32], 4G0.LO, scale 2x2 = [176,80]
C : relati, visib, [  32, -48], 4G0.HI, scale 1x4 = [208,64]
D : relati, invis, [  80, -16], 4R0.LO, scale 1x1 = [256,96]
    ; 4 bit graphics, invisible anchor
E : anchor, invis, [  32,  96], 4R0.HI, scale 1x1
F : relati, visib, [   0,  16], 4R1.LO (+16), scale 1x1 = [32,112]
    ; 4 bit graphics, red anchor beyond screen (top left), relative palette offsets
G : anchor, visib, [  64, -63], 4R1.HI (+16), scale 1x1
H : relati, visib, [  48, 127], "-1" +anchor.N +anchor.pal_ofs = 4G1.LO, scale 1x1 =[112,64]
I : relati, invis, [ -32, 127], 4RG0.HI +anchor.pal_ofs = 4GR1.HI, scale 1x1 =[32,64]
J : relati, visib, [  64, 127], 4RG0.HI, scale 1x1 =[128,64]
K : relati, visib, [ 112, 127], 4RG0.LO +anchor.pal_ofs = 4GR1.LO, scale 2x1 =[176,64]
    ; 4 bit graphics, red anchor beyond screen (bottom right), relative pal ofs wraps!
L : anchor, visib, [ 320, 240], 4GR1.HI (+16), scale 1x1
M : relati, invis, [ -64,-128], 4RG0.LO (+240) +anchor.pal_ofs = 4RG0.LO, scale 1x1 =[256,112]
N : relati, visib, [-128,-128], 4RG0.HI (+240) +anchor.pal_ofs = 4RG0.HI, scale 1x1 =[192,112]
    ; 8 bit graphics, just final dot after everything, sporting over-border feature
X : anchor, visib, [ 286, 222], 8b dot, scale 1x1

TODO/ideas:
- clipping window on/off for [2,2]->[317,253] (will anchor get registered?)
