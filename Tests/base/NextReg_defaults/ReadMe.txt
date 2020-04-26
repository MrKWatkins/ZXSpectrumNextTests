Next-register availability and default-value test
=================================================

This test does very basic read+write to every Next-register known to it, testing also
in some cases for known default values (keeping it relaxed where the default value is
unclear and may depend on user configuration, like 50/60Hz, etc.).

The implemented set of Next registers is according to info about core 3.1.5.

The machine is expected to be configured as ZX48 with NEXT functionality allowed, but
mostly OFF (expected: turbo speed OFF, memory contention as ZX48, ...)
Or to put it in other words, the expected defaults are as after power-on and booting
into ZX48 mode, defaults specified in: https://www.specnext.com/tbblue-io-port-system/
(the more recent source of next-registers info is now public VHDL source of the core:
https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA - there is "nextreg.txt" file)

The displayed values are all always hexadecimal, except the MachineID and core versions
under the "legend" part, those are decimal, as having core "2.0.16" instead of "2.0.22"
felt very confusing. But now it feels confusing to have hexadecimal everywhere else...
Then again, it's just a small test targetted at emu-writers, so it's "good enough".

There is 16x16 grid making up for 256 possible NextReg values (see labels for hexa
notation for number of particular grid cell), which is being colour coded as the test
progresses, the colour coding encodes this information:

The (R), (W) or (R/W) means the next register is read-only, write-only or read+write.

white - empty (no NextReg defined for that value)
blue  - didn't survive read or write (machine is frozen on the operation)
red   - (R) - survived read, default value test failed
      - (R/W) - when W part is skipped and default read value test failed
      - (R/W) - survived read+write, value read back was unexpected
yellow- (R/W) - survived read+write, read value back OK, but default value test failed
cyan  - (R/W) - (R) part works OK (any value), (W) part is too specific, skipped
green - (R/W) - (R) part works OK (test value), (W) part is too specific, skipped
        this is for registers which are impossible to do benign write to them,
        like they are supposed to be used only in machine configuration mode, etc.
bright white
      - (W) - only write register, and too specific to even test it, skipped
bright magenta
      - (W) - survived write (but no test to validate functionality of it)
bright cyan
      - (R) - survived read, default value is not defined
      - (R/W) - survived read+write, read expected value back (default undefined)
      - (R/W) - survived read+write, write done, but untested (!), (default undef/OK)
bright green
      - (R) - survived read, and it matched the strict/weak-ly defined default value
      - (R/W) - as (R), then write, read expected value back (strict test of W result)

The "default" value is either defined strictly (exact value) or weakly (non-zero value
expected as default, then zero value will be reported as "red" colour code), or not
tested at all (any value is ok).

Unfortunately, the colour coding is not as simple as I expected, as the total amount
of combinations is quite a bit higher. You can use source code + debugging to get more
precise info about what is being tested and at which stage it failed.

As an observable side-effect, the test will also set clip window and transparency fallback
registers in such way, that right + bottom of pixel-area (256x192) should display 3 pixel
wide cyan lines (transparency fallback colour), as ULA layer is clipped to {0,252,0,188}.
(List of unobservable side-effects is at bottom in separate list)

In case of failure, the unexpected value is printed into "LOG" (bottom third of screen):
* yellow = "default value" kind of test
* red = "verify write" kind of test
* cyan = NextRegister number for the previously reported "bad values"
* empty/garbage colours boxes = the ROM char gfx got unmapped due to MMU1 read failure
or the current ROM does not contain character set gfx (due to ROM mapping failure)

For clip-window test there may be printed multiple wrong values for single NextReg (one
to four for "defaults", and one to four for "verify", but there's no identification
which value was printed - except when all four are printed :) ), other test should always
produce value+NextReg pairs (sorry for NextReg being second, but it made the code a bit
shorter). This info may still require full code review of test to fully understand why
particular value was deemed as "failure" and what was expected.

Default-value failures for machine-configuration registers like $08 may happen due to
user's custom configuration/current status of board, now you can read the value on screen
and decide yourself, if it is valid "default" or not, and ignore the failure.

Extra how-to for emulator writers (and some observations from writing the test):
================================================================================

- if you will make your emulator freeze when value is read/written to unexpected NextReg,
you can detect which NextRegs are supported by the test, but not by your emulator (blue).

- most of the registers are independent on each other, but some are interconnected. The
code does proceed from $00 to $FF register in order, thus clip-index $1C depends on tests
of clip-window registers $18..$1A, if you see some "error" reported, make sure you fully
understand what kind of error is reported (check the source code for extra comments in
some particular cases), or open an issue on github to get extra explanation.

- the preconditions to make this test (at least somewhat) functional is to have:
* Z80 emulation (Z80N is not needed, only Z80 instructions are used)
* ZX48 ROM mapped into address space, precisely the character graphics ($3D00..$3FFF)
* ZX48 standard ULA graphics mode (256x192 bitmap at $4000 with attributes at $5800)
* ZXN "NextRegs" being readable/writeable through I/O ports $243B and $253B

- The machine ID $00 test is "non-zero" value, I did notice some emulators report itself
as "ZX Spectrum Next" instead of "Emulators" - IMHO this should be option in your
emulator, and by default it should return 8 (Emulators) instead of 10 (ZXN), only
having optional override in case some SW will fail due to that.

- The test expects the timing/mode to be already in ZX48 (not raw config), i.e. register
$03 is expected to return non-zero value (zero is possible only for "config mode").
(Although the actual test of $03 is relaxed, and any non-zero value is "OK")

- Register $22 has some tiny chance to fail due to INT signal on CPU being on raise just
when the reading of port value is done (it is expected that test runs between interrupts)
If this happens, it should probably happen every time, deterministically, you can ignore
such failure (or let me know to put extra timing code into test to avoid this risk).

- If your MMU1 (NextReg $51) returns wrong value upon first read ($FF is expected), the
test will get confused, and unmap the ROM, making remaining LOG output garbage. Fix your
MMU regs reading first, then rerun the test, to see remaining values in log output.

List on unobservable side-effect of "write" tests into NextRegs:
================================================================

! this info is now outdated and requires refresh ! (code changes for core 3.1.5)

$02: zero is written into it, it shouldn't do anything. From the docs it is not clear,
 when reading value should modify, whether the on-reset flags are one-time-read flags,
 or whole-session flags (allowing for multiple re-reads).

$05: value read is written back (to not affect user's configuration)

$06: %0000_0010: Turbo, divMMC paging, lightpen, Audio chip mode, ... all disabled

$08: %0111_0100: disable RAM contention, ACB stereo, internal speaker, Timex modes

$09: %0000_1000: disable Kempston port $DF, scanlines off, AY mono off,
 sprite-index $34 decoupled.

$12, $13: Layer2 beginning set to 9, shadow Layer2 set to 10

$14: global transparency colour set to $25

$15: %0000_0010: all default, except sprites over border allowed (but invisible)

$16, $17: Layer2 [x,y] scroll set to [$55, $56]

$18, $19, $1A, $1B: clip windows are set to {port^$1A, 278-port, (port^$1A)*2, 214-port},
 i.e. L2: {2, 254, 4, 190}, Sprites: {3, 253, 6, 189}, ULA: {0, 252, 0, 188},
 Tile: {1, 251, 2, 187}
 - the reads don't increment particular register-index, so the tests skip "read-only"
 phase, and all testing is done in custom-write part of code. The test will leave
 indices at 0, 1, 2 and 3, so the $1C read should produce $C6.
 The test consists of reading the register (i.e. X1 value on first read is expected),
 then writing the new X1, and so on. It does two rounds, first time expecting default
 clip window 0,255,0,191 (0,159,0,255 for tilemode), second time expecting (and writing
 back again) the new clip window coordinates, as mentioned above.
 Finally 0..3 more re-writes are done to set index.
 Fails in 1st round are yellow, 2nd round fails are red.

$1C: reset of Tilemap internal clip-window-indices (pointing back to X1) is requested

$22, $23: line interrupt is set to $102, but not enabled (original ULA interrupt is kept)

$2D: SoundDrive port mirror: simply zero is written there, I didn't bother to check if
 it is good idea, let me know if some value is less disruptive.

$2F, $30, $41: Tilemode scroll offset [xhi:xlo,y] set to [1:3 (= 259), 6].

$32, $33: LoRes scroll [x,y] set to [$02, $01] (after test is finished, this gets reset
back to [0,0] to make ULA displayed normally).

$34: Sprite attribute-index is set to $7B (core2.00.26 supports 128 sprites)
$35, $36, $37, $38, $39: some sprite attributes for sprite $7B: {$00,$00,$0F,$3F,$0A}

$40: palette index is set to $70 (as first thing of them)
$41:
 - first read colour[$70] = $00 black (ULA palette0) (no index increment, only write does)
 - writes $1F colour into it (increments index to $71)
 - "verify write" read should then read $02 (blue colour in ULA palette0[$71])
$42: INK_mask 7 is written (instead of default 15)
$43: writes %0110_1000: selects secondary Sprite palette for R/W and display, ULANext off
$44: the index is still $71, the read should see "second" byte of colour $71, $01 from
 second Sprite palette, i.e. expected value is $01 (in "default value test").
 Then colour $79, $00 is written, which will increment the palette index to $72.
 As write-verify the "second" byte of colour $72, $01 is expected to be read back (= $01).
 (to read "first" byte of colours, one would have to read NextReg $41 - not in this test)

$4A, $4B, $4C: transparency fallback colour, sprite-transparency-index, tilemode
transparency index - set to: $1F, $20, $0E

$50, $51: MMU0 and MMU1 are set to value read from them (should be 0xFF = ROM), but test
 is checking only by the "non zero" condition (due to technical limitations in code).
$52, .., $57: MMU2, .., MMU7 are set to defaults {$0A,$0B,$04,$05,$00,$01}, i.e. memory
 content shouldn't change (but read+write+verify cycle is done).

$60, $61, $62: zero is sent to Copper data, then $33 to Copper control LO, and $01 to
 Copper control HI (should keep the Copper in "STOP" state, just modifies indices)

$68: ULA Control - value $40 written = enable ULA/tilemap mix for blending in SLU 6&7

$6B: Tilemap Control - value $60 written = 80x32, global attribute (byte map)

$6C: Default Tilemap Attribute - value $0F written = x+y mirrors and rotate, ULA over T.

$6E: Tilemap Base Address - value $5B as base address, should read back as $1B.

$6F: Tile Definitions Base Address - value $5C as base address, should read back as $1C.

$75, .., $79: again sprite attributes {$00,$00,$0F,$3F,$0A} are written, but this time
 the index should increment after each write, i.e. first attribute lands into sprite $7B
 and last attribute should land into sprite $7F, leaving the index in undefined state.

$FF: $01 is written, hopefully doesn't damage Victor's board (no idea about legal values)
