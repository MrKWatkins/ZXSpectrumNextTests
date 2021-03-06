    device zxspectrum48

SPRITE_POSX_BASE    equ 35      ; X coordinates are at offset to make "275" fit into byte

; this table is at $7FFE address, the low byte of address will also set up byte3 features
; (rotate|mirY|mirX = 2,4,8) (after 2x inc, i.e. first used will be $00 = no-extras)
    org     $7FFE
SpriteAnchorPositions:
; sprite anchor positions: X={35, 115, 195, 275}, Y={55, 145}
    db       35-SPRITE_POSX_BASE,  55
    db      115-SPRITE_POSX_BASE,  55
    db      195-SPRITE_POSX_BASE,  55
    db      275-SPRITE_POSX_BASE,  55
    db       35-SPRITE_POSX_BASE, 145
    db      115-SPRITE_POSX_BASE, 145
    db      195-SPRITE_POSX_BASE, 145
    db      275-SPRITE_POSX_BASE, 145
    db       75-SPRITE_POSX_BASE, 100   ; the invisible extra one!

BigSpriteVisibility_Normal:
    db      B4_VIS, B4_VIS, B4_VIS, B4_VIS
    db      B4_VIS, B4_VIS, B4_VIS, B4_VIS
    db      B4_INVIS

BigSpriteVisibility_Departed:
    db      B4_INVIS, B4_INVIS, B4_INVIS, B4_INVIS
    db      B4_INVIS, B4_INVIS, B4_INVIS, B4_VIS
    db      B4_INVIS, B4_INVIS, B4_INVIS, B4_INVIS
    db      B4_INVIS, B4_INVIS, B4_INVIS, B4_INVIS

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"
    INCLUDE "../../controls.i.asm"

SPRITE_WRONG_PIX_COLOUR equ $A2

OPT_BIT_SHOW    equ     0
OPT_BIT_CLIP    equ     1
OPT_BIT_PRIOR   equ     2
OPT_BIT_SCALEX  equ     3
OPT_BIT_SCALEY  equ     4
OPT_BIT_DEPART  equ     5
OPTIONS_COUNT   equ     6

Options:
    db      0       ; (1<<OPT_BIT_SHOW)
    db      OPTIONS_COUNT   ; must follow in memory right after options byte

BigSpriteScale:
    db      0

DepartedIndex:      ; valid values are 0..7 and 8 is OFF
    dw      8

OptionsAttrOfs:
    ;       show, clip, prior, scaleX, scaleY, depart
    db      5*32+0, 5*32+11, 5*32+19, 6*32+0, 6*32+10, 6*32+20 ; into last third of attribs

Start:
    call    StartTest
    ; register control keys
    REGISTER_KEY KEY_Q, KeyHandlerShowAll
    REGISTER_KEY KEY_W, KeyHandlerClipWindow
    REGISTER_KEY KEY_E, KeyHandlerPriority
    REGISTER_KEY KEY_A, KeyHandlerScaleX
    REGISTER_KEY KEY_S, KeyHandlerScaleY
    REGISTER_KEY KEY_D, KeyHandlerDepart
    ; draw ULA part of screen
    call    DrawUlaPart
    call    SetSpritePalette
RefreshSpritesAndLoop:
    call    SetClipWindowAndNR15
    call    LoadPatterns
    call    ShowSprites
.MainLoop:
    call    RefreshKeyboardState
    ; make ScaleX/Y/depart hotkeys just "blip" upon press (check debounceState for zero)
    ld      a,(debounceState)
    or      a
    jr      nz,.MainLoop
    ; force-clear scale and depart opt-bits and refresh VRAM attributes
    ld      hl,Options
    res     OPT_BIT_SCALEX,(hl)
    res     OPT_BIT_SCALEY,(hl)
    res     OPT_BIT_DEPART,(hl)
    call    UpdateKeysStatus    ; update the UI state
    jr      .MainLoop
    ;call    EndTest

KeyHandlerShowAll:
    ld      a,1<<OPT_BIT_SHOW
    jr      FlipOptionAndRefreshSprites
KeyHandlerClipWindow:
    ld      a,1<<OPT_BIT_CLIP
    jr      FlipOptionAndRefreshSprites
KeyHandlerPriority:
    ld      a,1<<OPT_BIT_PRIOR
    jr      FlipOptionAndRefreshSprites
KeyHandlerScaleX:
    ld      a,(BigSpriteScale)
    add     a,B5_X_2X   ; scaleY is in lower bits, so not affected by this
    and     B5_X_8X|B5_Y_8X
    ld      (BigSpriteScale),a
    ld      a,1<<OPT_BIT_SCALEX
    jr      FlipOptionAndRefreshSprites
KeyHandlerScaleY:
    ld      a,(BigSpriteScale)
    and     B5_X_8X
    ld      l,a         ; preserve scaleX value
    ld      a,(BigSpriteScale)
    add     a,B5_Y_2X
    and     B5_Y_8X     ; scaleY value only
    or      l           ; mix them together
    ld      (BigSpriteScale),a
    ld      a,1<<OPT_BIT_SCALEY
    jr      FlipOptionAndRefreshSprites
KeyHandlerDepart:
    ; loop DepartedIndex through values 8,7,..,0 (8 = OFF)
    ld      a,(DepartedIndex)
    dec     a
    jp      p,.ValidDepartedIndex
    ld      a,8
.ValidDepartedIndex:
    ld      (DepartedIndex),a
    ld      a,1<<OPT_BIT_DEPART
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

; this will intentionally prepare all sprite attributes data first into memory,
; to make inspection of actual data easier for emulator/core authors
; To inspect the data, breakpoint at "upload all sprite attributes"
ShowSprites:
    ; target buffer for all sprite attributes
    ld      de,SpriteAttributesBuffer
    call    PrepareFixedSprites
    call    PrepareDynamicBigSprites    ; these are dynamically patched
    ;; calculate amount of bytes defined
    ld      hl,(-SpriteAttributesBuffer)&$FFFF
    add     hl,de
    ex      de,hl       ; DE = bytes defined
    ;; upload the prepared attributes to port $57
    ; Select pattern and sprite slot 0
    ld      bc,SPRITE_STATUS_SLOT_SELECT_P_303B
    xor     a
    out     (c),a
    ; upload all sprite attributes
    ld      bc,SPRITE_ATTRIBUTE_P_57    ; B = 0 (in case first otir will be skipped)
    ld      hl,SpriteAttributesBuffer
    ; send the non-256* count part of data
    cp      e
    jr      z,.CountIsMultipleOf256
    ld      b,e
    otir
.CountIsMultipleOf256:
    ; send the remaining D-times 256 blocks
    cp      d
.Upload256BBlocks:
    ret     z
    otir
    dec     d
    jr      .Upload256BBlocks

PrepareDynamicBigSprites:
    ;; prepare the eight+1 big sprites (all possible rotate/mirror combinations + hidden)
    ld      hl,BigSpriteDef
    ld      ix,BigSpriteVisibility_Normal   ; IX = anchor visibility data
    ; check if "departed" is ON, then use the alternate data
    ld      a,(DepartedIndex)
    cp      8
    jr      z,.NotDeparted
    ld      hl,BigSpriteDef_departed
    ld      ix,BigSpriteVisibility_Departed
    ld      bc,(DepartedIndex)
    add     ix,bc
.NotDeparted:
    ld      bc,SpriteAnchorPositions    ; C = byte3 extra feature bits
.OneBigSprite:
    call    .PrepareOneBigSprite
    ; check if all big sprites were uploaded
    ld      a,(B3_ROTATE|B3_MIRRORY|B3_MIRRORX)+2
    cp      c
    jr      nz,.OneBigSprite
    ret
.PrepareOneBigSprite:
    push    hl          ; preserve pointer to source data
    ; prepare anchor sprite, offset by "SpriteAnchorPositions" offset data
    ld      a,(bc)
    inc     bc
    add     a,(hl)
    push    af          ; preserve CF for MSBX bit
    inc     hl
    ld      (de),a      ; byte 1 = X
    inc     de
    ld      a,(bc)
    inc     bc
    add     a,(hl)
    inc     hl
    ld      (de),a      ; byte 2 = Y
    inc     de
    pop     af          ; restore of CF for MSBX
    ld      a,(hl)
    adc     a,0         ; add MSBX
    inc     hl
    or      c           ; add byte 3 features (rotate/mirror)
    ld      (de),a      ; byte 3 = MSBX+rotate/mirror+pal.ofs
    inc     de
    ; byte 4
    ld      a,(Options)
    bit     OPT_BIT_SHOW,a
    ld      a,(hl)
    jr      z,.KeepAnchorRegularVisibility
    or      B4_VIS      ; enforce big sprite visible in "show all"
.KeepAnchorRegularVisibility:
    inc     hl
    or      (ix+0)      ; add anchor visibility
    inc     ix
    ld      (de),a      ; byte 4
    inc     de
    ld      a,(BigSpriteScale)
    or      (hl)        ; no MSBY
    inc     hl
    ld      (de),a      ; byte 5
    inc     de
    ; prepare relative sub-sprites
    push    bc          ; preserve X/Y offset data pointer
    ld      bc,BIG_SPRITE_REL_SZ
.RelativeSubspritesLoop:
    ldi     ; byte 1 X
    ldi     ; byte 2 Y
    ldi     ; byte 3 features
    ; byte 4
    ld      a,(Options)
    bit     OPT_BIT_SHOW,a
    ld      a,(hl)
    jr      z,.NoShowAll
    or      B4_VIS
.NoShowAll:
    ld      (de),a      ; byte 4 (patched with "showAll")
    inc     hl
    inc     de
    dec     bc
    ldi     ; byte 5
    jp      pe,.RelativeSubspritesLoop
    pop     bc          ; restore X/Y offset data pointer
    pop     hl          ; restore source data pointer
    ret

PrepareFixedSprites:    ; DE = memory buffer to prepare sprites
    ;; copy first sprites with fixed definitions (no dynamic patching)
    ld      hl,SpritesDefs
.PrepareSingleSprite:
    ldi
    ldi
    ldi
    ld      a,(hl)
    ldi
    and     B4_5BEXT
    jr      z,.Only4ByteDef
    ldi
.Only4ByteDef:
    ; loop until end address of data is reached
    ld      a,SpritesDefsEnd&$FF
    cp      l
    jr      nz,.PrepareSingleSprite
    ret

; sprite helper defs
; B1 = X LSB
; B2 = Y LSB
B3_PAL_MSK  equ     $F0
B3_ROTATE   equ     $02
B3_MIRRORY  equ     $04
B3_MIRRORX  equ     $08
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
    ; invalid colour test
    db  0, 224, $90+0, B4_VIS|NAME_S0
SpritesDefsEnd  equ $

BigSpriteDef:
    ; !!! KEEP IN SYNC with BigSpriteDef_departed data !!!
    ;; anchor of big-sprite
    db   SPRITE_POSX_BASE,  0, $40, NAME_S0|B4_5BEXT, B5_RELT_BIG
    ; big sprite subsprites flags:
    ; -YX -Y- RYZ
    ; RY- ... R-X
    ; R-- --X ---
.relativeSpritesData:
    db  -15, -15, $00|B3_MIRRORY|B3_MIRRORX,            B4_VIS|NAME_S0|B4_5BEXT,    B5_REL
    db   +2, -15, $D0|B3_MIRRORY|B3_REL_PAL,            B4_VIS|NAME_S1|B4_5BEXT,    B5_REL
    db   +6, -15, $20|B3_ROTATE|B3_MIRRORY|B3_MIRRORX,  B4_VIS|NAME_S2|B4_5BEXT,    B5_REL
    db   -4,  -4, 0,                                    B4_INVIS|NAME_RED|B4_5BEXT, B5_REL
    db   +6,  +3, $30|B3_ROTATE|B3_MIRRORX,             B4_VIS|NAME_S3|B4_5BEXT,    B5_REL
    db   +6,  +8, $50|0,                                B4_VIS|0|B4_5BEXT,          B5_REL|B5_REL_NAME
    db  -11,  +8, $60|B3_MIRRORX,                       B4_VIS|NAME_S1|B4_5BEXT,    B5_REL
    db  -15,  +8, $70|B3_ROTATE,                        B4_VIS|2|B4_5BEXT,          B5_REL|B5_REL_NAME
    db  -15, -10, $40|B3_ROTATE|B3_MIRRORY|B3_REL_PAL,  B4_VIS|NAME_S3|B4_5BEXT,    B5_REL
BIG_SPRITE_REL_SZ  equ  $ - .relativeSpritesData

BigSpriteDef_departed:      ; variant with the relatives being +-60px further away
    ; !!! KEEP IN SYNC with BigSpriteDef data !!!
    ;; anchor of big-sprite
    db   SPRITE_POSX_BASE,  0, $40, NAME_S0|B4_5BEXT, B5_RELT_BIG
.relativeSpritesData:
    db  -75, -75, $00|B3_MIRRORY|B3_MIRRORX,            B4_VIS|NAME_S0|B4_5BEXT,    B5_REL
    db   +2, -75, $D0|B3_MIRRORY|B3_REL_PAL,            B4_VIS|NAME_S1|B4_5BEXT,    B5_REL
    db  +66, -75, $20|B3_ROTATE|B3_MIRRORY|B3_MIRRORX,  B4_VIS|NAME_S2|B4_5BEXT,    B5_REL
    db   20,  20, 0,                                    B4_INVIS|NAME_RED|B4_5BEXT, B5_REL
    db  +66,  +3, $30|B3_ROTATE|B3_MIRRORX,             B4_VIS|NAME_S3|B4_5BEXT,    B5_REL
    db  +66, +68, $50|0,                                B4_VIS|0|B4_5BEXT,          B5_REL|B5_REL_NAME
    db  -11, +68, $60|B3_MIRRORX,                       B4_VIS|NAME_S1|B4_5BEXT,    B5_REL
    db  -75, +68, $70|B3_ROTATE,                        B4_VIS|2|B4_5BEXT,          B5_REL|B5_REL_NAME
    db  -75, -10, $40|B3_ROTATE|B3_MIRRORY|B3_REL_PAL,  B4_VIS|NAME_S3|B4_5BEXT,    B5_REL

NAME_S0     equ     4
NAME_S1     equ     5
NAME_S2     equ     6
NAME_S3     equ     7
NAME_RED    equ     8

LoadPatterns:
    ; Select initial pattern slot NAME_S0
    ld      bc, SPRITE_STATUS_SLOT_SELECT_P_303B
    ld      a,NAME_S0
    out     (c),a
    ; Upload bigsprite-build blocks pattern data (8 bit, created by bitmasks provided)
    ; 0 8b 7x9 arrowed "b", empty stomach, pixel colours: $01 ink, $FF transparent
    ; 1 8b 7x9 arrowed "b", dash stomach, pixel colours: $01 ink, $FF transparent
    ; 2 8b 7x9 arrowed "b", chequered stomach, pixel colours: $01 ink, $FF transparent
    ; 3 8b 7x9 arrowed "b", full stomach, pixel colours: $01 ink, $FF transparent
    ld      c, SPRITE_PATTERN_P_5B
    call    OutputBeePattern
    ; Upload the red square pattern for invisible test
    ; 4 256x $02
    ld      hl, OtherPatternsDef
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
    db      0, $02, 0, 0

OutputBeePattern:
    ld      hl, BeePatternsDef
    ld      d,4*16
.OutputBeePatternLine:
    ld      a,(hl)
    inc     hl
    ld      b,16
.OutputBeePatternPixels:
    ld      e,$FF               ; transparent colour
    srl     a
    jr      nc,.TransparentDotPixel
    ld      e,$01               ; pixel colour
.TransparentDotPixel:
    out     (c),e
    djnz    .OutputBeePatternPixels
    dec     d
    jr      nz,.OutputBeePatternLine
    ret

BeePatternsDef:
    db  %0000010    ; 7x9px pattern
    db  %0000111
    db  %0000010
    db  %0000010
    db  %0111110
    db  %1000010
    db  %1000010
    db  %1000010
    db  %0111110
    db  0, 0, 0, 0, 0, 0, 0

    db  %0000010    ; 7x9px pattern
    db  %0000111
    db  %0000010
    db  %0000010
    db  %0111110
    db  %1000010
    db  %1011010
    db  %1000010
    db  %0111110
    db  0, 0, 0, 0, 0, 0, 0

    db  %0000010    ; 7x9px pattern
    db  %0000111
    db  %0000010
    db  %0000010
    db  %0111110
    db  %1101010
    db  %1010110
    db  %1101010
    db  %0111110
    db  0, 0, 0, 0, 0, 0, 0

    db  %0000010    ; 7x9px pattern
    db  %0000111
    db  %0000010
    db  %0000010
    db  %0111110
    db  %1111110
    db  %1111110
    db  %1111110
    db  %0111110
    db  0, 0, 0, 0, 0, 0, 0

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
; Colours used are: red, orange, yellow, light yellow, (!here!) blue for anchor in middle,
; light green, green, cyan and light blue clockwise from top left corner.
    db      $01, %11000000, $11, %11001000, $21, %10110000
    db      $31, %11011000, $41, %00000011, $51, %01011101
    db      $61, %00011000, $71, %00011010, $81, %01001111
    db      $02, %11100000
    db      0

SetClipWindowAndNR15:
    ; set clip window coordinates to: [52,63] -> [283, 151]
    NEXTREG_nn CLIP_WINDOW_CONTROL_NR_1C, 2 ; reset sprite clip window index
    NEXTREG_nn CLIP_SPRITE_NR_19, 26    ; X1 (*2 in "over border" mode)
    NEXTREG_nn CLIP_SPRITE_NR_19, 141   ; X2 (*2 in "over border" mode)
    NEXTREG_nn CLIP_SPRITE_NR_19, 63    ; Y1
    NEXTREG_nn CLIP_SPRITE_NR_19, 151   ; Y2
    ; set NextReg $15 (sprite control and layer priorities)
    ld      a,%00010011     ; Layers: USL, over border ON, sprites ON
    ld      hl,Options
    bit     OPT_BIT_CLIP,(hl)
    jr      z,.NoClip
    or      %00100000       ; enable clipping in over-border mode
.NoClip:
    bit     OPT_BIT_PRIOR,(hl)
    jr      z,.DefaultPriority
    or      %01000000       ; flip sprite priority (sprite 0 on top)
.DefaultPriority:
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
    ld      de,MEM_ZX_SCREEN_4000+16*256+7*32
    ld      bc,MEM_ZX_SCREEN_4000+16*256+8*32-11
    ld      ix,$ED01        ; display also extended info after MachineId
    ld      hl,MachineInfoLabels
    call    OutMachineIdAndCore

    ; setup ULANext + palette for ULA info graphics
    NEXTREG_nn PALETTE_CONTROL_NR_43, $01   ; select ULA palette 0, ULANext ON
    NEXTREG_nn PALETTE_FORMAT_NR_42, $07    ; ULANext ink format 7
    NEXTREG_nn PALETTE_INDEX_NR_40, 0       ; INK 0 = white
    NEXTREG_nn PALETTE_VALUE_NR_41, %10110110
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+7   ; PAPER 7 = transparent E3
    NEXTREG_nn PALETTE_VALUE_NR_41, $E3
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+6   ; BORDER 6 = dark grey
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, %00100100
    NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, %00000001
    ; interactive key colours
    NEXTREG_nn PALETTE_INDEX_NR_40, 4       ; INK 4 = white
    NEXTREG_nn PALETTE_VALUE_NR_41, $FF
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+4   ; PAPER 4 = dark grey
    NEXTREG_nn PALETTE_VALUE_NR_41, %00100100
    NEXTREG_nn PALETTE_INDEX_NR_40, 5       ; INK 5 = dark grey
    NEXTREG_nn PALETTE_VALUE_NR_41, %00100100
    NEXTREG_nn PALETTE_INDEX_NR_40, 128+5   ; PAPER 5 = white
    NEXTREG_nn PALETTE_VALUE_NR_41, $FF

    ; global transparency setup ($E3 -> ULA.white)
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14,$E3        ; $E3 is transparent colour for ULA
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A,0    ; transparency fallback = black

    ; draw control texts
    ld      hl,SpriteLabels
    ld      de,MEM_ZX_SCREEN_4000+16*256+5*32
    call    OutStringAtDe
    ; highlight interactive control keys
    call    UpdateKeysStatus

    ; draw labels about orientation of each big sprite
    ld      hl,OrientationLabelsTxt
    ld      de,MEM_ZX_SCREEN_4000+1
    call    .OneLabelLine
    ld      de,MEM_ZX_SCREEN_4000+16*256+3*32+1
.OneLabelLine:
    ld      b,4
.OneLabelLineLoop:
    call    OutStringAtDe
    ld      a,e
    add     a,9
    ld      e,a
    djnz    .OneLabelLineLoop
    ret

MachineInfoLabels:
    db      'mID:', 0, 'c:', 0

SpriteLabels:
    db      'Q showAll  W clip  E priority   '
    db      'A scaleX  S scaleY  D depart',0

OrientationLabelsTxt:
    db      '---',0,'--r',0,'-y-',0,'-yr',0
    db      'x--',0,'x-r',0,'xy-',0,'xyr',0

SpriteAttributesBuffer:
    ds      128*5   ; area to prepare sprite attributes ahead, before sending to IO $57

    savesna "SpritBig.sna", Start
