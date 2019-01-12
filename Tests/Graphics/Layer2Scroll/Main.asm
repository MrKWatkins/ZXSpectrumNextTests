    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

    INCLUDE "..\..\Constants.asm"
    INCLUDE "..\..\Macros.asm"
    INCLUDE "..\..\TestFunctions.asm"
    INCLUDE "..\..\OutputFunctions.asm"

    ; ULA white $B601 (%101 per channel)

    MACRO FILL_AREA adr, size, value
        ld      hl,adr
        ld      de,adr+1
        ld      bc,size-1
        ld      (hl),value
        ldir
    ENDM

XOFS        equ     196
YOFS        equ     5+64+64     ; if writing emulator, try all: 5+0, 5+64, 5+64+64

Start:
    call    StartTest
    ; show red border while drawing and preparing...
    ld      a,RED
    out     (ULA_P_FE),a
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
    ; setup global transparency features
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14, $FC       ; global transparency colour
    ; setup Layer2 bank to 9 (like NextZXOS does)
    NEXTREG_nn LAYER2_RAM_PAGE_NR_12, 9
    ; clear+draw ULA screen0
    FILL_AREA   MEM_ZX_SCREEN_4000, 32*192, 0
    FILL_AREA   MEM_ZX_ATTRIB_5800, 32*24, P_WHITE|BLUE
    call    DrawUlaPart
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
    ; and finally set the Layer2 scroll registers
    NEXTREG_nn LAYER2_XOFFSET_NR_16, XOFS           ; X offset 201
    NEXTREG_nn LAYER2_YOFFSET_NR_17, YOFS           ; Y offset 45
    ; and finish test (blue border)
    ld      a,BLUE
    out     (ULA_P_FE),a
    call EndTest

DrawUlaPart:
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
    ld      hl,((40+YOFS) MOD 192)*256 + (40+XOFS-1)  ; 1 pixel left of ULA pixel
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
    ld      hl,((41+YOFS) MOD 192)*256 + (40+XOFS)  ; start 2px over ULA line (overdraw)
    ld      bc,(20<<8) + 3  ; B = 20 pixels counter, C = blue-ish black colour
    ld      de,$FF00        ; -1 up, +0 sideways
    ld      ix,$FF08        ; -1 up, +8 right between lines
    ld      a,5             ; 5 lines loop
    call    DoLinesLoop
    ld      d,$01           ; +1 down
    ld      h,(78+YOFS)     ; start 2px over ULA line (overdraw)
    ld      ix,$0108        ; +1 down, +8 right between lines
    call    DoLinesLoop
    ; draw horizontal almost-black part of lines (connecting to ULA lines)
    ld      hl,((112+YOFS) MOD 192)*256 + (255&(177+XOFS))  ; start 2px over ULA line (overdraw)
    ld      de,$00FF        ; +0 up, -1 left
    ld      ix,$08FF        ; +8 down, -1 left between lines
    call    DoLinesLoop     ; use same BC and A as above
    ld      e,$01           ; +1 right
    ld      l,0xFF&(38+176+XOFS)     ; start 2px over ULA line (overdraw)
    ld      ix,$0801        ; +8 down, +1 right between lines
    call    DoLinesLoop
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

    savesna "L2Scroll.sna", Start
