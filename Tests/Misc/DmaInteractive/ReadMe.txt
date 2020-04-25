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
    h       outputs couple of hexa values from destination area (from first non-zero)
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

### screen layout

Top third of screen contains default test area for transfers and UI part (controls and
values). Most of the value changes are "uncommitted" after pressing the key, changed
only in UI part, but not written to DMA chip. The uncommitted changes are highlighted
in blue, pressing "Enter" or particular 0,1,2 or 4 key will write all/particular WR
value to the DMA chip (commit the change).

Bottom two thirds of screen is scrolling area where every byte sent to DMA chip is shown.
The bytes are parsed back, most of the DMA functionality should be recognized by test
(there are few omissions like interrupt-control functionality of Zilog DMA and zxnDMA
"prescalar" in WR2 - those may get test into confused state), and it will update its
internal "WR" state, and display the function of byte in the bottom line (like "WR2").

On the right side of each line the blue hexa values are full state of DMA chip read
back through WR6 $A7 "START_READ_SEQUENCE", registers are shown as:
RR0 (status) RR2:RR1 (counter) RR4:RR3 (port A address) RR6:RR5 (port B address)

### what it does

Allows you to try out various DMA init sequences. The test will after start prepare
default test sequence, operating in visible range of VRAM. You can add/adjust/change
the setup of DMA chip by using the UI commands, which offer basic possibilities (should
be enough for common memory transfer usage examples).

The default DMA port is $0B (press caps+p to switch between the ports $0B <-> $6B).

By using "custom byte" manual editing you can send anything to the DMA chip and initiate
sequence also with parameters not editable through the UI of test.

Be aware the test doesn't guard the validity of sequence, and doesn't guard itself
against sequence which would damage the test, it's up to the user to make sure the
values loaded in the DMA are reasonable before hitting that Caps_shift+E to ENABLE
the currently set transfer.

Test itself occupies memory in range $8000 to $97FF, does use ROM character set ($3D00),
but no ROM code, and doesn't use interrupt or memory banking, i.e. as long as your
transfers don't hit the test memory range, it should keep working (use "redraw" action
to restore the UI display).

If you just enter custom-byte edit and exit it immediately, it will reset the value
to "standard" value ("SS" in controls paragraph). This value can't be send to DMA
chip, but has special meaning for controls "⌥q" and "p", which will then fill
the source area with test-pattern data, and controls "⇑t" and "⇑y" will load timing
byte 0x0E (2T timing) to particular port.

The test will try to detect when it is run at ZX Spectrum Next board, and it will
configure the Next to use 28MHz mode, but test does **NOT** support zxnDMA specific
features like "prescalar" burst mode (you can switch between Zilog or zxnDMA mode
by alternating between the ports (core3.1.2+), but the test is designed for Zilog mode).

The zxnDMA documentation can be found at https://wiki.specnext.dev/DMA (mostly
describing the "zxnDMA" mode but also mentions limits of zxnDMA), for Zilog DMA chip
look for regular documentation.

### ZX128 +2 Grey with original Zilog DMA chip notes:

- the destination port is really loaded during write phase of transfer, the read-back
values after LOAD don't show the target address (as documented by Zilog).
- also the destination port must be ++ or -- to load (as documented by Zilog).
- the transaction starts at port A or B depending on the direction of transfer at the
time of LOAD command. If you flip the direction after LOAD and enable the transfer, it
will start with wrong port and do the write-phase first (with 0xFF byte in the
intermediate storage), then the read phase, finishing the transfer with last byte
read into the intermediate storage (without writing it). Further CONTINUE transfer
will still start with wrong port (doing write first) with that intermediate value
read at end of previous transfer.
- i.e. it's essential to do the last LOAD command with the correct transfer direction
set up, otherwise the transfer is damaged.
- the port adjustment type (--/++/fixed) can be modified any time before ENABLE, even
after load/continue commands, the DMA will pick the new change and use it
- the RESET command will adjust the source port by one in the selected direction

The photos included in `Tests/Misc/DmaInteractive/zilog_hw_photos` are from "grey"
ZX128+2 with genuine Zilog DMA chip (provided by MB-02 disk system).
