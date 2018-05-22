	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\Macros.asm"
	INCLUDE "..\..\TestFunctions.asm"

Start
	call StartTest

	ei

TestLoop
	halt

	call StartTiming

	ld a, 0				; Repeat switch 256 times.

@BankSwitchWithNextReg
	NEXTREG_nn MMU_REGISTER_6, 32
	NEXTREG_nn MMU_REGISTER_6, 33

        dec a
        jr nz, @BankSwitchWithNextReg

	call EndTiming

	call TestLoop

	savesna "Chg8kBan.sna", Start