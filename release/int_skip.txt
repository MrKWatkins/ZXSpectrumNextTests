Source in folder: Tests/ZX48_ZX128/Z80IntSkip/

Tests inhibition of interrupt acceptance after instruction EI and prefix
bytes 0xDD and 0xFD (producing large block of these).

If these correctly inhibit interrupt (until end of next instruction),
the test should count minimal amount of interrupts (usually zero, but
eventually some may hit during jump instruction at machines with
non-standard timings).

Non-blocking instructions like NOP, SCF, CCF should count ~50 interrupts
(at 3.5MHz in 50Hz mode).
