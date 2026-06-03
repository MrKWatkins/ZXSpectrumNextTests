# ZXSpectrumNextTests
[![build](https://github.com/MrKWatkins/ZXSpectrumNextTests/actions/workflows/main.yml/badge.svg)](https://github.com/MrKWatkins/ZXSpectrumNextTests/actions/workflows/main.yml)
![GitHub repo size in bytes](https://img.shields.io/github/repo-size/MrKWatkins/ZXSpectrumNextTests.svg)
![GitHub](https://img.shields.io/github/license/MrKWatkins/ZXSpectrumNextTests.svg)

Simple test programs for the ZX Spectrum Next (couple of them also for classic ZX48/ZX128). The programs here are designed to highlight certain behaviors of the Next hardware so emulator authors can test against real hardware. Also FPGA authors can change the core and make sure it still shows the desired behavior.

## TAP files available for classic ZX48/ZX128:

 * [Interactive DMA test (port $0B and $6B)](Tests/Misc/DmaInteractive/)
 * [Undocumented flags behaviour when interrupt happens during block instructions](Tests/ZX48_ZX128/Z80BlockInstructionFlags/)
 * [Inhibition of interrupt by long block of EI/0xDD/0xFD prefixes](Tests/ZX48_ZX128/Z80IntSkip/)
 * [Undocumented flags stability after CCF/SCF across frame timing](Tests/ZX48_ZX128/Z80CcfScfOutcomeStability/)
 * [Sinclair Joystick readings invisible at port $00FE vs visible at $EFFE/$F7FE](Tests/ZX48_ZX128/ULAvsSJS/)

# Photos and screenshots

## [base](Tests/base/)

### [Copper](Tests/base/Copper/)
<img src="Tests/base/Copper/Board_core3.01.5.jpg" width="300" height="200" /> <img src="Tests/base/Copper/CSpect2.11.1__BAD.png" width="300" height="200" /> <img src="Tests/base/Copper/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/base/Copper/ZEsarUX8.0__BAD.png" width="300" height="200" /> 

### [DMA](Tests/base/DMA/)
<img src="Tests/base/DMA/Board_core3.00.5.jpg" width="300" height="200" /> 

### [NextReg_defaults](Tests/base/NextReg_defaults/)
<img src="Tests/base/NextReg_defaults/board_core3.1.5.jpg" width="300" height="200" /> <img src="Tests/base/NextReg_defaults/CSpect2.9.2__BAD.png" width="300" height="200" /> <img src="Tests/base/NextReg_defaults/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/base/NextReg_defaults/ZEsarUX8.0__BAD.png" width="300" height="200" /> 

### [Z80N](Tests/base/Z80N/)
<img src="Tests/base/Z80N/Board_core2.00.24.jpg" width="300" height="200" /> <img src="Tests/base/Z80N/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/base/Z80N/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/base/Z80N/ZEsarUX8.0.png" width="300" height="200" /> 

### [Z80Nc2](Tests/base/Z80Nc2/)
<img src="Tests/base/Z80Nc2/Board_core2.00.26.jpg" width="300" height="200" /> <img src="Tests/base/Z80Nc2/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/base/Z80Nc2/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/base/Z80Nc2/ZEsarUX8.0.png" width="300" height="200" /> 

## [Graphics](Tests/Graphics/)

### [Layer2Colours](Tests/Graphics/Layer2Colours/)
<img src="Tests/Graphics/Layer2Colours/board_core2.00.25.png" width="300" height="200" /> <img src="Tests/Graphics/Layer2Colours/CSpect2.2.4.png" width="300" height="200" /> <img src="Tests/Graphics/Layer2Colours/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Graphics/Layer2Colours/ZEsarUX8.1-SN.png" width="300" height="200" /> 

### [Layer2Port](Tests/Graphics/Layer2Port/)
<img src="Tests/Graphics/Layer2Port/board_core3.1.5.jpg" width="300" height="200" /> <img src="Tests/Graphics/Layer2Port/CSpect2.11.6.png" width="300" height="200" /> <img src="Tests/Graphics/Layer2Port/MAME0.282.jpg" width="300" height="200" /> 

### [Layer2Scroll](Tests/Graphics/Layer2Scroll/)
<img src="Tests/Graphics/Layer2Scroll/board_core3.1.10.jpg" width="300" height="200" /> <img src="Tests/Graphics/Layer2Scroll/CSpect2.2.0_OK.png" width="300" height="200" /> <img src="Tests/Graphics/Layer2Scroll/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Graphics/Layer2Scroll/ZEsarUX10.2.png" width="300" height="200" /> 

### [LayersMixingHiCol](Tests/Graphics/LayersMixingHiCol/)
<img src="Tests/Graphics/LayersMixingHiCol/board_core2.00.25.png" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingHiCol/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingHiCol/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingHiCol/ZEsarUX7.2.png" width="300" height="200" /> 

### [LayersMixingHiRes](Tests/Graphics/LayersMixingHiRes/)
<img src="Tests/Graphics/LayersMixingHiRes/board_core2.00.25.png" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingHiRes/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingHiRes/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingHiRes/ZEsarUX7.2-RC.png" width="300" height="200" /> 

### [LayersMixingLoRes](Tests/Graphics/LayersMixingLoRes/)
<img src="Tests/Graphics/LayersMixingLoRes/board_core2.00.25.png" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingLoRes/CSpect2.3.3.png" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingLoRes/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Graphics/LayersMixingLoRes/ZEsarUX7.2.png" width="300" height="200" /> 

### [LightenDarken_L2_ULA](Tests/Graphics/LightenDarken_L2_ULA/)
<img src="Tests/Graphics/LightenDarken_L2_ULA/board_3.1.8.jpg" width="300" height="200" /> <img src="Tests/Graphics/LightenDarken_L2_ULA/CSpect2.12.36.png" width="300" height="200" /> <img src="Tests/Graphics/LightenDarken_L2_ULA/MAME0.282.jpg" width="300" height="200" /> 

### [NextReg0x69](Tests/Graphics/NextReg0x69/)
<img src="Tests/Graphics/NextReg0x69/MAME0.282.jpg" width="300" height="200" /> 

## [Interrupts](Tests/Interrupts/)

### [HaltAfterDisable](Tests/Interrupts/HaltAfterDisable/)
<img src="Tests/Interrupts/HaltAfterDisable/CSpect2.2.0__BAD.png" width="300" height="200" /> <img src="Tests/Interrupts/HaltAfterDisable/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Interrupts/HaltAfterDisable/ZEsarUX8.0.png" width="300" height="200" /> 

## [Misc](Tests/Misc/)

### [DmaInteractive](Tests/Misc/DmaInteractive/)

## [Sprites](Tests/Sprites/)

### [BigSprite](Tests/Sprites/BigSprite/)
<img src="Tests/Sprites/BigSprite/board_core2.00.27.png" width="300" height="200" /> <img src="Tests/Sprites/BigSprite/CSpect2.11.1__BAD.png" width="300" height="200" /> <img src="Tests/Sprites/BigSprite/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Sprites/BigSprite/ZEsarUX8.0__BAD.png" width="300" height="200" /> 

### [BigSprite4b](Tests/Sprites/BigSprite4b/)
<img src="Tests/Sprites/BigSprite4b/board_core3.1.5.jpg" width="300" height="200" /> <img src="Tests/Sprites/BigSprite4b/CSpect2.12.22__BAD.png" width="300" height="200" /> <img src="Tests/Sprites/BigSprite4b/MAME0.282.jpg" width="300" height="200" /> 

### [Relative](Tests/Sprites/Relative/)
<img src="Tests/Sprites/Relative/Board_core2.00.27.png" width="300" height="200" /> <img src="Tests/Sprites/Relative/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/Sprites/Relative/CSpect2.11.1_options_on.png" width="300" height="200" /> <img src="Tests/Sprites/Relative/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Sprites/Relative/ZEsarUX8.0__BAD.png" width="300" height="200" /> 

### [ScanlineDelay](Tests/Sprites/ScanlineDelay/)
<img src="Tests/Sprites/ScanlineDelay/board_core3.0.5_cupper_wait_h_35.jpg" width="300" height="200" /> <img src="Tests/Sprites/ScanlineDelay/CSpect_sprite_types_OK.png" width="300" height="200" /> <img src="Tests/Sprites/ScanlineDelay/MAME0.282.jpg" width="300" height="200" /> 

### [Transparency](Tests/Sprites/Transparency/)
<img src="Tests/Sprites/Transparency/Board_core2.00.26.png" width="300" height="200" /> <img src="Tests/Sprites/Transparency/CSpect2.2.0.png" width="300" height="200" /> <img src="Tests/Sprites/Transparency/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/Sprites/Transparency/ZEsarUX7.1_OK.png" width="300" height="200" /> 

## [Timing](Tests/Timing/)

### [Changing8kBank](Tests/Timing/Changing8kBank/)
<img src="Tests/Timing/Changing8kBank/MAME0.282.jpg" width="300" height="200" /> 

### [Changing8kBank_NoContention](Tests/Timing/Changing8kBank_NoContention/)
<img src="Tests/Timing/Changing8kBank_NoContention/MAME0.282.jpg" width="300" height="200" /> 

### [ScanlineReadingAndInterrupt](Tests/Timing/ScanlineReadingAndInterrupt/)
<img src="Tests/Timing/ScanlineReadingAndInterrupt/MAME0.282.jpg" width="300" height="200" /> 

## [ULA](Tests/ULA/)

### [BorderTransparencyFallback](Tests/ULA/BorderTransparencyFallback/)
<img src="Tests/ULA/BorderTransparencyFallback/board_core3.00.0.jpg" width="300" height="200" /> <img src="Tests/ULA/BorderTransparencyFallback/CSpect2.11.1__BAD.png" width="300" height="200" /> <img src="Tests/ULA/BorderTransparencyFallback/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/ULA/BorderTransparencyFallback/ZEsarUX8.0__OK.png" width="300" height="200" /> 

### [ChangePaletteTransparency](Tests/ULA/ChangePaletteTransparency/)
<img src="Tests/ULA/ChangePaletteTransparency/board_2.00.26.png" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency/ZEsarUX8.0.png" width="300" height="200" /> 

### [ChangePaletteTransparency_v2](Tests/ULA/ChangePaletteTransparency_v2/)
<img src="Tests/ULA/ChangePaletteTransparency_v2/board_2.00.26.png" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency_v2/CSpect2.2.0_OK.png" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency_v2/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency_v2/ZEsarUX7.2sn_OK.png" width="300" height="200" /> 

### [ChangePaletteTransparency_v3](Tests/ULA/ChangePaletteTransparency_v3/)
<img src="Tests/ULA/ChangePaletteTransparency_v3/board_2.00.26.png" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency_v3/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency_v3/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/ULA/ChangePaletteTransparency_v3/ZEsarUX8.0.png" width="300" height="200" /> 

### [ClassicPaletized](Tests/ULA/ClassicPaletized/)
<img src="Tests/ULA/ClassicPaletized/CSpect2.2.4.png" width="300" height="200" /> <img src="Tests/ULA/ClassicPaletized/MAME0.282.jpg" width="300" height="200" /> 

### [DefaultTransparency](Tests/ULA/DefaultTransparency/)
<img src="Tests/ULA/DefaultTransparency/board_2.00.26.png" width="300" height="200" /> <img src="Tests/ULA/DefaultTransparency/CSpect2.11.1.png" width="300" height="200" /> <img src="Tests/ULA/DefaultTransparency/MAME0.282.jpg" width="300" height="200" /> <img src="Tests/ULA/DefaultTransparency/ZEsarUX8.0.png" width="300" height="200" /> 

### [UlaScroll](Tests/ULA/UlaScroll/)
<img src="Tests/ULA/UlaScroll/board_3.01.10.jpg" width="300" height="200" /> <img src="Tests/ULA/UlaScroll/CSpect2.16.6.png" width="300" height="200" /> <img src="Tests/ULA/UlaScroll/MAME0.282.jpg" width="300" height="200" /> 
