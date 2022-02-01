Source in folder: Tests/ZX48_ZX128/Z80CcfScfOutcomeStability/

This tests stability of outcome of CCF/SCF instructions, if the CPU does
produce random values in flag register, the test will display red attribute
square. For more details check the source comments.

This is near impossible to fail at FPGA or emulator, as it would need to add
randomness intentionally, but some clones of Z80 CPUs in some machines
do produce random values in undocumented flag bits (YF/XF), and this test
can display whether the machine does produce random values at all, and
whether it can be pinpointed to certain frame period like drawing PAPER area.
