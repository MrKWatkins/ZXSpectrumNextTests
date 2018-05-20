	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\Macros.asm"
	INCLUDE "..\..\TestData.asm"

Start
	di
	ld sp, 0

	NEXTREG_nn SPRITE_CONTROL_REGISTER, %00010100	; Set ULA over Layer2 over sprites, with sprites not visible.

	call FillLayer2WithTestData

	ld a, %01011000
	call SetPaperWithA

	call InfiniteLoop

SetPaperWithA
	ld hl, $5800
	ld (hl), a			; Write A to the start of the attribute area.

	ld de, $5801			
	ld bc, 767
	ldir				; For 767 bytes we fill DE with the value from HL, i.e. copy the previous byte to the next.
	ret

InfiniteLoop
	jr InfiniteLoop



	savesna "DefTrans.sna", Start