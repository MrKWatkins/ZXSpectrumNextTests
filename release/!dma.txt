Source in folder: Tests/base/DMA/

Screen content 32x24:
01234567012345670123456701234567

A -> B        m+ = m++, m- = m--            ;0
m+m+ .####. m+m- .####. m+m0 .#.            ;1
m-m+ .####. m-m- .####. m-m0 .#.            ;2
m0m+ .####. m0m- .####. m0m0 .#.            ;3
IOm+ .####. IOm- .####. IOm0 .#.            ;4
                                            ;5
Short init: .#########. (4+4+1)             ;6
                                            ;7
B -> A     m0=const, IO=I/O port            ;0
m+m+ .####. m+m- .####. m+m0 .#.            ;1
m-m+ .####. m-m- .####. m-m0 .#.            ;2
m0m+ .####. m0m- .####. m0m0 .#.            ;3
IOm+ .####. IOm- .####. IOm0 .#.            ;4
                                            ;5
Short cont: .####.####. (4+4)               ;6 (must be at +256)
################################            ;7
................................            ;0
................................            ;1
..slow.burst..change.color......            ;2
..wraps.around..auto-restart....            ;3
................................            ;4
................................            ;5
################################            ;6
MachineID: .. core: 1.2.3                   ;7
--------------------------------            ;24
fill bottom rectangle of screen "slowly" with burst mode + max delay
(fill color keeps changing by interrupt)

## What does this all mean:

The A->B and B->A 4x3 blocks are doing DMA transfers with quite full init,
all the transfers are 4 byte long, from memory ("m") or I/O port ("IO"),
to memory (only), with different address change schema (increment "+",
decrement "-", fixed "0").

When the target is "m0", then four bytes are transfered, but only to single
byte in memory, i.e. width of test area is just one DMA transfered square.

The test areas are ZX attributes, with 4-byte patterns being 2x bright for
start, 1x non-bright, 1x bright for end. Areas should be all-green (the dark
green ahead/after the DMA block is non-DMA pre-set attribute, if those are
red, it means the DMA did +1 or more byte transfer.

When I/O port is source for data, the yellow color is shown (if it lands at
correct spot). Any red square signals either the DMA did overrun designed
area, or it didn't transfer enough bytes.

The "short init" blocks are next test done by the code, using known last
state of DMA to re-init only minimal amount of registers and do the transfer
like that. Last two transfers are even initiated by "CONTINUE" command,
without the "LOAD", which should just reset length counter, but continue
with current source/target addresses, even if new addresses were written
to WR0/WR4 (these block are in the top "4+4+1" row, which is set after
bottom "short" 4+4 row). The 4+4+1 should finish as single 9B area, having
the two bright at start, one bright at end, and 6x non-bright green in middle.

Finally after these tests the border will be changed to blue color, and the
zxnDMA extra feature of "slow" DMA transfer (with max delay prescalar=255)
is used to fill bottom area, the transfer has also flag "auto-restart" and
there is installed IM2 interrupt handler which keeps changing the fill color
every frame (50 or 60 Hz depending on your video mode). Unfortunately even
with maximum delay the burst is kinda too fast for naked eye observation,
but it should do roughly about 18FPS (to fill whole area), i.e. with the
50Hz mode there should be about 2.7 regions with different color, every frame.
