	device zxspectrum48

	org	$6000

	INCLUDE "../../Constants.asm"
	INCLUDE "../../Macros.asm"
	INCLUDE "../../TestFunctions.asm"
	INCLUDE "../../OutputFunctions.asm"

Start:
	call   StartTest
	ld     hl,TestTxt
	ld     de,MEM_ZX_SCREEN_4000
	call   OutStringAtDe
	ei

	;; set Next speed to turbo mode at 14MHz
	; read current settings (to keep PS/2 and divMMC paging configuration intact)
	NEXTREG2A  PERIPHERAL_2_NR_06
	or     $80          ; switch turbo mode ON
	NEXTREG_A  PERIPHERAL_2_NR_06
	; set up 14MHz speed
	NEXTREG_nn TURBO_CONTROL_NR_07, %10
	; set RAM contention OFF
	NEXTREG2A  PERIPHERAL_3_NR_08
	or     $40          ; disable RAM contention
	NEXTREG_A  PERIPHERAL_3_NR_08
    ; make sure Layer2 is DISABLED
    ld      bc, LAYER2_ACCESS_P_123B
    xor     a
    out     (c), a

TestLoop:
	halt
	call   StartTiming

	ld     b, 0         ; Repeat switch block 256 times.
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
