    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

ModesTableNR69:
    DB      $00                     ; regular Bank 4 ULA
    DB      $40                     ; ZX128 shadow ULA Bank 7
    DB      $06                     ; Timex 512x192
    DB      $02                     ; Timex 8x1 HiColor
.c  EQU     $-ModesTableNR69
    ASSERT  4 == .c && 0 == low ModesTableNR69

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

    ; ULA white $B601 (%101 per channel)

XOFS        equ     232
YOFS        equ     164             ; intentionally over 128 to use "3rd third"

LegendTxts:
    DB      'ULA Scroll',0
    DB      'NextRegs:',0
    DB      '$26, $27',0
    DB      ' ',0
    DB      '  Green',0
    DB      ' border:',0
    DB      ' OPQA HRM',0
    DB      ' ',0
    DB      'ULA clip:',0
    DB      '[8,8] ->',0
    DB      '[239,175]',0
    DB      ' ',0
    DB      'ULA BANK4',0
    DB      'ULA BANK7',0
    DB      'Timex 512',0
    DB      'Timex 8x1',0
    DB      0

Start:
    call    StartTest
    ; show red border while drawing and preparing...
    BORDER  RED
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14,$E3    ; enforce $E3 (NextZXOS sets $00 lately!)
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%101'000'00  ; red border extension
    ; reset ULA scroll registers
    NEXTREG_nn ULA_XOFFSET_NR_26, 0
    NEXTREG_nn ULA_YOFFSET_NR_27, 0
    NEXTREG_nn ULA_CONTROL_NR_68, 0     ; half-scroll + completely classic ULA
    NEXTREG_nn DISPLAY_CONTROL_NR_69,0  ; Layer2 off, Bank4 ULA, Timex = 0x00
    ; reset LoRes scroll registers
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; reset Layer2 scroll registers
    NEXTREG_nn LAYER2_XOFFSET_NR_16, 0
    NEXTREG_nn LAYER2_YOFFSET_NR_17, 0
    ; Set layers to: SLU, no sprites, no LoRes
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00000000
    ; set ULA clipping window to [8,8] -> [239,175]
    NEXTREG_nn CLIP_WINDOW_CONTROL_NR_1C,$0F    ; reset clip indices
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,8
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,239
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,8
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,175
    ; ULA will be used classic one, original colours and attributes
    ; draw ULA screen0
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*3+15
    ld      bc,MEM_ZX_SCREEN_4000+$1000+$20*4+15
    call    OutMachineIdAndCore_defLabels
    call    Draw16x16GridWithHexaLabels
    ld      hl,LegendTxts
    ld      de,MEM_ZX_SCREEN_4000+$20*1+19
.OutputFullLegend:
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    push    de
    call    OutStringAtDe
    pop     de
    xor     a
    or      (hl)
    jr      nz,.OutputFullLegend
    ; OPQA HR highlight
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*6+19, 10, P_GREEN|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*7+19, 10, P_GREEN|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*8+19, 10, A_BRIGHT|P_CYAN|BLACK
    ld      hl,MEM_ZX_SCREEN_4000+29
    ld      a,$01
    ld      de,32
    ld      b,192
.DrawRightEdge:
    ld      (hl),a
    add     hl,de
    djnz    .DrawRightEdge
    FILL_AREA   MEM_ZX_ATTRIB_5800-32*3, 32, $FF  ; bottom edge line
    ld      de,$0F08
    ld      hl,MEM_ZX_SCREEN_4000+30
.DrawRighHiddenStripes:
    ld      bc,$0216
    push    hl
    call    FillSomeUlaLines
    pop     hl
    inc     h
    rlc     d
    dec     e
    jr      nz,.DrawRighHiddenStripes
    ld      de,$0F08
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20*6
.DrawBottomHiddenStripes:
    ld      bc,$2002
    push    hl
    call    FillSomeUlaLines
    pop     hl
    inc     h
    rlc     d
    dec     e
    jr      nz,.DrawBottomHiddenStripes
    FILL_AREA   MEM_ZX_ATTRIB_5800, 30, A_BRIGHT|P_YELLOW|BLACK ; top edge with attr
    ld      hl,MEM_ZX_ATTRIB_5800
    ld      a,A_BRIGHT|P_YELLOW|BLACK
    ld      de,32
    ld      b,22
.DrawLeftAttrEdge:
    ld      (hl),a
    add     hl,de
    djnz    .DrawLeftAttrEdge
    ; fill Timex 8x1 and 512x192 second buffer with some debug data which display at least something
    ld      hl,MEM_TIMEX_SCR1_6000
    ld      de,MEM_TIMEX_SCR1_6000+1
    ld      bc,32*192-1
    ld      (hl),P_WHITE|BLUE
    ldir
    ; copy Bank4 ULA to Bank7 (ZX128 Shadow ULA)
    NEXTREG_nn MMU0_0000_NR_50, 14
    ld      hl,MEM_ZX_SCREEN_4000
    ld      de,0
    ld      bc,$2000
    ldir
    FILL_AREA $1800+$20*15+19, 9, A_BRIGHT|P_BLUE|WHITE ; highlight BANK 7
    NEXTREG_nn MMU0_0000_NR_50, 255
    FILL_AREA MEM_ZX_ATTRIB_5800+$20*14+19, 9, A_BRIGHT|P_BLUE|WHITE ; highlight BANK 4
    ; highlight Timex 8x1
    FILL_AREA MEM_TIMEX_SCR1_6000+$1100+$20*1+19, 9, A_BRIGHT|P_BLUE|GREEN
    FILL_AREA MEM_TIMEX_SCR1_6000+$1200+$20*1+19, 9, A_BRIGHT|P_BLUE|CYAN
    FILL_AREA MEM_TIMEX_SCR1_6000+$1300+$20*1+19, 9, A_BRIGHT|P_BLUE|WHITE
    FILL_AREA MEM_TIMEX_SCR1_6000+$1400+$20*1+19, 9, A_BRIGHT|P_BLUE|WHITE
    FILL_AREA MEM_TIMEX_SCR1_6000+$1500+$20*1+19, 9, A_BRIGHT|P_BLUE|CYAN
    FILL_AREA MEM_TIMEX_SCR1_6000+$1600+$20*1+19, 9, A_BRIGHT|P_BLUE|GREEN
    ; blue border to signal next phase of test
    BORDER  BLUE
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%000'000'10  ; blue border extension
    ; setup empty interrupt handler
    ld      a,IVT2
    ld      i,a
    im      2
    ei
    ; and finally set the ULA scroll registers ; do it in "animated" way
    ld      ix,-XOFS<<8
    ld      iy,YOFS<<8
    ld      hl,+XOFS/2      ; fixed point math 8.8 for 512 steps, i.e. the final coords.
    ld      de,-YOFS/2      ; will be [0,0] in top 8 bits of [ix, iy]
    ; do the initial scroll and wait 0.5s before scroll starts
    ld      a,ixh
    NEXTREG_A ULA_XOFFSET_NR_26
    ld      a,iyh
    NEXTREG_A ULA_YOFFSET_NR_27
    ld      b,25
.WaitBefore:
    halt
    djnz    .WaitBefore
    ; start the scroll animation loop
    ld      bc,$0002        ; B = 0 (256x), C = 2 (2*256 = 512x)
.ScrollLoop:
    halt
    ; advance the 8.8 coordinates in [ix,iy]
    add     iy,de
    ex      de,hl
    add     ix,de
    ex      de,hl
    ; set the scroll registers
    ld      a,ixh
    NEXTREG_A ULA_XOFFSET_NR_26
    ld      a,iyh
    NEXTREG_A ULA_YOFFSET_NR_27
    ld      a,%1111'1011    ; QWERT row
    in      a,(ULA_P_FE)
    and     %000'01000      ; check R to skip scroll loop
    jr      z,.SkipScroll
    djnz    .ScrollLoop
    dec     c
    jr      nz,.ScrollLoop
    ; signal end of test, read keyboard OPQAHR to modify scroll
.SkipScroll:
    BORDER  GREEN
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%000'101'00  ; green border extension
    ; ULA_CONTROL_NR_68 was already set to zero by test init, so no need to read "current" value
.ResetScrollCoordinates:
    ld      e,0             ; NR_68 value -> does include half-scroll bit 2 (0x04)
    ld      ixh,e           ; reset scroll coordinates
    ld      iyh,e
.InteractiveLoop:
    ; set croll registers
    ld      a,ixh
    NEXTREG_A ULA_XOFFSET_NR_26
    ld      a,iyh
    NEXTREG_A ULA_YOFFSET_NR_27
    ld      a,e
    NEXTREG_A ULA_CONTROL_NR_68
    halt
    ; read keys, adjust regs
    ld      a,%0111'1111    ; M (bit 2) row
    in      a,(ULA_P_FE)
    and     %000'00100
    jr      nz,.notM
.mN+1:  ld      a,0         ; index into ModesTableNR69
    inc     a
    and     ModesTableNR69.c-1
    ld      (.mN),a
    ld      l,a
    ld      h,high ModesTableNR69
    ld      a,(hl)          ; fetch mode value from the table
    NEXTREG_A DISPLAY_CONTROL_NR_69     ; set new mode
    ld      b,10
    halt
    djnz    $-1             ; slight delay (10 frames = 0.2s)
.notM:
    ld      a,%1011'1111    ; H (bit 4) row
    in      a,(ULA_P_FE)
    and     %000'10000
    jr      nz,.notH
    ld      a,1<<2          ; H pressed, flip half-scroll bit
    xor     e
    ld      e,a
    ld      b,10
    halt
    djnz    $-1             ; slight delay (10 frames = 0.2s)
.notH:
    ld      a,%1101'1111    ; O (bit 1) and P (bit 0) row
    in      a,(ULA_P_FE)
    rra
    jr      c,.notP
    inc     ixh
.notP:
    rra
    jr      c,.notO
    dec     ixh
.notO:
    ld      a,%1111'1011    ; Q (bit 0) row
    in      a,(ULA_P_FE)
    push    af
    rra
    jr      c,.notQ
    xor     a
    cp      iyh
    jr      nz,.YofsOk1
    ld      iyh,192
.YofsOk1:
    dec     iyh
.notQ:
    ld      a,%1111'1101    ; A (bit 0) row
    in      a,(ULA_P_FE)
    rra
    jr      c,.notA
    ld      a,191
    cp      iyh
    jr      nz,.YofsOk2
    ld      iyh,-1
.YofsOk2:
    inc     iyh
.notA:
    pop     af              ; R is in the same row as Q (already read)
    and     %000'01000
    jr      z,.ResetScrollCoordinates
    jr      .InteractiveLoop

    call EndTest

    ALIGN   256
IVT2        equ     high $
Im2Handler  equ     ((IVT2+1)<<8) + IVT2+1
    BLOCK   257,IVT2+1

    ORG Im2Handler
    ei
    ret

    savesna "UlaScrol.sna", Start
