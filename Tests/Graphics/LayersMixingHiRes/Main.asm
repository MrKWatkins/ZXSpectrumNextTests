; this is similar to "Layer2Colours" test, only ULA parts are changed to Timex Hi-Res
; mode (512x192 with monochrome graphics).
; not sure if there's point to share more source between, let's keep it like this for
; the moment, then maybe refactor later

    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

; colour definitions
C_BLACK     equ     %00000000       ; 0
C_WHITE     equ     %10110110       ; 1
C_B_WHITE   equ     %11111111       ; 2
C_T_WHITE   equ     %01101101       ; 3
C_B_YELLOW  equ     %11011000       ; 4
C_B_CYAN    equ     %00011011       ; 5
C_B_GREEN   equ     %00011000       ; 6
C_B_GREEN2  equ     %00011100       ; 7
C_TEXT      equ     %11110011       ; 8
C_PINK2     equ     $E3             ; 9
C_PINK      equ     $E3             ; 10
C_D_TEXT    equ     %01100101       ; 11

CI_BLACK    equ     0
CI_WHITE    equ     1
CI_B_WHITE  equ     2
CI_T_WHITE  equ     3
CI_B_YELLOW equ     4
CI_B_CYAN   equ     5   ; need it to be 5 for Timex ink -> UlaNext
CI_B_GREEN  equ     6
CI_B_GREEN2 equ     7   ; for Layer2 it will get "priority" bit set
CI_TEXT     equ     8
CI_PINK2    equ     9   ; for Layer2 it will get "priority" bit set
CI_PINK     equ     10  ; need it to be 10 for Timex paper -> UlaNext
CI_D_TEXT   equ     11

colourDef:
    db      C_BLACK, C_WHITE, C_B_WHITE, C_T_WHITE, C_B_YELLOW, C_B_CYAN
    db      C_B_GREEN, C_B_GREEN2, C_TEXT, C_PINK2, C_PINK, C_D_TEXT
colourDefSz equ     $ - colourDef

    MACRO   IDLE_WAIT loop_count
        ld      bc,loop_count
        call    WaitSomeIdleTime
    ENDM

Start:
    call    StartTest

    ; set up Timex HiColor mode
    NEXTREG2A PERIPHERAL_3_NR_08
    or      %00000100               ; enable Timex modes
    NEXTREG_A PERIPHERAL_3_NR_08
    ld      a,%00101110             ; set Hi-colour Timex mode, Cyan/Red colouring
    out     (TIMEX_P_FF),a

    ; Set first-ULA palette, enable ULANext, enable auto-inc    (ULA pal. is HiRes pal.!)
    NEXTREG_nn PALETTE_CONTROL_NR_43, %00000001
    NEXTREG_nn PALETTE_FORMAT_NR_42, $07    ; ULANext INK mask 7
        ; ULA attribute (generated by config of port $FF) is %01010101 (cyan+red+bright)
        ; with INK mask 7 that should produce: ink 5, paper 128+10 (in theory, by Jim B.)
    NEXTREG_nn PALETTE_INDEX_NR_40, 0       ; index 0   (ink)
    call    SetTestPalette
    NEXTREG_nn PALETTE_INDEX_NR_40, 128     ; index 128 (paper+borders)
    call    SetTestPalette
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

    ; show text-pink paper+border while drawing and preparing...
    ld      a,%00111110             ; set Hi-colour Timex mode, White/Black colouring
    out     (TIMEX_P_FF),a          ; with UlaNext that should be: Green2/Text-pink

    ; draw the ULA Timex hi-colour part for pixel combining
    call    DrawUlaHiColPart
    ; reset LoRes scroll registers (does affect ULA screen since core 2.00.25+)
    NEXTREG_nn LORES_XOFFSET_NR_32, 0   ; not sure if it affects hi-res, but to be sure
    NEXTREG_nn LORES_YOFFSET_NR_33, 0

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

    ; Draw Layer2: draw test data
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

    ; set HiRes paper+border to desired final colour (cyan+red -> cyan+pink)
    ld      a,%00101110             ; set Hi-colour Timex mode and colour scheme
    out     (TIMEX_P_FF),a

    ;;DEBUG using ordinary ULA mode, screen0
;     ld      a,%00101000
;     out     (TIMEX_P_FF),a
;     FILL_AREA   MEM_TIMEX_SCR0_4000+(32*192), 32*24, CI_B_CYAN + (CI_PINK<<3)
    ;;^^^ DEBUG using ordinary ULA mode, screen0

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; loop infinitely and set correct layer ordering for various parts of screen

    ; the TEST areas (except the first one) are at x:88 coordinate, giving probably
    ; almost enough time to control register NR_15 to kick-in and modify output.

    ; The scanline does change at pixel x:0, i.e. after that there are instructions:
    ; IN 12T, JR cc 7T, RET 10T, NEXTREG_nn 20T
    ; => cca 49+T until the layer order is modified (first pixels of TEST may be wrong)

    ; (better solution would be to use COPPER for these, but when written like this,
    ; the test does not depend on COPPER existence/emulation, so it's written like this)

    ; There are no border changes, because in Timex Hi-Res the border is equal to paper

ScanlinesLoop:
    ei
    halt

    ;; SLU phase (first 32 scanlines)
    ; Set layers to: SLU, enable sprites (no over border), no LoRes
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00000001
    ; wait some fixed time after IM1 handler to get into scanlines 255+
    IDLE_WAIT   $0002
    ; wait until scanline MSB becomes 0 again (scanline 0)
    ld      l,0
    call    WaitForScanlineMSB
    ; wait until scanline 32
    ld      l,32
    call    WaitForScanline
    ;; LSU phase (scanlines 32..63)
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00000101
    ld      l,64
    call    WaitForScanline
    ;; SUL phase (scanlines 64..95)
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00001001
    ld      l,96
    call    WaitForScanline
    ;; LUS phase (scanlines 96..127)
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00001101
    ld      l,128
    call    WaitForScanline
    ;; USL phase (scanlines 128..159)
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00010001
    ld      l,160
    call    WaitForScanline
    ;; ULS phase (scanlines 160..191)
    NEXTREG_nn SPRITE_CONTROL_NR_15, %00010101
    ld      l,192
    call    WaitForScanline
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
    ; clear whole 512x192 area (which should make it transparent!) - the white background
    ; known from other Layers-mixing tests have to be provided by Layer2 in this one!
    FILL_AREA   MEM_TIMEX_SCR0_4000, 32*192, 0  ; clear "odd" char-columns (1st,3rd,...)
    FILL_AREA   MEM_TIMEX_SCR1_6000, 32*192, 0  ; clear "even" char-columns (2nd,4th,...)

    ; draw MachineID and core versions (draw it as in ULA mode => space between letters):
    ld      de,MEM_TIMEX_SCR0_4000 + (16*8*32) + 5*32 + 18  ; AT [21,18] machineID
    ld      bc,MEM_TIMEX_SCR0_4000 + (16*8*32) + 6*32 + 18  ; AT [22,18] core
    call    OutMachineIdAndCore_defLabels

    ; draw HiRes output of "result" 6x4 boxes
    ld      hl,MEM_TIMEX_SCR0_4000 + 5 + 3*7    ; "odd" columns
    call    .Draw4x6TestData
    ld      hl,MEM_TIMEX_SCR1_6000 + 5 + 3*7    ; "even" columns
    call    .Draw4x6TestData
    ; other result boxes are placed cca. under L2 box
    ld      hl,MEM_TIMEX_SCR0_4000 + (4*32) + 4 + 1*7
.DrawTestDataForOtherModesSecondRun:
    ld      b,5
.DrawTestDataForOtherModes:
    call    .Draw4x6TestData
    djnz    .DrawTestDataForOtherModes
    ; check if this was already second run into MEM_TIMEX_SCR1_6000 area
    ld      a,h
    cp      MEM_TIMEX_SCR1_6000>>8
    ld      hl,MEM_TIMEX_SCR1_6000 + (4*32) + 4 + 1*7
    jr      c,.DrawTestDataForOtherModesSecondRun   ; if not, re-run with new HL

    ; and that's all what is done by HiRes layer, everything else is in Layer2/Sprites
    ret

.Draw4x6TestData:
    call    .Draw2x6Boxes
.Draw2x6Boxes:
    push    bc
    ld      bc,6
    push    de
    push    hl
    ; fill 6 lines with full ink (creating solid cyan block)
    ld      e,6
.FullLinesLoop:
    push    hl
    ld      a,$FF
    call    FillArea
    pop     hl
    inc     h
    dec     e
    jr      nz,.FullLinesLoop
    ; add two lines with dithered pattern
    ld      a,$AA
    push    hl
    call    FillArea
    pop     hl
    inc     h
    ld      a,$55
    call    FillArea
    pop     hl
    call    AdvanceVramHlToNextLine
    ; add two more lines with dithered pattern
    push    hl
    ld      a,$AA
    push    hl
    call    FillArea
    pop     hl
    inc     h
    ld      a,$55
    push    hl
    call    FillArea
    pop     hl
    inc     h
    ; add 6 empty lines (creating solid transparent block)
    ld      e,6
.EmptyLinesLoop:
    push    hl
    xor     a
    call    FillArea
    pop     hl
    inc     h
    dec     e
    jr      nz,.EmptyLinesLoop
    pop     hl
    call    AdvanceVramHlToNextLine
    pop     de
    pop     bc
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Draw Layer2 part ;;;;;;;;;;;;;;;;;;;

DrawLayer2Part:
    ; clear whole Layer2 to be white (In this HiRes test Layer2 is source of white paper)
    FILL_AREA   $0000, 256*192, CI_WHITE

    ; draw black area under MachineID + core versions (AT [21,18] machineID, AT [22,18]..)
    ld      de,CI_BLACK*256 + CI_BLACK
    ld      bc,$3808
    ld      hl,21*8*256 + 17*8 + 4
    call    FillL2BoxWithDither2x2

    ; draw "legend" boxes, draw expected result areas and also the test-areas themselves

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
    ld      hl,0*256 + 8*(5+0)
    ld      de,CI_BLACK*256 + CI_WHITE
    ld      bc,$0820
    call    FillL2Box
    ld      hl,0*256 + 8*(5+5)
    call    FillL2Box
    ld      de,CI_B_YELLOW*256 + CI_B_YELLOW
    ld      hl,0*256 + 8*(5+1)
    call    FillL2Box
    ld      hl,0*256 + 8*(5+3)
    call    FillL2Box
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      bc,$0410
    ld      hl,0*256 + 8*(5+2)
    call    FillL2BoxWithDither2x2
    ld      hl,0*256 + 8*(5+4)
    call    FillL2BoxWithDither2x2
    ; draw the dithered 16x16 boxes to reveal full sprite size
    ld      de,SPR_DITHER_BOX_GFX
    ld      hl,0*256 + 8*(5+1)
    call    DrawDitherGfxInside16x16Box
    ld      hl,0*256 + 8*(5+3)
    call    DrawDitherGfxInside16x16Box
    ld      hl,16*256 + 8*(5+1)
    call    DrawDitherGfxInside16x16Box
    ld      hl,16*256 + 8*(5+3)
    call    DrawDitherGfxInside16x16Box

    ; draw Layer2-legend
    ld      bc,$0C08
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      hl,2*8*256 + 8*(5+7+0)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_WHITE*256 + CI_WHITE
    ld      hl,2*8*256 + 8*(5+7+3)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_GREEN*256 + CI_B_GREEN
    ld      hl,0*8*256 + 8*(5+7+0)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_GREEN2*256 + CI_B_GREEN2
    ld      hl,0*8*256 + 8*(5+7+3)
    call    FillL2BoxWithDither2x2

    ; draw also Layer2 TEST pixels (final area in last 6 characters)
    ld      hl,0*8*256 + 8*(5+3*7+3)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_GREEN*256 + CI_B_GREEN
    ld      hl,0*8*256 + 8*(5+3*7+0)
    call    FillL2BoxWithDither2x2
    ld      de,CI_PINK2*256 + CI_PINK2  ; transparent half with priority
    ld      hl,2*8*256 + 8*(5+3*7+3)
    call    FillL2BoxWithDither2x2
    ld      de,CI_PINK*256 + CI_PINK  ; normal transparent half
    ld      hl,2*8*256 + 8*(5+3*7+0)
    call    FillL2BoxWithDither2x2

    ; draw Layer2 TEST pixels for other combining modes (TEST area under ~L2 legend)
    ld      h,4*8
    ld      ixl,5
.OtherModesDrawLoop:
    ld      l,8*(4+1*7+0)
    ld      de,CI_B_GREEN*256 + CI_B_GREEN
    call    FillL2BoxWithDither2x2
    ld      l,8*(4+1*7+3)
    ld      de,CI_B_GREEN2*256 + CI_B_GREEN2
    call    FillL2BoxWithDither2x2
    ld      a,16
    add     a,h
    ld      h,a
    ld      de,CI_PINK2*256 + CI_PINK2
    call    FillL2BoxWithDither2x2
    ld      l,8*(4+1*7+0)
    ld      de,CI_PINK*256 + CI_PINK
    call    FillL2BoxWithDither2x2
    ld      a,16
    add     a,h
    ld      h,a
    dec     ixl
    jr      nz,.OtherModesDrawLoop

    ; draw ULA-legend
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    ld      bc,$180C
    ld      hl,1*8*256 + 8*(5+2*7+0)
    call    FillL2BoxWithDither2x2
    ld      de,CI_B_CYAN*256 + CI_B_CYAN
    ld      bc,$1804
    ld      hl,0*8*256 + 8*(5+2*7+0)
    call    FillL2BoxWithDither2x2
    ld      hl,2*8*256 + 8*(5+2*7+0)
    call    FillL2BoxWithDither2x2
    ; patch it with dither depiction
    ld      de,CI_B_CYAN*256 + CI_T_WHITE
    ld      bc,$3004
    ld      hl,1*8*256 - 512 + 8*(5+2*7+0)
    ld      a,1
    call    FillL2Box
    ld      hl,3*8*256 - 512 + 8*(5+2*7+0)
    call    FillL2Box

    ret

.DrawExpectedResultTransparent:
    ld      bc,$0C08
    ld      de,CI_B_WHITE*256 + CI_T_WHITE
    jr      FillL2BoxWithDither2x2

.DrawExpectedResultUla:
    push    hl
    ld      de,CI_B_CYAN*256 + CI_B_CYAN
    ld      bc,$0C02
    ld      a,2*4
    add     a,h
    ld      h,a
    call    FillL2BoxWithDither2x2
    pop     hl
    jr      FillL2BoxWithDither2x2

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
    jr      FillL2BoxWithDither2x2

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
    ; set four sprites over test area (pattern 0) (SLU mode)
    ld      de,$2020 + 0*8*256 + 8*(5+3*7+1)    ; [x,y]
    ld      hl,$8000                ; H: visible, 4Bset, pattern 0, L:palOfs 0, ..., X9 0
    call    .UploadOneAttribSet
    ld      d,$20 + 2*8
    call    .UploadOneAttribSet
    ld      e,$20 + 8*(5+3*7+3) - 256
    inc     l                       ; X9 1
    call    .UploadOneAttribSet
    ld      d,$20 + 0*8
    call    .UploadOneAttribSet
    ; set four sprites for other 5 modes (+20 sprites)
    ld      b,5
    ld      de,$2020 + 4*8*256 + 8*(4+1*7+1)    ; [x,y]
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

DrawCharLabels:
    ; single-letter hints into the Separate-layer graphics
    ld      de,$0400 + 8*(5+0*7+1)+4
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$0C00 + 8*(5+1*7+1)
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$0C00 + 8*(5+1*7+4)-4
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$0C00 + 8*(5+1*7+4)+4
    ld      a,'p'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$0400 + 8*(5+2*7+3)-4
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$1400 + 8*(5+2*7+1)-4
    ld      a,'H'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$1400 + 8*(5+2*7+2)-4
    ld      a,'i'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$1400 + 8*(5+2*7+3)-4
    ld      a,'R'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$1400 + 8*(5+2*7+4)-4
    ld      a,'e'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      de,$1400 + 8*(5+2*7+5)-4
    ld      a,'s'
    call    OutL2WhiteOnBlackCharAndAdvanceDE

    ; Layers order scheme above expected results

    ; SLU
    ld      de,$0304    ; [4,3] pixel pos
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ; LSU
    ld      de,$2304
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ; SUL
    ld      de,$4304
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ; LUS
    ld      de,$6304
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ; USL
    ld      de,$8304
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ; ULS
    ld      de,$A304
    ld      a,'U'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'L'
    call    OutL2WhiteOnBlackCharAndAdvanceDE
    ld      a,'S'
    call    OutL2WhiteOnBlackCharAndAdvanceDE

    ret

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

    savesna "LmxHiRes.sna", Start
