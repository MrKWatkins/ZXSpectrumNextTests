Source in folder: Tests/ULA/UlaScroll/

This tests the X/Y offset of ULA.

There is 16x16 dithered grid printed (just to have something on screen) and
offset registers are animated from [-233,165] to [0,0] in 512 steps (~10s).

After the animation is finished, the border will turn green, and the test
will become interactive (OPQA to scroll).

There is also ULA clip window set to [8,8] -> [239,175] (hides two columns
and two rows at bottom/right (with "///" stripes gfx), and one column/row
at top/left, hiding part of grid and having yellow paper).
