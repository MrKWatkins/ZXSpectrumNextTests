	device zxspectrum48

	org	$6000

	INCLUDE "../../Constants.asm"
	INCLUDE "../../Macros.asm"
	INCLUDE "../../TestData.asm"
	INCLUDE "../../TestFunctions.asm"

Start
	call StartTest

	NEXTREG_nn SPRITE_CONTROL_NR_15, %00010100	; Set ULA over Layer2 over sprites, with sprites not visible.

	call FillLayer2WithTestData

	; set paper to bright magenta
	FILL_AREA MEM_ZX_ATTRIB_5800, 32*24, P_MAGENTA|A_BRIGHT

	call EndTest

	savesna "DefTrans.sna", Start