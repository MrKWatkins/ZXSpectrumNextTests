    device zxspectrum48
    org     $E000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"
    DEFINE _CONTROLS_DEBOUNCE_REGULAR 2
    INCLUDE "../../controls.i.asm"

    OPT --zxnext            ; enable Z80N instructions, this test does use few of them

; max scanline is 260..320 (depending on the mode), so values 0..63 may happen twice, 64+ only once
TEST_LINE_LSB = 200         ; start at +8 pixels under PAPER area
TEST_TYPE_READ      EQU     1
TEST_TYPE_IRQ       EQU     0

LegendText:
    DW      MEM_ZX_SCREEN_4000+4*32+1
    DB      "Q/A:  Target line LSB: ",0
    DW      MEM_ZX_SCREEN_4000+5*32+1
    DB      "W/S:  Target line LSB +-8",0
    DW      MEM_ZX_SCREEN_4000+6*32+1
    DB      "Z:     Read $1F Interrupt",0
    DW      MEM_ZX_SCREEN_4000+7*32+1
    DB      "F8/T: MHz: 3.5  7   14  28",0
    DW      MEM_ZX_SCREEN_4000+8*256+0*32+1
    DB      "F3/F: Display: 50Hz 60Hz",0
    DW      MEM_ZX_SCREEN_4000+8*256+1*32+1
    DB      "V:    VGA: ?? 48 +2 +3 Pg",0
    DW      MEM_ZX_SCREEN_4000+8*256+3*32+1
    DB      "(F# keys are NMI+number)",0
    DW      MEM_ZX_SCREEN_4000+8*256+4*32+1
    DB      "(HDMI ignores V key)",0
    DB      0, 0, 0
LineLsbVramAdr      EQU     MEM_ZX_SCREEN_4000+4*32+24

HighlightKeysData:
    DW      MEM_ZX_ATTRIB_5800+4*32+1, MEM_ZX_ATTRIB_5800+4*32+3
    DW      MEM_ZX_ATTRIB_5800+5*32+1, MEM_ZX_ATTRIB_5800+5*32+3
    DW      MEM_ZX_ATTRIB_5800+6*32+1
    DW      MEM_ZX_ATTRIB_5800+7*32+1, MEM_ZX_ATTRIB_5800+7*32+2, MEM_ZX_ATTRIB_5800+7*32+4
    DW      MEM_ZX_ATTRIB_5800+8*32+1, MEM_ZX_ATTRIB_5800+8*32+2, MEM_ZX_ATTRIB_5800+8*32+4
    DW      MEM_ZX_ATTRIB_5800+9*32+1
.count = ($ - HighlightKeysData)/2

R_5     EQU     %0000'0101
R_10    EQU     %0001'1111
R_50    EQU     %0101'1111
R_100   EQU     %1111'1111
RulerTicks:
    DB      R_100, R_5, R_10, R_5, R_10, R_5, R_10, R_5, R_10, R_5
    DB      R_50, R_5, R_10, R_5, R_10, R_5, R_10, R_5, R_10, R_5
    DB      R_100, R_5, R_10, R_5, R_10, R_5, R_10, R_5, R_10, R_5
    DB      R_50, R_5, R_10, R_5, R_10, R_5, R_10, R_5, R_10, 0

R_LAB_0:
    DG      -----#--
    DG      ----#-#-
    DG      ----#-#-
    DG      ----#-#-
    DG      -----#--
R_LAB_50:
    DG      ###--#--
    DG      #---#-#-
    DG      ##--#-#-
    DG      --#-#-#-
    DG      ##---#--
R_LAB_00:
    DG      -#---#--
    DG      #-#-#-#-
    DG      #-#-#-#-
    DG      #-#-#-#-
    DG      -#---#--
R_LAB_1:
    DG      ------#-
    DG      -----##-
    DG      ------#-
    DG      ------#-
    DG      ------#-

UiLineLsb   DB  TEST_LINE_LSB-1
UiType      DB  -1
UiMhz       DB  -1
UiVidHz     DB  -1
UiVidVga    DB  -1

KeysRepeatDelay     DB  0

TestLineLsb DB  TEST_LINE_LSB
TestType    DB  TEST_TYPE_READ

UiVidHzAttrs:
            BLOCK   5, P_WHITE
            BLOCK   6, A_BRIGHT|P_CYAN
.len:       BLOCK   5, P_WHITE

UiTypeAttrs:
            BLOCK   10, P_WHITE
.ofs:       BLOCK   11, A_BRIGHT|P_CYAN
.len:       BLOCK   10, P_WHITE

UiMhzAttrs:
            BLOCK   4, P_WHITE
            BLOCK   4, P_WHITE
            BLOCK   4, P_WHITE
.ofs:       BLOCK   5, A_BRIGHT|P_CYAN
.len:       BLOCK   4, P_WHITE
            BLOCK   4, P_WHITE
            BLOCK   4, P_WHITE

UiVidVgaAttrs:
            BLOCK   3, P_WHITE
            BLOCK   3, P_WHITE
            BLOCK   3, P_WHITE
            BLOCK   3, P_WHITE
.ofs:       BLOCK   4, A_BRIGHT|P_CYAN
.len:       BLOCK   3, P_WHITE
            BLOCK   3, P_WHITE
            BLOCK   3, P_WHITE
            BLOCK   3, P_WHITE

    MACRO SET_PALETTE_ELEMENT newColor?
        nextreg PALETTE_VALUE_NR_41,newColor?
    ENDM

Start:
    call    StartTest
    nextreg TURBO_CONTROL_NR_07,0   ; 3.5MHz
    NEXTREG2A PERIPHERAL_2_NR_06
    or      %1010'0000              ; force-enable F8 and F3 keys
    nextreg PERIPHERAL_2_NR_06,a

    ; show MachineID and core version
    ld      de,MEM_ZX_SCREEN_4000+1*32+1
    ld      bc,MEM_ZX_SCREEN_4000+2*32+1
    ld      ix,$ED01        ; display also extended info after MachineId
    call    OutMachineIdAndCore_defLabels

    ; show controls + legend
    ld      hl,LegendText
    jr      .legendPrintLoopEntry
.legendPrintLoop:
    call    OutStringAtDe
.legendPrintLoopEntry:
    ld      e,(hl)
    inc     hl
    ld      d,(hl)
    inc     hl
    ld      a,(hl)
    or      a
    jr      nz,.legendPrintLoop
    ld      a,A_BRIGHT|P_BLUE|WHITE
    ld      hl,HighlightKeysData
    ld      b,HighlightKeysData.count
.highlightKeysLoop:
    ld      e,(hl)
    inc     hl
    ld      d,(hl)
    inc     hl
    ld      (de),a
    djnz    .highlightKeysLoop
    call    drawRightEdgeRuler
    call    refreshUi       ; initial draw of UI values

    ; install the keyboard handlers
    REGISTER_KEY KEY_Q, KeyHandlerLsbUp
    REGISTER_KEY KEY_A, KeyHandlerLsbDown
    REGISTER_KEY KEY_Z, KeyHandlerTestType
    REGISTER_KEY KEY_T, KeyHandlerSwTurboKey
    REGISTER_KEY KEY_F, KeyHandlerSwHzKey
    REGISTER_KEY KEY_W, KeyHandlerLsbUp8
    REGISTER_KEY KEY_S, KeyHandlerLsbDown8
    REGISTER_KEY KEY_V, KeyHandlerVgaTiming

    ; setup the color registers to modify white PAPER color in ULA palette (to show "line")
    nextreg PALETTE_CONTROL_NR_43,%1'000'0000   ; ULA palette, no-increment, classic ULA
    nextreg PALETTE_INDEX_NR_40,16+7        ; white paper color index

    ; set IM2 handler
    ld      a,im2tabHI
    ld      i,a
    im      2
    nextreg VIDEO_INTERUPT_CONTROL_NR_22,%00000'1'1'0  ; scanline interrupt only, disable ULA

MainLoop:
    ld      a,(KeysRepeatDelay)
    sub     1
    adc     a,0
    ld      (KeysRepeatDelay),a
    call    RefreshKeyboardState
    call    refreshUi
    ld      a,(TestType)
    cp      TEST_TYPE_READ
    jr      z,TestReadNr1F
    ; nothing more to do in interrupt type
    halt
    jr      MainLoop
TestReadNr1F:
    ; wait for scanline (reading nextreg $1F) type of test
    SET_PALETTE_ELEMENT %101'101'10     ; white paper
    ld      hl,(TestLineLsb)    ; L = LSB value
    ; read NextReg $1F - LSB of current raster line
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    ld      a,VIDEO_LINE_LSB_NR_1F
    out     (c),a               ; select NextReg $1F
    inc     b                   ; BC = TBBLUE_REGISTER_ACCESS_P_253B
    ; if not yet at scanline, wait for it ... wait for it ...
.waitLoop:
    in      a,(c)               ; read the raster line LSB
    cp      l
    jr      nz,.waitLoop
    SET_PALETTE_ELEMENT %000'011'00     ; green paper
    ld      a,8
.wasteTimeLoop:
    dec     a
    jr      nz,.wasteTimeLoop
.waitFullLine:
    in      a,(c)               ; read the raster line LSB
    cp      l
    jr      z,.waitFullLine
    SET_PALETTE_ELEMENT %101'101'10     ; white paper
    jr      MainLoop

;--------------------------------------------------------------------------------------
; keyboard handlers
;--------------------------------------------------------------------------------------

KeyHandlerTestType:
    di
    ld      a,(TestType)
    xor     1
    ld      (TestType),a
    ret     nz                  ; TEST_TYPE_READ is set up like this (by DI)
    ; TEST_TYPE_IRQ - enable the interrupt at correct line
    ld      a,(TestLineLsb)
    nextreg VIDEO_INTERUPT_VALUE_NR_23,a
    ei
    ret
KeyHandlerSwHzKey:
    NEXTREG2A PERIPHERAL_1_NR_05
    xor     4
    nextreg PERIPHERAL_1_NR_05,a
    ret
KeyHandlerVgaTiming:
    ld      a,(UiVidVga)
    inc     a
    ret     z           ; ignore HDMI video (no action)
    NEXTREG2A MACHINE_TYPE_NR_03
    add     a,$90       ; ++displayTiming and set $80
    cp      %1101'0000  ; this should set carry for any legal mode (bits6-4: 000..100)
    jr      c,.newValueReady
    and     %1000'1111  ; reset video timing to 000 from invalid one
.newValueReady:
    nextreg MACHINE_TYPE_NR_03,a
    ret
KeyHandlerSwTurboKey:
    NEXTREG2A   TURBO_CONTROL_NR_07
    inc     a
    and     3
    nextreg TURBO_CONTROL_NR_07,a
    ret
KeyHandlerLsbUp:
    call    KeyHandlerLsb_all
    ret     nz
    ld      hl,TestLineLsb
    dec     (hl)
    ret
KeyHandlerLsbDown:
    call    KeyHandlerLsb_all
    ret     nz
    ld      hl,TestLineLsb
    inc     (hl)
    ret
KeyHandlerLsbUp8:
    call    KeyHandlerLsb_all
    ret     nz
    ld      a,(TestLineLsb)
    sub     8
    ld      (TestLineLsb),a
    ret
KeyHandlerLsbDown8:
    call    KeyHandlerLsb_all
    ret     nz
    ld      a,(TestLineLsb)
    add     a,8
    ld      (TestLineLsb),a
    ret
KeyHandlerLsb_all:      ; returns Zf=1 if the value should be adjusted
    xor     a           ; modify controls.i.asm behaviour for auto-repeat and own delay
    ld      (debounceState),a
    ld      a,(KeysRepeatDelay)
    or      a
    ret     nz
    ld      a,3
    ld      (KeysRepeatDelay),a
    ret

;--------------------------------------------------------------------------------------
; draw-UI related functions
;--------------------------------------------------------------------------------------

getVideoModeNumber:
    ; return -1 if the HDMI display is used
    NEXTREG2A VIDEO_TIMING_NR_11
    inc     a
    and     %00000'111  ; bits 2-0 are video mode (+1 from INC)
    ld      a,-1
    ret     z
    NEXTREG2A MACHINE_TYPE_NR_03
    swapnib
    and     7
    ret                 ; for VGA return 0..5 for video timing selected

refreshUi:
    ld      hl,UiLineLsb
    ld      a,(TestLineLsb)
    cp      (hl)
    call    nz,refreshUiLineLsb
    ld      hl,UiType
    ld      a,(TestType)
    cp      (hl)
    call    nz,refreshUiType
    NEXTREG2A TURBO_CONTROL_NR_07
    and     3
    ld      hl,UiMhz
    cp      (hl)
    call    nz,refreshUiMhz
    call    getVideoModeNumber
    ld      hl,UiVidVga
    cp      (hl)
    call    nz,refreshVidVga
    NEXTREG2A PERIPHERAL_1_NR_05
    and     4
    ld      hl,UiVidHz
    cp      (hl)
    ret     z
    ; |
    ; fallthrough to refreshUiVidHz
    ; |
refreshUiVidHz:
    ld      (hl),a
    ld      hl,UiVidHzAttrs     ; add +5 or +0 for 50Hz/60Hz
    xor     4
    add     hl,a
    rrca
    rrca
    add     hl,a
    ld      de,MEM_ZX_ATTRIB_5800+8*32+15
    ld      bc,UiVidHzAttrs.len-UiVidHzAttrs
    ldir
    ret
refreshVidVga:
    ld      (hl),a
    sub     4
    neg
    ld      e,a
    add     a,a
    add     a,e                 ; A = (5-mode)*3 (offset into attr data)
    ld      hl,UiVidVgaAttrs
    add     hl,a
    ld      de,MEM_ZX_ATTRIB_5800+9*32+11
    ld      bc,UiVidVgaAttrs.len-UiVidVgaAttrs
    ldir
    ret
refreshUiType:
    ld      (hl),a
    ld      d,UiTypeAttrs.ofs-UiTypeAttrs
    ld      e,a
    mul     de
    ld      hl,UiTypeAttrs
    add     hl,de
    ld      de,MEM_ZX_ATTRIB_5800+6*32+6
    ld      bc,UiTypeAttrs.len-UiTypeAttrs
    ldir
    ret
refreshUiMhz:
    ld      (hl),a
    xor     3
    rlca
    rlca            ; A = (3-turbo)*4 = offset into UiMhzAttrs data
    ld      hl,UiMhzAttrs
    add     hl,a
    ld      de,MEM_ZX_ATTRIB_5800+7*32+11
    ld      bc,UiMhzAttrs.len-UiMhzAttrs
    ldir
    ret
refreshUiLineLsb:
    ld      (hl),a
    ; clear old value in pixel VRAM
    ld      bc,$0400
    ld      hl,LineLsbVramAdr
.clearLoop:
    ld      (hl),c  ; clear 3 bytes to right
    inc     l
    ld      (hl),c
    inc     l
    ld      (hl),c
    inc     h
    ld      (hl),c  ; clear 3 bytes back to left
    dec     l
    ld      (hl),c
    dec     l
    ld      (hl),c
    inc     h
    djnz    .clearLoop  ; do it four times => 8 lines cleared
    ld      hl,LineLsbVramAdr
    ld      (OutCurrentAdr),hl
    jp      OutDecimalValue

    MACRO DRAW_RULER_LABEL coords?, labeladr?
        ld      de,coords?
        pixelad
        ld      de,labeladr?
        call    drawRulerLabelChar
    ENDM

    MACRO DRAW_RULER_LABEL2 coords?, labeladr1?, labeladr2?
        ld      de,coords?
        pixelad
        push    hl
        ld      de,labeladr1?
        call    drawRulerLabelChar
        pop     hl
        inc     l
        ld      de,labeladr2?
        call    drawRulerLabelChar
    ENDM

drawRulerLabelChar:
    ld      b,5
.loop:
    ld      a,(de)
    inc     de
    ld      (hl),a
    pixeldn
    djnz    .loop
    ret

drawRightEdgeRuler:
    ; display numbers at right edge of PAPER
    DRAW_RULER_LABEL $00F0, R_LAB_0
    DRAW_RULER_LABEL $30F0, R_LAB_50
    DRAW_RULER_LABEL2 $62E8, R_LAB_1, R_LAB_00
    DRAW_RULER_LABEL2 $94E8, R_LAB_1, R_LAB_50
    ; create rules at right edge of PAPER
    ld      de,$00FF
    ld      bc,RulerTicks
.rulerLoop:
    ld      a,(bc)
    inc     bc
    or      a
    ret     z
    pixelad             ; Z80N special
    ld      (hl),a      ; draw ruler line at [E,D] coordinates
    ; move Y by +5
    ld      hl,$0500
    add     hl,de
    ex      de,hl
    jr      .rulerLoop

;--------------------------------------------------------------------------------------
; interrupt at scanline type of test - interrupt table + handler
;--------------------------------------------------------------------------------------
    ; IM2 vector table
        ALIGN   256
im2tabHI = high $
im2handlerHI = im2tabHI+1
        BLOCK   257,im2tabHI+1
    ; IM2 handler itself
        ORG     (im2handlerHI<<8) | im2handlerHI
im2handler:
        SET_PALETTE_ELEMENT %000'011'01     ; cyan paper
        push    af
    ; set interrupt line with new value in TestLineLsb
        ld      a,(TestLineLsb)
        nextreg VIDEO_INTERUPT_VALUE_NR_23,a
        ld      a,20
.waitLoop:
        dec     a
        jr      nz,.waitLoop
    ; finish IM2 handler
        pop     af
        ei
        SET_PALETTE_ELEMENT %101'101'10     ; white paper
        ret

    savesna "linesIRQ.sna", Start
