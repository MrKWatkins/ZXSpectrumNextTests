StartTest
	di		; Turn off interrupts in case they interfere.
	ret

EndTest
	jr EndTest	; Loop forever so we can take a screengrab.

StartTiming
	ld a, 4         
       	out (254), a	; Set the border to green.
       	ret

EndTiming
	ld a, 0         
       	out (254), a	; Set the border to black.
       	ret