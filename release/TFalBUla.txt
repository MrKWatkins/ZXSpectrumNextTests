This test checks border/paper picking up transparency-fallback colour in three modes (need key pressing):

1) Enhanced ULA ON, ink-mask 7, BORDER 0, PAPER:INK 7:0 + 0:7 halves,
ula_palette0[128] = 0xAA, global_transparency = 0xAA, fallback colour = 0x1C (green)

The whole border and right half of paper area should be green from the transparency-fallback colour, left half of paper should be white (from default Enhanced ULA palette).

Press "n" to switch to next mode of the test:

2) Enhanced ULA ON, ink-mask 255 (full-ink), BORDER 0, attribute bytes stay from previous phase (working as ink-colour only), palette/transparency/fallback registers stay same as in 1)

In full-ink mode the whole border+paper area should pick the fallback colour (green), text should be pal[0x07] + pal[0x38] (from default Enhanced ULA palette).

Press "n" to switch to next mode of the test:

3) Enhanced ULA OFF, BORDER 5, attribute bytes stay from previous phase = black and white (half inverted), all other Enhanced-ULA nextregs stay from previous phase, but shouldn't affect the output!

The border should be cyan, main paper area should be black+white, with half inverted.

Press "n" to restart test into first phase.
