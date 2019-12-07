    device zxspectrum48

    org     $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

    MACRO FILL_SPRITE_PATTERN bytes?    ; with value in A
        ld      b,bytes?
.fillLoop:
        out     (SPRITE_PATTERN_P_5B),a
        djnz    .fillLoop
    ENDM

Start:
    NEXTREG_nn  TURBO_CONTROL_NR_07,3       ; 28MHz
    call    StartTest
    ld      de,MEM_ZX_SCREEN_4000+18
    ld      bc,MEM_ZX_SCREEN_4000+32+18
    call    OutMachineIdAndCore_defLabels
    ; rulers for visibility on/off
    ld      a,$F8
    ld      (MEM_ZX_SCREEN_4000+17+$20*1+$100*0),a
    ld      a,$E0
    ld      (MEM_ZX_SCREEN_4000+17+$20*1+$100*4),a
    ld      a,$C0
    ld      (MEM_ZX_SCREEN_4000+17+$20*0+$100*6),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*1+$100*2),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*1+$100*6),a
    ld      a,$03
    ld      (MEM_ZX_SCREEN_4000+14+$20*0+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*0+$100*7),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*1+$100*1),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*1+$100*3),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*1+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*1+$100*7),a
    ld      a,$3C
    ld      (MEM_ZX_SCREEN_4000+14+$20*1+$100*0),a
    ld      a,$0C
    ld      (MEM_ZX_SCREEN_4000+14+$20*1+$100*4),a
    ld      de,MEM_ZX_SCREEN_4000+$20*1
    ld      hl,LegendaryText_T0
    call    OutStringAtDe
    ; rulers for rotate/mirror and X position on/off
    ld      a,$F8
    ld      (MEM_ZX_SCREEN_4000+17+$20*3+$100*0),a
    ld      a,$E0
    ld      (MEM_ZX_SCREEN_4000+17+$20*3+$100*4),a
    ld      a,$C0
    ld      (MEM_ZX_SCREEN_4000+17+$20*2+$100*6),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*3+$100*2),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*3+$100*6),a
    ld      a,$03
    ld      (MEM_ZX_SCREEN_4000+14+$20*2+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*2+$100*7),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*3+$100*1),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*3+$100*3),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*3+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*3+$100*7),a
    ld      a,$3C
    ld      (MEM_ZX_SCREEN_4000+14+$20*3+$100*0),a
    ld      a,$0C
    ld      (MEM_ZX_SCREEN_4000+14+$20*3+$100*4),a
    ld      de,MEM_ZX_SCREEN_4000+$20*3
    ld      hl,LegendaryText_T1
    call    OutStringAtDe
    ; rulers for transparency index
    ld      a,$F8
    ld      (MEM_ZX_SCREEN_4000+17+$20*5+$100*0),a
    ld      a,$E0
    ld      (MEM_ZX_SCREEN_4000+17+$20*5+$100*4),a
    ld      a,$C0
    ld      (MEM_ZX_SCREEN_4000+17+$20*4+$100*6),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*5+$100*2),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*5+$100*6),a
    ld      a,$03
    ld      (MEM_ZX_SCREEN_4000+14+$20*4+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*4+$100*7),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*5+$100*1),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*5+$100*3),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*5+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*5+$100*7),a
    ld      a,$3C
    ld      (MEM_ZX_SCREEN_4000+14+$20*5+$100*0),a
    ld      a,$0C
    ld      (MEM_ZX_SCREEN_4000+14+$20*5+$100*4),a
    ld      de,MEM_ZX_SCREEN_4000+$20*5
    ld      hl,LegendaryText_T2
    call    OutStringAtDe
    ; rulers for palette item change
    ld      a,$F8
    ld      (MEM_ZX_SCREEN_4000+17+$20*7+$100*0),a
    ld      a,$E0
    ld      (MEM_ZX_SCREEN_4000+17+$20*7+$100*4),a
    ld      a,$C0
    ld      (MEM_ZX_SCREEN_4000+17+$20*6+$100*6),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*7+$100*2),a
    ld      (MEM_ZX_SCREEN_4000+17+$20*7+$100*6),a
    ld      a,$03
    ld      (MEM_ZX_SCREEN_4000+14+$20*6+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*6+$100*7),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*7+$100*1),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*7+$100*3),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*7+$100*5),a
    ld      (MEM_ZX_SCREEN_4000+14+$20*7+$100*7),a
    ld      a,$3C
    ld      (MEM_ZX_SCREEN_4000+14+$20*7+$100*0),a
    ld      a,$0C
    ld      (MEM_ZX_SCREEN_4000+14+$20*7+$100*4),a
    ld      de,MEM_ZX_SCREEN_4000+$20*7
    ld      hl,LegendaryText_T3
    call    OutStringAtDe
    ;; 4/5 byte type check legend:
    ld      hl,LegendaryText_AttribsHandling
    ld      de,MEM_ZX_SCREEN_4000+$800+$20*1
    call    OutStringAtDe
    ld      de,MEM_ZX_SCREEN_4000+$800+$20*6
    call    OutStringAtDe
    BORDER  CYAN

    ; setup sprite palette0 to default 8bit index=RGB
    NEXTREG_nn  PALETTE_CONTROL_NR_43,%00100000     ; sprites first palette, auto-increment
    NEXTREG_nn  PALETTE_INDEX_NR_40,0
    xor     a
.setSpritePalLoop:
    NEXTREG_A   PALETTE_VALUE_NR_41
    inc     a
    jr      nz,.setSpritePalLoop
    ; setup sprites control registers
    ld      a,PERIPHERAL_4_NR_09
    call    ReadNextReg
    set     4,a
    NEXTREG_A   PERIPHERAL_4_NR_09  ; set "lockstep" for port $303B <-> nextreg $34
    NEXTREG_nn  SPRITE_CONTROL_NR_15,3  ; sprites visible + over border, everything else to 0 (SLU order, etc)
    NEXTREG_nn  SPRITE_TRANSPARENCY_I_NR_4B,$1F ; bright cyan index is transparent
    ; set up sprite-pattern 0 (the only one used in the test)
    NEXTREG_nn  SPRITE_ATTR_SLOT_SEL_NR_34,0    ; index of pattern/attributes = 0
    ; cyan 8px, 8px transparent
    ld      a,%000'101'10 : FILL_SPRITE_PATTERN 8 : ld a,$1F : FILL_SPRITE_PATTERN 8
    ; red 8px, 8px transparent
    ld      a,%110'000'00 : FILL_SPRITE_PATTERN 8 : ld a,$1F : FILL_SPRITE_PATTERN 8
    ; yellow 8px, 8px transparent
    ld      a,%111'101'00 : FILL_SPRITE_PATTERN 8 : ld a,$1F : FILL_SPRITE_PATTERN 8
    ; green 8px, 8px transparent
    ld      a,%000'101'00 : FILL_SPRITE_PATTERN 8 : ld a,$1F : FILL_SPRITE_PATTERN 8
    ; violet 8px, 8px transparent
    ld      a,%101'000'10 : FILL_SPRITE_PATTERN 8 : ld a,$1F : FILL_SPRITE_PATTERN 8
    ; white 8px, 8px transparent
    ld      a,%111'111'11 : FILL_SPRITE_PATTERN 8 : ld a,$1F : FILL_SPRITE_PATTERN 8
    ; black 8px, 8px transparent
    ld      a,%000'000'00 : FILL_SPRITE_PATTERN 8 : ld a,$1F : FILL_SPRITE_PATTERN 8
    ; make rest of the sprite transparent
    ld      a,$1F         : FILL_SPRITE_PATTERN 16*16-7*16
        ; cyan    -2
        ; red     -1
        ; yellow  +0
        ; green   +1
        ; violet  +2
        ; white   +3
        ; black   +4
    ; set up sprite 0 attributes (on left side inside rulers, will be visible all time)
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+120       ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,VIS_SPR_Y    ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$0           ; all default/off, X MSB = 0
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$80          ; visible, 4-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$0       ; just clear fifth byte to be sure
    ; set up sprite 1 attributes (on right side inside rulers, will be visible only for one scanline)
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+129       ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,VIS_SPR_Y    ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$0           ; all default/off, X MSB = 0
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$80          ; visible, 4-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$0       ; just clear fifth byte to be sure
    ; set up sprite 2 (rotation/position measuring)
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+120       ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,ROTPOS_S_Y   ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$00          ; X MSB = 0, rotate, mirrorX OFF
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$80          ; visible, 4-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$00      ; just clear fifth byte to be sure
    ; set up sprite 3 (rotation/position measuring)
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+120       ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,TRANS_S_Y    ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$00          ; X MSB = 0
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$80          ; visible, 4-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$00      ; just clear fifth byte to be sure
    ; set up sprite 4 (palette color measuring)
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+120       ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,PAL_S_Y      ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$00          ; X MSB = 0
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$80          ; visible, 4-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$00      ; just clear fifth byte to be sure

    ;; 4/5 byte type check sprites
    ; sprite 5: 4 byte type + explicit zero written to fifth
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+16*0+6    ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,TYPES_SPR_Y  ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$00          ; X MSB = 0, no rotate/mirror/pal offset
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$80          ; visible, 4-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$00      ; explicit zeroing of fifth byte
    ; sprite 6: 4 byte type converted from 5 byte type (scaleY) (fifth byte non-zero ahead)
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+16*1+6    ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,TYPES_SPR_Y  ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$00          ; X MSB = 0, no rotate/mirror/pal offset
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$C0          ; visible, 5-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_NR_39,$02          ; 2xY, 8bit gfx, composite anchor, Y8=0
        ; convert it to to 4-byte type after 5-byte (not touching fifth byte)
    NEXTREG_nn  SPRITE_ATTR3_INC_NR_78,$80      ; visible, 4-byte system, pattern 0
    ; sprite 7: 4 byte type + explicit non-zero (scaleY) written to fifth after fourth
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+16*2+6    ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,TYPES_SPR_Y  ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$00          ; X MSB = 0, no rotate/mirror/pal offset
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$80          ; visible, 4-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$02      ; 2xY, but should not affect display
    ; sprite 8: 5 byte type +scaleY
    NEXTREG_nn  SPRITE_ATTR0_NR_35,32+16*3+6    ; X 8b LSB
    NEXTREG_nn  SPRITE_ATTR1_NR_36,TYPES_SPR_Y  ; Y 8b LSB
    NEXTREG_nn  SPRITE_ATTR2_NR_37,$00          ; X MSB = 0, no rotate/mirror/pal offset
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$C0          ; visible, 5-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_INC_NR_79,$02      ; 2xY, 8bit gfx, composite anchor, Y8=0
    jr      .setupByPort

    ; data for the setup
.PortSpritesData:
    DB      32+16*0+6, TYPES_SPR_Y+32, $00, $80 ; sprite 9: 4 byte type
    DB      32+16*1+6, TYPES_SPR_Y+32, $00, $C0, $02    ; sprite 10: 5 byte type
.PortSpriteSz   EQU     $-.PortSpritesData

    ;; 4/5 byte type check sprites set by I/O port + check lockstep of PERIPHERAL_4_NR_09
    ; the port should now point to the sprite id 9, same as next registers
.setupByPort:
    ; first set sprite 9 to be 5-byte with 2xY scale by nextregs
    NEXTREG_nn  SPRITE_ATTR3_NR_38,$C0          ; visible, 5-byte system, pattern 0
    NEXTREG_nn  SPRITE_ATTR4_NR_39,$02          ; 2xY, 8bit gfx, composite anchor, Y8=0
    ; now overwrite sprite 9 through port and add sprite 10
    ld      bc,.PortSpriteSz<<8 | SPRITE_ATTRIBUTE_P_57  ; BC = counter + port
    ld      hl,.PortSpritesData
    otir

    ; create copper to multiplex it over several lines and hide it above/below
    NEXTREG_nn  COPPER_CONTROL_HI_NR_62,0
    NEXTREG_nn  COPPER_CONTROL_LO_NR_61,0
    ld      b,CopperCodeLength
    ld      hl,CopperCode
.SetupCopperLoop:
    ld      a,(hl)
    inc     hl
    NEXTREG_A   COPPER_DATA_NR_60
    djnz    .SetupCopperLoop
    NEXTREG_nn  COPPER_CONTROL_HI_NR_62,$C0     ; START copper, reset at Vblank

    jp      EndTest

VIS_TARGET_Y    EQU     8   ; in ULA coordinates, which scanline is active (+0) offset
    ; the copper is programmed to trigger actually at VIS_TARGET_Y-1 scanline, but in the
    ; H-blank period AFTER the scanline should be rendered already, i.e. ahead of VIS_TARGET_Y
    ; left border area ... in most of the emulators collecting some nextregs once per
    ; scanline for rendering of scanline, this will actually affect the VIS_TARGET_Y-1 line (!)
VIS_SPR_Y       EQU     VIS_TARGET_Y+32-2   ; display sprites already two scanlines above

ROTPOS_T_Y      EQU     VIS_TARGET_Y+16
ROTPOS_S_Y      EQU     ROTPOS_T_Y+32-2

TRANS_T_Y       EQU     ROTPOS_T_Y+16
TRANS_S_Y       EQU     TRANS_T_Y+32-2

PAL_T_Y         EQU     TRANS_T_Y+16
PAL_S_Y         EQU     PAL_T_Y+32-2

TYPES_SPR_Y     EQU     32+8*11+6

CopperCode:     ;; remember the copper instructions are big endian (bytes: WAIT/REGISTER, scanline/value)
    DW  SPRITE_ATTR_SLOT_SEL_NR_34|(1<<8)       ; select second sprite (first one to modify on fly)
    DW  PALETTE_CONTROL_NR_43|(%10000000<<8)    ; ULA first palette, auto-increment OFF
    DW  PALETTE_INDEX_NR_40|(16+7<<8)           ; index of white paper (bright 0) (will be used a lot)
    ; in h-blank of previous scanline, make the second sprite visible
    DW  COPPER_WAIT_H|(35<<1)|(VIS_TARGET_Y-1<<8)
    DW  SPRITE_ATTR3_NR_38|($80<<8)             ; visible ON sprite
    DW  PALETTE_VALUE_NR_41|(%011'101'10<<8)    ; bright cyan paper in ULA (also active scanline)
    ; in h-blank of target scanline, make the second sprite invisible again
    DW  COPPER_WAIT_H|(35<<1)|(VIS_TARGET_Y<<8)
    DW  SPRITE_ATTR3_INC_NR_78|($00<<8)         ; visible OFF sprite ++sprite index
    DW  PALETTE_VALUE_NR_41|(%101'101'10<<8)    ; regular white paper in ULA
    ; sprite 2 test (rotation/position test)
    DW  COPPER_WAIT_H|(35<<1)|(ROTPOS_T_Y-1<<8)
    DW  SPRITE_ATTR0_NR_35|(32+129<<8)          ; move it to right with X coordinate
    DW  SPRITE_ATTR2_NR_37|($0A<<8)             ; switch ON ROTATE+MIRRORX
    DW  PALETTE_VALUE_NR_41|(%110'110'10<<8)    ; bright yellow paper in ULA
    DW  COPPER_WAIT_H|(35<<1)|(ROTPOS_T_Y<<8)
    DW  SPRITE_ATTR0_NR_35|(32+120<<8)          ; move it back
    DW  SPRITE_ATTR2_INC_NR_77|($00<<8)         ; switch OFF ROTATE+MIRRORX
    DW  PALETTE_VALUE_NR_41|(%101'101'10<<8)    ; regular white paper in ULA
    ; sprite 3 test (transparency index test)
    DW  COPPER_WAIT_H|(35<<1)|(TRANS_T_Y-1<<8)
    DW  SPRITE_TRANSPARENCY_I_NR_4B|(1<<8)      ; transparency index set to $01 (blue)
    DW  PALETTE_VALUE_NR_41|(%101'011'10<<8)    ; bright yellow paper in ULA
    DW  COPPER_WAIT_H|(35<<1)|(TRANS_T_Y<<8)
    DW  SPRITE_TRANSPARENCY_I_NR_4B|($1F<<8)    ; transparency index back to $1F
    DW  PALETTE_VALUE_NR_41|(%101'101'10<<8)    ; regular white paper in ULA
    ; sprite 4 test (palette color measuring)
    DW  COPPER_WAIT_H|(35<<1)|(PAL_T_Y-5<<8)
    DW  SPRITE_TRANSPARENCY_I_NR_4B|(1<<8)      ; transparency index to $01 (make sprite fully visible)
    DW  COPPER_WAIT_H|(35<<1)|(PAL_T_Y-1<<8)
    DW  PALETTE_VALUE_NR_41|(%011'101'10<<8)    ; bright cyan paper in ULA
    DW  PALETTE_CONTROL_NR_43|(%10100000<<8)    ; Sprites first palette, auto-increment OFF
    DW  PALETTE_INDEX_NR_40|($1F<<8)            ; index $1F (the right side of sprite pattern)
    DW  PALETTE_VALUE_NR_41|(%111'100'00<<8)    ; orange color (but transparency is index-based)
    DW  COPPER_WAIT_H|(35<<1)|(PAL_T_Y<<8)
    DW  PALETTE_VALUE_NR_41|($1F<<8)            ; back to $1F color (to make it transparent)
    DW  PALETTE_CONTROL_NR_43|(%10000000<<8)    ; ULA first palette, auto-increment OFF
    DW  PALETTE_INDEX_NR_40|(16+7<<8)           ; index of white paper (bright 0) (will be used a lot)
    DW  PALETTE_VALUE_NR_41|(%101'101'10<<8)    ; regular white paper in ULA
    DW  COPPER_WAIT_H|(35<<1)|(PAL_T_Y+7<<8)
    DW  SPRITE_TRANSPARENCY_I_NR_4B|($1F<<8)    ; transparency index back to $1F

    DW  COPPER_HALT_B|(COPPER_HALT_B<<8)    ; copper HALT
CopperCodeLength EQU $ - CopperCode

LegendaryText_T0:
    DB  'Visibility:',0
LegendaryText_T1:
    DB  'RotMir / Xpos:',0
LegendaryText_T2:
    DB  'Transp. index:',0
LegendaryText_T3:
    DB  'Palette color:',0
LegendaryText_AttribsHandling:
    DB  '________________________________'
    DB  'Setup by NextRegs, check 4B/5B:',0
    DB  'Setup by I/O port:',0

    ASSERT  $ < $E000
    savesna "SprDelay.sna", Start
