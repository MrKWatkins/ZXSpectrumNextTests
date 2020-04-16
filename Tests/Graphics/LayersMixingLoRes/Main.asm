; this is pretty much copy of "Layer2Colours" test, only ULA parts are changed to LoRes.
; not sure if there's point to share more source between, let's keep it like this for
; the moment, then maybe refactor later (there're more variants pending with Timex modes!)

    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"
    INCLUDE "../../timing.i.asm"

; colour definitions
C_BLACK     equ     %00000000       ; 0
C_WHITE     equ     %10110110       ; 1
C_WHITE2    equ     %10010010       ; 2
C_B_WHITE   equ     %11111111       ; 3
C_T_WHITE   equ     %01101101       ; 4
C_B_YELLOW  equ     %11011000       ; 5
C_B_GREEN   equ     %00011000       ; 6
C_PINK      equ     $E3             ; 7
C_B_GREEN2  equ     %00011100       ; 8
C_B_CYAN    equ     %00011011       ; 9
C_PINK2     equ     $E3             ; 10
C_TEXT      equ     %11110011       ; 11
C_D1_TEXT   equ     %01100101       ; 12    ; soft shadow edges ([+1,0], [0,+1])
C_D2_TEXT   equ     %00000000       ; 13    ; hard shadow [+1,+1]

CI_BLACK    equ     0
CI_WHITE    equ     1
CI_WHITE2   equ     2   ; for emphasisig different layer priority block
CI_B_WHITE  equ     3
CI_T_WHITE  equ     4
CI_B_YELLOW equ     5
CI_B_GREEN  equ     6
CI_PINK     equ     7
CI_B_GREEN2 equ     8   ; for Layer2 it will get "priority" bit set
CI_B_CYAN   equ     9
CI_PINK2    equ     10  ; for Layer2 it will get "priority" bit set
CI_TEXT     equ     11
CI_D1_TEXT  equ     12
CI_D2_TEXT  equ     13

colourDef:
    db      C_BLACK, C_WHITE, C_WHITE2, C_B_WHITE, C_T_WHITE, C_B_YELLOW, C_B_GREEN
    db      C_PINK, C_B_GREEN2, C_B_CYAN, C_PINK2, C_TEXT, C_D1_TEXT, C_D2_TEXT
colourDefSz equ     $ - colourDef

Start:
    ld      sp,$FFE0
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
    ; modify the two extra colours exercising the "priority" bit
    NEXTREG_nn PALETTE_INDEX_NR_40, CI_B_GREEN2
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, C_B_GREEN2
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $80    ; set priority bit, Blue=0
    NEXTREG_nn PALETTE_INDEX_NR_40, CI_PINK2
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, C_PINK2
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $81    ; set priority bit, Blue=1

    ; setup transparency features - make pink transparent and visible as fallback
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14, C_PINK
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A, C_PINK
    NEXTREG_nn SPRITE_TRANSPARENCY_I_NR_4B, CI_PINK     ; sprite transparency needs index
    ; show yellow border while drawing and preparing...
    BORDER  CI_B_YELLOW

    ; reset LoRes scroll registers
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; draw the LoRes part for pixel combining
    call    DrawLoResPart

    ; reset Layer2 scroll registers
    NEXTREG_nn LAYER2_XOFFSET_NR_16, 0
    NEXTREG_nn LAYER2_YOFFSET_NR_17, 0
    ; setup Layer2 bank to 9 (like NextZXOS does)
    NEXTREG_nn LAYER2_RAM_BANK_NR_12, 9
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
    FILL_AREA   $0000, 256*192, CI_PINK
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
    ; loop infinitely and set correct layer ordering for various parts of screen

    ; the TEST areas (except the first one) are at x:88 coordinate, giving probably
    ; almost enough time to control register NR_15 to kick-in and modify output.

    ; The scanline does change at pixel x:0, i.e. after that there are instructions:
    ; IN 12T, JR cc 7T, RET 10T, NEXTREG_nn 20T
    ; => cca 49+T until the layer order is modified (first pixels of TEST may be wrong)

    ; (better solution would be to use COPPER for these, but when written like this,
    ; the test does not depend on COPPER existence/emulation, so it's written like this)

ScanlinesLoop:
    ei
    halt
    BORDER  CI_WHITE
    ;; SLU phase (scanlines 0..31)
    ; Set layers to: SLU, enable sprites (no over border), LoRes ON
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10000001
    ; wait some fixed time after IM1 handler to get into scanlines 255+
    IDLE_WAIT   $0002
    ; wait until scanline MSB becomes 0 again (scanline 0)
    WAIT_FOR_SCANLINE_MSB 0
    ; wait until scanline 32 (31 and well over half, flip rendering after half-line)
    WAIT_HALF_SCANLINE_AFTER 31
    ;; LSU phase (scanlines 32..63) - white border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10000101
    BORDER  CI_WHITE2
    WAIT_HALF_SCANLINE_AFTER 63
    ;; SUL phase (scanlines 64..95) - grey border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10001001
    BORDER  CI_WHITE
    WAIT_HALF_SCANLINE_AFTER 95
    ;; LUS phase (scanlines 96..127) - white border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10001101
    BORDER  CI_WHITE2
    WAIT_HALF_SCANLINE_AFTER 127
    ;; USL phase (scanlines 128..159) - grey border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10010001
    BORDER  CI_WHITE
    WAIT_HALF_SCANLINE_AFTER 159
    ;; ULS phase (scanlines 160..191) - white border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %10010101
    BORDER  CI_WHITE2
    ; make bottom border white
    WAIT_HALF_SCANLINE_AFTER 191
    BORDER  CI_WHITE
    jr      ScanlinesLoop

    ;call    EndTest

;;;;;;;;;;;;;;;;;;;;;;;; Set palette (currently selected one) ;;;;;;;;;;;;;;;;;;;

SetTestPalette:
    ld      hl,colourDef
    ld      b,colourDefSz
.SetPaletteColours:
    ld      a,(hl)
    NEXTREG_A PALETTE_VALUE_NR_41
    inc     hl
    djnz    .SetPaletteColours
    ret

;;;;;;;;;;;;;;;;;;;; Draw ULA (LoRes) part ;;;;;;;;;;;;;;;;;;;

DrawLoResPart:
    ; set all pixels to white
    FILL_AREA   MEM_LORES0_4000, 128*48, CI_WHITE
    FILL_AREA   MEM_LORES1_6000, 128*48, CI_WHITE
    ; set dark white under certain areas to emphasise the separate sections
    ld      a,CI_WHITE2
    ld      hl,MEM_LORES0_4000 + $10 + (4*4*128)
    ld      bc,$102C
    call    .DrawNxM_AttributeBox
    ld      hl,MEM_LORES1_6000 + $10 + (0*4*128)
    ld      bc,$102C
    call    .DrawNxM_AttributeBox
    ld      hl,MEM_LORES1_6000 + $10 + (8*4*128)
    ld      bc,$102C
    call    .DrawNxM_AttributeBox

    ; make ULA transparent under other "legend" boxes (separate layers)
    ld      hl,MEM_LORES0_4000 + (6*4*128) + 23*4
    call    .Draw4x6TransparentBoxes
    ld      hl,MEM_LORES0_4000 + (11*4*128) + 23*4
    ld      bc,$0418
    call    .DrawNxM_AttributeBox
    ld      hl,MEM_LORES1_6000 + (0*4*128) + 23*4
    ld      bc,$0C18
    call    .DrawNxM_AttributeBox
    ld      hl,MEM_LORES1_6000 + ((16-12)*4*128) + 23*4
    call    .Draw4x6TransparentBoxes
    ; make ULA transparent under legend-label area (left column)
    ld      hl,MEM_LORES0_4000 + 0
    ld      bc,$3010
    call    .DrawNxMTransparentBoxes
    ld      hl,MEM_LORES1_6000 + 0
    ld      bc,$3010
    call    .DrawNxMTransparentBoxes

    ; set attributes of "result" 6x4 boxes
    ld      hl,MEM_LORES0_4000 + 5*4
    ld      e,3
.DrawTestDataForOtherModes:
    call    .Draw4x6TestData
    dec     e
    jr      nz,.DrawTestDataForOtherModes
    ld      hl,MEM_LORES1_6000 + 5*4
    ld      e,3
.DrawTestDataForOtherModesBottomHalf:
    call    .Draw4x6TestData
    dec     e
    jr      nz,.DrawTestDataForOtherModesBottomHalf
    ret

.Draw4x6TestData:
    call    .Draw2x6Boxes
.Draw2x6Boxes:
    ld      a,CI_B_CYAN
    ld      bc,$0418
    call    .DrawNxM_AttributeBox
    ld      b,4
    jr      .DrawNxMTransparentBoxes
.Draw4x6TransparentBoxes:   ; 4x6 chars = 16x24 LoRes pixels
    ld      bc,$1018
.DrawNxMTransparentBoxes:
    ld      a,CI_PINK
; HL = target address, BC = rows/columns, A = attribute
.DrawNxM_AttributeBox:
    push    bc
    push    hl
    ld      b,0
    call    FillArea
    pop     hl
    push    af
    ld      a,128
    add     a,l
    ld      l,a
    ld      a,0
    adc     a,h
    ld      h,a
    pop     af
    pop     bc
    djnz    .DrawNxM_AttributeBox
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Draw Layer2 part ;;;;;;;;;;;;;;;;;;;

DrawLayer2Part:
    ; draw "legend" boxes, draw expected result areas and also the test-areas themselves

    ; fill background under "label/expected" areas (all 6 of them in one fill)
    ld      a,8
    ld      de,CI_WHITE*256 + CI_WHITE
    ld      bc,$0418
    ld      hl,0*256 + 0
    call    FillL2Box
    ; set dark white under certain areas to emphasise the separate sections
    ld      de,CI_WHITE2*256 + CI_WHITE2
    ld      bc,$0404
    ld      hl,4*8*256 + 0
.DarkSectionsLoop:
    ld      a,8
    call    FillL2Box
    ld      a,h
    add     a,8*8
    ld      h,a
    cp      3*8*8
    jr      c,.DarkSectionsLoop

    ; draw expected result area for orders: SLU, LSU, SUL, LUS, USL, ULS
    ld      hl,12*256 + 4
    ; SLU
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultLayer2p
    ld      a,4*8
    add     a,h
    ld      h,a
    ; LSU
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultLayer2p
    ld      a,4*8
    add     a,h
    ld      h,a
    ; SUL
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultLayer2p
    ld      a,4*8
    add     a,h
    ld      h,a
    ; LUS
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultLayer2p
    ld      a,4*8
    add     a,h
    ld      h,a
    ; USL
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultLayer2p
    ld      a,4*8
    add     a,h
    ld      h,a
    ; ULS
    call    .DrawExpectedResultTransparent
    call    .DrawExpectedResultSprites
    call    .DrawExpectedResultLayer2
    call    .DrawExpectedResultUla
    call    .DrawExpectedResultLayer2p

    ; draw Sprite-legend
    ld      a,1
    ld      hl,6*8*256 + 8*(23+0)
    ld      de,CI_BLACK*256 + CI_WHITE
    ld      bc,$0820
    call    FillL2Box
    ld      l,8*(23+5)
    call    FillL2Box
    ld      de,CI_B_YELLOW*256 + CI_B_YELLOW
    ld      l,8*(23+1)
    call    FillL2Box
    ld      l,8*(23+3)
    call    FillL2Box
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      bc,$0410
    ld      l,8*(23+2)
    call    FillL2BoxWithDither2x2
    ld      l,8*(23+4)
    call    FillL2BoxWithDither2x2
    ; draw the dithered 16x16 boxes to reveal full sprite size
    ld      de,SPR_DITHER_BOX_GFX
    ld      hl,(6+0)*8*256 + 8*(23+1)
    call    DrawDitherGfxInside16x16Box
    ld      hl,(6+0)*8*256 + 8*(23+3)
    call    DrawDitherGfxInside16x16Box
    ld      hl,(6+2)*8*256 + 8*(23+1)
    call    DrawDitherGfxInside16x16Box
    ld      hl,(6+2)*8*256 + 8*(23+3)
    call    DrawDitherGfxInside16x16Box

    ; draw Layer2-legend
    ld      bc,$0C08
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      hl,(11+2)*8*256 + 8*(23+0)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_WHITE*256 + CI_WHITE
    ld      hl,(11+2)*8*256 + 8*(23+3)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_GREEN*256 + CI_B_GREEN
    ld      hl,(11+0)*8*256 + 8*(23+0)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_GREEN2*256 + CI_B_GREEN2
    ld      hl,(11+0)*8*256 + 8*(23+3)
    call    FillL2BoxWithDither2x2

    ; draw Layer2 TEST pixels for all combining modes
    ld      h,(0+0)*8
    ld      ixl,6
.OtherModesDrawLoop:
    ld      l,8*(5+0)
    ld      de,CI_B_GREEN*256 + CI_B_GREEN
    call    FillL2BoxWithDither2x2
    ld      l,8*(5+3)
    ld      de,CI_B_GREEN2*256 + CI_B_GREEN2
    call    FillL2BoxWithDither2x2
    ld      a,16
    add     a,h
    ld      h,a
    ld      de,CI_PINK2*256 + CI_PINK2
    call    FillL2BoxWithDither2x2
    ld      a,16
    add     a,h
    ld      h,a
    dec     ixl
    jr      nz,.OtherModesDrawLoop

    ; draw ULA-legend
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      bc,$180C
    ld      hl,(16+1)*8*256 + 8*(23+0)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_CYAN*256 + CI_B_CYAN
    ld      bc,$1804
    ld      hl,(16+0)*8*256 + 8*(23+0)
    call    FillL2BoxWithDither2x2
    ld      hl,(16+2)*8*256 + 8*(23+0)
    call    FillL2BoxWithDither2x2
    ret

.DrawExpectedResultTransparent:
    ld      bc,$0C08
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    jp      FillL2BoxWithDither2x2

.DrawExpectedResultUla:
    push    hl
    ld      de,CI_B_CYAN*256 + CI_B_CYAN
    ld      bc,$0C02
    ld      a,2*4
    add     a,h
    ld      h,a
    call    FillL2BoxWithDither2x2
    pop     hl
    jp      FillL2BoxWithDither2x2

.DrawExpectedResultSprites:
    push    hl
    ld      de,CI_B_YELLOW*256 + CI_B_YELLOW
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

.DrawExpectedResultLayer2:
    ld      de,CI_B_GREEN*256 + CI_B_GREEN
    ld      bc,$0604
    jp      FillL2BoxWithDither2x2

.DrawExpectedResultLayer2p:
    ;; Layer2 priority part
    push    hl
    ld      de,CI_B_GREEN2*256 + CI_B_GREEN2
    ld      bc,$0604
    ld      a,3*4
    add     a,l
    ld      l,a
    call    FillL2BoxWithDither2x2
    pop     hl
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
    ld      de,CI_B_YELLOW*256 + CI_B_YELLOW
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
    ; set four sprites over test area for all 6 modes
    ld      b,6
    ld      de,$2020 + 0*8*256 + 8*(5+1)    ; [x,y]
    ld      hl,$8000                ; H: visible, 4Bset, pattern 0, L:palOfs 0, ..., X9 0
.SetSpritesForOtherModes:
    call    .UploadOneAttribSet
    ld      a,16
    add     a,e
    ld      e,a
    call    .UploadOneAttribSet
    ld      a,16
    add     a,d
    ld      d,a
    call    .UploadOneAttribSet
    ld      a,-16
    add     a,e
    ld      e,a
    call    .UploadOneAttribSet
    ld      a,16
    add     a,d
    ld      d,a
    djnz    .SetSpritesForOtherModes

    ; make sure all other sprites are not visible (only expects 64 total sprites)
    ld      h,0                     ; with new total 128 the remaining 64 are not set!
    ld      b,64-6*4
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

LayerOrderLabelsTxt:    ; array[X, Y, ASCIIZ], $FF
    db      $C4, $34, "S", 0, $C0, $64, "L", 0, $D4, $64, "Lp", 0
    db      $CC, $84, "U", 0, $BC, $94, "LoRes",0
    db      $04, $03, "SLU", 0, $04, $23, "LSU", 0, $04, $43, "SUL", 0
    db      $04, $63, "LUS", 0, $04, $83, "USL", 0, $04, $A3, "ULS", 0
    db      $B8, $20, 'Legend', 0
    db      $FF

DrawCharLabels:
    ; single-letter hints into legend with the Separate-layer graphics
    ; and Layers order scheme above expected results
    ld      bc,CI_TEXT*256 + CI_D1_TEXT
    ld      hl,LayerOrderLabelsTxt
    call    OutL2StringsIn3Cols

.drawMachineId:
    ; draw MachineID and core versions:
    ld      de,$0800 + 8*21
    ld      a,'m'
    call    OutL2CharIn3ColsAndAdvanceE
    NEXTREG2A MACHINE_ID_NR_00
    call    OutDecimalValueToL2
    ld      de,$1000 + 8*21
    ld      a,'c'
    call    OutL2CharIn3ColsAndAdvanceE
    NEXTREG2A NEXT_VERSION_NR_01
    push    af
    rrca
    rrca
    rrca
    rrca
    and     $0F
    call    OutDecimalValueToL2
    ld      a,'.'
    call    OutL2CharIn3ColsAndAdvanceE
    pop     af
    and     $0F
    call    OutDecimalValueToL2
    ld      a,'.'
    call    OutL2CharIn3ColsAndAdvanceE
    NEXTREG2A NEXT_VERSION_MINOR_NR_0E
    call    OutDecimalValueToL2

    ret

;A: 0..99 value, modifies L,A
OutDecimalValueToL2:
    ld      l,-1
.MidToDec:
    inc     l
    sub     10
    jr      nc,.MidToDec
    add     a,'0'+10    ; 10^0 amount to ASCII
    push    af
    ld      a,'0'
    add     a,l         ; 10^1 amount to ASCII
    call    OutL2CharIn3ColsAndAdvanceE
    pop     af
    jp      OutL2CharIn3ColsAndAdvanceE

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

    savesna "LmixLoRs.sna", Start
