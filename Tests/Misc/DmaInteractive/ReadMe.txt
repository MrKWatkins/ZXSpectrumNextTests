## zzz

    Screen content 32x24:
    01234567012345670123456701234567
    --------------------------------________
    Amem......v+....V+..............            ;0 (mem/IO .. left/right to avoid "v/V") ("custom address" in next line maybe)
    .##############################.  test      ;1
    Bmem........-V....-v............  area      ;2
    .%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%.________    ;3
    ??↲↲ pix WR0124↲  A+t3Tt?? mburs            ;4
    WR3 WR5 Test:qwer B+y3Ty?? l1234 keys&RR    ;5
    LOAD F-RDY ENA RST-S RST-M a1234  area      ;6
    CONT DIS RST RST-A RST-B d>b1234________    ;7
                                                ;0
                                     scroll     ;1
                                      area      ;2
                                                ;3
                                                ;4
    c RESET     C3 ss cccc aaaa bbbb            ;5
    c RESET A t C7 ss cccc aaaa bbbb            ;6 (must be at +256)
    WR0 7D8B927B0D ss cccc aaaa bbbb            ;7
    WR1 540E       ss cccc aaaa bbbb            ;0
    WR2 680E       ss cccc aaaa bbbb            ;1
    WR3 80         ss cccc aaaa bbbb            ;2
    WR4 ADFE00     ss cccc aaaa bbbb            ;3
    WR5 82         ss cccc aaaa bbbb            ;4
    c LOAD      CF ss cccc aaaa bbbb            ;5
    c FORCE RDY B3 ss cccc aaaa bbbb            ;6
    c ENABLE    87 ss cccc aaaa bbbb            ;7
    --------------------------------            ;24

commands: (⌥ = caps shift, ↲ = enter, ⇑ = symbol shift)
qwer    test scenario
l       change length
a +⇑    change A address / increment mode
b +⇑    change B address / increment mode
t +⇑    timing port A / from custom byte
y +⇑    timing port B / from custom byte
d       flip direction (flip also swap source/destination test area when confirmed)
m       change mode (burst/continuous)
↲       send WR0-4 edits (all different automatically)
0124    send WR0-4 edits per register group
p       test area attributes/pixels (will require addresses re-LOAD!)
        the source test area for pixels is pre-filled by custom byte (SS=default patterns)
        does redraw screen (like ⌥q)
⌥q      redraw screen, reset source+destination area
⌥3      WR3     ; WR3=$80 (disable interrupt and all) (for other use custom byte)
⌥5      WR5     ; WR5=$82 (stop on end, /CE, ready active low) (for other use custom byte)
⌥r      RST     ; reset
⌥d      DIS     ; disable
⌥e      ENA     ; enable
⌥l      LOAD    ; load
⌥c      CONT    ; continue
⌥f      F-RDY   ; force ready
⌥a      RST-pA  ; reset timing on port A
⌥b      RST-pB  ; reset timing on port B
⌥s      RST-S   ; reinit status byte
⌥m      RST-M   ; reset read mask to $7F
⇑↲      edit custom byte
↲       (if edit mode) end custom byte edit
⌥↲      send custom byte (if edit mode, also end edit)
⌥p      alternate DMA port ($0B vs $6B) - restarts whole test!
