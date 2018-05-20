FillLayer2WithTestData
        ld e, 3				; Number of 16k banks we need to fill.

	ld a, %00000011			; Write paging enabled, Layer2 visible, video bank 0 selected.
        ld bc, LAYER2_ACCESS_PORT

@BankLoop
        out (c), a			; Page in the bank.

        ld d, 0				
        ld hl,0

@FillLoop
        ld (hl), d			
        inc d	
        inc l			
        jr nz, @FillLoop		; Write a line into the bank.
        inc h
	bit 6, h			; Test bit 6 of h; when this is non-zero we've hit 16k and the end of the bank.
        jr z, @FillLoop

        add	a, %01000000		; Update the control register value for the next bank.
        dec	e			
        jr nz, @BankLoop		; If we haven't done 3 banks carry on.
        ret