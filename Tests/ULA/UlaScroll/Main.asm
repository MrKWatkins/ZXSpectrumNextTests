    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

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
    DB      'After green',0
    DB      'border: OPQA',0
    DB      0

Start:
    call    StartTest
    ; show red border while drawing and preparing...
    BORDER  RED
    ; reset ULA scroll registers
    NEXTREG_nn ULA_XOFFSET_NR_26, 0
    NEXTREG_nn ULA_YOFFSET_NR_27, 0
    ; reset LoRes scroll registers
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; reset Layer2 scroll registers
    NEXTREG_nn LAYER2_XOFFSET_NR_16, 0
    NEXTREG_nn LAYER2_YOFFSET_NR_17, 0
    ; Set layers to: SLU, no sprites, no LoRes
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00000000
    ; ULA will be used classic one, original colours and attributes
    ; draw ULA screen0
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*5+17
    ld      bc,MEM_ZX_SCREEN_4000+$1000+$20*6+17
    call    OutMachineIdAndCore_defLabels
    call    Draw16x16GridWithHexaLabels
    ld      hl,LegendTxts
    ld      de,MEM_ZX_SCREEN_4000+$20*0+19
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
    ld      hl,MEM_ZX_SCREEN_4000+31
    ld      a,$01
    ld      de,32
    ld      b,192
.DrawRightEdge:
    ld      (hl),a
    add     hl,de
    djnz    .DrawRightEdge
    FILL_AREA   MEM_ZX_ATTRIB_5800-32, 32, $FF  ; bottom edge line
    FILL_AREA   MEM_ZX_ATTRIB_5800, 32, A_BRIGHT|P_YELLOW|BLACK ; top edge with attr
    ld      hl,MEM_ZX_ATTRIB_5800
    ld      a,A_BRIGHT|P_YELLOW|BLACK
    ld      de,32
    ld      b,24
.DrawLeftAttrEdge:
    ld      (hl),a
    add     hl,de
    djnz    .DrawLeftAttrEdge
    ; blue border to signal next phase of test
    BORDER  BLUE
    ; setup empty interrupt handler
    ld      a,high Im2Table
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
    djnz    .ScrollLoop
    dec     c
    jr      nz,.ScrollLoop
    ; signal end of test, read keyboard OPQA to modify scroll
    BORDER  GREEN
.InteractiveLoop:
    ; set croll registers
    ld      a,ixh
    NEXTREG_A ULA_XOFFSET_NR_26
    ld      a,iyh
    NEXTREG_A ULA_YOFFSET_NR_27
    halt
    ; read keys, adjust regs
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
    jr      .InteractiveLoop
    
    call EndTest

    ASSERT $ < $C400
    ORG $C400
Im2Table:
    BLOCK   257,$C5
    ORG $C5C5
Im2Handler:
    ei
    ret

    savesna "UlaScrol.sna", Start
