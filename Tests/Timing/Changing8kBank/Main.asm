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
	or     $80         ; switch turbo mode ON
	NEXTREG_A  PERIPHERAL_2_NR_06
	; set up 14MHz speed
	NEXTREG_nn TURBO_CONTROL_NR_07, %10

TestLoop:
	halt
	call   StartTiming

	ld     bc, 7       ; Repeat switch 7*256 times. (b=0)
@BankSwitchWithNextReg:
	NEXTREG_nn MMU6_C000_NR_56, 32
	NEXTREG_nn MMU6_C000_NR_56, 33
	djnz   @BankSwitchWithNextReg
	dec    c
	jr     nz,@BankSwitchWithNextReg

	call   EndTiming

	jr     TestLoop

	savesna "Chg8kBan.sna", Start
