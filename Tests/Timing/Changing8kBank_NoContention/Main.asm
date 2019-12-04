	device zxspectrum48

	org	$6000

	INCLUDE "../../Constants.asm"
	INCLUDE "../../Macros.asm"
	INCLUDE "../../TestFunctions.asm"
	INCLUDE "../../OutputFunctions.asm"

Start:
	call   StartTest
	ld     hl,TestTxt
	ld     de,MEM_ZX_SCREEN_4000+1
	call   OutStringAtDe
	ld     d,$E0
	ld     bc,$0118
	ld     hl,MEM_ZX_SCREEN_4000
	call   FillSomeUlaLines
	ld     d,$80
	ld     bc,$0118
	ld     hl,MEM_ZX_SCREEN_4000+$400
	call   FillSomeUlaLines
	ld     a,$FC
	ld     (MEM_ZX_SCREEN_4000),a
	ld     (MEM_ZX_SCREEN_4000+$800),a
	ld     (MEM_ZX_SCREEN_4000+$1000),a
	ld     a,A_BRIGHT|P_GREEN|BLACK
	ld     hl,MEM_ZX_ATTRIB_5800
	ld     de,32
	ld     b,24
.doAttribsRainbow:
	ld     (hl),a
	add    hl,de
	add    a,P_BLUE
	and    P_WHITE
	or     A_BRIGHT|P_GREEN
	djnz   .doAttribsRainbow
	ei

	; set up base 3.5MHz speed (turbo modes have contention OFF)
	NEXTREG_nn TURBO_CONTROL_NR_07, %00
	; set RAM contention OFF
	NEXTREG2A  PERIPHERAL_3_NR_08
	or     $40          ; disable RAM contention
	NEXTREG_A  PERIPHERAL_3_NR_08

TestLoop:
	halt
	call   StartTiming

	ld     b,128           ; Repeat switch block N times.
@BankSwitchWithNextReg: ; switch 16 pages in
    ; this is intentionally as multiple NEXTREG instructions not in loop, to make major
    ; part of time spent come from the switching itself, and not from loop instructions
	NEXTREG_nn MMU6_C000_NR_56, 11
	NEXTREG_nn MMU6_C000_NR_56, 12
	NEXTREG_nn MMU6_C000_NR_56, 13
	NEXTREG_nn MMU6_C000_NR_56, 14
	NEXTREG_nn MMU6_C000_NR_56, 15
	NEXTREG_nn MMU6_C000_NR_56, 16
	NEXTREG_nn MMU6_C000_NR_56, 17
	NEXTREG_nn MMU6_C000_NR_56, 18
	NEXTREG_nn MMU6_C000_NR_56, 19
	NEXTREG_nn MMU6_C000_NR_56, 20
	NEXTREG_nn MMU6_C000_NR_56, 21
	NEXTREG_nn MMU6_C000_NR_56, 22
	NEXTREG_nn MMU6_C000_NR_56, 23
	NEXTREG_nn MMU6_C000_NR_56, 24
	NEXTREG_nn MMU6_C000_NR_56, 25
	NEXTREG_nn MMU6_C000_NR_56, 26
	djnz   @BankSwitchWithNextReg

	call   EndTiming

	jr     TestLoop

TestTxt:
    db      '256x 8k switch, contention OFF', 0

	savesna "Chg8kB_2.sna", Start
