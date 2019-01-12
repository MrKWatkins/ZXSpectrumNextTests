FillLayer2WithTestData:     ; takes roughly about 16 frames at 3.5MHz (~0.3s)
    ; Fills current Layer2 memory with pattern: 0,1,2,...,255 for every line
        ld  a, LAYER2_ACCESS_WRITE_OVER_ROM+LAYER2_ACCESS_L2_ENABLED+LAYER2_ACCESS_OVER_ROM_BANK_2
            ; enable layer2, write-over-ROM, and select bank 2 for write
        ld  bc, LAYER2_ACCESS_P_123B

@BankLoop:
        out (c), a          ; Page in the bank.
        ld  hl,$3F00

@FillLoop:
        ld  (hl), l
        inc l
        jr  nz, @FillLoop   ; Write a line into the bank.
        dec h
        jp  p, @FillLoop    ; write whole third of screen (stops at h=$FF)
        sub LAYER2_ACCESS_OVER_ROM_BANK_1   ; Update the control register value for the next bank.
        jr nc, @BankLoop    ; If we haven't done 3 banks, continue
        ; switch OFF "write-over-ROM" feature (but keep Layer 2 enabled)
        ld  a, LAYER2_ACCESS_L2_ENABLED
        out (c), a
        ret

; Fills BC many bytes (min 2) at address HL by value A.
; modifies: HL (HL = orig.HL + BC)
FillArea:
    push    de
    push    bc
    ld      d,h
    ld      e,l
    inc     de              ; DE = HL+1
    dec     bc              ; adjust length by 1
    ld      (hl),a
    ldir
    inc     hl              ; point just beyond filled area upon return
    pop     bc
    pop     de
    ret

    MACRO FILL_AREA adr, size, value
        ld      a,value
        ld      hl,adr
        ld      bc,size
        call    FillArea
    ENDM
