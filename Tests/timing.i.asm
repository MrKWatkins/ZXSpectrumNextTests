    MACRO WAIT_FOR_SCANLINE scanline?
        ld      l, scanline?
        call    WaitForScanline
    ENDM

    MACRO WAIT_FOR_SCANLINE_MSB msb?
        ld      l, msb?
        call    WaitForScanlineMSB
    ENDM

    ; delays for (C-1)x4363T + Bx17T + 16T + 27T, where r=0 is as r=256
    MACRO IDLE_WAIT delay_counts?
        ld      bc,delay_counts?
        call    WaitForSomeCycles
    ENDM

    MACRO WAIT_HALF_SCANLINE_AFTER scanline?
        ld      l, scanline?
        call    WaitForScanlineAndHalf
    ENDM

; this is not precisely robust routine, it waits while (scanline-low8-bits < L)
; the code calling this should be partially aware where the scanline was prior
; and call it only when it makes sense (i.e. high bit of scanline is known to it)
WaitForScanline:    ; code is somewhat optimized to return ASAP when it happens
    ld      bc, TBBLUE_REGISTER_SELECT_P_243B
    ld      a, VIDEO_LINE_LSB_NR_1F
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
.waitLoop:
    in      a,(c)   ; read VIDEO_LINE_LSB_NR_1F
    cp      l
    jr      c,.waitLoop
    ret

; this waits until MSB is equal to L (0/1) (otherwise same gimmick as WaitForScanline)
WaitForScanlineMSB: ; code is somewhat optimized to return ASAP when it happens
    ld      bc, TBBLUE_REGISTER_SELECT_P_243B
    ld      a, VIDEO_LINE_MSB_NR_1E
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
    dec     l
    ld      l,1
    jr      z,.waitForMsbSet
.waitForMsbReset:
    in      a,(c)   ; read VIDEO_LINE_MSB_NR_1E
    and     l
    jr      nz,.waitForMsbReset
    ret
.waitForMsbSet:
    in      a,(c)   ; read VIDEO_LINE_MSB_NR_1E
    and     l
    jr      z,.waitForMsbSet
    ret

; similar as WaitForScanline, but even less precise, and waits cca. ~"half" of line extra
WaitForScanlineAndHalf:
    call    WaitForScanline
    ld      bc,$0401                ; wait until detected scanline is well over half
    ; continue with WaitForSomeCycles code

; delays for (C-1)x4363T + Bx17T + 16T, where r=0 is as r=256
; with "ld bc,** call Delay" the final duration is: (C-1)x4363T + Bx17T + 16T + 27T
WaitForSomeCycles:
    nop                             ; 4T
    djnz    WaitForSomeCycles       ; 13/8T = 4347T for B=0
    dec     c                       ; 4T
    jr      nz,WaitForSomeCycles    ; 12/7T
    ret                             ; 10T
