# Possible ways to contribute

* reporting issues with tests running at real HW board
* emulator authors: reporting usability issues with the test suite (and ideas what changes would make the tests more usable for you)
* core/emulator authors: suggesting ideas for new tests to cover area which you are working currently on
* ZX Spectrum Next programming newcomers: reporting your experience with using tests as "examples" for learning about particular feature of ZXN and ideas how to improve it
* coders: help with adding new tests or improving current tests (check the [test ideas](TestIdeas.txt) for inspiration), below are further detailed guidelines to be considered when writing tests.
* and probably anything else you can think of :)

# ZXSpectrumNextTests test-writing guidelines

The mission is to provide set of very short, simple and single feature focused tests of ZX Spectrum Next machine.

These should be helpful mainly to emulator authors, and also to verify functionality of new core versions.

The test will then, in many cases, work also as short example how to correctly and fully initialize/use certain feature.

## Following principles should be considered when designing new test:

* test source code should be buildable with sjasmplus under linux
* provide stable screen output suitable for photographing/screenshotting
* focus on single particular feature
* remaining parts of code should try to minimize usage of extra features
* do not rely on expected "default" values of machine
* code not directly related to focus of test should reuse library code as much as possible
* keep code style clean and well commented, consider the source being also an example
* test source should be accompanied by ReadMe.txt and produce single self-contained SNA file
* do not edit/keep files directly in "release" folder

### Test source code should be buildable with sjasmplus under linux

The current CI (continuous integration) setup does use [sjasmplus with Next extensions](https://github.com/ped7g/sjasmplus/tree/ped-master) running from [docker container](Tools/CI/Dockerfile) based on official GCC gcc:6 image, and all scripting is done in bash, expecting linux environment.

The tests themselves (asm files) should still build also under Microsoft Windows OS, at least at the moment of writing this paragraph I'm not aware of any fatal issue in this regard.

But when writing new test under windows, make sure you are using forward slash as directory separator in include paths (`include "some/path/to/file.i.asm"`), and name include assembly files with extension `.i.asm`, as the build script will try to assemble any `.asm` (except `.i.asm`) file in particular `Tests` sub-folders and include files on their own are
rarely buildable.

You may also try to build windows docker container and see if you can use that for building tests, let us know about your experience, thank you.

### Provide stable screen output suitable for photographing/screenshotting

If possible, after some short time (couple of seconds max), the test should reach state where displayed screen is stable and presents test results in a form suitable for photos and screenshots.

### Focus on single particular feature

One test should focus only on one specific area/feature of machine, although if there's neat way to exercise multiple variants at the same time (neat way to display results of tests), the test can actually do many actions.

The area/feature focused by test and the test implementation details should be of similar abstraction level.

For example, the base/NextReg_defaults tests only existence of particular Next registers (although the write-verify tests respects specific nature of some of the registers, and the test contains extra code for those to make the test meaningful), it does not test various combinations of settings. But it does test existence of all next registers, not breaking the test down into 30+ separate tests per register. To test particular variations of palette register setup, there should be specialized tests added, not cluttering the test checking _all_ registers.

### Remaining parts of code should try to minimize usage of extra features

To make these tests simpler to use by emulator authors, the test should try to use only minimal set of machine features, so author of emulator can use most of the tests related to feature under development, even while their emulator is missing many other features.

This is especially important for "base" tests, which are expected to produce somewhat reasonable results with minimal requirements, in ideal case the standard ZX Spectrum 48k machine should be enough, i.e. only Z80 instructions used (and rather only the documented official ones), only 16k ROM + 48k RAM memory expected and ULA graphics mode at $4000..$5AFF addresses.

If test does rely on other more advanced feature of machine, which is not in the focus of test itself, such dependency should be mentioned in ReadMe.txt of the test, and ideally there should exist other tests exercising the required feature (then add also list of those tests).

### Do not rely on expected "default" values of machine

Test code should initialize all required properties and sub systems to test particular feature properly even when machine is in unexpected state initially. Reporting non-default state of machine may be still helpful, in some warning-like way, but most of tests should not break completely due to wrong default state and there should be clear distinction between test failing (error) and just reporting invalid default (warning).

The reasoning is, that while emulator producing meaningful defaults is a good idea, on real board, if somebody wants to run multiple tests, it will save them time and hassle by allowing soft reset or just load of next test, so the state of the machine may be already altered considerably.

There may be few essential (base) tests treating check of defaults more importantly, if checking defaults is part of their focus, to give emulator authors also way to validate these, but most of the time test-failure due to unexpected default is not wanted.

On contrary, the tests are allowed and encouraged to rely on defaults set by the library functions, at this moment the `StartTest` code does clear screen to default `BORDER 7, PAPER 7, INK 0` and disables interrupts, so there should be no need to clear the ULA screen again.

### Code not directly related to focus of test should reuse library code as much as possible

If you have multiple tests with identical/similar code repeating, and the code is not part of the test-focus, consider possibility to move that code into the "library" of functions, to keep test source focused on the feature-specific code.

If the repeating code is part of the tested feature setup, keep rather the code duplicated in each test, so the single test works also as full example.

Add new functions to "library" rather after they are already used by several tests, for first couple of them just copy/paste to give the code some time to ripe and have better feel to finalize universal API for those. Then refactor the tests (even older ones) to use the new library functions (if such refactoring makes sense and the code was not part of test itself).

Also try to use always at least the two `call StartTest` and `call EndTest` lines of code (or `call EndTiming` followed by looping the test) - to give all tests some similar structure.

### Keep code style clean and well commented, consider the source being also an example

A good comment should provide insight into the idea behind the code, what is intended to happen, or why particular code was added to test. I.e. there's no point to comment that `ld a,0` sets register A to zero (that's obvious), but adding comment that register A will be used as index into array may help reader more.

The test code should rather focus on clear and straightforward way of doing the particular "thing", than using some advanced optimization techniques for better performance. Clarity is more important than performance of tests.

### Test source should be accompanied by ReadMe.txt and produce single self-contained SNA file

Include all required binary data/etc into the SNA file.

Also use only 8 characters for SNA file base name, and make sure the filename is unique, so all tests can be distributed also in single "release" folder (in their binary form) on various limited file systems.

The "base" tests should have name starting with exclamation mark (to be at the beginning of the file list when sorted by file name).

Use only characters: a..z 0..9 - _ ! $

The Cirrus CI task is trying to validate these rules for every commit, see scripts [Tools/validateSnapNames.sh](Tools/validateSnapNames.sh), [Tools/dorelease.sh](Tools/dorelease.sh) and [Tools/chkReleaseAbundance.sh](Tools/chkReleaseAbundance.sh).

### Do not edit/keep files directly in "release" folder

All files required to build output and prepare "release" folder must exist outside of the "release" folder, the "release" folder content should be updated only by [Tools/dorelease.sh](Tools/dorelease.sh) script.

Files in "release" folder are kept in git only for convenience of user who does want to only run the tests.

The whole "release" folder content should be generated from "source" form stored elsewhere in the project, i.e. do not put any data/source into "release" folder manually.
