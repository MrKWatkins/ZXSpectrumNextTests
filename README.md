# ZXSpectrumNextTests
[![Build Status](https://api.cirrus-ci.com/github/MrKWatkins/ZXSpectrumNextTests.svg?branch=develop)](https://cirrus-ci.com/github/MrKWatkins/ZXSpectrumNextTests)
![GitHub repo size in bytes](https://img.shields.io/github/repo-size/MrKWatkins/ZXSpectrumNextTests.svg)
![GitHub](https://img.shields.io/github/license/MrKWatkins/ZXSpectrumNextTests.svg)

Simple test programs for the ZX Spectrum Next (couple of them also for classic ZX48/ZX128). The programs here are designed to highlight certain behaviours of the Next hardware so emulator authors can test against real hardware. Also FPGA authors can change the core and make sure it still shows the desired behaviour.

## TAP files available for classic ZX48/ZX128:

 * [Interactive DMA test (port $0B and $6B)](Tests/Misc/DmaInteractive/)
 * [Undocumented flags behaviour when interrupt happens during block instructions](Tests/ZX48_ZX128/Z80BlockInstructionFlags/)
