    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

    MACRO   LDI_DE_FROM_HL
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
    ENDM

    ; ULA white $B601 (%101 per channel)

XOFS        equ     196
YOFS        equ     133             ; intentionally over 128 to finish in 3rd third

Start:
    ld      sp,$FFE0
    call    StartTest
    ; show red border while drawing and preparing...
    BORDER  RED
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%101'000'00  ; red border extension
    ; reset LoRes scroll registers (did affect ULA screen in cores 2.00.25+ to 3.0.5?)
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; reset ULA scroll registers (regular scroll for ULA since some late core 3.0.x)
    NEXTREG_nn ULA_XOFFSET_NR_26, 0
    NEXTREG_nn ULA_YOFFSET_NR_27, 0
    ; reset Layer2 scroll registers
    NEXTREG_nn LAYER2_XOFFSET_NR_16, 0
    NEXTREG_nn LAYER2_YOFFSET_NR_17, 0
    NEXTREG_nn LAYER2_XOFFSET_MSB_NR_71, 0
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
    ; setup Layer2 bank to 9 (like NextZXOS does) and to 640x256x4bpp mode (will be switched to 256x192)
    NEXTREG_nn LAYER2_RAM_BANK_NR_12, 9
    NEXTREG_nn LAYER2_CONTROL_NR_70, %00'10'0000    ; 640x256x4bpp, palette offset 0
    ; set ULA clipping window to [8,8] -> [239,175] (L2 clip is reset by switch mode routine)
    NEXTREG_nn CLIP_WINDOW_CONTROL_NR_1C,$0F    ; reset clip indices
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
    call    DrawLayer2Part              ; 256x192x8bpp
    call    DrawLayer2Part_320x256_and_640x256
    ; map ROM and low RAM back to make ULA UI redraw work (im1/ROM is not used any more)
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
    ; switch from 640x256x4bpp to default 256x192x8bpp (+ refresh UI)
    call    SwitchL2Mode
    ; wait a short while before scroll starts
    ld      b,15
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
    ld      a,%1111'1011    ; QWERT row
    in      a,(ULA_P_FE)
    and     %000'01000      ; check R to skip scroll loop
    jr      z,.SkipScroll
    djnz    .ScrollLoop
    ; and finish test
.SkipScroll:

    ; signal end of test, read keyboard OPQA to modify scroll
    BORDER  GREEN
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%000'101'00  ; green border extension
ResetScrollPos:
    ld      ix,XOFS
    ld      iy,YOFS
InteractiveLoop:
    ; set croll registers
    ld      a,ixl
    NEXTREG_A LAYER2_XOFFSET_NR_16
    ld      a,ixh
    NEXTREG_A LAYER2_XOFFSET_MSB_NR_71
    ld      a,iyl
    NEXTREG_A LAYER2_YOFFSET_NR_17
    halt
    ; read keys, adjust regs
    ld      a,%0111'1111    ; M (bit 2) row
    in      a,(ULA_P_FE)
    and     %000'00100
    call    z,SwitchL2Mode
    ld      a,%1101'1111    ; O (bit 1) and P (bit 0) row
    in      a,(ULA_P_FE)
    rra
    jr      c,.notP
    inc     ix
.notP:
    rra
    jr      c,.notO
    dec     ix
.notO:
    ld      a,%1111'1011    ; Q (bit 0) row and R (bit 3)
    in      a,(ULA_P_FE)
    bit     3,a             ; reset scroll position when R is pressed
    jr      z,ResetScrollPos
    rra
    jr      c,.notQ
    dec     iy
.notQ:
    ld      a,%1111'1101    ; A (bit 0) row
    in      a,(ULA_P_FE)
    rra
    jr      c,.notA
    inc     iy
.notA:
    call    WrapOffsets
    ld      a,%1111'1110    ; C (bit 3) row
    in      a,(ULA_P_FE)
    bit     3,a
    jr      nz,InteractiveLoop
    NEXTREG_nn $18,0        ; switch off clipping
    NEXTREG_nn $18,255
    NEXTREG_nn $18,0
    NEXTREG_nn $18,255
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*11+17, 13, P_WHITE|CYAN
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*12+17, 13, P_WHITE|CYAN
    jr      InteractiveLoop
    call EndTest

WrapOffsets:
    ; wrap X offset
.x_limit+*: ld  de,256
    push    ix
    pop     hl
    call    .wrapValue
    push    hl
    pop     ix
    ; output X ofs value to ULA
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*3+9
    call    .prepareOutput
    ld      a,h
    call    OutHexaDigit
    ld      a,l
    call    OutHexaValue
    ; wrap Y offset
.y_limit+*: ld  de,192
    push    iy
    pop     hl
    call    .wrapValue
    push    hl
    pop     iy
    ; output Y ofs value to ULA
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*4+10
    call    .prepareOutput
    ld      a,l
    jp      OutHexaValue
.wrapValue:
    add     hl,de
    ret     c               ; -1 was fixed by adding the limit
    sbc     hl,de           ; restore value
    sbc     hl,de           ; subtract limit
    ret     nc              ; over limit was fixed by subtracting it
    add     hl,de           ; restore value
    ret
.prepareOutput:
    ld      (OutCurrentAdr),de
.wipeUlaChars:
    xor     a
    ld      b,8
.wipeOneChar:
    ld      (de),a
    inc     d
    djnz    .wipeOneChar
    res     3,d
    inc     e
    bit     2,e
    jr      z,.wipeUlaChars
    ret

ModesTableNR70:
  ; 256x192x8bpp
    DB      9                               ; first 16ki bank
    DB       8, 239,    8,    175           ; clip coordinates
    DW      256, 192                        ; scroll limits x, y
    DW      MEM_ZX_ATTRIB_5800+$20*6+17     ; ULA highlight mode
    DW      MEM_ZX_ATTRIB_5800+$20*11+17    ; ULA highlight clip coordinates
    DB      0,0,0
    ASSERT 16 == $-ModesTableNR70
  ; 320x256x8bpp
    DB      12                              ; first 16ki bank
    DB      20, 135, 32+8, 32+175           ; clip coordinates
    DW      320, 256                        ; mode scroll limits x, y
    DW      MEM_ZX_ATTRIB_5800+$20*7+17     ; ULA highlight mode
    DW      MEM_ZX_ATTRIB_5800+$20*12+17    ; ULA highlight clip coordinates
    DB      0,0,0
    ASSERT 32 == $-ModesTableNR70
  ; 640x256x4bpp
    DB      17                              ; first 16ki bank
    DB      20, 135, 32+8, 32+175           ; clip coordinates
    DW      320, 256                        ; mode scroll limits x, y
    DW      MEM_ZX_ATTRIB_5800+$20*8+17     ; ULA highlight mode
    DW      MEM_ZX_ATTRIB_5800+$20*12+17    ; ULA highlight clip coordinates
    DB      0,0,0

SwitchL2Mode:
    ; reset mode/clip-highlight attributes
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20* 6+17, 13, P_WHITE|CYAN
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20* 7+17, 13, P_WHITE|CYAN
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20* 8+17, 13, P_WHITE|CYAN
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*11+17, 13, P_WHITE|CYAN
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*12+17, 13, P_WHITE|CYAN
    ; read current mode and advance to next one
    NEXTREG2A LAYER2_CONTROL_NR_70
    add     a,%00'01'0000   ; 256x192x8bpp -> 320x256x8bpp -> 640x256x4bpp
    cp      %00'11'0000
    jr      c,.valid_mode
    xor     a               ; back to 256x192x8bpp
.valid_mode:
    ; set new mode and its extra properties
    NEXTREG_A LAYER2_CONTROL_NR_70  ; set new mode
    ld      hl,ModesTableNR70       ; HL = mode table
    DW      $31ED           ; Z80N add hl,a ; +0, +16 or +32 for each mode
    ld      a,(hl)
    inc     hl
    NEXTREG_A LAYER2_RAM_BANK_NR_12 ; set first bank of the mode
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B    ; set clip registers
    ld      a,CLIP_LAYER2_NR_18
    out     (c),a
    inc     b               ; set new clip window for the mode
    DW      $90ED           ; Z80N instruction outinb
    DW      $90ED
    DW      $90ED
    DW      $90ED
    LDI_DE_FROM_HL          ; scroll limit X
    ld      (WrapOffsets.x_limit),de
    LDI_DE_FROM_HL          ; scroll limit Y
    ld      (WrapOffsets.y_limit),de
    ; change highligh of mode/clip string (must be last, as it destroys HL)
    LDI_DE_FROM_HL
    push    de
    LDI_DE_FROM_HL
    ex      de,hl
    ld      a, P_GREEN|BLACK
    ld      bc,13
    call    FillArea
    pop     hl
    call    FillArea
    ; reset scroll registers to default position
    ld      ix,XOFS
    ld      iy,YOFS
    ; slight delay (10 frames = 0.2s)
    ld      b,10
    halt
    djnz    $-1
    ret

LegendTxts:
    DB      '   Green',0
    DB      '  border:',0
    DB      '  OPQA RMC',0
    DB      ' ',0
    DB      '256x192x8bpp',0
    DB      '320x256x8bpp',0
    DB      '640x256x4bpp',0
    DB      ' ',0
    DB      'L2clip NR $18',0
    DB      ' 8,239, 8,175',0
    DB      '20,135,40,207',0
    DB      0
    DB      '$71$16:',0
    DB      'NR $17:',0
    DB      0

DrawUlaPart:
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*3+15
    ld      bc,MEM_ZX_SCREEN_4000+$1000+$20*4+15
    call    OutMachineIdAndCore_defLabels
    ld      hl,LegendTxts
    ld      de,MEM_ZX_SCREEN_4000+$20*1+17
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
    bit     4,d
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*1+2
    jr      z,.OutputFullLegend     ; second send of labels (scroll regs)
    ; OPQA highlight
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*2+18,  9, P_GREEN|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*3+18,  9, P_GREEN|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*4+18,  9, A_BRIGHT|P_CYAN|BLACK
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
    ; map whole Layer2 into memory (into 0000..BFFF region)
    NEXTREG_nn MMU0_0000_NR_50, 18
    NEXTREG_nn MMU1_2000_NR_51, 19
    NEXTREG_nn MMU2_4000_NR_52, 20
    NEXTREG_nn MMU3_6000_NR_53, 21
    NEXTREG_nn MMU4_8000_NR_54, 22
    NEXTREG_nn MMU5_A000_NR_55, 23
    FILL_AREA   $0000, 256*192, $01
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
    jr      DrawL2StripesSideEdge

ClipPatternTopLeft:
    DB      4, 4, 4, 4, 5, 5, 5, 5, 4, 4, 4, 4, 5, 5, 5, 5
ClipPatternBottomRight:
    DB      6, 6, 6, 6, 7, 7, 7, 7, 6, 6, 6, 6, 7, 7, 7, 7
ClipPatternBorder32px:
    HEX     01 06 06 01 01 01 01 01  01 06 06 01 01 01 01 01
ClipPatternPaper_4bpp:
    HEX     55 54 44 44 44 45 55 55  55 54 44 44 44 45 55 55
ClipPatternBorder32px_4bpp:
    HEX     11 11 14 44 41 11 11 11  11 11 14 44 41 11 11 11

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

; A = number of 8px wide lines
DrawL2StripesFullLines:
    push    hl
    call    DrawL2StripesFullLine
    pop     hl
    dec     a
    jr      nz,DrawL2StripesFullLines
    ret

DrawL2StripesPatchBorderArea:
    ld      e,YOFS - 32
    ld      l,YOFS - 32
    ld      bc,64
    ldir
    inc     d
    inc     h
    dec     a
    jr      nz,DrawL2StripesPatchBorderArea
    ret

DrawL2StripesSideEdge_320:
    ld      e,YOFS - 32 - 16
    ld      l,YOFS - 32 - 16
    ld      bc,16 + 64 + 8
    ldir
    inc     d
    inc     h
    dec     a
    jr      nz,DrawL2StripesSideEdge_320
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

DrawLayer2Part_320x256_and_640x256:
    ; clear 10 banks (5 for each mode)
    ld      a,12*2          ; first bank of 320x256
    ex      af,af
    ld      a,$01
    call    .clear80ki      ; clear 320x256x8bpp with $01 color
    ld      a,$11
    call    .clear80ki      ; clear 640x256x4bpp with $11 pixels
    ; border + clipped paper stripes
    ld      a,12*2
    ld      hl,ClipPatternBottomRight
    call    .doClippedAreas
    ld      a,17*2
    ld      hl,ClipPatternPaper_4bpp
    call    .doClippedAreas
    ; draw X/Y axis with [0,0] origin to make the scroll coordinates "visible"
    ld      a,12*2
    ld      iyl,(12+5)*2
    call    .doAxes         ; do axes for 320x256x8bpp with colors 2 and 3
    ld      a,$22
    ld      (.light_blue_one_dot),a
    ld      a,$31
    ld      (.blackish_one_dot),a
    ld      a,17*2
    ld      iyl,(17+5)*2
    call    .doAxes         ; do axes for 640x256x4bpp with colors $22 and $33 (double-pixels)
    ; draw scroll lines matching the ULA lines (at target scroll coordinates [XOFS, YOFS]
    ld      a,12*2
    call    .doScrollLinesMatchingUla
    ld      a,$21
    ld      (.light_blue_twenty),a
    ld      a,$31
    ld      (.blackish_one_twenty),a
    ld      a,17*2
    call    .doScrollLinesMatchingUla
    ret

.doScrollLinesMatchingUla:
    ; draw vertical dotted light blue lines just around the ULA lines
    push    af
    add     a,(32+40+XOFS-1) / 64 * 2
    NEXTREG_A MMU0_0000_NR_50
    inc     a
    NEXTREG_A MMU1_2000_NR_51
    ld      hl,($3F&(32+40+XOFS-1))*256 + ($FF&(32+40+YOFS))  ; 1 pixel left of ULA pixel
    ld      bc,(.light_blue_twenty)     ; B = 20 pixels counter, C = ligh blue colour
    ld      de,$0002        ; +2 down, +0 sideways (between line pixels)
    ld      ix,$0800        ; +0 up, +8 right between whole lines
    ld      a,5
    call    DoLinesLoop
    ; [+1, +2] the second set of lines
    inc     h
    inc     h
    inc     l
    call    DoLinesLoop
    ; draw horizontal dotted light blue lines around the horizontal ULA lines
    pop     af
    push    af
    add     a,(32+176+XOFS) % 320 / 64 * 2
    NEXTREG_A MMU0_0000_NR_50
    inc     a
    NEXTREG_A MMU1_2000_NR_51
    ld      hl,($3F&((32+176+XOFS) % 320))*256 + ($FF&(32+112+YOFS-1))    ; 1 pixel up of ULA pixel
    ld      de,$0200        ; +0 vertically, +2 right (between line pixels)
    ld      ix,$0008        ; +8 down, +0 right between whole lines
    ld      a,5
    call    DoLinesLoop     ; BC and A remain identical
    ; [+2, +1] the second set of lines
    inc     l
    inc     l
    inc     h
    call    DoLinesLoop
    ; draw vertical almost-black part of lines (connecting to ULA lines)
    pop     af
    push    af
    add     a,(32+40+XOFS) / 64 * 2
    NEXTREG_A MMU0_0000_NR_50
    inc     a
    NEXTREG_A MMU1_2000_NR_51
    ld      hl,($3F&(32+40+XOFS))*256 + ($FF&(32+41+YOFS))  ; start 2px over ULA line (overdraw)
    ld      bc,(.blackish_one_twenty)   ; B = 20 pixels counter, C = blue-ish black colour
    ld      de,$00FF        ; -1 up, +0 sideways
    ld      ix,$08FF        ; -1 up, +8 right between lines
    ld      a,5             ; 5 lines loop
    call    DoLinesLoop
    ld      e,$01           ; +1 down
    ld      l,32+78+YOFS    ; start 2px over ULA line (overdraw)
    ld      ixl,$01         ; +1 down
    call    DoLinesLoop
    ; draw horizontal almost-black part of lines (connecting to ULA lines)
    pop     af
    add     a,(32+177+XOFS) % 320 / 64 * 2 - 1
    NEXTREG_A MMU0_0000_NR_50
    inc     a
    NEXTREG_A MMU1_2000_NR_51
    inc     a
    NEXTREG_A MMU2_4000_NR_52
    inc     a
    NEXTREG_A MMU3_6000_NR_53
    ld      hl,$2000 + ($3F&(32+177+XOFS))*256 + ($FF&(32+112+YOFS))  ; start 2px over ULA line (overdraw)
    ld      de,$FF00        ; +0 up, -1 left
    ld      ix,$FF08        ; +8 down, -1 left between lines
    ld      a,5
    call    DoLinesLoop     ; use same BC and A as above
    ld      d,$01           ; +1 right
    ld      h,$20 + ($3F&(32+176+XOFS+38))  ; start 2px over ULA line (overdraw)
    ld      ixh,$01         ; +8 down, +1 right between lines
    jp      DoLinesLoop

.doAxes:
    ; draw X/Y axis with [0,0] origin to make the scroll coordinates "visible"
    NEXTREG_A MMU0_0000_NR_50
    ex      af,af
    ld      hl,$0100        ; starting coordinates (address)
    ld      ix,$0020        ; IX = vector between lines, DE = line vector (not important for 1px line)
    ld      bc,(.blackish_one_dot)  ; B = line length, C = color
    ld      a,8             ; number of lines
    call    DoLinesLoop     ; 32px black dots vertical [1,0], [1,32], ...
    ld      ixl,$08
    ld      a,32
    dec     h
    ld      bc,(.light_blue_one_dot)
    call    DoLinesLoop     ; 8px lightblue dots vertical [0,0], [0,8], ...
    ex      af,af
.h_axis_loop:
    NEXTREG_A MMU0_0000_NR_50
    ex      af,af
    ld      ix,$0800
    ld      a,4
    ld      bc,(.light_blue_one_dot)
    call    DoLinesLoop     ; 4x 8px lightblue dots horizontal [0,0], [8,0], ...
    ld      ixh,$20
    inc     l
    ld      a,1
    ld      bc,(.blackish_one_dot)
    call    DoLinesLoop     ; 1x 32px black dots horizontal [0, 1], ... ([32,1], [64,1],.. in other banks)
    dec     l
    ex      af,af
    inc     a
    cp      iyl
    jr      c,.h_axis_loop
    ret

.doClippedAreas:
    add     a,(XOFS-32-16) / 32
    NEXTREG_A MMU0_0000_NR_50
    inc     a
    NEXTREG_A MMU1_2000_NR_51
    inc     a
    NEXTREG_A MMU2_4000_NR_52
    inc     a
    NEXTREG_A MMU3_6000_NR_53   ; map 128px span (to cover (16+32 + 32+8 in worst case starting at +31)
    inc     a
    NEXTREG_A MMU4_8000_NR_54
    inc     a
    NEXTREG_A MMU5_A000_NR_55   ; extra 64px to fill bottom/top edges as far as possible
    push    af
    ld      de,((XOFS-32-16) % 32) << 8
    ld      a,2
    call    DrawL2StripesFullLines          ; 16px paper stripes
    ld      bc,16
    add     hl,bc
    ld      a,8
    call    DrawL2StripesFullLines          ; 64px border stripes
    ld      bc,-16
    add     hl,bc
    call    DrawL2StripesFullLine           ; 8px border stripes
    ld      hl,((XOFS-32-16-1) % 32) << 8   ; clear 320th column as 320x256 visual clue
    ld      a,(hl)                          ; A = transparent pixel for 256th row clear
    ld      de,((XOFS-32-16-1) % 32 + 48) << 8
    ld      bc,256
    ldir
    ld      hl,(((XOFS-32-16) % 32) << 8) | (YOFS-1)  ; clear last scrolled row as 320x256 visual clue
    ld      b,16+64+8
.clearBorderRowLoop:
    ld      (hl),a
    inc     h
    djnz    .clearBorderRowLoop
    ; override paper-columns with border-effects in top/bottom area
    ld      d,(XOFS-32-16) % 32
    ld      h,(XOFS-32-16) % 32 + 16
    ld      a,16
    call    DrawL2StripesPatchBorderArea
    ld      d,(XOFS-32-16) % 32 + 16 + 64
    ld      h,(XOFS-32-16) % 32 + 16
    ld      a,8
    call    DrawL2StripesPatchBorderArea
    ; copy upper/bottom part into inner paper columns
    ld      h,(XOFS-32-16) % 32 + 16 + 64
    ld      d,(XOFS-32-16) % 32 + 16 + 64 + 8
    ld      a,20+64
    call    DrawL2StripesSideEdge_320
    pop     af
    NEXTREG_A MMU0_0000_NR_50               ; last 8ki page is already done, use it as source data
    sub     9
    NEXTREG_A MMU1_2000_NR_51
    inc     a
    NEXTREG_A MMU2_4000_NR_52
    inc     a
    NEXTREG_A MMU3_6000_NR_53
    inc     a
    NEXTREG_A MMU4_8000_NR_54
    inc     a
    NEXTREG_A MMU5_A000_NR_55               ; map remaining span
    ld      h,0
    ld      d,32
    ld      a,256-8-16-20-64                ; wraps also into first 8ki page mapped extra to $A000
    jp      DrawL2StripesSideEdge_320

.clear80ki:
    ld      b,10                ; 10 pages => 80ki
.clear80ki_page_loop:
    ex      af,af
    NEXTREG_A MMU0_0000_NR_50   ; map next 8ki page
    inc     a
    ex      af,af
    push    bc
    ld      hl,0
    ld      bc,$2000
    call    FillArea
    pop     bc
    djnz    .clear80ki_page_loop
    ret

.light_blue_one_dot:
    DB      2, 1                ; lightblue, 1 pixels
.blackish_one_dot:
    DB      3, 1                ; blueish black, 1 pixels
.light_blue_twenty:
    DB      2, 20               ; lightblue, 20 pixels
.blackish_one_twenty:
    DB      3, 20               ; blueish black, 20 pixels

    ALIGN   256
IVT2        equ     high $
Im2Handler  equ     ((IVT2+1)<<8) + IVT2+1
    BLOCK   257,IVT2+1

    ORG Im2Handler
    ei
    ret

    savesna "L2Scroll.sna", Start
