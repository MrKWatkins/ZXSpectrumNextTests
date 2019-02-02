	device zxspectrum48

	org	$6000

	INCLUDE "..\..\Constants.asm"
	INCLUDE "..\..\Macros.asm"
	INCLUDE "..\..\TestFunctions.asm"

Start:
	call   StartTest
	ei

	;; set Next speed to turbo mode at 14MHz
	; read current settings (to keep PS/2 and divMMC paging configuration intact)
	NEXTREG2A  PERIPHERAL_2_NR_06
	or     $80          ; switch turbo mode ON
	NEXTREG_A  PERIPHERAL_2_NR_06
	; set up 14MHz speed
	NEXTREG_nn TURBO_CONTROL_NR_07, %10
	; set RAM contention ON
	NEXTREG2A  PERIPHERAL_3_NR_08
	and    ~$40         ; enable RAM contention
	NEXTREG_A  PERIPHERAL_3_NR_08

    ld  bc, LAYER2_ACCESS_P_123B
    out (c), 0          ; make sure Layer2 is DISABLED

TestLoop:
	halt
	call   StartTiming

	ld     b, 0         ; Repeat switch block 256 times.
@BankSwitchWithNextReg: ; switch 16 pages in
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

	savesna "Chg8kBan.sna", Start
