
Screen content 32x24:
01234567012345670123456701234567

A -> B        m+ = m++, m- = m--            ;0
m+m+  ####  m+m-  ####  m+m0  #             ;1
m-m+  ####  m-m-  ####  m-m0  #             ;2
m0m+  ####  m0m-  ####  m0m0  #             ;3
IOm+  ####  IOm-  ####  IOm0  #             ;4
(IO is yellow colour when OK)               ;5
Short init:  ##########  (4+4+2)            ;6
                                            ;7
B -> A     m0=const, IO=I/O port            ;0
m+m+  ####  m+m-  ####  m+m0  #             ;1
m-m+  ####  m-m-  ####  m-m0  #             ;2
m0m+  ####  m0m-  ####  m0m0  #             ;3
IOm+  ####  IOm-  ####  IOm0  #             ;4
                                            ;5
Short cont:  #### ####  (4+4)               ;6 (must be at +256)
First flashing border block:                ;7
 *4T: 6.5 rows   6T:  9.5 rows              ;0
  5T: 8.0 rows   7T: 11.3 rows              ;1
 (* = desired outcome)                      ;2
Second block is standard timing?            ;3
 if 3+3T: 9.5 rows, UA858D is 4T            ;4
Both blocks are 2918B transfer              ;5
from memory to I/O ULA port $FE             ;6
DMA port: $   Press P to change.            ;7
--------------------------------            ;24

## What does this all mean:

The A->B and B->A 4x3 blocks are doing DMA transfers with quite full init,
all the transfers are 4 byte long, from memory ("m") or I/O port ("IO", AY
registers $FFFD and $BFFD are used for the test), to memory (only), with
different address change schema (increment "+", decrement "-", fixed "0").

When the target is "m0", then four bytes are transfered, but only to single
byte in memory, i.e. width of test area is just one DMA transfered square.

The test areas are ZX attributes, with 4-byte patterns being 2x bright for
start, 1x non-bright, 1x bright for end. Areas should be all-green (the dark
green ahead/after the DMA block is non-DMA pre-set attribute, if those are
red, it means the DMA did +1 or more byte transfer.

The squares with single pixel dot in them are designed for DMA (all of them
should become green by DMA transfer, any left red is error).

When I/O port is source for data, the yellow color is shown (if it lands at
correct spot). Any red square signals either the DMA did overrun designed
area, or it didn't transfer enough bytes.

The "short init" blocks are next test done by the code, using known last
state of DMA to re-init only minimal amount of registers and do the transfer
like that. Last two transfers are even initiated by "CONTINUE" command,
without the "LOAD", which should just reset length counter, but continue
with current source/target addresses, even if new addresses were written
to WR0/WR4 (these block are in the top "4+4+2" row, which is set after
bottom "short" 4+4 row). The 4+4+2 should finish as single 10B area, having
the two bright at start, one bright at end, and 7x non-bright green in middle.

----------------------------------------------------------------------------

The line full of hexadecimal values shows results of reading the DMA port.

On UA858D chip it should read as (second value 3B may be 3A):
003B000000000000000000001B03D408

The meaning of values:
00SSssccaabb00ssccaabb00ssccaabb

00 = reading DMA port without valid request (zxnDMA responds with status)
SS = read-status-byte command response
ssccaabb = read-sequence command response (with read bytes mask %00101011)
  ss = status byte, cc = counter LSB, aa = portA.adr LSB, bb = portB.adr LSB

The first ssccaabb block is read after first transfer (m++ -> m++), expected
values are 1B030429 (but UA858D invalidates read sequence command upon LOAD).

Second block is expected to be 1B03D004 after first 4B transfer of the 4+4+2
short init test (again nullified by LOAD on UA chip), and last block should
be 1B03D408 after the middle 4B part of the short init test (works on UA).

Generally according to Zilog DMA docs after setting "length" to N and
addresses AadrS, BadrS (and assume both of "increment" type), the transfer
will copy N+1 bytes from address AadrS to BadrS, and read of values from
DMA will produce counter=N, A.adr=AadrS+N+1, B.adr=BadrS+N (not +1).

And according to Zilog DMA docs the LOAD should not affect read sequence.
(to be confirmed, if somebody with actual Zilog DMA will run this test)

----------------------------------------------------------------------------

The DMA inits are written in Zilog DMA compatible way, loading fixed-address
to destination port by flipping directions, and not doing WR3=$C0 (unfortunate
mistake of many MB-02/UA858D examples, gets ignored on UA, but triggers the
transfer prematurely on Zilog chip).

The DMA port will be guessed ($0B or $6B) at beginning of test, you can press
"P" on keyboard to switch between the two manually.

----------------------------------------------------------------------------

The final part of test is "DMA" text in top border, timed on "Toastrack"
ZX128 + UA858D chip in MB-02 disc system and two "flashing" border blocks
below.

The first flashing block has explicit DMA setup using custom variable timing
for both ports, using value 0x0E (2T cycles + 1/2 early signals /WR/RD), and
if the transfer is truly 4T per byte, the block should be about 6.5 rows high
(if larger, you can count the rows and guess the real T-states per byte).

The second block does set WR1/2 registers with D6=0, which I did expect to
reset port timing due to wording of Zilog docs, but from the test with real
UA858D chip the 2T+2T timing remains even there, D6=0 leads just to shorter
init sequence.

----------------------------------------------------------------------------

ZX Spectrum Next has "zxnDMA" DMA implemented in FPGA core, the test contains
extra setup of ZXN registers to switch zxnDMA into Zilog-compatibility mode
and display timing to toastrack ZX128 - these will be silently ignored by
regular ZX (unless you have some HW listening to ports $243B/$253B).

At the moment of writing this text, the latest ZXN core 3.0.5 will pass the
tests with mostly identical results to UA858D chip, except these differences:
 - the "DMA" text in border turns into "noise" because there is only single
   LOAD command done while direction of transfer is flipped, the LOAD of
   zxnDMA is sensitive to correct direction of transfer (but not sensitive
   to loading "fixed" address to destination port, that works)
 - any read from DMA port without read request command will read status byte
 - the values after transfer N are:
   counter=0, A.adr=AadrS+N+1, B.adr=BadrS+N+1 (counter and B.adr differ)
 - status byte has never bit 0 set (any byte transferred)

This behaviour and differences from legacy DMA chips may change in future
versions of ZXN core, you can use this test to check current status then.

----------------------------------------------------------------------------

Other HW/emulators status:

 - MB-03 current work-in-progress version will ignore CONTINUE type
   of transfers (no transfer happens)
 - #CSpect 2.11.10 - autodetect of port fails (reads too many $FF)
   if forced with $6B port, it will do 64kiB transfer upon CONTINUE - crash
 - RealSpec did survive one of the earlier versions of test, but timing
   of blocks is always 3T+3T (didn't try with latest version of test)
 - Fuse does produce mostly incorrect results for almost all transfer variants
 - ZEsarUX 8.1 beta2 in TBBlue mode has only zxnDMA-like implementation
