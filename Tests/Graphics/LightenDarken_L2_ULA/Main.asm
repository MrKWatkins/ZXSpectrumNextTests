; this is based on "LayersMixingLoRes" test, but focusing on the colour mixing in the two
; new layer-priority modes: U+L and U+L-5 (introduced somewhere in 2.00.xx cores).

    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

    INCLUDE "..\..\Constants.asm"
    INCLUDE "..\..\Macros.asm"
    INCLUDE "..\..\TestFunctions.asm"
    INCLUDE "..\..\TestData.asm"
    INCLUDE "..\..\OutputFunctions.asm"

C_BLACK     equ     %00000000       ; 0
C_WHITE     equ     %10110110       ; 1
C_B_WHITE   equ     %11111111       ; 2
C_T_WHITE   equ     %01101101       ; 3
C_TEXT      equ     %11110011       ; 4
C_D_TEXT    equ     %01100101       ; 5
C_PINK      equ     %11101011       ; 6
C_PINK2     equ     %11101011       ; 7     ; for layer2 with priority
C_SPRITE    equ     %11100011-1*%01000001       ; 8     ; for expected result drawing
C_LAYER2    equ     %10110100       ; 9     ; the "mixed" areas will be displayed
C_LAYER2P   equ     %11111100       ; 10    ; as 1x1 dither (C_LAYER2 + C_ULA)
C_ULA       equ     %00011111       ; 11
; 12 .. 15 will be used for Layer2 intensities
; 16 .. 19 will be used for Layer2 intensities with priority
; 20 .. 23 will be used for ULA intensities

    align   32
; colour definitions
colourDef:
CI_BLACK    equ     $-colourDef
    db      C_BLACK
CI_WHITE    equ     $-colourDef
    db      C_WHITE
CI_B_WHITE  equ     $-colourDef
    db      C_B_WHITE
CI_T_WHITE  equ     $-colourDef
    db      C_T_WHITE
CI_TEXT     equ     $-colourDef
    db      C_TEXT
CI_D_TEXT   equ     $-colourDef
    db      C_D_TEXT
CI_PINK     equ     $-colourDef
    db      C_PINK
CI_PINK2    equ     $-colourDef
    db      C_PINK2
CI_SPRITE   equ     $-colourDef
    db      C_SPRITE
CI_LAYER2   equ     $-colourDef
    db      C_LAYER2
CI_LAYER2P  equ     $-colourDef
    db      C_LAYER2P
CI_ULA      equ     $-colourDef
    db      C_ULA
CI_L2_0     equ     $-colourDef
    db      0, 0, 0, 0          ; these will be set dynamically
CI_L2P_0    equ     $-colourDef
    db      0, 0, 0, 0          ; these will be set dynamically
CI_ULA_0    equ     $-colourDef
    db      0, 0, 0, 0          ; these will be set dynamically
COLOUR_DEF_SZ   equ     $-colourDef

    align   4
selectedBaseColours:
selectedBaseColourSprite:
    db      %00011101   ; starting at %101 (R+B) = magenta
selectedBaseColourLayer2:
    db      %10001110   ; starting at %110 (R+G) = yellow
selectedBaseColourUla:
    db      %10100011   ; starting at %011 (G+B) = cyan
selectedBaseColourLayer2P:
    db      %11101000   ; starting at %000 - this is XOR with Layer2 base (000 = same col)

KEY_DEBOUNCE_DELAY  equ 4
    align   4
debounceKeys:           ; counters to debounce key presses
    db      8, 8, 8, 8

    align   16
colourGenInit:
    db      %00000000   ; base %000
    db      %00000011   ; base %001
    db      %00011100   ; base %010
    db      %00011111   ; base %011
    db      %11100000   ; base %100
    db      %11100011   ; base %101
    db      %11111100   ; base %110
    db      %11111111   ; base %111
colourGenDelta:         ; will be subtracted from base
    db      %00000000   ; base %000
    db      %00000001   ; base %001
    db      %00001000   ; base %010
    db      %00001001   ; base %011
    db      %01000000   ; base %100
    db      %01000001   ; base %101
    db      %01001000   ; base %110
    db      %01001001   ; base %111

    MACRO   IDLE_WAIT loop_count
        ld      bc,loop_count
        call    WaitSomeIdleTime
    ENDM

Start:
    call    StartTest

    ; Set first-ULA palette, enable ULANext, enable auto-inc    (ULA pal. is LoRes pal.!)
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00000001
    NEXTREG_nn PALETTE_INDEX_NR_40, 0       ; index 0   (full-ink will apply for LoRes)
    call    SetTestPalette
    NEXTREG_nn PALETTE_INDEX_NR_40, 128     ; index 128 (for border)
    call    SetTestPalette
    NEXTREG_nn PALETTE_FORMAT_NR_42, $03    ; ULANext INK mask to insensible 3
        ; INK mask should NOT affect LoRes, LoRes should work as full-ink 255 config.
    ; Set first-Sprite palette, enable ULANext, enable auto-inc
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00100001
    NEXTREG_nn PALETTE_INDEX_NR_40, 0       ; index 0
    call    SetTestPalette
    ; Set first-Layer2 palette, enable ULANext, enable auto-inc
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00010001
    NEXTREG_nn PALETTE_INDEX_NR_40, 0       ; index 0
    call    SetTestPalette                  ; this did set only 8 bit colours
    ; modify the Layer2 transparency exercising the "priority" bit
    NEXTREG_nn PALETTE_INDEX_NR_40, CI_PINK2
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, C_PINK2
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $81    ; set priority bit, Blue=1

    ; setup transparency features - make pink transparent and visible as fallback
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14, C_PINK
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A, C_PINK
    NEXTREG_nn SPRITE_TRANSPARENCY_I_NR_4B, CI_PINK     ; sprite transparency needs index

    ; show text-pink border while drawing and preparing...
    ld      a,CI_TEXT
    out     (ULA_P_FE),a

    ; reset LoRes scroll registers
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; draw the LoRes part for pixel combining
    call    DrawLoResPart

    ; reset Layer2 scroll registers
    NEXTREG_nn LAYER2_XOFFSET_NR_16, 0
    NEXTREG_nn LAYER2_YOFFSET_NR_17, 0
    ; setup Layer2 bank to 9 (like NextZXOS does)
    NEXTREG_nn LAYER2_RAM_PAGE_NR_12, 9
    ; make Layer2 visible
    ld      bc, LAYER2_ACCESS_P_123B
    ld      a, LAYER2_ACCESS_L2_ENABLED
    out     (c), a
    ; map last third of Layer2 into memory (into 8000..BFFF region)
    NEXTREG_nn MMU4_8000_NR_54, 22      ; $04
    NEXTREG_nn MMU5_A000_NR_55, 23      ; $05

    ; intermezzo - prepare sprite graphics + upload them, in the last third of L2 area
    call    PrepareSpriteGraphics

    ; map whole Layer2 into memory (into 0000..BFFF region) (commented are default values)
    NEXTREG_nn MMU0_0000_NR_50, 18      ; $FF
    NEXTREG_nn MMU1_2000_NR_51, 19      ; $FF
    NEXTREG_nn MMU2_4000_NR_52, 20      ; $0A
    NEXTREG_nn MMU3_6000_NR_53, 21      ; $0B

    ; Draw Layer2: clear Layer2 with transparent colour + draw test info
    call    DrawLayer2Part

    ; map full ROM back to make ROM characters graphics available
    NEXTREG_nn MMU0_0000_NR_50, $FF
    NEXTREG_nn MMU1_2000_NR_51, $FF

    ; use Layer2-over-ROM feature to write into Layer2 for 0000..3FFF region
    ld      a,LAYER2_ACCESS_WRITE_OVER_ROM+LAYER2_ACCESS_L2_ENABLED+LAYER2_ACCESS_OVER_ROM_BANK_0
                ; enable layer2, write-over-ROM, and select bank 0 for write
    ld      bc,LAYER2_ACCESS_P_123B
    out     (c),a   ; this effectively creates L2-full-RAM mode in 0000..BFFF for WRITE

    call    DrawCharLabels

    ; map low RAM back to make im1 work (updates counters in $5B00+ area)
    NEXTREG_nn MMU2_4000_NR_52, $0A
    NEXTREG_nn MMU3_6000_NR_53, $0B
    ; all drawing is now finished, the test will enter loop just changing layer-modes

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; loop infinitely and set correct layer ordering for particular part of screen
    ; also read keyboard and modify base colours as requested

    ; the TEST areas are at x:56 coordinate

    ; The scanline does change at pixel x:0, i.e. after that there are instructions:
    ; IN 12T, JR cc 7T, RET 10T, NEXTREG_nn 20T
    ; => cca 49+T until the layer order is modified

ScanlinesLoop:
    ei
    halt
    ld      a,CI_WHITE
    out     (ULA_P_FE),a
    ;; SLU "legend" phase (first 52 scanlines)
    ; Set layers to: SLU, enable sprites (no over border), LoRes ON
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10000001
    ; read keyboard and adjust base colours based on the user actions
    call    KeyboardHandler
    ; refresh all dynamic colours every frame
    call    DynamicColoursHandler

    ; wait some fixed time after IM1 handler to get into scanlines 255+
    IDLE_WAIT   $E001
    ; wait until scanline MSB becomes 0 again (scanline 0)
    ld      l,0
    call    WaitForScanlineMSB
    ; wait until scanline 52
    ld      l,54
    call    WaitForScanline
    ;; L+U phase (scanlines 54..89) - grey border
    ld      a,CI_T_WHITE
    out     (ULA_P_FE),a
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10011001
    ld      l,90
    call    WaitForScanline
    ; interphase displaying white border for scanlines 90..93
    ld      a,CI_WHITE
    out     (ULA_P_FE),a
    ld      l,94
    call    WaitForScanline
    ;; L+U-5 phase (scanlines 94..129) - grey border
    ld      a,CI_T_WHITE
    out     (ULA_P_FE),a
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10011101
    ld      l,130
    call    WaitForScanline
    ; restore SLU standard mode and white border for remaining scanlines 130..
    ld      a,CI_WHITE
    out     (ULA_P_FE),a
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10000001
    jr      ScanlinesLoop

    ;call    EndTest

;;;;;;;;;;;;;;;;;;;; read keyboard, adjust colours by keys ;;;;;;;;;;;;;;;;;;;;;

KeyboardHandler:
    ld      hl,debounceKeys
    ld      de,selectedBaseColours
    ld      b,4             ; only A,S,D,F are tested
    ld      a,$FD
    in      a,(ULA_P_FE)
.ReadKeyLoop:
    rra
    dec     (hl)            ; and check debounce delay (DEC doesn't modify CF)
    jr      c,.KeyReleased
    ; key pressed - check debounce delay first
    ld      (hl),KEY_DEBOUNCE_DELAY ; pressed key resets debounce delay in any case
    jr      nz,.NextKey     ; not debounced yet = ignore the key
    ; modify particular base colour selector
    ex      de,hl
    rrc     (hl)
    ex      de,hl
    jr      .NextKey
.KeyReleased:               ; released key -> just countdown debounce counter
    jr      nz,.NextKey
    ld      (hl),1          ; fully debounced (keep it reaching ZF next time)
.NextKey:
    inc     hl
    inc     de
    djnz    .ReadKeyLoop
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Set palette (currently selected one) ;;;;;;;;;;;;;;;;;;;

SetTestPalette:
    ld      hl,colourDef
    ld      b,COLOUR_DEF_SZ
.SetPaletteColours:
    ld      a,(hl)
    NEXTREG_A PALETTE_VALUE_NR_41
    inc     hl
    djnz    .SetPaletteColours
    ret

; does set up way too many redundant items in palettes, but maybe at least the code
; is simpler? ... hopefully - does set up all important test colours by selector values
DynamicColoursHandler:
    ld      e,0             ; L2 priority
    ; set up Sprite colour
    ld      a,(selectedBaseColourSprite)
    call    .GetBaseColour
    ld      b,CI_SPRITE
    call    .SetSingleColourInAllPalettes
    ; set up ULA LoRes colour (with gradient)
    ld      a,(selectedBaseColourUla)
    call    .GetBaseColour
    ld      b,CI_ULA
    call    .SetSingleColourInAllPalettes
    ld      b,CI_ULA_0
    call    .SetFourColoursInAllPalettes
    ; set up Layer2 no-priority colour (with gradient and extra quirk)
    ld      a,(selectedBaseColourLayer2)
    push    af                      ; also keep it for priority-selector on stack
    call    .GetBaseColour
    push    bc
    ld      b,CI_L2_0
    call    .SetFourColoursInAllPalettes
    pop     bc
    ; adjust the main colour by one delta notch, to depict "no priority" colour
    ld      a,c
    sub     (hl)
    ld      c,a
    ld      b,CI_LAYER2
    call    .SetSingleColourInAllPalettes
    ; set up Layer2 with priority
    ld      e,$80                   ; Layer2 priority bit set
    pop     bc                      ; B = non-priority selector
    ld      a,(selectedBaseColourLayer2P)
    xor     b                       ; mix selector together to get final
    call    .GetBaseColour
    ld      b,CI_LAYER2P
    call    .SetSingleColourInAllPalettes
    ld      b,CI_L2P_0
    call    .SetFourColoursInAllPalettes
    ret

; A = base colour selector (bottom 3 bits = current selection)
.GetBaseColour:
    and     %111            ; bottom 3 bits selects colour
    ld      hl,colourGenInit
    add     a,l             ; should not overflow due to aligns
    ld      l,a
    ld      c,(hl)          ; colour
    ld      a,8             ; advance HL to colourGenDelta table
    add     a,l
    ld      l,a
    ret

; B = colour index, C = colour, E = layer2 priority bit, (HL) colour delta
.SetFourColoursInAllPalettes:
    ld      d,4
.FourColourLoop:
    call    .SetSingleColourInAllPalettes
    inc     b               ; adjust colour index
    ld      a,c             ; adjust colour itself (by -delta)
    sub     (hl)
    ld      c,a
    dec     d
    jr      nz,.FourColourLoop
    ret

; B = colour index, C = colour, E = layer2 priority bit
.SetSingleColourInAllPalettes:
    ; ULA-LoRes palette
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00000001
    ld      a,b
    NEXTREG_A   PALETTE_INDEX_NR_40
    ld      a,c
    NEXTREG_A   PALETTE_VALUE_NR_41
    ; sprite palette
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00100001
    ld      a,b
    NEXTREG_A   PALETTE_INDEX_NR_40
    ld      a,c
    NEXTREG_A   PALETTE_VALUE_NR_41
    ; Layer2 palette
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00010001
    ld      a,b
    NEXTREG_A   PALETTE_INDEX_NR_40
    ; set 9 bit colour, including priority
    ld      a,c
    NEXTREG_A   PALETTE_VALUE_9BIT_NR_44
    ; calculate 9th blue bit (blue.b0 = blue.b2|blue.b1)
    rra         ; a.b0 = blue.b2
    or      c   ; a.b0 |= blue.b1
    and     1
    or      e   ; keep only blue bit and add priority
    NEXTREG_A   PALETTE_VALUE_9BIT_NR_44
    ret

;;;;;;;;;;;;;;;;;;;; Draw ULA (LoRes) part ;;;;;;;;;;;;;;;;;;;

DrawLoResPart:
    ; set all pixels to white
    FILL_AREA   MEM_LORES0_4000, 128*48, CI_WHITE
    FILL_AREA   MEM_LORES1_6000, 128*48, CI_WHITE

    ; make ULA transparent under "legend" boxes
    ld      hl,MEM_LORES0_4000 + 128 - 1*7*4
    call    .Draw4x6TransparentBoxes
    ld      hl,MEM_LORES0_4000 + 128 - 2*7*4
    call    .Draw4x6TransparentBoxes
    ld      hl,MEM_LORES0_4000 + 128 - 3*7*4
    call    .Draw4x6TransparentBoxes
    ; make ULA transparent under legend-label area
    ld      hl,MEM_LORES0_4000 + 7*4*128 + 0
    ld      bc,$1418
    call    .DrawNxMTransparentBoxes
    ld      hl,MEM_LORES1_6000 + 0
    call    .Draw4x6TransparentBoxes
    ; set attributes of "result" 6x4 boxes
    ld      hl,MEM_LORES0_4000 + 7*4*128 + 7*4
    call    .Draw4x6TestData
    ld      hl,MEM_LORES1_6000 + 0*4*128 + 7*4
    call    .Draw4x6TestData
    ret

.Draw4x6TransparentBoxes:   ; 4x6 chars = 16x24 LoRes pixels
    ld      bc,$1018
.DrawNxMTransparentBoxes:
    ld      a,CI_PINK
; HL = target address, BC = rows/columns, A = attribute
.DrawNxM_SolidLoResBox:
    push    de
    push    bc
    push    hl
    ld      b,0
    call    FillArea
    pop     hl
    ld      de,128
    add     hl,de
    pop     bc
    pop     de
    djnz    .DrawNxM_SolidLoResBox
    ret

.Draw4x6TestData:
    push    hl
    push    hl
    call    .Draw4x6TransparentBoxes
    pop     hl
    ld      bc,2*4*128
    add     hl,bc
    call    .Draw4x6TestDataOneRow
    pop     hl
.Draw4x6TestDataOneRow:
    ld      b,6
.Draw4x6TestDataOneRowLoop:
    call    .DrawLoRes4x4TestGradient
    djnz    .Draw4x6TestDataOneRowLoop
    ret

.DrawLoRes4x4TestGradient:
    push    bc
    push    de
    push    hl
    ld      b,4
    ld      de,128-3
.Draw4DotTestGradientLoop:
    ld      (hl),CI_ULA_0+0
    inc     l
    ld      (hl),CI_ULA_0+1
    inc     l
    ld      (hl),CI_ULA_0+2
    inc     l
    ld      (hl),CI_ULA_0+3
    add     hl,de
    djnz    .Draw4DotTestGradientLoop
    pop     hl
    ld      e,4
    add     hl,de
    pop     de
    pop     bc
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Draw Layer2 part ;;;;;;;;;;;;;;;;;;;

DrawLayer2Part:
    ; clear Layer 2 with transparent colour
    FILL_AREA   $0000, 256*192, CI_PINK

    ; draw "legend" boxes, draw expected result areas and also the test-areas themselves

    ; fill background under "label/expected" areas (all 2 of them in one fill)
    ld      a,8
    ld      de,CI_WHITE*256 + CI_WHITE
    ld      bc,$0609
    ld      hl,7*8*256 + 0
    call    FillL2Box

    ; draw expected result area for orders: L+U, L+U-5
    ld      hl,9*8*256 + 12
    ; L+U
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultLayer2p
    ; L+U-5
    ld      h,14*8
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultLayer2p

    ; draw white background under all control keys
    ld      a,1
    ld      bc,$0909
    ld      de,CI_B_WHITE*256 + CI_B_WHITE
    ld      hl,36*256 + 256 - 8*(3*7-1)
    call    FillL2Box
    ld      hl,36*256 + 256 - 8*(2*7-1) - 5
    call    FillL2Box
    ld      hl,36*256 + 256 - 8*(2*7-5) - 4
    call    FillL2Box
    ld      hl,36*256 + 256 - 8*(1*7-1)
    call    FillL2Box
    ; draw the sprite/L2/ula colour boxes next to control keys
    ld      de,CI_SPRITE*256 + CI_SPRITE
    ld      hl,36*256 + 256 - 8*(3*7-2) + 4
    call    FillL2Box
    ld      de,CI_L2_0*256 + CI_L2_0
    ld      hl,36*256 + 256 - 8*(2*7-2) - 1
    call    FillL2Box
    ld      de,CI_L2P_0*256 + CI_L2P_0
    ld      hl,36*256 + 256 - 8*(2*7-3)
    call    FillL2Box
    ld      de,CI_ULA*256 + CI_ULA
    ld      hl,36*256 + 256 - 8*(1*7-2) + 4
    call    FillL2Box

    ; draw Sprite-legend
    ld      a,1
    ld      hl,256 - 8*(3*7)
    ld      de,CI_BLACK*256 + CI_WHITE
    ld      bc,$0820
    call    FillL2Box
    ld      hl,256 - 8*(3*7-5)
    call    FillL2Box
    ld      de,CI_SPRITE*256 + CI_SPRITE
    ld      hl,256 - 8*(3*7-1)
    call    FillL2Box
    ld      hl,256 - 8*(3*7-3)
    call    FillL2Box
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      bc,$0410
    ld      hl,256 - 8*(3*7-2)
    call    FillL2BoxWithDither2x2
    ld      hl,256 - 8*(3*7-4)
    call    FillL2BoxWithDither2x2
    ; draw the dithered 16x16 boxes to reveal full sprite size
    ld      de,SPR_DITHER_BOX_GFX
    ld      hl,256 - 8*(3*7-1)
    call    DrawDitherGfxInside16x16Box
    ld      hl,256 - 8*(3*7-3)
    call    DrawDitherGfxInside16x16Box
    ld      hl,17*256 - 8*(3*7-1)
    call    DrawDitherGfxInside16x16Box
    ld      hl,17*256 - 8*(3*7-3)
    call    DrawDitherGfxInside16x16Box

    ; draw Layer2-legend
    ld      bc,$0C08
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      hl,2*8*256 + 256 - 8*(2*7)
    call    FillL2BoxWithDither2x2      ; transparent part
    ld      de,CI_B_WHITE*256 + CI_WHITE
    ld      hl,2*8*256 + 256 - 8*(2*7-3)
    call    FillL2BoxWithDither2x2      ; transparent-priority part
    ; layer2 ink legend - keep one dither color fixed to CI_LAYER2P
    ld      hl,256 - 8*(2*7)
    ld      de,CI_L2P_0*256 + CI_LAYER2P
    ld      ix,$0100
    call    FillL2LegendData

    ; draw also Layer2 TEST pixels (L+U)
    ld      hl,7*8*256 + 8*(7)
    call    FillL2TestData
    ; draw transparent priority part
    ld      de,CI_PINK2*256 + CI_PINK2  ; overwrite also transparent half with priority
    ld      bc,$0C08
    ld      hl,9*8*256 + 8*(7+3)
    call    FillL2BoxWithDither2x2

    ; draw also Layer2 TEST pixels (L+U-5)
    ld      hl,12*8*256 + 8*(7)
    call    FillL2TestData
    ; draw transparent priority part
    ld      de,CI_PINK2*256 + CI_PINK2  ; overwrite also transparent half with priority
    ld      bc,$0C08
    ld      hl,14*8*256 + 8*(7+3)
    call    FillL2BoxWithDither2x2

    ; draw ULA-legend
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      bc,$180C
    ld      hl,1*8*256 + 256 - 8*(1*7)
    call    FillL2BoxWithDither2x2
    ld      de,CI_ULA*256 + CI_ULA
    ld      bc,$1804
    ld      hl,0*8*256 + 256 - 8*(1*7)
    call    DrawL2_LoResGradient6Chars
    ld      hl,2*8*256 + 256 - 8*(1*7)
    call    DrawL2_LoResGradient6Chars

    ret

.DrawExpectedResultSprites:
    push    hl
    ld      de,CI_SPRITE*256 + CI_SPRITE
    ld      bc,$0208
    ld      a,1*4
    add     a,l
    ld      l,a
    call    FillL2BoxWithDither2x2
    ld      a,2*4
    add     a,l
    ld      l,a
    call    FillL2BoxWithDither2x2
    pop     hl
    ret

.DrawExpectedResultUla:
    push    hl
    ld      de,CI_ULA*256 + CI_ULA
    ld      bc,$0C02
    ld      a,2*4
    add     a,h
    ld      h,a
    call    FillL2BoxWithDither2x2
    pop     hl
    jr      FillL2BoxWithDither2x2

.DrawExpectedResultTransparent:
    ld      bc,$0C08
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    jr      FillL2BoxWithDither2x2

.DrawExpectedResultLayer2:
    push    hl
    ld      a,1*4
    add     a,h
    ld      h,a
    ld      de,CI_LAYER2*256 + CI_LAYER2
    ld      bc,$0602
    call    FillL2BoxWithDither2x2
    pop     hl
    ld      a,1
    ld      bc,$0C04
    ld      de,CI_LAYER2*256 + CI_ULA
    jr      FillL2Box

.DrawExpectedResultLayer2p:
    ; Layer2 priority part
    push    hl
    ld      a,3*4
    add     a,l
    ld      l,a
    push    hl
    ld      a,1*4
    add     a,h
    ld      h,a
    ld      de,CI_LAYER2P*256 + CI_LAYER2P
    ld      bc,$0602
    call    FillL2BoxWithDither2x2
    pop     hl
    ld      a,1
    ld      bc,$0C04
    ld      de,CI_LAYER2P*256 + CI_ULA
    call    FillL2Box
    pop     hl
    ret

FillL2BoxWithDither2x2:
    ld      a,2
    ; continue with FillL2Box code
; HL: coordinates, DE = colour pattern, B = width, C = height, A = size of dither
; width and height is in dither size
FillL2Box:
    push    ix
    push    de
    push    hl
    push    bc
.RowsFill:
    ld      ixl,a
.RowsDitherFill:
    push    hl
    push    de
    push    bc
.PixelsFill:        ; write two pixels of desired pixel pattern
    push    af
.DitherAFill:
    ld      (hl),d
    inc     l
    dec     a
    jr      nz,.DitherAFill
    ld      a,d     ; swap pattern to create dither
    ld      d,e
    ld      e,a
    pop     af
    djnz    .PixelsFill
    pop     bc      ; restore HL+DE+BC
    pop     de
    pop     hl
    inc     h       ; next row
    dec     ixl
    jr      nz,.RowsDitherFill
    ld      ixl,d   ; swap pattern to create dither
    ld      d,e
    ld      e,ixl
    dec     c
    jr      nz,.RowsFill
    pop     bc
    pop     hl
    pop     de
    pop     ix
    ret

FillL2TestData:
    ld      de,CI_L2P_0*256 + CI_L2P_0
    ld      ix,$0101            ; for real test data just advance both colours (no dither)
FillL2LegendData:
    push    hl                  ; do the "priority side first
    ld      bc,3*8              ; move HL 3 chars right
    add     hl,bc
    call    .FillTwoFourDoubleLines
    pop     hl
    ld      de,CI_L2_0*256 + CI_L2_0
    ld      ix,$0101            ; move both dither colours by +1 each double-line
    ; continue with .FillTwoFourDoubleLines
.FillTwoFourDoubleLines:
    ld      bc,$1802            ; 3 chars width, 2 pixel height "line"
    push    de
    call    .FillFourDoubleLines    ; do four of them, then restore the colours
    pop     de
    ; and do another four of them
.FillFourDoubleLines:
    call    .FillTwoDoubleLines ; do two and continue with two more (= four)
.FillTwoDoubleLines:
    call    .FillOneDoubleLine  ; do one and continue with one more (= two)
.FillOneDoubleLine:
    ld      a,1
    call    FillL2Box
    push    ix                  ; add ix to de (reason for the push/pop around)
    add     ix,de
    push    ix                  ; 3B ld de,ix
    pop     de
    pop     ix                  ; restore ix
    inc     h                   ; move 2px down
    inc     h
    ret

DrawL2_LoResGradient6Chars:
    push    bc
    ld      b,6
.DrawTestGradientLoop:
    call    DrawL2_LoResGradient
    djnz    .DrawTestGradientLoop
    pop     bc
    ret

DrawL2_LoResGradient:   ; draws 8x8 "char" resembling 4x4 test gradient used by LoRes
    push    bc
    push    de
    push    hl
    ld      b,8
    ld      de,256-7
.DrawTestGradientLoop:
    ld      (hl),CI_ULA_0+0
    inc     l
    ld      (hl),CI_ULA_0+0
    inc     l
    ld      (hl),CI_ULA_0+1
    inc     l
    ld      (hl),CI_ULA_0+1
    inc     l
    ld      (hl),CI_ULA_0+2
    inc     l
    ld      (hl),CI_ULA_0+2
    inc     l
    ld      (hl),CI_ULA_0+3
    inc     l
    ld      (hl),CI_ULA_0+3
    add     hl,de
    djnz    .DrawTestGradientLoop
    pop     hl
    ld      e,8
    add     hl,de
    pop     de
    pop     bc
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Setup Sprites part ;;;;;;;;;;;;;;;;;;;

SPR_DITHER_BOX_GFX  equ     $0300 + CI_BLACK

PrepareSpriteGraphics:
    ; draw transparent sprite colour (8x16px)
    ld      a,1
    ld      bc,$0408
    ld      hl,$8008
    ld      de,CI_PINK*256 + CI_PINK
    call    FillL2BoxWithDither2x2
    ; draw the solid sprite colour (8x16px)
    ld      l,0
    ld      de,CI_SPRITE*256 + CI_SPRITE
    call    FillL2BoxWithDither2x2
    ; draw the dithered rectangle inside sprite
    ld      de,SPR_DITHER_BOX_GFX   ; HL = $8000 already
    call    DrawDitherGfxInside16x16Box

    ; upload prepared sprite pattern
    ld      bc,SPRITE_STATUS_SLOT_SELECT_P_303B
    out     (c), 0  ; Write to pattern/attribute slot 0
    ld      c,SPRITE_PATTERN_P_5B   ; port number for pattern upload
    ld      hl,$8000                ; starting xy L2 coordinates (= memory address)
    call    .UploadOnePatternFromL2

    ; set up sprites to be drawn (4 byte attribute set is enough for this test)
    ; set four sprites over test area (L+U mode)
    ld      de,$2020 + 7*8*256 + 8*(7+1)    ; [x,y]
    ld      hl,$8000                ; H: visible, 4Bset, pattern 0, L:palOfs 0, ..., X9 0
    call    .UploadOneAttribSet
    ld      d,$20 + 9*8
    call    .UploadOneAttribSet
    ld      e,$20 + 8*(7+3)
    call    .UploadOneAttribSet
    ld      d,$20 + 7*8
    call    .UploadOneAttribSet
    ; set four sprites over test area (L+U-5 mode)
    ld      d,$20 + 12*8
    call    .UploadOneAttribSet
    ld      d,$20 + 14*8
    call    .UploadOneAttribSet
    ld      e,$20 + 8*(7+1)
    call    .UploadOneAttribSet
    ld      d,$20 + 12*8
    call    .UploadOneAttribSet

    ; make sure all other sprites are not visible
    ld      h,0
    ld      b,64-2*4
.SetRemainingSpritesLoop:
    call    .UploadOneAttribSet
    djnz    .SetRemainingSpritesLoop
    ret

;E: byte1, D: byte2, L: byte3, H: byte4
.UploadOneAttribSet:
    ld      c,SPRITE_ATTRIBUTE_P_57
    out     (c),e                   ; low8b X
    out     (c),d                   ; low8b Y
    out     (c),l                   ; palette offset, mirror/rotation, X9
    out     (c),h                   ; visible, 4/5B set, pattern 0..63
    ret

.UploadOnePatternFromL2:
    ld      a,h
    add     a,16    ; ending Y coordinate
.UploadOnePatternPixels:
    push    hl
    ld      b,16
    otir
    pop     hl
    inc     h
    cp      h
    jr      nz,.UploadOnePatternPixels
    ret

;;;;;;;;;;;;;;;;; Draw letter-hints into Layer2 ;;;;;;;;;;;;;;;;;;;

DrawCharLabels:
    ; single-letter hints into the Separate-layer graphics
    ld      de,$0400 + 256 - 3*7*8 + 1*8 + 4
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$0C00 + 256 - 2*7*8 + 1*8
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$0C00 + 256 - 2*7*8 + 4*8 - 4
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'p'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$0400 + 256 - 1*7*8 + 3*8 - 4
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$1400 + 256 - 1*7*8 + 1*8 - 4
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'o'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'R'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'e'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'s'
    call    OutL2WhiteOnBlackCharAndAdvanceDE

    ; Layers order scheme above expected results

    ; S U+L
    ld      de,$3B0C
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'+'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ; S U+L-5
    ld      de,$6304
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'+'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'-'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'5'
    call    OutL2WhiteOnBlackCharAndAdvanceDE

    ; draw controls legend
    ld      de,9*4*256 + 256 - 3*7*8 + 8
    ld      a,'A'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,9*4*256 + 256 - 2*7*8 + 3
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,9*4*256 + 256 - 2*7*8 + 4 + 32
    ld      a,'F'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,9*4*256 + 256 - 1*7*8 + 8
    ld      a,'D'
    call    OutL2WhiteOnBlackCharAndAdvanceDE

    ld      de,9*4*256 + 4*8 + 4
    ld      a,'P'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'r'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'e'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'s'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'s'
    call    OutL2WhiteOnBlackCharAndAdvanceDE

    ; draw MachineID and core versions:
    ld      de,$0800 + 4
    ld      a,'m'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    NEXTREG2A MACHINE_ID_NR_00
    call    OutDecimalValueToL2
    ld      a,12
    add     a,e
    ld      e,a
    ld      a,'t'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    NEXTREG2A MACHINE_TYPE_NR_03
    and     $7F             ; omit lock timing bit to keep it reasonably decimal
    call    OutDecimalValueToL2

    ld      de,$1000 + 4
    ld      a,'c'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    NEXTREG2A NEXT_VERSION_NR_01
    push    af
    rrca
    rrca
    rrca
    rrca
    and     $0F
    call    OutDecimalValueToL2
    ld      a,'.'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    pop     af
    and     $0F
    call    OutDecimalValueToL2
    ld      a,'.'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    NEXTREG2A NEXT_VERSION_MINOR_NR_0E
    call    OutDecimalValueToL2

    ret

;A: 0..99 value, modifies B,A
OutDecimalValueToL2:
    ld      b,-1
.MidToDec:
    inc     b
    sub     10
    jr      nc,.MidToDec
    add     a,'0'+10    ; 10^0 amount to ASCII
    push    af
    ld      a,'0'
    add     a,b         ; 10^1 amount to ASCII
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    pop     af
    jr    OutL2WhiteOnBlackCharAndAdvanceDE

;;;;;;;;;;;;;;;;;;;;;;;; Helper functions ;;;;;;;;;;;;;;;;;;;

; HL: coordinates, E:colour, D:ditherMask (pixels-1)
DrawDitherGfxInside16x16Box:
    push    af
    push    hl
    push    bc
    ld      bc,$1010    ; 16x16 fixed size of this box (can't change easily because $0E)
.DitherRowLoop:
    push    hl
    push    bc
.DitherPixelLoop:
    ld      a,h
    xor     l
    and     d
    jr      nz,.DoNotDot
    ld      a,h
    xor     2   ; moves the dots toward inside (with xor0 the edge of sprite is dotted)
    inc     a   ; 0 -> 1, 0F -> 10
    and     $0E ; 0 -> H=x0/xF
    jr      z,.DoDot
    ld      a,l
    xor     2
    inc     a   ; 0 -> 1, 0F -> 10
    and     $0E ; 0 -> L=x0/xF
    jr      nz,.DoNotDot
.DoDot:
    ld      (hl),e
.DoNotDot:
    inc     l
    djnz    .DitherPixelLoop
    pop     bc
    pop     hl
    inc     h
    dec     c
    jr      nz,.DitherRowLoop
    pop     bc
    pop     hl
    pop     af
    ret

; A = ASCII char, DE = target VRAM address (modifies A, DE)
OutL2WhiteOnBlackCharAndAdvanceDE:  ; whiteOnBlack has become "bright pink on black"
    push    bc
    ld      c,CI_D_TEXT
    inc     e
    call    OutL2Char
    dec     e
    inc     d
    call    OutL2Char
    ld      c,CI_BLACK
    inc     e
    call    OutL2Char
    ld      c,CI_TEXT
    dec     d
    dec     e
    call    OutL2Char
    ; increment char position by one to right
    ld      a,8
    add     a,e
    ld      e,a
    pop     bc
    ret

; A = ASCII char, C = Layer2 colour, DE = target VRAM address
OutL2Char:
    push    af
    push    hl
    push    de
    push    bc
    ; calculate ROM data address of ASCII code in A into DE
    ld      h,MEM_ROM_CHARS_3C00/(8*256)
    add     a,$80
    ld      l,a     ; hl = $780+A (for A=0..127) (for A=128..255 result is undefined)
    add     hl,hl
    add     hl,hl
    add     hl,hl   ; hl *= 8
    ex      de,hl   ; HL = VRAM target address, DE = ROM charmap with letter data
    ; output char to the VRAM
    ld      b,8
.LinesLoop:
    ld      a,(de)
    push    hl
.PixelLoop:
    sla     a
    jr      nc,.SkipDotFill
    ld      (hl),c
.SkipDotFill:
    inc     hl      ; inc HL to keep ZF from `SLA A`
    jr      nz,.PixelLoop
    pop     hl
    inc     h
    inc     e
    djnz    .LinesLoop
    pop     bc
    pop     de
    pop     hl
    pop     af
    ret

; this is not precisely robust routine, it waits while (scanline-low8-bits < L)
; the code calling this should be partially aware where the scanline was prior
; and call it only when it makes sense (i.e. high bit of scanline is known to it)
WaitForScanline:    ; code is somewhat optimized to return ASAP when it happens
    ld      bc, TBBLUE_REGISTER_SELECT_P_243B
    ld      a, RASTER_LINE_LSB_NR_1F
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
.waitLoop:
    in      a,(c)   ; read RASTER_LINE_LSB_NR_1F
    cp      l
    jr      c,.waitLoop
    ret

; this wait until MSB is equal to L (0/1)
WaitForScanlineMSB: ; code is somewhat optimized to return ASAP when it happens
    ld      bc, TBBLUE_REGISTER_SELECT_P_243B
    ld      a, RASTER_LINE_MSB_NR_1E
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
    dec     l
    ld      l,1
    jr      z,.waitForMsbSet
.waitForMsbReset:
    in      a,(c)   ; read RASTER_LINE_MSB_NR_1E
    and     l
    jr      nz,.waitForMsbReset
    ret
.waitForMsbSet:
    in      a,(c)   ; read RASTER_LINE_MSB_NR_1E
    and     l
    jr      z,.waitForMsbSet
    ret

; C = time to spend = (C-1)*(256x empty NOP loop), B = 1/256th of C extra wait
WaitSomeIdleTime:
.idleLoop:
    nop
    djnz    .idleLoop
    dec     c
    jr      nz,.idleLoop
    ret

    savesna "Lmix_LxU.sna", Start
