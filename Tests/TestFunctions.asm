StartTest
	di		; Turn off interrupts in case they interfere.
	ret

EndTest
	jr EndTest	; Loop forever so we can take a screengrab.