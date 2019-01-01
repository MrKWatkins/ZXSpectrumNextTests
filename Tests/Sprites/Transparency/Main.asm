	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\Macros.asm"
	INCLUDE "..\..\TestData.asm"
	INCLUDE "..\..\TestFunctions.asm"

Start
	call StartTest

	NEXTREG_nn SPRITE_CONTROL_NR_15, %00000001	; Set sprites over Layer2 and ULA and enable sprites.

	call LoadPattern

	call ShowSprite

	call SetFirstColourInSpritePaletteToTransparent

	call EndTest

SetFirstColourInSpritePaletteToTransparent
	NEXTREG_nn PALETTE_CONTROL_NR_43, $20	; We're changing the sprite palette.
	NEXTREG_nn PALETTE_INDEX_NR_40, 0		; Change the first colour in the palette, index 0.
	NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, $e3
	NEXTREG_nn PALETTE_VALUE_9BIT_NR_44, 0	; Set to default transparent colour.
	ret

ShowSprite
	ld bc, SPRITE_ATTRIBUTE_P_57
	ld a, 64
	out (c), a
	out (c), a					; Display the sprite at 64, 64.
	out (c), 0
	ld a, %10000000
	out (c), a					; Make the sprite visible.
	ret

LoadPattern
	ld bc, SPRITE_STATUS_SLOT_SELECT_P_303B
	out (c), 0					; Write to pattern slot 0.

	ld bc, SPRITE_PATTERN_P_5B
	ld hl, Pattern
	ld a, 0

@Loop
	outi						; Write a byte to the port, increase HL and decrease B.
	inc b						; Increase B so it points at the port again.
	dec a
	jr nz, @Loop

	ret

; Sprite is divided into four squares, top left bottom right are coloured index 0, the other two coloured index 1.
Pattern
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00
	defb $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00

	savesna "SpritTra.sna", Start
