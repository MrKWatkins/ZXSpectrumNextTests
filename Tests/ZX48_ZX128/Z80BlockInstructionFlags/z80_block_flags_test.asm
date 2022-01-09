; (C): copyright 2022 Peter Ped Helcmanovsky, license: MIT
; name: Test of flag register value of block-instructions interrupted
; history: 2022-??-??: WIP  - check for too fast machines (4+MHz), whole test in uncontended memory, TRD output
;                             added INIR.3 case (using floating bus at $FF for $FF value)
;          2022-01-03: v4.1 - no code change, only extra credit to D.Banks and upload to public github repo
;          2022-01-01: v4.0 - added OTDR, INIR, INDR (basic cases)
;          2021-12-31: v3.0 - added OTIR three basic cases
;          2021-12-30: v2.0 - test of LDIR, LDDR, CPIR, CPDR
;
; purpose: to confirm this doc:
;   https://github.com/hoglet67/Z80Decoder/wiki/Undocumented-Flags#interrupted-block-instructions
; to assemble (with z00m's sjasmplus https://github.com/z00m128/sjasmplus/ v1.18.3+)
; run: sjasmplus z80_block_flags_test.asm
;
; screen results:
; - instruction with <expected>?=<actual> F value, four times for four different instruction location
;   (green <actual> after "=" is as expected, red <actual> after "!=" differs)
;
; memory setup:
; - CLEAR $7FFF, entry point $8000, test does self-modify the code but should be capable to re-run (inits all)
; - block instructions used to test behaviour are at four identical blocks starting at $8002, $8802, $A002, $A802
; - main test code and IM2 interrupt table + routine are in remainder of $8000..$8700 region
; - stack area is in $8701..$7FF region (test needs about 30-40 bytes of stack at most)
; - block instructions target area around $E000 (both directions), but whole $C000..FFFF is filled with filler value
;
; TODO: INxR/OTxR checking HF for CF=1 case, when it should change every 16th B value
; TODO: LDxR/INxR tests overwriting the instruction itself (interrupting it without interrupt)
; TODO: CPxR test when A == (HL) (fill TEST_AREA with A value, make test block consist of multiple CPxR, one will be hit by IM2)
; TODO: check also https://floooh.github.io/visualz80remix/ if it does match these and maybe check for edge-case details
; TODO: there's also http://www.visual6502.org/JSSim/expert-z80.html ... not sure how it is related to floooh's remix

    OPT --syntax=abf
    DEVICE zxspectrum48, $7FFF

ROM_ATTR_P: EQU     $5C8D
ROM_CLS:    EQU     $0DAF
ROM_PRINT:  EQU     $203C
LAST_ATTR:  EQU     $5AFF
TEST_AREA:  EQU     $E000
TEST_FILL:  EQU     $DE

    STRUCT SAVED_REGS
bc      DW      0
de      DW      0
hl      DW      0
af      DW      0
pc      DW      0
    ENDS

    STRUCT INST_META
name    TEXT    4, { "xxxR" }
init    DW      inst_default_init
checkF  DW      inst_default_checkF
dataF1  DB      0
dataF2  DB      0
dataF3  DB      0
dataF4  DB      0
    ENDS

    ORG     $8000

code_start:
        jr      test_start

; test-code in $80xx area follows (to be also copied to $88xx, $A0xx, $A8xx and run in all places)
test_code_80:                   ; first LDIR+RET at $8002
        ldir
        ret
        lddr
        ret
        cpir
        ret
        cpdr
        ret
        otir                    ; otir1
        ret
        otir                    ; otir2
        ret
        otir                    ; otir3
        ret
        otdr                    ; otdr1
        ret
        otdr                    ; otdr2
        ret
        otdr                    ; otdr3
        ret
        inir                    ; inir1
        ret
        inir                    ; inir2
        ret
        inir                    ; inir3
        ret
        indr                    ; indr1
        ret
        indr                    ; indr2
        ret
        rst $0                  ; should never reach this
.l:     EQU     $-test_code_80
        ASSERT  .l < $80
test_code_88:   EQU     test_code_80+$0800
test_code_A0:   EQU     test_code_80+$2000
test_code_A8:   EQU     test_code_80+$2800

; helper function to provide "call hl" functionality
call_hl:
        jp      hl

; copy test-code to region starting at DE
copy_test_code:
        ld      hl,test_code_80
        ld      bc,test_code_80.l
        ldir
        ret

; fill TEST_AREA with value in A
fill_test_area:
        ld      hl,TEST_AREA-$2000
        ld      de,TEST_AREA-$2000+1
        ld      bc,$4000-1
        ld      (hl),a
        ldir
        ret

; main test code setting it up and doing all tests + printing results
test_start:
        ld      a,7<<3
        ld      (ROM_ATTR_P),a  ; ATTR-P = PAPER 7 : INK 0 : BRIGHT 0 : FLASH 0
        call    ROM_CLS
        ld      de,head_txt     ; text at top of screen
        ld      bc,head_txt.l
        call    ROM_PRINT
        ld      ix,i_meta       ; meta data about next instruction to test
        ld      a,TEST_FILL
        call    fill_test_area

    ; copy test subroutines also to: $88xx, $A0xx, $A8xx
        ld      de,test_code_88
        call    copy_test_code
        ld      de,test_code_A0
        call    copy_test_code
        ld      de,test_code_A8
        call    copy_test_code
    ; reset self-modify .call value in code
        ld      hl,test_code_80
        ld      (next_test.call),hl

    ; setup stack and IM2 handler: fill the im2 table with im2isr address, enable IM2
        di
        ld      (next_test.sp),sp
        ld      sp,STACK_TOP
        ld      hl,im2tab
        ld      a,h
        ld      i,a
        ld      de,im2tab+1
        ld      bc,256
        ld      a,low im2isr
        ld      (hl),a
        ldir
        im      2
        ei

    ; calibrate initial BC delay before launching block instruction (delay depends on ZX type and prologue code)
        ld      hl,3500         ; long enough delay to be interrupted by IM2 (remaining BC is stored in im_saved_regs)
        ld      (init_and_delay.del),hl
        halt                    ; here is BC = 0 from ldir for IM2 (to detect too fast machines)
        call    init_and_delay
        ; calculate calibrated delay to interrupt block instructions ASAP
        ld      bc,(im_saved_regs.bc)
        ld      a,b
        or      c
        jp      z,too_fast_machine
        ld      hl,3500-5       ; -5 to make sure the interrupt happens after at least one iteration in block ins.
        sbc     hl,bc
        ld      (init_and_delay.del),hl
        ; check availability of IN ports $FE, $1F and $FF for $1xxx'xxxx, $0xxx'xxxx and $FF readings for INxR tests
        ld      a,$FF           ; write $FF to last attribute of VRAM
        ld      (LAST_ATTR),a   ; to have also +2A/+3 models read $FF on port $FF (all test code is in fast memory)
        halt
        in      a,($FE)
        ld      (ulaB7),a       ; should be %1xxx'xxxx if ULA keyboard reads like Issue2+ model
        in      a,($1F)
        ld      (kempB7),a      ; should be %00xx'xxxx if Kempston interface is connected
        in      a,($FF)
        ld      (float),a       ; expected value $FF from floating bus

next_instruction:
        ld      de,ix           ; fake-ok ; DE = string mnemonics of instruction to PRINT it
        ld      bc,4
        add     ix,bc           ; advance meta data to expected F values
        call    ROM_PRINT
        ld      de,after_i_txt
        ld      bc,after_i_txt.l
        call    ROM_PRINT       ; "<instruction> F:" printed
        ldi     hl,(ix)         ; fake-ok ; HL = address of init function for next instruction test, IX+=2
        call    call_hl         ; do the init
        ldi     hl,(ix)         ; fake-ok ; HL = address of checkF function for next instruction test, IX+=2
        ld      (next_test.chkF),hl

    ; test code - calling the <block instruction> and timing the IM2 interrupt to happen during it
next_test:
        ld      a,$FF           ; write $FF to last attribute of VRAM
        ld      (LAST_ATTR),a   ; to have also +2A/+3 models read $FF on port $FF (all test code is in fast memory)
        halt
        call    init_and_delay  ; delay to start block instruction late ahead of IM2 (dynamically calibrated value)
.call+1 call    0               ; test_code_80 ; call block instruction to be interrupted with IM2

    ; im_saved_regs contains snapshot of bc,de,hl,af DURING block instruction - preserve it for output/debugging
        ld      hl,im_saved_regs
        ld      de,in_instr_regs
        ld      bc,SAVED_REGS
        ldir

    ; compare saved F flag with expected value and print result
        ld      a,' '
        rst     $10
.chkF+1 call    0               ; checkF function ; L = expected F value
        ld      a,l
        call    printHexByte
        ld      a,(in_instr_regs.af)    ; actual F value -> to be compared with expected value at (ix)
        ld      de,expected_value_txt   ; "=" with green paper
        ld      bc,expected_value_txt.l
        cp      l
        jr      z,.f_is_expected
        ld      de,unexpected_value_txt ; "!=" with red paper
        ld      bc,unexpected_value_txt.l
.f_is_expected:
        call    ROM_PRINT
        ld      a,(in_instr_regs.af)
        call    printHexByte    ; print actual F value in color
        ld      de,restore_color
        ld      bc,restore_color.l
        call    ROM_PRINT       ; restore colors back to white paper

    ; advance to next round of test ($80xx -> $88xx -> $A0xx -> $A8xx and back to $80xx for next instruction)
        ld      a,(.call+1)
        or      $10
        add     a,$08
        and     $A8
        ld      (.call+1),a     ; update call to block instruction
        ld      hl,init_and_delay.af+1
        inc     (hl)            ; update the A content itself + use it to stop test after A4++
        ld      a,$A5
        cp      (hl)
        jr      nz,next_test

    ; print ENTER after all four addresses were done
.skip_test:
        ld      a,13
        rst     $10

    ; advance test to next block instruction
        ld      hl,(.call)      ; advance test-call to next test-block (look for RET in current block)
        ld      a,$C9           ; RET opcode
        cpir
        ld      (.call),hl
        ld      a,low i_meta.e
        cp      ixl             ; until all block instructions were test
        jp      nz,next_instruction

    ; restore IM1 ROM mode and return to BASIC
.exit:  di
.sp+1:  ld      sp,0            ; restore original SP
        ld      a,$3F
        ld      i,a
        im      1
        ei
        ld      a,7
        out     (254),a
        ret

too_fast_machine:
        ld      de,calibrate_fail_txt
        ld      bc,calibrate_fail_txt.l
        call    ROM_PRINT
        jr      next_test.exit

; change border to "init_and_delay.af & 7", set HL=DE=TEST_AREA, BC=init_and_delay.bc (16), AF=init_and_delay.af
init_and_delay:
.del+1: ld      bc,0            ; delay value (to be self-modified by test)
    ; final delay of following code is (BC + 5) * 21 T (from those 30T are after the busy-loop LDIR doing wait)
.af+1:  ld      hl,0
        push    hl
        ld      a,h
        and     7
        out     (254),a         ; change BORDER based on ".af" value
.hl+1:  ld      hl,TEST_AREA
        nop                     ; +4T nop
        sbc     hl,bc
        ld      d,h
        ld      e,l             ; HL = DE = (TEST_AREA - BC)
        ldir
        pop     af              ; A = next_test.ra, F = $00
.bc+1:  ld      bc,16           ; small amount of bytes to use during the test itself
        ret
    ; =10+11+4+7+11+10+4+15+4+4+16+10+10+10 = 126 (for BC=1) (JFYI 126 / 21 = 6)

; HL = value to print with `rst $10`
printHexWord:
        ld      a,h
        call    printHexByte
        ld      a,l
printHexByte:                   ; A = value to print with `rst $10`
        push    af
        .4 rrca
        call    printHexDigit
        pop     af
printHexDigit:                  ; Convert nibble to ASCII
        and     $0f
        cp      10
        sbc     a,$69
        daa
        rst     $10
        ret

ulaB7:  DB      $00
kempB7: DB      $FF
float:  DB      $00

head_txt:
        DB      $15,1           ; `OVER 1` for "!=" mixing
        DB      "v4.1+ 2022-01-01 Ped7g",13
        DB      "based on David Banks' research",13
        DB      "F of IM2 interrupted block inst",13
        DB      "Instr   @80xx @88xx @A0xx @A8xx",13
.l:     EQU     $-head_txt

after_i_txt:
        DB      " F:"       ;
.l:     EQU     $-after_i_txt

expected_value_txt:
        DB      '=',$13,0,$11,4             ; =, BRIGHT 0, PAPER 4
.l:     EQU     $-expected_value_txt

unexpected_value_txt:
        DB      '=',8,'!',$13,1,$11,2       ; !=, BRIGHT 1, PAPER 2
.l:     EQU     $-unexpected_value_txt

restore_color:
        DB      $13,0,$11,7                 ; BRIGHT 0 : PAPER 7
.l:     EQU     $-restore_color

skip_txt:
        DB      " unexpected IN 1F,FE,FF"
.l:     EQU     $-skip_txt

calibrate_fail_txt:
        DB      $10,2,"failed delay calibration\ris frame > 73500T?",13
.l:     EQU     $-calibrate_fail_txt

; default settings of init_and_delay for testing block instructions (used by LDIR/LDDR/CPIR/CPDR test)
inst_default_init:
        ld      hl,TEST_AREA    ; to end delay with HL=DE=TEST_AREA
        ld      bc,16           ; BC=16 for block instructions
        ld      de,$A100        ; A=$A1, F=$00
.set:
        ld      (init_and_delay.hl),hl
        ld      (init_and_delay.bc),bc
        ld      (init_and_delay.af),de
        ret

; default check F function, should return in L expected F value (used by LDIR/LDDR/CPIR/CPDR test)
inst_default_checkF:
        ld      l,(ix)
        inc     ix
        ret

; OTIR/OTDR case 1 - sends value zero to port 254 (black border), thus M+L is always < 256 (CF=0 case)
otxr1_init:
        xor     a
        call    fill_test_area
        ld      hl,TEST_AREA+$10; to end delay with HL=DE=TEST_AREA+$10 (works for both OTIR/OTDR)
        ld      bc,$10FE        ; B = 16, port = $FE
        ld      de,$A101        ; A=$A1, F=$01 (CF=1)
        jr      inst_default_init.set

otxr1_checkF:                   ; PF = (((M+Lo) & 7) ^ Bo ^ (Bo & 7)).parity
        ld      a,(in_instr_regs.bc+1)
        and     ~7              ; Bo ^ (Bo & 7)
        ld      l,a
        ld      a,(in_instr_regs.hl)
        and     7               ; M was zero, so A = M + Lo
        xor     l               ; PF = (((M+Lo) & 7) ^ Bo ^ (Bo & 7)).parity
.chkPF: ld      a,$04           ; turn real PF into expected F value
        jp      pe,.hasPF
        xor     a
.hasPF: xor     (ix)            ; xor other expected F bits from expected data
        ld      l,a
        inc     ix
        ret

; OTIR/OTDR case 2 - sends value $FF to port 254, thus M+L is > 255 when interrupted (CF=1)
otxr2_init:
        ld      a,$FF
        call    fill_test_area
        ld      hl,TEST_AREA+$10; to end delay with HL=DE=TEST_AREA+$10 (works for both OTIR/OTDR)
        ld      bc,$10FE        ; B = 16, port = $FE
        ld      de,$A100        ; A=$A1, F=$00 (CF=0)
        jr      inst_default_init.set

otxr2_checkF:                   ; PF = (((M+Lo) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity
        ld      a,(in_instr_regs.bc+1)
        ld      l,a
        dec     a
        and     7
        xor     l               ; Bo ^ ((Bo - 1) & 7)
        ld      l,a
        ld      a,(in_instr_regs.hl)
        dec     a               ; $FF + Lo
        and     7
        xor     l               ; PF = (((M+Lo) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity
        jr      otxr1_checkF.chkPF

; OTIR/OTDR case 3 - sends value $47 to port 254 from $E0E0, thus M+L is > 255 when interrupted (CF=1)
otxr3_init:
        ld      a,$47
        call    fill_test_area
        ld      hl,TEST_AREA+$E0; to end delay with HL=DE=TEST_AREA+$E0 (works for both OTIR/OTDR)
        ld      bc,$10FE        ; B = 16, port = $FE
        ld      de,$A100        ; A=$A1, F=$00 (CF=0)
        jr      inst_default_init.set

otxr3_checkF:                   ; PF = (((M+Lo) & 7) ^ Bo ^ ((Bo + 1) & 7)).parity
        ld      a,(in_instr_regs.bc+1)
        ld      l,a
        inc     a
        and     7
        xor     l               ; Bo ^ ((Bo + 1) & 7)
        ld      l,a
        ld      a,(in_instr_regs.hl)
        add     a,$47           ; $47 + Lo
        and     7
        xor     l               ; PF = (((M+Lo) & 7) ^ Bo ^ ((Bo + 1) & 7)).parity
        jr      otxr1_checkF.chkPF

; INIR/INDR case 1 - reads Kempston joystick port $1F (%00xx'xxxx values), thus M+((C+1)&$FF) is always < 256 (CF=0 case)
inxr1_init:
        ld      a,(kempB7)
        rla
        jp      c,init_skipTest ; Kempston port doesn't read as expected with b7=0 in values, skip whole test
        ld      hl,TEST_AREA    ; to end delay with HL=DE=TEST_AREA (doesn't matter for INIR/INDR)
        ld      bc,$101F        ; B = 16, port = $1F
        ld      de,$A101        ; A=$A1, F=$01 (CF=1)
        jp      inst_default_init.set

inir1_checkF:                   ; PF = (((M+((Co+1)&$FF)) & 7) ^ Bo ^ (Bo & 7)).parity
        ld      a,(in_instr_regs.bc)
        inc     a               ; A = (Co + 1) & $FF
        ld      hl,(in_instr_regs.hl)
        dec     hl              ; HL points at value read from I/O port, aka M
.doT:   add     a,(hl)          ; A += M (CF = 0, can't overflow because it's Kempston $1F port + readings), aka T
        and     7               ; A = T & 7
        ld      l,a
        ld      a,(in_instr_regs.bc+1)
        and     ~7              ; Bo ^ (Bo & 7)
        xor     l               ; PF = ((T & 7) ^ Bo ^ (Bo & 7)).parity
        jp      otxr1_checkF.chkPF

indr1_checkF:                   ; PF = (((M+((Co-1)&$FF)) & 7) ^ Bo ^ (Bo & 7)).parity
        ld      a,(in_instr_regs.bc)
        dec     a               ; A = (Co - 1) & $FF
        ld      hl,(in_instr_regs.hl)
        inc     hl              ; HL points at value read from I/O port, aka M
        jr      inir1_checkF.doT

; INIR case 3 - reads port $FF for value $FF, testing if the C+1 is truncated by `& $FF` producing just zero
inxr3_init:
        ld      a,(float)
        inc     a
        jr      nz,init_skipTest; port $FF doesn't read as $FF value, skip whole test
        ld      hl,TEST_AREA    ; to end delay with HL=DE=TEST_AREA (doesn't matter for INIR/INDR)
        ld      bc,$10FF        ; B = 16, port = $FF
        ld      de,$A101        ; A=$A1, F=$01 (CF=1)
        jp      inst_default_init.set

; INIR/INDR case 2 - reads ULA port $FE (%1xxx'xxxx values), thus M+((C+1)&$FF) is always >= 256 (CF=1 case), and M.b7=1
inxr2_init:
        ld      a,(ulaB7)
        rla
        jr      nc,init_skipTest; ULA port doesn't read as expected with b7=1 in values, skip whole test
        ld      hl,TEST_AREA    ; to end delay with HL=DE=TEST_AREA (doesn't matter for INIR/INDR)
        ld      bc,$10FE        ; B = 16, port = $FE
        ld      de,$A100        ; A=$A1, F=$00 (CF=0)
        jp      inst_default_init.set

inir2_checkF:                   ; PF = (((M+((Co+1)&$FF)) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity
        ld      a,(in_instr_regs.bc)
        inc     a               ; A = Co + 1 & $FF ( == $FF)
        ld      hl,(in_instr_regs.hl)
        dec     hl              ; HL points at value read from I/O port, aka M
.doT:   add     a,(hl)          ; A += M (CF = 1, must overflow as value read is >= $80), aka T
        and     7               ; A = T & 7
        ld      l,a
        ld      a,(in_instr_regs.bc+1)
        ld      h,a
        dec     a
        and     7
        xor     h               ; Bo ^ ((Bo - 1) & 7)
        xor     l               ; PF = ((T & 7) ^ Bo ^ ((Bo - 1) & 7)).parity
        jp      otxr1_checkF.chkPF

indr2_checkF:                   ; PF = (((M+((Co-1)&$FF)) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity
        ld      a,(in_instr_regs.bc)
        dec     a               ; A = Co - 1 & $FF ( == $FD)
        ld      hl,(in_instr_regs.hl)
        inc     hl              ; HL points at value read from I/O port, aka M
        jr      inir2_checkF.doT

init_skipTest:
        ld      de,skip_txt
        ld      bc,skip_txt.l
        call    ROM_PRINT
        ld      bc,2+4
        add     ix,bc           ; IX += 6 (checkF address and four expected F values)
        pop     hl              ; skip to next test
        jp      next_test.skip_test

i_meta:     ; name of instruction + expected flag when interrupted by IM2 during block operation (BC!=0)
        ; LDIR: N=0, P/V=1, H=0, C=Z=S=unchanged (0), YF=PC.13, XF=PC.11
        INST_META   { { "LDIR" }, , , $04, $0C, $24, $2C }  ; using inst_default_init and inst_default_checkF
        ; LDDR: N=0, P/V=1, H=0, C=Z=S=unchanged (0), YF=PC.13, XF=PC.11
        INST_META   { { "LDDR" }, , , $04, $0C, $24, $2C }  ; using inst_default_init and inst_default_checkF
        ; CPIR: N=1, P/V=1, H=1, S=1, Z=0, C=unchanged (0), YF=PC.13, XF=PC.11 (A-(HL) <=> 0xA? - 0xDE)
        INST_META   { { "CPIR" }, , , $96, $9E, $B6, $BE }  ; using inst_default_init and inst_default_checkF
        ; CPDR: N=1, P/V=1, H=1, S=1, Z=0, C=unchanged (0), YF=PC.13, XF=PC.11
        INST_META   { { "CPDR" }, , , $96, $9E, $B6, $BE }  ; using inst_default_init and inst_default_checkF
        ; OTIR 1 (M+L < 256): N=0 (M.7), C=0, Z=0 (B>0), S=0 (--B.7), H=0, P=(((M+L) & 7) ^ Bo ^ (Bo & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "OTIR" }, otxr1_init, otxr1_checkF, $00, $08, $20, $28 }
        ; OTIR 2 (M+L > 255): N=1 (M.7), C=1, Z=0 (B>0), S=0 (--B.7), H=0 (B=12..13), P=(((M+L) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "  .2" }, otxr2_init, otxr2_checkF, $03, $0B, $23, $2B }
        ; OTIR 3 (M+L > 255): N=0 (M.7), C=1, Z=0 (B>0), S=0 (--B.7), H=0 (B=12..13), P=(((M+L) & 7) ^ Bo ^ ((Bo + 1) & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "  .3" }, otxr3_init, otxr3_checkF, $01, $09, $21, $29 }
        ; OTDR 1 (M+L < 256): N=0 (M.7), C=0, Z=0 (B>0), S=0 (--B.7), H=0, P=(((M+L) & 7) ^ Bo ^ (Bo & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "OTDR" }, otxr1_init, otxr1_checkF, $00, $08, $20, $28 }
        ; OTDR 2 (M+L > 255): N=1 (M.7), C=1, Z=0 (B>0), S=0 (--B.7), H=0 (B=12..13), P=(((M+L) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "  .2" }, otxr2_init, otxr2_checkF, $03, $0B, $23, $2B }
        ; OTDR 3 (M+L > 255): N=0 (M.7), C=1, Z=0 (B>0), S=0 (--B.7), H=0 (B=12..13), P=(((M+L) & 7) ^ Bo ^ ((Bo + 1) & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "  .3" }, otxr3_init, otxr3_checkF, $01, $09, $21, $29 }
        ; INIR 1 (M+((C+1)&$FF) < 256): N=0 (M.7), C=0, Z=0 (B>0), S=0 (--B.7), H=0, P=(((M+((C+1)&$FF)) & 7) ^ Bo ^ (Bo & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "INIR" }, inxr1_init, inir1_checkF, $00, $08, $20, $28 }
        ; INIR 2 (M+((C+1)&$FF) > 255): N=1 (M.7), C=1, Z=0 (B>0), S=0 (--B.7), H=0 (B=12..13), P=(((M+((C+1)&$FF)) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "  .2" }, inxr2_init, inir2_checkF, $03, $0B, $23, $2B }
        ; INIR 3 (port $FF) (M+((C+1)&$FF) < 256): N=1 (M.7), C=0, Z=0 (B>0), S=0 (--B.7), H=0, P=((M & 7) ^ Bo ^ (Bo & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "  .3" }, inxr3_init, inir1_checkF, $02, $0A, $22, $2A }
        ; can't think of commonly available 8bit-address-port producing data $01..$7F near interrupt to overflow (port + data)
        ; so skipping that case for INIR (maybe AY could be used for this, but needs decoding of AY port to depend only on few top bits of B)
        ; INDR 1 (M+((C-1)&$FF) < 256): N=0 (M.7), C=0, Z=0 (B>0), S=0 (--B.7), H=0, P=(((M+((C-1)&$FF)) & 7) ^ Bo ^ (Bo & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "INDR" }, inxr1_init, indr1_checkF, $00, $08, $20, $28 }
        ; INDR 2 (M+((C-1)&$FF) > 255): N=1 (M.7), C=1, Z=0 (B>0), S=0 (--B.7), H=0 (B=12..13), P=(((M+((C-1)&$FF)) & 7) ^ Bo ^ ((Bo - 1) & 7)).parity, YF=PC.13, XF=PC.11
        INST_META   { { "  .2" }, inxr2_init, indr2_checkF, $03, $0B, $23, $2B }
.e:

/*
M is the value written to or read from the I/O port == (HL), Co/Lo/Bo are "output" values of registers C/L/B
if instruction == INIR
        T = M + ((Co + 1) & 0xFF)
else if instruction == INDR
        T = M + ((Co - 1) & 0xFF)
    // WARNING: to verify the "& 0xFF" part (ie. bit-width of (C-1) intermediate) one would need to
    //  read value 00 from port 00, which is not possible on regular ZX machine with common peripherals -> giving up.
else if (instruction == OTIR) || (instruction == OTDR)
        T = M + Lo

NF = M.7
CF = T > 255

if B
        ZF = 0
        SF = Bo.7
        YF = PCi.13
        XF = PCi.11

        if CF
                if M & 0x80
                        PF = ((T & 7) ^ Bo).parity ^ ((Bo - 1) & 7).parity ^ 1
                        HF = (Bo & 0xF) == 0
                else
                        PF = ((T & 7) ^ Bo).parity ^ ((Bo + 1) & 7).parity ^ 1
                        HF = (Bo & 0xF) == 0xF
        else
                PF = ((T & 7) ^ Bo).parity ^ (Bo & 7).parity ^ 1
                HF = 0 (CF)

else ; counter is zero, flags are same as single INI/IND/OUTI/OUTD
        SF = 0
        ZF = 1
        HF = CF
        PF = ((T & 7) ^ Bo).parity

// implementation (simplification to calculate expected PF):
PF = ((T & 7) ^ Bo).parity ^ ((Bo - 1) & 7).parity ^ 1 <=> ((T & 7) ^ Bo ^ ((Bo - 1) & 7)).parity
PF = ((T & 7) ^ Bo).parity ^ ((Bo + 1) & 7).parity ^ 1 <=> ((T & 7) ^ Bo ^ ((Bo + 1) & 7)).parity
PF = ((T & 7) ^ Bo).parity ^ (Bo & 7).parity ^ 1 <=> ((T & 7) ^ Bo ^ (Bo & 7)).parity

// the "if B" case flag calculations can be further simplified by recognising the ALU usage applied to Bo driven by CF and NF:
    T = ...
    ZF = 0
    SF = Bo.7
    YF = PCi.13
    XF = PCi.11
    NF = M.7
    CF = T > 255
    Balu = Bo + (NF ? -CF : CF);
    HF = (Balu ^ Bo).4;
    PV ^= Balu & 7;  // or full: PV = ((T & 7) ^ Bo ^ (Balu & 7)).parity
*/

im_saved_regs:      SAVED_REGS
in_instr_regs:      SAVED_REGS

    ; IM2 interrupt handler (must start at specific $xyxy address)
    IF low $ <= high $
        DS high $ - low $, 0    ; pad to $xyxy address for im2isr
    ELSE
        DS (high $ - low $) + 257, 0    ; pad to $xyxy address for im2isr
    ENDIF
im2isr:
        ASSERT low im2isr == high im2isr
        push    af,,hl,,de,,bc
        ld      hl,0
        add     hl,sp
        ld      de,im_saved_regs
        ld      bc,SAVED_REGS
        ldir
        pop     bc,,de,,hl,,af
        ei
        ret

im2tab: EQU     ($ + 255) & $FF00
        ASSERT im2tab <= $8600

STACK_TOP:  EQU     $8800

code_end:

    ;; produce SNA file with test code
        SAVESNA "z80bltst.sna", code_start

CODE        EQU     $AF
USR         EQU     $C0
LOAD        EQU     $EF
CLEAR       EQU     $FD
RANDOMIZE   EQU     $F9
REM         EQU     $EA

    ;; produce TAP file with the test code
        DEFINE tape_file "z80bltst.tap"
        DEFINE prog_name "z80bltst"

        ;; 10 CLEAR 32767:LOAD "z80bltst"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
tap_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      CLEAR,'8',$0E,0,0
        DW      code_start-1
        DB      0,':'
        DB      LOAD,'"'
.fname: DB      prog_name
        ASSERT  ($ - .fname) <= 10
        DB      '"',CODE,$0D
.l10ln: EQU     $-.l10
        DB      0,20    ;; Line number 20
        DW      .l20ln
.l20:   DB      RANDOMIZE,USR,"32768",$0E,0,0
        DW      code_start
        DB      0,$0D
.l20ln: EQU     $-.l20
.l:     EQU     $-tap_bas

        EMPTYTAP tape_file
        SAVETAP  tape_file,BASIC,prog_name,tap_bas,tap_bas.l,1
        SAVETAP  tape_file,CODE,prog_name,code_start,code_end-code_start,code_start

    ;; produce TRD file with the test code
        DEFINE trd_file "z80bltst.trd"

        ;; 10 CLEAR 32767:RANDOMIZE USR 15619:REM:LOAD "z80bltst"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
trd_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      CLEAR,'8',$0E,0,0
        DW      code_start-1
        DB      0,':'
        DB      RANDOMIZE,USR,"15619",$0E,0,0
        DW      15619
        DB      0,':',REM,':',LOAD,'"'
.fname: DB      "z80bltst"
        ASSERT  ($ - .fname) <= 8
        DB      '"',CODE,$0D
.l10ln: EQU     $-.l10
.l20:   DB      0,20    ;; Line number 20
        DW      .l20ln
        ASSERT  32768 == code_start
        DB      RANDOMIZE,USR,"32768",$0E,0,0
        DW      code_start
        DB      0,$0D
.l20ln: EQU     $-.l20
.l:     EQU     $-trd_bas

        EMPTYTRD trd_file
        SAVETRD  trd_file,"boot.B",trd_bas,trd_bas.l,10
        SAVETRD  trd_file,"z80bltst.C",code_start,code_end-code_start
