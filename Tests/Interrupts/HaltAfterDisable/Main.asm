	device zxspectrum48

	org	$6000

	INCLUDE "..\..\TestFunctions.asm"

Start
	call StartTest

	di

	halt		; Test should not proceed past this point!

	ld a, 2
       	out (254), a	; Set the border to red.

	call EndTest

	savesna "DIHalt.sna", Start