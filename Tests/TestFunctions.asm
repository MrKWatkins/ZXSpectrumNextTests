StartTest
	di		; Turn off interrupts in case they interfere.
	ret

EndTest
	jr EndTest	; Loop forever so we can take a screengrab.

StartTiming
    ; Set the border to green.
    ld a, GREEN
    out (ULA_P_FE), a
    ret

EndTiming
    ; Set the border to black.
    ld a, BLACK
    out (ULA_P_FE), a
    ret

ReadNextReg:
    ; reads nextreg in A into A (does modify currently selected NextReg on I/O port)
    push    bc
    ld      bc, TBBLUE_REGISTER_SELECT_P_243B
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
    in      a,(c)   ; read desired NextReg state
    pop     bc
    ret

; Read NextReg into A (does modify A, and NextReg selected on the I/O port)
; is not optimized for speed + restores BC
    MACRO NEXTREG2A register
        ld     a, register
        call   ReadNextReg
    ENDM

WriteNextRegByIo:
    ; writes value A into nextreg B (does modify currently selected NextReg on I/O port)
    push    bc
    push    af
    ld      a,b
    ld      bc, TBBLUE_REGISTER_SELECT_P_243B
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
    pop     af
    out     (c),a   ; write value
    pop     bc
    ret
