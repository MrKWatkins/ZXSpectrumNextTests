Source in folder: Tests/ZX48_ZX128/ULAvsSJS/

Test keyboard/sinclair joystick reading on ports 00FE, EFFE and F7FE.

It was reported by XoRRoX that grey +2 machine does not mix SJS inputs
into the whole 8x5 matrix reading at port 00FE, only mixes them into
more specific port readings like EFFE and F7FE (maybe even more
of them, but not 00FE).

If such reading is detected by the test (joy input is only on specific port),
the extra message "difference detected" is shown and all ports difference.

On regular ZX just pressing keys should never display any difference,
as anything read at EFFE and 7FFE should be included also in 00FE reading.
