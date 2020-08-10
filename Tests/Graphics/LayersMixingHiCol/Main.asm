; this is pretty much copy of "Layer2Colours" test, only ULA parts are changed to Timex
; Hi Colour mode (256x192 with 8x1 attributes).
; not sure if there's point to share more source between, let's keep it like this for
; the moment, then maybe refactor later (there's one more variant pending, Timex-HiRes)

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

LegendText:
    db      'Legend', 0

Start:
    ld      sp,$FFE0
    call    StartTest

    ; Set first-ULA palette, enable ULANext, enable auto-inc    (ULA pal. is LoRes pal.!)
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00000001
    NEXTREG_nn PALETTE_INDEX_NR_40, 0       ; index 0   (ink)
    call    SetTestPalette
    NEXTREG_nn PALETTE_INDEX_NR_40, 128     ; index 128 (paper+border)
    call    SetTestPalette
    NEXTREG_nn PALETTE_FORMAT_NR_42, $0F    ; ULANext INK mask 15
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

    ; set up Timex HiColor mode
    NEXTREG2A PERIPHERAL_3_NR_08
    or      %00000100               ; enable Timex modes
    NEXTREG_A PERIPHERAL_3_NR_08
    ld      a,%00000010             ; set Hi-colour Timex mode
    out     (TIMEX_P_FF),a

    ; show yellow border while drawing and preparing...
    BORDER  CI_B_YELLOW

    ; draw the ULA Timex hi-colour part for pixel combining
    call    DrawUlaHiColPart
    ; reset LoRes scroll registers (did affect ULA screen in cores 2.00.25+ to 3.0.5?)
    NEXTREG_nn LORES_XOFFSET_NR_32, 0
    NEXTREG_nn LORES_YOFFSET_NR_33, 0
    ; reset ULA scroll registers (regular scroll for ULA since some late core 3.0.x)
    NEXTREG_nn ULA_XOFFSET_NR_26, 0
    NEXTREG_nn ULA_YOFFSET_NR_27, 0
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
    ; Set layers to: SLU, enable sprites (no over border), no LoRes
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00000001
    ; wait some fixed time after IM1 handler to get into scanlines 255+
    IDLE_WAIT   $0002
    ; wait until scanline MSB becomes 0 again (scanline 0)
    WAIT_FOR_SCANLINE_MSB 0
    ; wait until scanline 32 (31 and well over half, flip rendering after half-line)
    WAIT_HALF_SCANLINE_AFTER 31
    ;; LSU phase (scanlines 32..63) - white border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00000101
    BORDER  CI_WHITE2
    WAIT_HALF_SCANLINE_AFTER 63
    ;; SUL phase (scanlines 64..95) - grey border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00001001
    BORDER  CI_WHITE
    WAIT_HALF_SCANLINE_AFTER 95
    ;; LUS phase (scanlines 96..127) - white border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00001101
    BORDER  CI_WHITE2
    WAIT_HALF_SCANLINE_AFTER 127
    ;; USL phase (scanlines 128..159) - grey border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00010001
    BORDER  CI_WHITE
    WAIT_HALF_SCANLINE_AFTER 159
    ;; ULS phase (scanlines 160..191) - white border
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00010101
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

;;;;;;;;;;;;;;;;;;;; Draw ULA (HiCol) part ;;;;;;;;;;;;;;;;;;;

DrawUlaHiColPart:
    ; set all attributes: black on white
    FILL_AREA   MEM_TIMEX_SCR1_6000, 32*192, CI_BLACK + (CI_WHITE<<4)
    ; set dark white under certain areas to emphasise the separate sections
    ld      hl,MEM_TIMEX_SCR1_6000+4*32
    ld      e,3
.DarkSectionsLoop:
    ld      bc,$040F
    ld      a,CI_BLACK + (CI_WHITE2<<4)
    call    .DrawNxM_AttributeBox
    ld      bc,4*32
    add     hl,bc
    dec     e
    jr      nz,.DarkSectionsLoop

    ; draw MachineID and core versions:
    ld      de,MEM_ZX_SCREEN_4000 + 1*32 + 18   ; AT [1,18] machineID
    ld      bc,MEM_ZX_SCREEN_4000 + 2*32 + 18   ; AT [2,18] core
    call    OutMachineIdAndCore_defLabels
    ld      hl,LegendText
    ld      de,MEM_ZX_SCREEN_4000 + 4*32 + 23
    call    OutStringAtDe
    ; have some fun with machineID + core version attributes in HiCol mode
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 0*256, 14, CI_B_WHITE + (CI_BLACK<<4)
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 1*256, 14, CI_B_WHITE + (CI_BLACK<<4)
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 2*256, 14, CI_TEXT + (CI_BLACK<<4)
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 3*256, 14, CI_D1_TEXT + (CI_BLACK<<4)
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 4*256, 14, CI_T_WHITE + (CI_BLACK<<4)
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 5*256, 14, CI_WHITE + (CI_BLACK<<4)
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 6*256, 14, CI_WHITE + (CI_BLACK<<4)
    FILL_AREA MEM_TIMEX_SCR1_6000 + 1*32 + 17 + 7*256, 14, CI_WHITE + (CI_BLACK<<4)

    ; make ULA transparent under other "legend" boxes
    ld      hl,MEM_TIMEX_SCR1_6000 + 6*32 + 23  ; SPRITE leg. NEEDS even line, odd column!
    call    .Draw4x6TransparentBoxes
    ld      hl,MEM_TIMEX_SCR1_6000 + 2048 + 3*32 + 23
    call    .Draw4x6TransparentBoxes
    ld      hl,MEM_TIMEX_SCR1_6000 + 4096 + 0*32 + 23
    call    .Draw4x6TransparentBoxes

    ; make ULA transparent under legend-label area
    ld      hl,MEM_TIMEX_SCR1_6000 + 0
    ld      bc,$1804
    call    .DrawNxMTransparentBoxes
    ; set attributes of "result" 6x4 boxes
    ld      hl,MEM_TIMEX_SCR1_6000 + 5
    ld      e,6
.DrawTestDataForOtherModes:
    call    .Draw4x6TestData
    dec     e
    jr      nz,.DrawTestDataForOtherModes
    ret

.Draw4x6TestData:
    call    .Draw2x6Boxes
.Draw2x6Boxes:
    ld      a,CI_BLACK+(CI_B_CYAN<<4)
    ld      bc,$0106
    call    .DrawNxM_AttributeBox
    ld      b,1
    jr      .DrawNxMTransparentBoxes
.Draw4x6TransparentBoxes:
    ld      bc,$0406
.DrawNxMTransparentBoxes:
    ld      a,CI_BLACK+(CI_PINK<<4)
; HL = target address, BC = rows/columns, A = attribute
.DrawNxM_AttributeBox:
    push    de
    ld      e,a     ; preserve attribute in E
.DrawNRowsLoop:
    push    bc
    push    hl
    ld      b,0
.Draw8LinesLoop:
    ld      a,e
    push    hl
    call    FillArea
    pop     hl
    inc     h       ; go 1 line down (ULA VRAM addressing scheme)
    ld      a,h
    and     $07     ; a == 0 when all 8 lines of char were done
    jr      nz,.Draw8LinesLoop
    pop     hl
    call    AdvanceVramHlToNextLine
    pop     bc
    djnz    .DrawNRowsLoop
    pop     de
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
    xor     a
    out     (c), a  ; Write to pattern/attribute slot 0
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

    ; make sure all other sprites are not visible
    ld      h,0
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
    db      $CC, $84, "U", 0, $BC, $94, "HiCol",0
    db      $04, $03, "SLU", 0, $04, $23, "LSU", 0, $04, $43, "SUL", 0
    db      $04, $63, "LUS", 0, $04, $83, "USL", 0, $04, $A3, "ULS", 0
    db      $FF

DrawCharLabels:
    ; single-letter hints into legend with the Separate-layer graphics
    ; and Layers order scheme above expected results
    ld      bc,CI_TEXT*256 + CI_D1_TEXT
    ld      hl,LayerOrderLabelsTxt
    jp      OutL2StringsIn3Cols

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

    savesna "LmxHiCol.sna", Start
