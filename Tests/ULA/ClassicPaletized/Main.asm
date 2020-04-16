    device zxspectrum48

    org    $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../timing.i.asm"

; ink is single channel gradient -1+1, paper is two channel gradient -1+1
PalDef:
    ; ink 0-8:      700,610,520,430,340,250,160,070     ; dark ink 7 ~= bright ink 0
    dw  700o,610o,520o,430o,340o,250o,160o,070o
    ; ink 9-15:     170,061,052,043,034,025,016,007
    dw  170o,061o,052o,043o,034o,025o,016o,007o
    ; paper 0-8:    707,617,527,437,347,257,167,077     ; dark paper 7 ~= bright paper 0
    dw  707o,617o,527o,437o,347o,257o,167o,077o
    ; paper 9-15:   177,176,275,374,473,572,671,770
    dw  177o,176o,275o,374o,473o,572o,671o,770o
PalDef_CNT  equ     32

Start:
    call StartTest
    ;; configure machine to specific state
    NEXTREG_nn TURBO_CONTROL_NR_07,0            ; 3.5hz
    NEXTREG_nn MACHINE_TYPE_NR_03, %10110011    ; enforce +3e/Next timing
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14,$E3    ; default transparent colour
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,$E3  ; +make it visible (i.e. "solid" :) )
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00010100    ; Set ULS layer priority, sprites OFF
    ; reset LoRes scroll registers (did affect ULA screen in cores 2.00.25+ to 3.0.5?)
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; reset ULA scroll registers (regular scroll for ULA since some late core 3.0.x)
    NEXTREG_nn ULA_XOFFSET_NR_26, 0
    NEXTREG_nn ULA_YOFFSET_NR_27, 0

    ;; keep first ULA palette in default state (should emulate classic ZX colours)
    ;; setup second ULA palette to distinct patterns for visual-test purpose
    NEXTREG_nn PALETTE_CONTROL_NR_43,%01000000  ; select ULA-second, display first, ULA classic
    NEXTREG_nn PALETTE_INDEX_NR_40,0
    ld      hl,PalDef
    ld      b,PalDef_CNT
.setPalLoop:
    ld      e,(hl)
    inc     hl
    ld      d,(hl)      ; DE = 0000_000R_RRGG_GBBB (wrong format for Next $44)
    inc     hl
    ; convert to Next format
    rr      d
    rr      e
    rl      d           ; DE = 0000_000B_RRRG_GGBB (old CF preserved, JFYI, not used)
    ; set up palette item
    ld      a,e
    NEXTREG_A PALETTE_VALUE_9BIT_NR_44
    ld      a,d
    NEXTREG_A PALETTE_VALUE_9BIT_NR_44
    ; loop through all 32 colour definitions
    djnz    .setPalLoop
    ; define remaining colours are pure black (in case they show accidentally somewhere)
    ld      b,256-PalDef_CNT
    xor     a
.setRemainingPalLoop:
    NEXTREG_A PALETTE_VALUE_9BIT_NR_44
    NEXTREG_A PALETTE_VALUE_9BIT_NR_44
    djnz    .setRemainingPalLoop

    ;; fill 1st and 3rd third of screen with all 0..255 values in attributes
    ld      hl,MEM_ZX_ATTRIB_5800
    call    Fill0to255
    inc     h
    inc     h
    call    Fill0to255
    ;; fill pixel area with some patterns to display ink vs paper
    FILL_AREA   MEM_ZX_SCREEN_4000+2*256, 4*256, %00111100
    FILL_AREA   MEM_ZX_SCREEN_4000+(16+2)*256, 4*256, %00111100

    ;; IM2 interrupt will be used to time the palette changes
    ld      a,im2table>>8
    ld      i,a
    im      2
    ei
    nop                 ; give EI time to kick in

.mainLoop:
    ; 128k: 14364T - first pixel (63 lines in retrace and top border, 228T per line)
    ; 128k: 128T pixels, 24T right border, 48T H-retrace, 24T left border +4T somewhere? = 228T
    ; screen timing 128k mode: (63+192+56)*228=70908

    halt                ; interrupt handler is 18T long
    ; set ULA to display first palette
    NEXTREG_nn PALETTE_CONTROL_NR_43,0  ; display first ULA palette, ULA classic mode (+20T = 38T)
    BORDER  WHITE           ; BORDER 7 in top area of screen (+7+11T = 56T)

    ;; wait for left border of line -1 (to create border rainbow with 1px edges)
    ; => switch border colour somewhere between 14064T..14112T (horizontal retrace) -35!
    ; let's try 14040T (13984T to wait)
    nop
    IDLE_WAIT $3204         ; +13986T = 14042T (+35 = 14077)
    ; do the rainbow border (1px green, 8x8px spectrum, 1px green)
    call    DoBorderRainbow ; A = 0, +15048T = 29090T
    ; do white border (extra timing to make it +35 till OUT ends)
    ld      bc,0            ; 10T
    ld      b,0             ; 7T
    BORDER  WHITE           ; +7+11T = 29125T (line 65)
    ; wait for half of the screen -> 36180T earliest => wait cca. 7055T
    IDLE_WAIT $9C02         ; +7058T = 36183T
    ;; switch to second ULA palette in the middle of screen
    NEXTREG_nn PALETTE_CONTROL_NR_43,2  ; display second ULA palette, +20T = 36203T
    ; wait till cca. 43248T (earliest) -35! and do the BORDER rainbow again
    ; => 43213 earliest => 7010T wait
    nop
    ld      bc,0
    IDLE_WAIT $9902         ; +4+10+7007T = 43224T
    call    DoBorderRainbow
    ; do white border (extra timing to make it +35 till OUT ends)
    ld      bc,0            ; 10T
    ld      b,0             ; 7T
    BORDER  WHITE           ; +7+11T

    jr      .mainLoop
;    call EndTest

DoBorderRainbow:
    call    .Green1pxLine   ; 228T (at +35 OUT), A=0
.OneCharLineLoop:
    ld      bc,0            ; 10T
    ld      b,0             ; 7T
    ld      b,0             ; 7T
    out     (ULA_P_FE),a    ; 11T (at +35T OUT)
    ;; now wait 8 scanlines (8*228=1824T), and turn BORDER to 1, 2, ... 7
    ; there's already 35+4+7+12=58T in loop management: 1824-58=1766T to wait
    inc     bc              ; +6T
    IDLE_WAIT $6501         ; +1760T
    inc     a               ; 4T
    cp      8               ; 7T
    jr      nz,.OneCharLineLoop ; 12/7T
    ; last iteration was -5T
    ld      bc,0            ; 10T extra
    jr      z,.Green1pxLine ; 12T instead of CALL 17T (-5)

; total including "call": 17+7+11+179+4+10 = 228T, the OUT ends at +35T
; returns A = 0 (!)
.Green1pxLine:
    BORDER  GREEN           ; +7+11T
    IDLE_WAIT $0A01         ; +179T
    xor     a
    ret

Fill0to255:
    ld      (hl),l
    inc     l
    jr      nz,Fill0to255
    ret

    ;; IM2 vector table + interrupt handler
    org     $8E00
im2table:
    ds      257, $8F

    org     $8F8F
im2handler:
    ; just empty handler taking fixed time (4+14 = 18T)
    ei
    reti

    savesna "Ula_Pal.sna", Start