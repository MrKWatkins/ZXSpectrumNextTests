    OPT     reset --zxnext --syntax=abfw
    DEVICE  zxspectrum48

    ORG     $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"

    MACRO   PRINT_PHASE_TXT txt?
        ld      hl,txt?
        ld      de,MEM_ZX_SCREEN_4000 + 2*32
        call    OutStringAtDe
    ENDM

Start:
    ; DI : BORDER 7 : PAPER 7 : INK 0 : CLS
    call    StartTest
    ; fill right half of screen with PAPER 0 : INK 7 (inverting it)
    FILL_AREA MEM_ZX_ATTRIB_5800+16, 16, P_BLACK|WHITE
    ld      hl,MEM_ZX_ATTRIB_5800
    ld      de,MEM_ZX_ATTRIB_5800+32
    ld      bc,32*23
    ldir
    ; display Machine ID + core version
    ld      de,MEM_ZX_SCREEN_4000 + $1000 + 5*32 + 18
    ld      bc,MEM_ZX_SCREEN_4000 + $1000 + 6*32 + 18
    call    OutMachineIdAndCore_defLabels
    ; display "press n to roll phases" message (it stays the same)
    ld      hl,PressNTxt
    ld      de,MEM_ZX_SCREEN_4000 + 6*32
    call    OutStringAtDe

Phase1:
    ;; Phase 1 setup:
    ; Enhanced ULA ON, ink-mask 7, BORDER 0, PAPER:INK 7:0 + 0:7 halves,
    ; ula_palette0[128] = 0xAA, global_transparency = 0xAA, fallback colour = 0x1C (green)

    BORDER  0
    ; ink-mask 7, select ULA palette for write, display first palette, enable Enhanced ULA
    nextreg $42,$07 ,, $43,%0'000'0'0'0'1
    ; ULApalette[$80] = $AA (= black paper+border), global transparency = $AA, fallback = $1C (green)
    nextreg $40,$80 ,, $41,$AA ,, $14,$AA ,, $4A,$1C
    ; print legend-text for phase 1
    PRINT_PHASE_TXT Phase1Txt
    ; wait for "n"
    call    waitForN
    ; clear the legend text (the PRINT helper is using XOR method)
    PRINT_PHASE_TXT Phase1Txt

    ;; Phase 2 setup:
    ; Enhanced ULA ON, ink-mask 255 (full-ink), BORDER 0, keeps attributes (works as INK 0x38 and 0x07)
    ; palette, transparency, fallback = kept same as in Phase 1 (not touching them)

    BORDER  0
    ; ink-mask 255, select ULA palette for write, display first palette, enable Enhanced ULA
    nextreg $42,$FF ,, $43,%0'000'0'0'0'1
    ; print legend-text for phase 2
    PRINT_PHASE_TXT Phase2Txt
    ; wait for "n"
    call    waitForN
    ; clear the legend text
    PRINT_PHASE_TXT Phase2Txt

    ;; Phase 3 setup:
    ; Enhanced ULA OFF, BORDER 5, everything else is kept intact

    BORDER  5
    ; Disable Enhanced ULA (also selects first ULA palette again)
    nextreg $43,%0'000'0'0'0'0
    ; print legend-text for phase 3
    PRINT_PHASE_TXT Phase3Txt
    ; wait for "n"
    call    waitForN
    ; clear the legend text
    PRINT_PHASE_TXT Phase3Txt

    jr      Phase1

waitForN:
    ld      b,10
.wait200ms:             ; wait 200ms first to give a chance to release the key
    ei
    halt
    djnz    .wait200ms
.waitForKey:
    ld      a,$7F
    in      a,(254)
    and     %0000'1000  ; test for "N" key
    jr      nz,.waitForKey
    ret

;        0123456789ABCDEF0123456789ABCDEF
Phase1Txt:
    db  '       Phase 1: inkmask 7       '
    db  ' Green border + right paper half', 0
Phase2Txt:
    db  '      Phase 2: inkmask 255      '
    db  ' Green border + green paper     ', 0
Phase3Txt:
    db  '   Phase 3: Enhanced ULA OFF    '
    db  ' Cyan border + B&W inverted half', 0
PressNTxt:
    db  ' Press "n" to roll phases 1,2,3 ', 0

    savesna "TFalBUla.sna", Start
