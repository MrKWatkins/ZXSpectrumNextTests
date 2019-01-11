StartTest:
    di                      ; Turn off interrupts in case they interfere.
    ; clear ULA screen to: BORDER 7 : PAPER 7 : INK 0 : CLS
    ; - this removes any ULA artefacts left by SNA loaders and majority of tests expects
    ;   this "BASIC" state of screen, so let's make sure it is like that.
    ld      a,WHITE
    out     (ULA_P_FE),a    ; BORDER 7
    ld      hl,MEM_ZX_SCREEN_4000
    ld      de,MEM_ZX_SCREEN_4000+1
    ld      bc,32*24*8      ; 6144 bytes of pixel data, also C = 0 (!)
    ld      (hl),c
    ldir                    ; HL==MEM_ZX_ATTRIB_5800, DE==HL+1
    ld      (hl),P_WHITE|BLACK
    ld      bc,32*24-1      ; and overwrite remaining 767 bytes
    ldir
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
