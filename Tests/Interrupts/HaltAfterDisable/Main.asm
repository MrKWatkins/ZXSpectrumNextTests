	device zxspectrum48

	org	$6000

	INCLUDE "../../Constants.asm"
	INCLUDE "../../TestFunctions.asm"

Start
	call StartTest
    ld a, GREEN
    out (ULA_P_FE), a	; Set the border to green

	di

	; also move stack pointer into attributes, so if interrupt handler is executed
	; it will be visible on damaged attributes
	ld sp,MEM_ZX_ATTRIB_5800+16*32

	halt		; Test should not proceed past this point!

    ld a, RED
    out (ULA_P_FE), a	; Set the border to red.

freezeHere:     ; freeze without touching stack to make attributes damaged only by handler
    jr  freezeHere

	savesna "DIHalt.sna", Start
