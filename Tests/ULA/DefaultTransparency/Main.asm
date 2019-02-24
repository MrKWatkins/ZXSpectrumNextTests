	device zxspectrum48

	org	$6000

	INCLUDE "../../Constants.asm"
	INCLUDE "../../Macros.asm"
	INCLUDE "../../TestData.asm"
	INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"

Start
	call StartTest
    ld   hl,TestTxt
    ld   de,MEM_ZX_SCREEN_4000
    call OutStringAtDe

	NEXTREG_nn SPRITE_CONTROL_NR_15, %00010100	; Set ULA over Layer2 over sprites, with sprites not visible.
    ; default "pink" as transparency colour and bright cyan as transparency fallback
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14, $E3
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A, $1F

	call FillLayer2WithTestData

	; set paper to bright magenta
	FILL_AREA MEM_ZX_ATTRIB_5800, 32*24, P_MAGENTA|A_BRIGHT

	call EndTest

TestTxt:
    db  ' Magenta paper + this text = OK', 0

	savesna "DefTrans.sna", Start