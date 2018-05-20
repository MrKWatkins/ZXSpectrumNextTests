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

	call ChangeUlaPalette

	call InfiniteLoop

ChangeUlaPalette
	NEXTREG_nn PALETTE_CONTROL_REGISTER, 0		; We're changing the ULA palette.
	NEXTREG_nn PALETTE_INDEX_REGISTER, 135		; Change paper 7 = 128 + 7 = 135.
	NEXTREG_nn PALETTE_VALUE_BIT9_REGISTER, $e3
	NEXTREG_nn PALETTE_VALUE_BIT9_REGISTER, 0	;Set to default transparent colour.
	ret

InfiniteLoop
	jr InfiniteLoop



	savesna "CPalTran.sna", Start