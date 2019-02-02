	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\Macros.asm"
	INCLUDE "..\..\TestFunctions.asm"

Start
	call StartTest

	NEXTREG_nn SPRITE_CONTROL_NR_15, %00000001	; Set sprites over Layer2 and ULA and enable sprites.
	NEXTREG_nn PALETTE_CONTROL_NR_43, $20   ; select sprite palette 0, ULANext off

	call LoadPattern

	call ShowSprite

	call CheckDefaultTransparencyIndex
	NEXTREG_nn PALETTE_INDEX_NR_40, 1       ; Change palette[S][0][1] = A (green/yellow)
	NEXTREG_A PALETTE_VALUE_NR_41

	call SetIdx2ColourInSpritePaletteToTransparent

	call EndTest

CheckDefaultTransparencyIndex:              ; returns green (OK)/yellow (ERR) colour in A
    ; test sprite transparency index
    NEXTREG2A SPRITE_TRANSPARENCY_I_NR_4B
    cp  $E3                                 ; A=E3 should be true after reset
    ld  a,%00001100                         ; return green colour when OK
    ret z
    ld  a,%10010000                         ; return yellow when error
    ret

SetIdx2ColourInSpritePaletteToTransparent:
    ; Set sprite transparent-index to 2
    NEXTREG_nn SPRITE_TRANSPARENCY_I_NR_4B, 2
    ; Set also colour 2 to red to signalize error in emulation, if it is somehow visible
    NEXTREG_nn PALETTE_INDEX_NR_40, 2       ; Change palette[S][0][2] = red
    NEXTREG_nn PALETTE_VALUE_NR_41, $e0
    ret

ShowSprite:
	ld bc, SPRITE_ATTRIBUTE_P_57
	ld a, 64
	out (c), a
	out (c), a					; Display the sprite at 64, 64.
	out (c), 0                  ; pal.ofs=0, mirror/rotation=0, X8=0
	ld a, %10000000             ; visible=1, 4 bytes struct only, pattern=0
	out (c), a					; Make the sprite visible.
	ret

LoadPattern
	ld bc, SPRITE_STATUS_SLOT_SELECT_P_303B
	out (c), 0					; Write to pattern slot 0.

	ld bc, SPRITE_PATTERN_P_5B  ; b=0 as counter
	ld hl, Pattern
	otir                        ; send 256 bytes to $xx5B port (uploads whole pattern)
	ret

; Sprite is divided into four squares, top left bottom right are coloured index 2, the other two coloured index 1.
Pattern:            ; avoiding index 0 in case some emulator defaults to 0 with $4B
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $02, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
	defb $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02

	savesna "SpritTra.sna", Start
