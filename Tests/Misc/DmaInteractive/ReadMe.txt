## ZX DMA chips interactive test

### controls: (⌥ = caps shift, ↲ = enter, ⇑ = symbol shift)

    qwer    test scenario
    l       change length
    a +⇑    change A address / increment mode
    b +⇑    change B address / increment mode
    t +⇑    timing port A / from custom byte (SS = 0x0E)
    y +⇑    timing port B / from custom byte
    d       flip direction (flip also swap source/destination test area when committed)
    m       change mode (burst/continuous/byte) (don't use "byte" on zxnDMA)
    ↲       commit WR0-4 edits (all with uncommitted difference)
    0124    commit WR0-4 edits per register group
    p       test area is in attributes/pixels (will require addresses re-LOAD!)
            the source test area for pixels is pre-filled by custom byte (SS=default patterns)
            does redraw screen (not fully like ⌥q)
    ⌥q      redraw screen, reset source+destination area
    ⌥3      WR3     ; WR3=$80 (disable interrupt and all) (for other use custom byte)
    ⌥5      WR5     ; WR5=$82 (stop on end, /CE, ready active low) (for other use custom byte)
    ⌥r      RST     ; DMA reset
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
    ⌥↲      send custom byte to DMA (if edit mode, also ends edit)
    ⌥p      alternate DMA port ($0B vs $6B) - restarts whole test!

### what it does

Allows you to try out various DMA init sequences. The test will after start prepare
default test sequence, operating in visible range of VRAM. You can add/adjust/change
the setup of DMA chip by using the UI commands, which offer basic possibilities (should
be enough for common memory transfer usage examples).

The default DMA port is $0B, but when Spectrum Next is detected, the port $6B is used
first (press caps+p to switch between the ports).

By using "custom byte" manual editing you can send anything to the DMA chip and initiate
sequence also with parameters not editable through the UI of test.

Be aware the test doesn't guard the validity of sequence, and doesn't guard itself
against sequence which would damage the test, it's up to the user to make sure the
values loaded in the DMA are reasonable before hitting that Caps_shift+E to ENABLE
the currently set transfer.

Test itself occupies memory in range $8000 to $9FFF, does use ROM character set ($3D00),
but no ROM code, and doesn't use interrupt or memory banking, i.e. as long as your
transfers don't hit the test memory range, it should keep working (use "redraw" action
to restore the UI display).

If you just enter custom-byte edit and exit it immediately, it will reset the value
to "standard" value ("SS" in controls paragraph). This value can't be send to DMA
chip, but has special meaning for controls "⌥q" and "p", which will then fill
the source area with test-pattern data, and controls "⇑t" and "⇑y" will load timing
byte 0x0E to particular port.

The test will try to detect when it is run at ZX Spectrum Next board, and it will
configure the Next to use 28MHz mode, but it will switch zxnDMA to "Zilog"
compatibility mode (test does **NOT** support zxnDMA mode and "prescalar" feature).

The zxnDMA documentation can be found at https://wiki.specnext.dev/DMA (mostly
describing the "zxnDMA" mode but also mentions limits of zxnDMA), for Zilog DMA chip
look for regular documentation.
