	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\TestFunctions.asm"

Start
	call StartTest

	di

	halt		; Test should not proceed past this point!

    ld a, RED
    out (ULA_P_FE), a	; Set the border to red.

	call EndTest

	savesna "DIHalt.sna", Start
