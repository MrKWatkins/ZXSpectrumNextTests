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
