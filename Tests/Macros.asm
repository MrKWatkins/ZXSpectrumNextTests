; Gratuitously nicked from the Scroll Nutter demo.

; Set Next hardware register using A
	MACRO NEXTREG_A register
	dw $92ED
	db register
	ENDM
	
; Set Next hardware register using an immediate value
	MACRO NEXTREG_nn register, value
	dw $91ED
	db register
	db value
	ENDM