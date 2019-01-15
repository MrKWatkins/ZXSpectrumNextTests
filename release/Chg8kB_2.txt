This times how long it takes to swap in and out an 8k bank.

The test code is placed at $6000, memory contention is switched OFF and Turbo mode is
set to 14MHz, Layer2 is DISABLED (i.e. real board is expected to run at full 14MHz).

This should make the code a bit faster than the other Changing8kBank test, because
now the code is not slow down by the $4000..$7FFF RAM contention of ZX48k machine.

The result is the size of the green part of border area.
