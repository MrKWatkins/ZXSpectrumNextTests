	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\Macros.asm"
	INCLUDE "..\..\TestData.asm"
	INCLUDE "..\..\TestFunctions.asm"

Start
	call StartTest

	NEXTREG_nn SPRITE_CONTROL_NR_15, %00010100	; Set ULA over Layer2 over sprites, with sprites not visible.

	call FillLayer2WithTestData

	ld a, %01011000
	call SetPaperWithA

	call EndTest

SetPaperWithA
	ld hl, MEM_ZX_ATTRIB_5800
	ld (hl), a			; Write A to the start of the attribute area.

	ld de, MEM_ZX_ATTRIB_5800+1
	ld bc, 767
	ldir				; For 767 bytes we fill DE with the value from HL, i.e. copy the previous byte to the next.
	ret



	savesna "DefTrans.sna", Start