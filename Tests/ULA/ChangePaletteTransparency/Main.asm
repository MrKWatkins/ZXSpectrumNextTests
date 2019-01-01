	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\Macros.asm"
	INCLUDE "..\..\TestData.asm"
	INCLUDE "..\..\TestFunctions.asm"

Start
	call StartTest

	NEXTREG_nn SPRITE_CONTROL_NR15, %00010100	; Set ULA over Layer2 over sprites, with sprites not visible.

	call FillLayer2WithTestData

	call ChangeUlaPalette

	call EndTest

ChangeUlaPalette
	NEXTREG_nn PALETTE_CONTROL_NR43, 0		; We're changing the ULA palette.
	NEXTREG_nn PALETTE_INDEX_NR40, 135		; Change paper 7 = 128 + 7 = 135.
	NEXTREG_nn PALETTE_VALUE_9BIT_NR44, $e3
	NEXTREG_nn PALETTE_VALUE_9BIT_NR44, 0	; Set to default transparent colour.
	ret



	savesna "CPalTran.sna", Start