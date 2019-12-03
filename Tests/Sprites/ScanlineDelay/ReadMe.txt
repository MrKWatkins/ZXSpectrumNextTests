Test will draw some kind of "ruler" in the ULA screen, with the largest
ruler line representing the +0 scanline, the active target of copper code.

The left side of ruler is on odd lines (-3,-1,+1,+3,+5,+7) with +0 and +4
having extra parts left of the odd-marks. The right side of the ruler
shows even lines (-2,+0,+2,+4,+6) with +0 and +4 being longest+longer ones.

Between the rulers the left half is occupied by static sprite (for
comparison purposes and to verify that sprites are actually rendered),
the right half should contain only single line from the sprite (same
graphics pattern is used for the right sprite, but only single line is
rendered (visibility = ON/OFF)).

Depending on the position of the single line, one can read the sprite
renderer delay.

There is extra change of ULA paper to light cyan for the whole scanline,
where the sprite is set to "visible", this one should align to the
+0 ruler.

If the ULA line is misaligned, it signals the copper commands are affecting
wrong scanlines (common in emulators to affect previous scanline instead
of target one, in such case the sprite delay counts against the cyan paper).

On current core 3.0.5 the sprite engine is using double-buffering (per
scanline), so the result is visible with one scanline delay. But be aware
the rendering of buffer for scanline "y" starts right after the last
sprite pixel of line y-2 is displayed (copper H=36, sprite X=320), and will
continue with rendering until the same spot is reached on line y-1.

This means you need to adjust sprite attributes quite early if you want the
change to be visible with only one line delay, like toward end of paper
area or within the sprite area - of course then you risk some of the changes
may get rendered in the current process, if you are exhausting pixel
bandwidth a lot, and you modify the last sprites in list too early
(the sprite engine always render sprites from sprite 0 to sprite 127, even
when top-to-bottom priority is flipped, and there's about 1600+ pixels per
line available, so if you have on single line 50 visible sprites with scale
1x (16 pixels per sprite), the sprite engine will finish the rendering
roughly around first third of "paper" area, then changing sprite attributes
after half of screen (sprite X=32+128) shouldn't affect anything as the
buffer is already finished.

## How the test works:

The copper will WAIT for scanline-1, horizontal=35 = just around sprite
X=312 coordinate, ahead of the target scanline (the target scanline is
eighth pixel line from top).

Then the copper commands will modify the ULA paper color to light cyan
and make the right sprite visible.

Another copper WAIT is issued for "scanline" (with horizontal=35 too),
i.e. just single scanline below the first wait.

And the following commands will restore the ULA paper color, and make
the right sprite invisible again.

This copper code is auto-restarted every frame (the copper mode %11).

## Added four further variants of the initial test described above:

The second test "RotMir / Xpos" does test two distinct things with single
sprite. At the target scanline the ULA paper is changed to light yellow
and sprite attributes are modified to have ROTATE+MIRROR_X, and move
sprite by 9 pixels to right. The rotate+mirror will demonstate itself
as single line with color dots (instead of single-color line), the X-offset
will demonstrate by the line of sprite being on the right side. These two
effects will very likely happen at the same line (with most of the sprite
renderers), but they are two distinct tests and maybe some renderer may
trigger each feature on different line.

The third test "Transp. index" doesn't modify the sprite attributes, but
only changes the global Sprite transparency index from $1F to $01 at the
active line (ULA paper light violet). On that line the sprite transparent
area with $1F cyan color will be suddenly visible, for single scanline.

The fourth test "Palette color" will turn off sprite transparency (set to $01)
for whole rectangle area to make the $1F area visible, and the copper will
modify the Sprite palette item $1F to "orange" color, at the active scanline
(ULA paper cyan). This should uncover if the palette values are used at the
moment of rendering, or rendering is done with index-colors and 9b RGB is
fetched from palette later, when buffer is applied to display output.

(the core 3.0.5 does render sprites in index mode into buffer, and does
fetch final 9b color from palette when the buffer is mixed into display
output, so the changes applied to palette item are without delay)

## How is it even useful if you want to code for Next:

There is old art of "sprite multiplexing" technique, allowing you to
display more sprites on screen than the original HW claims to support,
if you modify the HW sprites attributes racing the display-beam drawing
the scanlines one by one to the display. So the same HW sprite may be
used to draw one sprite in top area, and another sprite in bottom area
(as long as the areas don't share the same scanline, which would require
two HW sprites to get them rendered both).

With Next and it's 128 HW sprites it is actually not that likely you
would need multiplexing technique, but if you do, the info from this
test is important for you to time the multiplexing changes (or even
non-multiplexing-but-very-late changes) correctly to get the desired
display output. With current core 3.0.5 it seems you need to modify
sprite coordinates, visibility and pattern one scanlines ahead, but
very early (the buffer is flipped at sprite X=320, i.e. already
32px after the regular "paper" area).
