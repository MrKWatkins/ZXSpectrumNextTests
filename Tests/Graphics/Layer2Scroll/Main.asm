    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

    ; ULA white $B601 (%101 per channel)

XOFS        equ     196
YOFS        equ     133             ; intentionally over 128 to finish in 3rd third

Start:
    call    StartTest
    ; show red border while drawing and preparing...
    BORDER  RED
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%101'000'00  ; red border extension
    ; reset LoRes scroll registers (does affect ULA screen since core 2.00.25+)
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; reset Layer2 scroll registers
    NEXTREG_nn LAYER2_XOFFSET_NR_16, 0
    NEXTREG_nn LAYER2_YOFFSET_NR_17, 0
    ; Set layers to: SLU, no sprites, no LoRes
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00000000
    ; select first-L2 palette, disable ULANext, enable auto-inc
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00010000
    ; ULA will be used classic one, original colours and attributes
    ; Setup Layer2 palette:
    NEXTREG_nn PALETTE_INDEX_NR_40, 1
    ; palette[L2][0][1] = $FC00     ; will be transparent
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $FC
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $00
    ; palette[L2][0][2] = $9301     ; light blue
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $93
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $01
    ; palette[L2][0][3] = $0001     ; blue-ish black
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $00
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $01
    NEXTREG_nn PALETTE_VALUE_NR_41, %101'000'00 ; [L2][0][4] = red
    NEXTREG_nn PALETTE_VALUE_NR_41, %101'101'00 ; [L2][0][5] = yellow
    NEXTREG_nn PALETTE_VALUE_NR_41, %101'000'01 ; [L2][0][6] = blueish red
    NEXTREG_nn PALETTE_VALUE_NR_41, %101'101'01 ; [L2][0][7] = blueish yellow
    ; setup global transparency features
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14, $FC       ; global transparency colour
    ; setup Layer2 bank to 9 (like NextZXOS does)
    NEXTREG_nn LAYER2_RAM_BANK_NR_12, 9
    ; set Layer2 and ULA clipping window to [8,8] -> [239,175]
    NEXTREG_nn CLIP_WINDOW_CONTROL_NR_1C,$0F    ; reset clip indices
    NEXTREG_nn CLIP_LAYER2_NR_18,8
    NEXTREG_nn CLIP_LAYER2_NR_18,239
    NEXTREG_nn CLIP_LAYER2_NR_18,8
    NEXTREG_nn CLIP_LAYER2_NR_18,175
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,8
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,239
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,8
    NEXTREG_nn CLIP_ULA_LORES_NR_1A,175
    ; draw ULA screen0
    FILL_AREA   MEM_ZX_ATTRIB_5800, 32*24, P_WHITE|BLUE ; change attributes
    call    DrawUlaPart             ; draw lines
    ; make Layer2 visible
    ld      bc, LAYER2_ACCESS_P_123B
    ld      a, LAYER2_ACCESS_L2_ENABLED
    out     (c), a
    ; map whole Layer2 into memory (into 0000..BFFF region) (commented are default values)
    NEXTREG_nn MMU0_0000_NR_50, 18      ; $FF
    NEXTREG_nn MMU1_2000_NR_51, 19      ; $FF
    NEXTREG_nn MMU2_4000_NR_52, 20      ; $0A
    NEXTREG_nn MMU3_6000_NR_53, 21      ; $0B
    NEXTREG_nn MMU4_8000_NR_54, 22      ; $04
    NEXTREG_nn MMU5_A000_NR_55, 23      ; $05
    ; clear Layer2 with colour 1 (transparent)
    FILL_AREA   $0000, 256*192, $01
    call    DrawLayer2Part
    ; map ROM and low RAM back to make im1 work!
    NEXTREG_nn MMU0_0000_NR_50, $FF
    NEXTREG_nn MMU1_2000_NR_51, $FF
    NEXTREG_nn MMU2_4000_NR_52, $0A
    NEXTREG_nn MMU3_6000_NR_53, $0B
    ; blue border to signal next phase of test
    BORDER  BLUE
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%000'000'10  ; blue border extension
    ; setup empty interrupt handler
    ld      a,IVT2
    ld      i,a
    im      2
    ei
    ; wait a short while before scroll starts
    ld      b,25
.WaitBefore:
    halt
    djnz    .WaitBefore
    ; and finally set the Layer2 scroll registers ; do it in "animated" way
    ld      ix,0
    ld      iy,0
    ld      hl,XOFS*2       ; fixed point math 8.8 for 128 steps, i.e. the final coords.
    ld      de,YOFS*2       ; will be [XOFS,YOFS] in top 8 bits of [ix, iy]
    ld      b,128
.ScrollLoop:
    halt
    ; advance the 8.8 coordinates in [ix,iy]
    add     iy,de
    ex      de,hl
    add     ix,de
    ex      de,hl
    ; set the scroll registers
    ld      a,ixh
    NEXTREG_A LAYER2_XOFFSET_NR_16
    ld      a,iyh
    NEXTREG_A LAYER2_YOFFSET_NR_17
    djnz    .ScrollLoop
    ; and finish test

    ; signal end of test, read keyboard OPQA to modify scroll
    BORDER  GREEN
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%000'101'00  ; green border extension
InteractiveLoop:
    ; set croll registers
    ld      a,ixh
    NEXTREG_A LAYER2_XOFFSET_NR_16
    ld      a,iyh
    NEXTREG_A LAYER2_YOFFSET_NR_17
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
    jr      nz,.notR
    ld      ixh,196         ; reset scroll coordinates to [196,133]
    ld      iyh,133
.notR:
    jr      InteractiveLoop
    call EndTest

LegendTxts:
    DB      ' Green',0
    DB      'border:',0
    DB      ' OPQA R',0
    DB      0

DrawUlaPart:
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*3+15
    ld      bc,MEM_ZX_SCREEN_4000+$1000+$20*4+15
    call    OutMachineIdAndCore_defLabels
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
    ; OPQA highlight
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*2+19, 7, P_GREEN|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*3+19, 7, P_GREEN|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*4+19, 7, A_BRIGHT|P_CYAN|BLACK

    ; draw vertical lines
    ld      hl,MEM_ZX_SCREEN_4000 + 5*32 + 5        ; [5, 5] char pos
    ld      de,$8008        ; D = $80 (pixel to draw), E = 8 counter
.VerticalLinesLoop:
    push    hl
    ld      bc,$0505
    call    FillSomeUlaLines
    pop     hl
    inc     h
    dec     e
    jr      nz,.VerticalLinesLoop
    ; draw horizontal lines
    ld      hl,MEM_ZX_SCREEN_4000 + 2048 + (14-8)*32 + 22   ; second VRAM third [22, 14]
    ld      d,$FF           ; D = $FF (pixels to draw)
    ld      bc,$0505
    call    FillSomeUlaLines
    ret

DrawLayer2Part:
    ; draw X/Y axis with [0,0] origin to make the scroll coordinates "visible"
    ld      hl,1
    ld      de,$0001
    ld      ix,$2000
    ld      bc,(1<<8) + 3
    ld      a,6
    call    DoLinesLoop
    ld      ixh,$08
    ld      a,24
    dec     l
    ld      c,2
    call    DoLinesLoop
    ld      de,$0100
    ld      ix,$0008
    ld      a,32
    call    DoLinesLoop
    ld      ixl,$20
    ld      a,8
    inc     h
    ld      c,3
    call    DoLinesLoop
    ; draw vertical dotted light blue lines just around the ULA lines
    ld      hl,((40+YOFS) MOD 192)*256 + ($FF&(40+XOFS-1))  ; 1 pixel left of ULA pixel
    ld      bc,(20<<8) + 2  ; B = 20 pixels counter, C = ligh blue colour
    ld      de,$0200        ; +2 down, +0 sideways (between line pixels)
    ld      ix,$0008        ; +0 up, +8 right between whole lines
    ld      a,5
    call    DoLinesLoop
    ; [+1, +2] the second set of lines
    inc     l
    inc     l
    inc     h
    call    DoLinesLoop
    ; draw horizontal dotted light blue lines around the horizontal ULA lines
    ld      hl,((112+YOFS-1) MOD 192)*256 + (255&(176+XOFS))    ; 1 pixel up of ULA pixel
    ld      de,$0002        ; +0 vertically, +2 right (between line pixels)
    ld      ix,$0800        ; +8 down, +0 right between whole lines
    call    DoLinesLoop     ; BC and A remain identical
    ; [+2, +1] the second set of lines
    inc     h
    inc     h
    inc     l
    call    DoLinesLoop
    ; draw vertical almost-black part of lines (connecting to ULA lines)
    ld      hl,((41+YOFS) MOD 192)*256 + ($FF&(40+XOFS))  ; start 2px over ULA line (overdraw)
    ld      bc,(20<<8) + 3  ; B = 20 pixels counter, C = blue-ish black colour
    ld      de,$FF00        ; -1 up, +0 sideways
    ld      ix,$FF08        ; -1 up, +8 right between lines
    ld      a,5             ; 5 lines loop
    call    DoLinesLoop
    ld      d,$01           ; +1 down
    ld      h,(78+YOFS) MOD 192 ; start 2px over ULA line (overdraw)
    ld      ix,$0108        ; +1 down, +8 right between lines
    call    DoLinesLoop
    ; draw horizontal almost-black part of lines (connecting to ULA lines)
    ld      hl,((112+YOFS) MOD 192)*256 + ($FF&(177+XOFS))  ; start 2px over ULA line (overdraw)
    ld      de,$00FF        ; +0 up, -1 left
    ld      ix,$08FF        ; +8 down, -1 left between lines
    call    DoLinesLoop     ; use same BC and A as above
    ld      e,$01           ; +1 right
    ld      l,$FF&(38+176+XOFS)     ; start 2px over ULA line (overdraw)
    ld      ix,$0801        ; +8 down, +1 right between lines
    call    DoLinesLoop
    ;; draw the part under clipped window
    ld      hl,ClipPatternTopLeft
    ld      de,+(133<<8)
    call    DrawL2StripesFullLine
    ld      hl,ClipPatternBottomRight
    ld      de,+(133-8<<8)
    call    DrawL2StripesFullLine
    ld      hl,ClipPatternBottomRight
    ld      de,+(133-16<<8)
    call    DrawL2StripesFullLine
    ld      h,133
    ld      d,133+8
    ld      b,51
    call    DrawL2StripesSideEdge
    ld      h,133-16+3
    ld      d,0
    ld      b,8
    call    DrawL2StripesSideEdge
    ld      h,0
    ld      d,8
    ld      b,133-24
    call    DrawL2StripesSideEdge
    ret

ClipPatternTopLeft:
    DB      4, 4, 4, 4, 5, 5, 5, 5, 4, 4, 4, 4, 5, 5, 5, 5
ClipPatternBottomRight:
    DB      6, 6, 6, 6, 7, 7, 7, 7, 6, 6, 6, 6, 7, 7, 7, 7

DrawL2StripesSideEdge:
    push    bc
    ld      l,196-16
    ld      e,196-16
    ld      bc,24
    ldir
    inc     h
    inc     d
    pop     bc
    djnz    DrawL2StripesSideEdge
    ret

DrawL2StripesFullLine:
    ld      b,8
.DrawHorizontalStripesTop:
    push    hl
    push    bc
    push    de
    ld      bc,8
    ldir
    pop     hl
    ld      c,256-8
    ldir
    pop     bc
    pop     hl
    inc     hl
    djnz    .DrawHorizontalStripesTop
    ret

; HL = starting coordinates, DE = line vector, B = pixels to draw, C = colour
; IX = vector between lines, A = number of lines, preserves all registers
DoLinesLoop:
    push    af
    push    hl
.linesLoop:
    push    af
    push    hl
    push    bc
    call    DrawL2Line
    pop     bc
    pop     hl
    ; move between lines by IX vector
    ld      a,ixh
    add     a,h
    ld      h,a
    ld      a,ixl
    add     a,l
    ld      l,a
    pop     af
    dec     a
    jr      nz,.linesLoop
    pop     hl
    pop     af
    ret

; HL = starting coordinates, DE = line vector, B = pixel length, C = colour
DrawL2Line:
    ; check if HL didn't run out of screen area (0000..BFFF), wrap it around then
    ld      a,h
    cp      $C0
    jr      c,.HisOK
    sub     $C0
    ld      h,a
.HisOK:
    ld      (hl),c
    ; adjust HL by vector DE
    ld      a,l
    add     a,e
    ld      l,a
    ld      a,h
    add     a,d
    ld      h,a
    ; draw all pixels
    djnz    DrawL2Line
    ret

    ALIGN   256
IVT2        equ     high $
Im2Handler  equ     ((IVT2+1)<<8) + IVT2+1
    BLOCK   257,IVT2+1

    ORG Im2Handler
    ei
    ret

    savesna "L2Scroll.sna", Start
