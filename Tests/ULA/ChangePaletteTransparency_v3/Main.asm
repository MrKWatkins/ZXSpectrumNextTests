    device zxspectrum48

    org	$6000

    INCLUDE "..\..\Constants.asm"
    INCLUDE "..\..\Macros.asm"
    INCLUDE "..\..\TestData.asm"
    INCLUDE "..\..\TestFunctions.asm"

Start:
    call StartTest

    ; Set ULA over Layer2 over sprites, with sprites not visible.
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00010100
    NEXTREG_nn PALETTE_FORMAT_NR_42, 7      ; INK bitmask (0..7 is INK, 0..31 PAPER)
        ; this INK mask "7" is "compatible" with default attribute $38 filled in VRAM
    NEXTREG_nn PALETTE_CONTROL_NR_43, 0     ; select first-ULA palette + disable ULANext
    ; palette[ULA][0][135] change (paper 7 + border 7 colour to $E300)
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+7   ; Change paper 7 = 128 + 7 = 135.
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $E3
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $00; Set to default "pink" transparent colour.
    ; bright cyan as transparency fallback
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A, $1F

    call FillLayer2WithTestData

    call EndTest

    savesna "CPalTrV3.sna", Start
