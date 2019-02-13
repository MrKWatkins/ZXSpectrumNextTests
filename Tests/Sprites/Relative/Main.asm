    device zxspectrum48

    org    $7D00

CustomFont:
    db      $00, $00, $00, $00, $00, $00, $00, $00      ; ' ' = empty/space
    db      $01, $01, $01, $01, $01, $01, $01, $01      ; '!' = right solid
    db      $01, $01, $01, $01, $01, $01, $01, $FF      ; '"' = right bottom solid
    db      $00, $00, $00, $00, $00, $00, $00, $FF      ; '#' = bottom solid
    db      $00, $01, $00, $01, $00, $01, $00, $01      ; '$' = right dotted
    db      $00, $01, $00, $01, $00, $01, $00, $55      ; '%' = right bottom dotted
    db      $00, $00, $00, $00, $00, $00, $00, $55      ; '&' = bottom dotted
    db      $00, $70, $60, $50, $08, $04, $02, $00      ; ''' = arrow top-left
    db      $00, $40, $20, $10, $0A, $06, $0E, $00      ; '(' = arrow bottom-right
    db      $01, $01, $01, $01, $01, $01, $01, $55      ; ')' = right solid, bottom dotted
    db      $00, $01, $00, $01, $00, $01, $00, $FF      ; '*' = right dotted, bottom solid
    db      $00, $11, $28, $11, $54, $39, $00, $FF      ; '+' = anchor + solid bottom + dotted right
    db      $00, $00, $20, $50, $20, $A8, $70, $00      ; ',' = anchor
    db      $00, $11, $28, $11, $54, $39, $00, $55      ; '-' = anchor + dotted bottom + right
    ; './0123'

    org     $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"
    INCLUDE "../../controls.i.asm"

SPRITE_WRONG_PIX_COLOUR equ $A2

OPT_BIT_MARK    equ     0
OPT_BIT_ROT     equ     1
OPT_BIT_MIRY    equ     2
OPT_BIT_MIRX    equ     3
OPT_BIT_SHOW    equ     4
OPT_BIT_CLIP    equ     5
OPTIONS_COUNT   equ     6

Options:
    db      0       ; (1<<OPT_BIT_MARK)|(1<<OPT_BIT_SHOW)
    db      OPTIONS_COUNT   ; must follow in memory right after options byte

OptionsAttrOfs:
    ;       mark, rot, mirY, mirX, show, clip
    db      4*32+0, 5*32+20, 5*32+10, 5*32+0, 4*32+8, 4*32+18 ; into last third of attribs

Start:
    call    StartTest
    ; register control keys
    REGISTER_KEY KEY_Q, KeyHandlerMarks
    REGISTER_KEY KEY_W, KeyHandlerShowAll
    REGISTER_KEY KEY_E, KeyHandlerClipWindow
    REGISTER_KEY KEY_A, KeyHandlerMirrorX
    REGISTER_KEY KEY_S, KeyHandlerMirrorY
    REGISTER_KEY KEY_D, KeyHandlerRotate
    ; draw ULA part of screen
    call    DrawUlaPart
    call    SetSpritePalette
RefreshSpritesAndLoop:
    call    SetClipWindowAndNR15
    call    LoadPatterns
    call    ShowSprites
.MainLoop:
    call    RefreshKeyboardState
    jr      .MainLoop
    ;call    EndTest

KeyHandlerMarks:
    ld      a,1<<OPT_BIT_MARK
    jr      FlipOptionAndRefreshSprites
KeyHandlerShowAll:
    ld      a,1<<OPT_BIT_SHOW
    jr      FlipOptionAndRefreshSprites
KeyHandlerClipWindow:
    ld      a,1<<OPT_BIT_CLIP
    jr      FlipOptionAndRefreshSprites
KeyHandlerMirrorX:
    ld      a,1<<OPT_BIT_MIRX
    jr      FlipOptionAndRefreshSprites
KeyHandlerMirrorY:
    ld      a,1<<OPT_BIT_MIRY
    jr      FlipOptionAndRefreshSprites
KeyHandlerRotate:
    ld      a,1<<OPT_BIT_ROT
    ; continue with FlipOptionAndRefreshSprites
FlipOptionAndRefreshSprites:
    ; flip the option
    ld      hl,Options
    xor     (hl)
    ld      (hl),a
    ; update the UI state
    call    UpdateKeysStatus
    ; Reload patterns and sprite attributes
    jr      RefreshSpritesAndLoop

ShowSprites:
    ; Select pattern and sprite slot 0
    ld      bc, SPRITE_STATUS_SLOT_SELECT_P_303B
    xor     a
    out     (c),a
    ; prepare modifier bytes into D (Byte3) and E (Byte4)
    ld      e,a         ; E = 0 by default (no change to B4)
    ld      a,(Options)
    bit     OPT_BIT_SHOW,a
    jr      z,.NoShowAll
    ld      e,B4_VIS    ; E = enforce visible
.NoShowAll:
    ; OPT bits for rot/mir are identical to actual functional bits, so just AND them
    and     B3_ROTATE|B3_MIRRORX|B3_MIRRORY
    ld      d,a         ; D = enforce extra bits in B3
    ; upload all sprite attributes
    ld      hl, SpritesDefs
    ld      c, SPRITE_ATTRIBUTE_P_57
.UploadSingleSprite:
    outi    ; byte 1 X
    outi    ; byte 2 Y
    ; byte 3
    ld      a, (hl)
    inc     hl
    or      d
    out     (c),a
    ; byte 4
    ld      a, (hl)
    inc     hl
    or      e
    out     (c),a
    ; optional byte 5
    and     B4_5BEXT
    jr      z,.Only4ByteDef
    ; byte 5
    outi
.Only4ByteDef:
    ; loop until end address of data is reached
    ld      a,SpritesDefsEnd&$FF
    cp      l
    jr      nz,.UploadSingleSprite
    ret

; sprite helper defs
; B1 = X LSB
; B2 = Y LSB
B3_PAL_MSK  equ     $F0
B3_MIRRORX  equ     $08
B3_MIRRORY  equ     $04
B3_ROTATE   equ     $02
B3_MSBX     equ     $01
B3_REL_PAL  equ     $01
B4_VIS      equ     $80
B4_INVIS    equ     $00
B4_5BEXT    equ     $40
B4_NAME_MSK equ     $3F
B5_4BIT_LO  equ     $80
B5_4BIT_HI  equ     $C0
B5_RELT_BIG equ     $20 ; "big-sprite" type of relatives (not used in this test)
B5_REL      equ     $40
B5_REL_4BHI equ     $60
B5_X_2X     equ     $08
B5_X_4X     equ     $10
B5_X_8X     equ     $18
B5_Y_2X     equ     $02
B5_Y_4X     equ     $04
B5_Y_8X     equ     $06
B5_MSBY     equ     $01
B5_REL_NAME equ     $01

SpritesDefs:
    ; 0 : relati, visib, [  32,  32], 8R (should be hidden because it has no anchor)
    db  32, 32, 0, B4_VIS|B4_5BEXT|NAME_8R, B5_REL
    ;; 8 bit graphics, scale 1x, mostly simple positive coordinates (simple case)
    ; 1 : anchor, visib, [  80,  48], 8G  (4 byte attributes)
    db  80, 48, 0, B4_VIS|NAME_8G
    ; 2 : relati, visib, [   0,  16], 8G =[80,64]
    db  0, 16, 0, B4_VIS|B4_5BEXT|NAME_8G, B5_REL
    ; 3 : relati, invis, [ -48,  32], 8R =[32,80]
    db  -48, 32, 0, B4_INVIS|B4_5BEXT|NAME_8R, B5_REL
    ; 4 : relati, visib, [  16,  16], 8G =[96,64]  ; visible after invisible in cluster
    db  16, 16, 0, B4_VIS|B4_5BEXT|NAME_8G, B5_REL
    ;; 8 bit graphics, scales, negative coordinates for relatives, relative "name"
    ; 5 : anchor, visib, [ 144,  64], 8G, scale 2x4
    db  144, 64, 0, B4_VIS|B4_5BEXT|NAME_8G, B5_X_2X|B5_Y_4X
    ; 6 : relati, invis, [-112, -16], 8R, scale 1x1 = [32,48]
    db  -112, -16, 0, B4_INVIS|B4_5BEXT|NAME_8R, B5_REL
    ; 7 : relati, visib, [ -48, -16], 8G, scale 8x1 = [96,48]
    db  -48, -16, 0, B4_VIS|B4_5BEXT|NAME_8G, B5_REL|B5_X_8X
    ; 8 : relati, visib, [ -64,  32], 8G, scale 4x2 = [80,96]
    db  -64, 32, 0, B4_VIS|B4_5BEXT|NAME_8G, B5_REL|B5_X_4X|B5_Y_2X
    ; 9 : relati, visib, [ -64,  16], 0+anchor.N = 8G, scale 4x1 = [80,80]
    db  -64, 16, 0, B4_VIS|B4_5BEXT|0, B5_REL|B5_X_4X|B5_REL_NAME
    ;; 4 bit graphics, scales, positive/negative, palette offset
    ; A : anchor, visib, [ 176, 112], 4G1.LO (+16), scale 1x1
    db  176, 112, $10, B4_VIS|B4_5BEXT|NAME_4G1, B5_4BIT_LO
    ; B : relati, visib, [   0, -32], 4G0.LO, scale 2x2 = [176,80]
    db  0, -32, 0, B4_VIS|B4_5BEXT|NAME_4G0, B5_REL|B5_X_2X|B5_Y_2X
    ; C : relati, visib, [  32, -48], 4G0.HI, scale 1x4 = [208,64]
    db  32, -48, 0, B4_VIS|B4_5BEXT|NAME_4G0, B5_REL|B5_REL_4BHI|B5_Y_4X
    ; D : relati, invis, [  80, -16], 4R0.LO, scale 1x1 = [256,96]
    db  80, -16, 0, B4_INVIS|B4_5BEXT|NAME_4R0, B5_REL
    ;; 4 bit graphics, invisible anchor
    ; E : anchor, invis, [  32,  96], 4R0.HI, scale 1x1
    db  32, 96, 0, B4_INVIS|B4_5BEXT|NAME_4R0, B5_4BIT_HI
    ; F : relati, visib, [   0,  16], 4R1.LO (+16), scale 1x1 = [32,112]
    db  0, 16, $10, B4_VIS|B4_5BEXT|NAME_4R1, B5_REL
    ;; 4 bit graphics, red anchor beyond screen (top left), relative palette offset/name
    ; G : anchor, visib, [  64, -63], 4R1.HI (+16), scale 1x1
    db  64, -63, $10, B4_VIS|B4_5BEXT|NAME_4R1, B5_4BIT_HI|B5_MSBY
    ; H : relati, visib, [  48, 127], "-1" +anchor.N +anchor.pal_ofs = 4G1.LO, scale 1x1 =[112,64]
    db  48, 127, B3_REL_PAL, B4_VIS|B4_5BEXT|(-1&B4_NAME_MSK), B5_REL|B5_REL_NAME
    ; I : relati, invis, [ -32, 127], 4RG0.HI +anchor.pal_ofs = 4GR1.HI, scale 1x1 =[32,64]
    db  -32, 127, B3_REL_PAL, B4_INVIS|B4_5BEXT|NAME_4RG0, B5_REL_4BHI
    ; J : relati, visib, [  64, 127], 4RG0.HI, scale 1x1 =[128,64]
    db  64, 127, 0, B4_VIS|B4_5BEXT|NAME_4RG0, B5_REL_4BHI
    ; K : relati, visib, [ 112, 127], 4RG0.LO +anchor.pal_ofs = 4GR1.LO, scale 2x1 =[176,64]
    db  112, 127, B3_REL_PAL, B4_VIS|B4_5BEXT|NAME_4RG0, B5_REL|B5_X_2X
    ;; 4 bit graphics, red anchor beyond screen (bottom right), relative pal ofs wraps!
    ; L : anchor, visib, [ 320, 240], 4GR1.HI (+16), scale 1x1
    db  320&$FF, 240, $10+B3_MSBX, B4_VIS|B4_5BEXT|NAME_4GR1, B5_4BIT_HI
    ; M : relati, invis, [ -64,-128], 4RG0.LO (+240) +anchor.pal_ofs = 4RG0.LO, scale 1x1 =[256,112]
    db  -64, -128, $F0|B3_REL_PAL, B4_INVIS|B4_5BEXT|NAME_4RG0, B5_REL
    ; N : relati, visib, [-128,-128], 4RG0.HI (+240) +anchor.pal_ofs = 4RG0.HI, scale 1x1 =[192,112]
    db  -128, -128, $F0|B3_REL_PAL, B4_VIS|B4_5BEXT|NAME_4RG0, B5_REL_4BHI
    ;; 8 bit graphics, just final dot after everything, sporting over-border feature
    ; X : anchor, visib, [ 286, 222], 8b dot, scale 1x1
    db  286&$FF, 222, B3_MSBX, B4_VIS|NAME_8DOT
SpritesDefsEnd  equ $

NAME_8DOT   equ     0
NAME_8G     equ     1
NAME_8R     equ     2
NAME_4R0    equ     1
NAME_4G0    equ     2
NAME_4RG0   equ     3
NAME_4G1    equ     1
NAME_4R1    equ     2
NAME_4GR1   equ     3

LoadPatterns:
    ; Select pattern and sprite slot 0
    ld      bc, SPRITE_STATUS_SLOT_SELECT_P_303B
    xor     a
    out     (c),a
    ; Upload dot sprite pattern data (8 bit, created by bitmask provided)
    ; 0 8b 4x4 "dot" with transparent area around using $55 colour for dot pixels
    ld      c, SPRITE_PATTERN_P_5B
    call    OutputDotPattern
    ; Upload the remaining patterns for tests (green/red 8/4 bit variants, shared gfx)
    ; 1 256x $22: 8b G, 4b +0 R0, 4b +16 G1
    ; 2 256x $44: 8b R, 4b +0 G0, 4b +16 R1
    ; 3 128x $22, 128x $44: 4b +0 RG0, 4b +16 GR1
    ; - Can be patched to add orientation "marks" of light blue colour:
    ; 8b patterns: left-top light blue 1/8 width "mark" and left-middle 1/4 width "mark"
    ; 4b patterns left-top only: 1/4 width mark = LO pattern, 1/2 width mark = HI pattern
    ld      hl, OtherPatternsDef
    ld      a, (Options)
    bit     OPT_BIT_MARK,a
    jr      z, .OutPatternDataNextBatch  ; no marking
    ld      hl, OtherPatternsDefWithMark
.OutPatternDataNextBatch:
    ld      b,(hl)
    inc     hl
    ld      a,(hl)
    inc     hl
    or      a
    ret     z
.OutPatternData:
    out     (c),a
    djnz    .OutPatternData
    jr      .OutPatternDataNextBatch

OtherPatternsDef:
    db      0, $22, 0, $44, 128, $22, 128, $44, 0, 0

OtherPatternsDefWithMark:
    db      2, $11, 14+7*16, $22, 4, $11, 12+7*16, $22
    db      2, $11, 14+7*16, $44, 4, $11, 12+7*16, $44
    db      2, $11, 128-2, $22, 4, $11, 128-4, $44
    db      0, 0

OutputDotPattern:
    ld      hl, DotPatternDef
    ld      d,16
.OutputDotPatternLine:
    ld      a,(hl)
    inc     hl
    ld      b,16
.OutputDotPatternPixels:
    ld      e,$FF               ; transparent colour
    srl     a
    jr      nc,.TransparentDotPixel
    ld      e,$55               ; pixel colour
.TransparentDotPixel:
    out     (c),e
    djnz    .OutputDotPatternPixels
    dec     d
    jr      nz,.OutputDotPatternLine
    ret

DotPatternDef:
    db  %0110
    db  %1111
    db  %1111
    db  %0110
    db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

SetSpritePalette:
    ; Set sprite transparent-index to $FF
    NEXTREG_nn SPRITE_TRANSPARENCY_I_NR_4B, $FF
    ; select sprite palette 0, ULANext ON
    NEXTREG_nn PALETTE_CONTROL_NR_43, $21
    ; set whole sprite palette to $A2 violet (to signal some unexpected pixels if it shows)
    NEXTREG_nn PALETTE_INDEX_NR_40, 0
    ld      a,SPRITE_WRONG_PIX_COLOUR
    ld      b,0
.setWholeSpritePalLoop:
    NEXTREG_A PALETTE_VALUE_NR_41
    djnz    .setWholeSpritePalLoop
    ; set the few colours which are actually used for sprite patterns
    ld      hl,.SpritePalDef
.setSpritePalLoop:
    ld      a,(hl)
    or      a
    ret     z
    NEXTREG_A PALETTE_INDEX_NR_40
    inc     hl
    ld      a,(hl)
    NEXTREG_A PALETTE_VALUE_NR_41
    inc     hl
    jr      .setSpritePalLoop
.SpritePalDef:
    db      $02, %11100000, $04, %00011100, $01, %01001111  ; 4 bit colours pal.ofs=0
    db      $14, %11100000, $12, %00011100, $11, %01001111  ; 4 bit colours pal.ofs=16
    db      $44, %11101001, $22, %01011101, $55, %00000010  ; 8 bit colours (lighter than 4b)
    db      0

SetClipWindowAndNR15:
    ld      a,(Options)
    bit     OPT_BIT_CLIP,a
    ld      a,%00010011     ; Layers: USL, over border ON, sprites ON
    jr      z,.NoClip
    or      %00100000       ; enable clipping in over-border mode
    push    af
    ; set clip window coordinates to: [136,72] -> [287, 223]
    NEXTREG_nn CLIP_WINDOW_CONTROL_NR_1C, 2 ; reset sprite clip window index
    NEXTREG_nn CLIP_SPRITE_NR_19, 68    ; X1 (*2 in "over border" mode)
    NEXTREG_nn CLIP_SPRITE_NR_19, 143   ; X2 (*2 in "over border" mode)
    NEXTREG_nn CLIP_SPRITE_NR_19, 72    ; Y1
    NEXTREG_nn CLIP_SPRITE_NR_19, 223   ; Y2
    pop     af
.NoClip:
    ; set the NR15 to final value
    NEXTREG_A SPRITE_CONTROL_NR_15
    ret

UpdateKeysStatus:
    ld      bc,(Options)    ; C = options, B = number of options
    ld      hl,OptionsAttrOfs
    ld      de,MEM_ZX_ATTRIB_5800 + 16*32   ; target last third of attributes
.UpdateKeyLoop:
    ld      a,4+8*4         ; OFF colour
    rr      c
    jr      nc,.OptionIsOff
    ld      a,5+8*5         ; ON colour
.OptionIsOff:
    ld      e,(hl)          ; fetch target attribute address
    inc     hl
    ld      (de),a          ; update attribute with selected colour
    djnz    .UpdateKeyLoop
    ret

DrawUlaPart:
    ; yellow border (will be reconfigured in palette to grey)
    ld      a,YELLOW
    out     (ULA_P_FE),a

    ; show MachineID and core version
    ld      de,MEM_ZX_SCREEN_4000+16*256+6*32
    ld      bc,MEM_ZX_SCREEN_4000+16*256+7*32
    ld      ix,$ED01        ; display also extended info after MachineId
    call    OutMachineIdAndCore_defLabels

    ; setup ULANext + palette for ULA info graphics
    NEXTREG_nn PALETTE_CONTROL_NR_43, $01   ; select ULA palette 0, ULANext ON
    NEXTREG_nn PALETTE_FORMAT_NR_42, $07    ; ULANext ink format 7
    NEXTREG_nn PALETTE_INDEX_NR_40, 0       ; INK 0 = black
    NEXTREG_nn PALETTE_VALUE_NR_41, 0
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+7   ; PAPER 7 = transparent E3
    NEXTREG_nn PALETTE_VALUE_NR_41, $E3
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+6   ; BORDER 6 = grey
    NEXTREG_nn PALETTE_VALUE_NR_41, %01101101
    ; interactive key colours
    NEXTREG_nn PALETTE_INDEX_NR_40, 4       ; INK 4 = black
    NEXTREG_nn PALETTE_VALUE_NR_41, 0
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+4   ; PAPER 4 = bright pink
    NEXTREG_nn PALETTE_VALUE_NR_41, %11110110
    NEXTREG_nn PALETTE_INDEX_NR_40, 5       ; INK 5 = bright pink
    NEXTREG_nn PALETTE_VALUE_NR_41, %11110110
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+5   ; PAPER 5 = black
    NEXTREG_nn PALETTE_VALUE_NR_41, 0

    ; global transparency setup ($E3 -> ULA.white)
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14,$E3    ; $E3 is transparent colour for ULA
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,%10110110    ; transparency fallback = ULA white

    ; draw texts and target sprite area - sprite IDs (0..9,A..X), as defined in ReadMe.txt
    ld      hl,SpriteLabels
    ld      de,MEM_ZX_SCREEN_4000
    call    OutStringAtDe
    ; highlight interactive control keys
    call    UpdateKeysStatus

    ; draw target sprite area - rectangles around expected sprites (using custom font)
    NEXTREG_nn MMU1_2000_NR_51, 11          ; the font at $7D00 to $3D00
    ld      hl,SpriteLines
    ld      de,MEM_ZX_SCREEN_4000
    call    OutStringAtDe
    NEXTREG_nn MMU1_2000_NR_51, $FF         ; restore ROM in MMU1
    ret

SpriteLabels:
    ;    2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7
    ;    01234567890123456789012345678901
    db  '0    G                          '  ; 0 2
    db  ' -                              '  ; 1
    db  '6     1 7                       '  ; 2 3
    db  ' 5                     5        '  ; 3
    db  'I     2 4 H J 5   K   C         '  ; 4 4
    db  ' G     1 1 G G       G          '  ; 5
    db  '3     9           B             '  ; 6 5
    db  ' 1           5                  '  ; 7
    db  'E     8                     D   '  ; 8 6
    db  '                     A       A  '  ; 9
    db  'F                 A N       M   '  ; 0 7
    db  ' E           5       L A     L  '  ; 1
    db  '                                '  ; 2 8
    db  '                                '  ; 3
    db  '                                '  ; 4 9
    db  '                                '  ; 5
    db  '                                '  ; 6 0
    db  '                                '  ; 7
    db  '                                '  ; 8 1
    db  '                                '  ; 9
    db  'Qmarks  WshowAll  Eclip       L '  ; 0 2
    db  'AmirrorX  SmirrorY  Drotate     '  ; 1
    db  0

SpriteLines:
    ;    2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7
    ;    01234567890123456789012345678901
    db  " $  ' ,                         "  ; 0 2
    db  '&%    ##################        '  ; 1
    db  ' $   ! $               !        '  ; 2 3
    db  '&%   !&-&&&&&&&&&&&&&&&)        '  ; 3
    db  ' $   ! $ $ $ $   $   $ !        '  ; 4 4
    db  '&%   !&%&%&%&%   $&&&% !        '  ; 5
    db  ' $   !       $   $   $ !        '  ; 6 5
    db  '&%   !&&&&&&&%   $   $ !    &&  '  ; 7
    db  ' $   !       $   $   $ !   $ $  '  ; 8 6
    db  '&-   !       $   $&&&% !   $&%  '  ; 9
    db  ' $   !       $   $ $ $ !   $ $  '  ; 0 7
    db  '&%   !#######*###+#+#*#"   $&%  '  ; 1
    db  '                                '  ; 2 8
    db  '                                '  ; 3
    db  '                                '  ; 4 9
    db  '                                '  ; 5
    db  '                                '  ; 6 0
    db  '                                '  ; 7
    db  '                                '  ; 8 1
    db  '                                '  ; 9
    db  '                               ,'  ; 0 2
    db  '                               ('  ; 1
    db  0

    savesna "SpritRel.sna", Start
