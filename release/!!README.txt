Tests starting with exclamation mark (!) are "base" tests, these are checking ZX Spectrum
Next subsystems at very basic level, and there was put extra effort into the code of those
tests to operate with minimal extra features. Most of the time, if your platform (board or
emulator) does work as ZX Spectrum 48k well, you can expect somewhat meaningful results
from base tests. If you are "bootstrapping" new ZXN emulator (and you have ZX48k working),
getting base tests passing may be a good idea, before trying out the remaining tests.

Each test consists of self-contained SNA file (unless specified otherwise in the
accompanied .txt file).

Tests are generally expecting "Power-ON into ZX48k with Next features enabled" state
of machine, but they are also trying to be robust enough to operate also with non-default
state of machine (unless checking default state is sub-part of test, please report bugs
related to this, i.e. test working correctly in power-on state, but not in other state).

Failures in default state may be reported by some tests, but these can be treated mostly
as "warning" issues (unless you are writing your own emulator and you are trying to fix
default state of it).

The accompanied .txt file describes what the test does check, and how the result on screen
can be interpreted/measured (for further details you can also check source code of test).

If jpg/png file is accompanying the test, it is usually depicting correct output of test,
or most recent result of real ZX Spectrum Next HW (sometimes the test itself may have
been modified already, then the photo may show somewhat outdated result).

# do NOT edit *this* file in "release/" folder
# edit the source of it in the project root directory, under name: "release-README.txt"
