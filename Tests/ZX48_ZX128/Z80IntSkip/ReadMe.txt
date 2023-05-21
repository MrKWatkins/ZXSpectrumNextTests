Source in folder: Tests/ZX48_ZX128/Z80IntSkip/

Tests inhibition of interrupt acceptance after instruction EI and prefix
bytes 0xDD and 0xFD (producing large block of these).

If these correctly inhibit interrupt (until end of next instruction),
the test should count minimal amount of interrupts (usually zero, but
eventually some may hit during jump instruction at machines with
non-standard timings).

Non-blocking instructions like NOP, SCF, CCF should count ~50 interrupts
(at 3.5MHz in 50Hz mode).

ISR entries number depends on CPU frequency, but with 3.5MHz and 32T /INT
it should count at least two entries. (1 is displayed when emulator/machine
does end /INT upon interrupt ACK, triggering it only once per frame)

OUT (C),0 test is visual:
during block tests BORDER should be either black (0) or white (255)

IFF2 reading reports "CPU bug" when LD A,I||R reads IFF2 as zero during
int-ack, "correct" when it is read as one during int-ack, and "tst fail"
when machine CPU speed is non-standard and the /INT signal did happen
outside of LD A,I||R instruction, thus test failed.
