; Gratuitously nicked from the Scroll Nutter demo.

; Set Next hardware register using A
	MACRO NEXTREG_A register?
	dw $92ED
	db register?
	ENDM
	
; Set Next hardware register using an immediate value
	MACRO NEXTREG_nn register?, value?
	dw $91ED
	db register?
	db value?
	ENDM

; Set breakpoint for CSpect emulator (when it is executed with "-brk" option)
    MACRO CSPECT_BRK
        db  $DD, $01
    ENDM

; Set border to desired colour
    MACRO BORDER out_value?
        ld  a, out_value?
        out (ULA_P_FE), a
    ENDM