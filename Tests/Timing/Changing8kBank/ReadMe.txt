Source in folder: Tests/Timing/Changing8kBank/

This times how long it takes to swap in and out an 8k bank.

The test code is placed at $6000, memory contention is switched ON and CPU speed is
set to 3.5MHz, because any turbo mode will switch contention OFF (! since some late
core 2.x or core3.0).

The result is the size of the green part of border area.
