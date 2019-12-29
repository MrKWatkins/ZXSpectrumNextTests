	device zxspectrum48

	org	$6000

	INCLUDE "../../Constants.asm"
	INCLUDE "../../Macros.asm"
	INCLUDE "../../TestFunctions.asm"
	INCLUDE "../../OutputFunctions.asm"

Start
	call StartTest
	ld     b,4
	ld     de,MEM_ZX_SCREEN_4000+4
	ld     hl,LegendaryText
.printLegendLoop:
	call   OutStringAtDe
	ex     de,hl
	call   AdvanceVramHlToNextLine
	ex     de,hl
	djnz   .printLegendLoop

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

LegendaryText:
    DB  'BORDER GREEN',0
    DB  'DI',0
    DB  'HALT',0
    DB  'BORDER RED',0

	savesna "DIHalt.sna", Start
