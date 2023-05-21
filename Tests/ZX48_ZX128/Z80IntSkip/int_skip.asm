; (C): copyright 2022 Peter Ped Helcmanovsky, license: MIT
; name: test to see if block of bytes XX (0xDD/0xFD/0x00/0xDD+0xFD) does inhibit processing of /INT signal
; public git repo: https://github.com/MrKWatkins/ZXSpectrumNextTests/
;
; to assemble (with z00m's sjasmplus https://github.com/z00m128/sjasmplus/ v1.19.0+)
; run: sjasmplus int_skip.asm
;
; history: 2023-05-21: v4.0 - added `OUT (C),0` visual test and `LD A,I`, `LD A,R` IFF2 reading bug test
;          2022-05-16: v3.0 - added "ISR entries per /INT signal" check (should be 2+ if emulating /INT as 32T signal)
;                           - set resulting BORDER color also into sysvar, so will retain in BASIC
;          2022-02-19: v2.1 - adding EI and DI test blocks, removing the sync-halt induced +1 from counter
;          2022-02-19: v2.0 - complete rewrite of test logic:
;                             * result is displayed as text OK/ERR and returns to BASIC
;                             * test works also on faster machines (up to 30MHz) with slightly unstable IRQ period
;          2022-02-17: v1.0 - initial version
;
; purpose: to check if Z80 skips interrupt when it is inside long block of XX prefixes,
; where XX is one of the DD/FD values and miscellaneous others (nop,ei,di,...)
;
; ISR entries number depends on CPU frequency, but with 3.5MHz and 32T /INT it should count at least two entries.
; (if "1" is displayed, the emulator/machine does end /INT upon interrupt ACK, triggering it only once per frame)
;
; OUT (C),0 test is visual: during block tests BORDER should be either black (0) or white (255)
;
; IFF2 reading reports "CPU bug" when LD A,I||R reads IFF2 as zero during int-ack, "correct" when
; it is read as one during int-ack, and "tst fail" when machine CPU speed is non-standard and
; the /INT signal did happen outside of LD A,I||R instruction, thus test failed.
;

CLEAR_ADR   EQU     $8FFF   ; 36863 - have BASIC stack high in uncontended memory (just in case)
XX_BLOCK_SZ EQU     40*256  ; 10240 bytes of XX prefix = ~41k T per one run
ROM_ATTR_P: EQU     $5C8D
ROM_BORDCR: EQU     $5C48
ROM_CLS:    EQU     $0DAF
ROM_PRINT:  EQU     $203C

    OPT --syntax=abf
    DEVICE ZXSPECTRUM48,CLEAR_ADR

TEST_FLAG_BENCHMARK EQU     1
TEST_FLAG_ALLOWS    EQU     2
TEST_FLAG_INHIBITS  EQU     3

    STRUCT  S_TEST_DATA
prefix1     BYTE
prefix2     BYTE
counter     BYTE
name        TEXT    8, { ' ' }
flag        BYTE    TEST_FLAG_BENCHMARK
    ENDS

    ORG $9000
code_start:
    ASSERT CLEAR_ADR < $
    ; CLS + print info text
    ld      a,7<<3
    ld      (ROM_ATTR_P),a  ; ATTR-P = PAPER 7 : INK 0 : BRIGHT 0 : FLASH 0
    call    ROM_CLS
    ld      c,254
    out     (c),0           ; test `OUT (C),0` visually ; out0-ok
    ld      de,head_txt     ; text at top of screen
    ld      bc,head_txt.sz
    call    ROM_PRINT
    di
    ; setup IM2 - create 257 byte table and setup IM2, set R.7
    ld      de,im2_isr
    ld      hl,im2_ivt
    ld      a,h
    ld      i,a
    ld      r,a             ; set R.7
    im      2
.set_ivt:
    ld      (hl),e
    dec     l
    jr      nz,.set_ivt
    inc     h
    ld      (hl),e

    ; IM2 re-entry test (roughly measuring /INT signal lenth or whether it's "trigger" once-only)
    ld      hl,im2_isr_entries_test
    ld      bc,im2_isr_entries_test.sz
    ldir                    ; setup IM2 handler for re-entry test
    ld      b,8             ; try 8 times to measure the max, here C = 0 (max)
    ei
re_entry_test:
    halt
    djnz    re_entry_test
    ; print result of re-entrance test
    di
    ld      a,c
    call    printDecimalA

    ; IFF2 bug test
    call    iff2_test

    ; opcodes BLOCK tests
    ld      de,head_txt2    ; remaining header text
    ld      bc,head_txt2.sz
    call    ROM_PRINT

    ; setup IM2 handler for block-test
    ld      hl,im2_isr_block_test
    ld      de,im2_isr
    ld      bc,im2_isr_block_test.sz
    ldir

    ; start testing of different blocks
    ld      a,low txt_verdict_s_ok
    ld      (global_err_flag),a         ; reset global error flag
    ld      ix,test_data
mainloop:
    ; run the test + output results for current S_TEST_DATA at IX
    call    run_test

    ; repeat test through all defined blocks
    ld      bc,S_TEST_DATA
    add     ix,bc
    ld      a,low test_data.end
    cp      ixl
    jr      nz,mainloop

    ; change border color depending on the global result
    ld      a,(global_err_flag)
    cp      low txt_verdict_s_ok
    ld      a,4
    jr      z,.all_ok
    ld      a,2
.all_ok:
    out     ($FE),a                     ; border green/red
    .3 add     a,a
    ld      (ROM_BORDCR),a              ; set also BASIC sysvar for border color

    ; return back to basic
    im      1
    ld      a,$3F
    ld      i,a
    ei
    ret

txt_verdict_benchmark:
    DB      " |   |benchmark\r"
.sz EQU     $-txt_verdict_benchmark

txt_verdict_s_ok:
    DB      " |OK |"
txt_verdict_s_err:
    DB      " |ERR|"
txt_verdict.small_sz    EQU     $-txt_verdict_s_err

; IN: E D = bytes to fill, HL = target address, returns B = 0, HL += XX_BLOCK_SZ
set_block:
    ld      b,high (XX_BLOCK_SZ)    ; set about XX_BLOCK_SZ bytes
.set_loop:
    ld      (hl),e
    inc     l
    ld      (hl),d
    inc     l
    jr      nz,.set_loop
    inc     h
    djnz    .set_loop
    ret

; In: IX = S_TEST_DATA pointer
set_block_and_run_test:
    ld      hl,xx_block
    ; fill the stack Nx with xx_block address to Nx execute the block as part of test
    ld      b,3500000/40000         ; run the block for 1 second at 3.5MHz (~6 frames at 28MHz, ~50 frames at 3.5MHz)
.fill_stack:
    push    hl
    djnz    .fill_stack             ; all of this will be executed after `ret` is reached in each xx_block
    ; setup the block itself (fill memory with prefix data)
    ld      e,(ix+S_TEST_DATA.prefix1)
    ld      d,(ix+S_TEST_DATA.prefix2)
    call    set_block
    ; append `nop : ret` after the block
    ld      (hl),b                  ; nop
    inc     l
    ld      (hl),$C9                ; ret
    ; sync with halt, reset counter, and run the prefix blocks N times
    ei
    halt
    ld      (ix+S_TEST_DATA.counter),b  ; reset counter to 0 (after halt did already modify it once)
    ret

    ; IM2 interrupt handler 1 - testing block instruction inhibition
im2_isr_block_test:
    DISP im2_isr
    push    af
    inc     (ix+S_TEST_DATA.counter)    ; increment the test-counter
    pop     af
    ei
    ret
    ENT
.sz:    EQU     $-im2_isr_block_test

    ; IM2 interrupt handler 2 - checking re-entrance with long-enough /INT signal
im2_isr_entries_test:
    DISP im2_isr
    ei
    nop                                 ; 8T until ready for re-entry of handler (ACK is 11T, so 19T total)
    ; reaching here when INT goes back up, count entries by examining stack content
    ASSERT 0 == (0x200 & re_entry_test) && 0x200 == (0x200 & im2_isr)
    ; B = test-loop counter, C = 0 (max)
    xor     a                           ; current counter
.count_entries:
    inc     a
    pop     hl
    bit     1,h                         ; 0x92xx return address => count as re-entry
    jr      nz,.count_entries
    cp      c
    jr      c,.keep_old_max
    ld      c,a                         ; new max re-entry
.keep_old_max:
    jp      (hl)                        ; return back into test-loop
    ENT
.sz:    EQU     $-im2_isr_entries_test

    ; IM2 interrupt handler 3 - testing IFF2 reading bug
im2_isr_iff2_test:
    pop     de                          ; throw away return address into test routine
    ld      bc,iff2_result_txt.sz
    ld      de,iff2_unknown_txt
    ei                                  ; keep interrupts enabled (first: HALT, second: LD A,I||R)
    ret     p                           ; SF = 0 means the `ld a,i|r` block was not hit by /INT
    ld      de,iff2_fixed_txt
    ret     pe                          ; P/V = 1 means the CPU has fixed IFF2 bug
    ld      de,iff2_bug_txt
    ret                                 ; P/V = 0 means the CPU has bug in IFF2 reading
.sz:    EQU     $-im2_isr_iff2_test

; In: IX = S_TEST_DATA pointer
; Out: (IX + S_TEST_DATA.counter) = count of Interrupts during running test sequence
run_test:
    ; set the block to designed prefix and run it N-times, before returning here
    call    set_block_and_run_test
    di
    ; print result - name
    ld      de,ix                       ; fake ; ld e,ixl : ld d,ixh
    ld      hl,S_TEST_DATA.name
    add     hl,de
    ex      de,hl                       ; DE = test.name
    ld      bc,S_TEST_DATA.flag-S_TEST_DATA.name
    call    ROM_PRINT
    ld      de,txt_verdict_benchmark+1  ; use part of this for framing
    ld      bc,2
    call    ROM_PRINT
    ; print result - count
    ld      a,(ix+S_TEST_DATA.counter)
    ld      c,a
    call    printDecimalA
    ld      b,(ix+S_TEST_DATA.flag)
    djnz    .not_benchmark
    ; TEST_FLAG_BENCHMARK - print fixed string
    ld      de,txt_verdict_benchmark
    ld      bc,txt_verdict_benchmark.sz
    jp      ROM_PRINT
.not_benchmark:
    ; check if block did inhibit ISR or not
    ld      a,(test_data.counter)       ; NOP-block counter
    srl     a
    cp      c                           ; (NOP.counter/2) - test.counter
    sbc     a,a                         ; A = 00 inhibits / FF allows
    ld      c,a
    ; check if the result is as expected by test: OK/ERR verdict
    djnz    .allows_expected            ; TEST_FLAG_INHIBITS
    cpl                                 ; TEST_FLAG_ALLOWS
.allows_expected:
    ; A = 00 ok / FF error
    push    bc
    ld      de,txt_verdict_s_ok
    ld      bc,txt_verdict.small_sz
    ASSERT (high txt_verdict_s_ok == high txt_verdict_s_err) && (txt_verdict_s_err == txt_verdict_s_ok + txt_verdict.small_sz)
    and     c
    add     a,e
    ld      e,a                         ; DE = txt_verdict_s_ok / txt_verdict_s_err
    ; tamper global error flag in case there was error in any test
    ld      a,(global_err_flag)
    ASSERT low txt_verdict_s_ok != low txt_verdict_s_ok | low txt_verdict_s_err ; if this fails, use `and e` instead
    or      e
    ld      (global_err_flag),a
    ; print OK/ERR verdict
    call    ROM_PRINT
    ; print long description verdict
    pop     af                          ; CF=0 inhibits / 1 allows
    ASSERT txt_verdict_allows == txt_verdict_inhibits + txt_verdict.long_sz
    ld      hl,txt_verdict_inhibits
    ld      bc,txt_verdict.long_sz
    jr      nc,.did_inhibit
    add     hl,bc                       ; HL = txt_verdict_allows
.did_inhibit:
    ex      de,hl
    jp      ROM_PRINT

printDecimalA:
    push    bc
    ld      e,' '                   ; align with space
    ld      bc,$FF00 | 100          ; b = -1, c = 100
    call    .FindAndOutDigitOrSpace
    ld      a,c
    ld      bc,$FF00 | 10           ; b = -1, c = 10
    call    .FindAndOutDigitOrSpace
    ; output final digit (even zero)
    ld      a,c
    pop     bc
    jr      .OutDecDigit
.FindAndOutDigitOrSpace:
    inc     b
    sub     c       ; if A is less than current 10th power, CF will be set
    jr      nc,.FindAndOutDigitOrSpace
    add     a,c     ; fix A back above zero (B is OK, as it started at -1)
    ld      c,a
    ld      a,b
    add     a,e     ; test also against previously displayed digits, to catch any non-zero
    ld      e,a     ; remember the new mix
    cp      ' '
    jp      z,$10   ; if still no non-zero digit was printed, print space
    ld      a,b
.OutDecDigit:
    add     a,'0'
    rst     $10
    ret

iff2_test:
    ld      de,im2_isr
    ld      hl,im2_isr_iff2_test
    ld      bc,im2_isr_iff2_test.sz
    ldir                    ; setup IM2 handler for iff2 bug test
    ld      de,head_txt3    ; LD A,I header text
    ld      bc,head_txt3.sz
    call    ROM_PRINT
    ld      de,$57ED        ; create ED57 block = LD A,I
    call    .run_test
    di
    call    ROM_PRINT       ; print result
    ld      de,head_txt4    ; LD A,R header text
    ld      bc,head_txt4.sz
    call    ROM_PRINT
    ld      de,$5FED        ; create ED5F block = LD A,R
    call    .run_test
    di
    jp      ROM_PRINT       ; print result and exit into main loop

.run_test:                  ; E D = opcode bytes to test
    ld      hl,xx_block
    push    hl              ; address for im2_isr_iff2_test to start xx_block after HALT
    push    hl
    call    set_block
    ld      (hl),$AF        ; XOR A
    inc     l
    ld      (hl),$E9        ; JP (HL)
    pop     hl              ; HL = xx_block for JP (HL) after the block of LD instructions
    ei
    halt                    ; start block of `ld a,i||r` instructions to test IFF2 reading bug
    ; the test should RET one level up (to xx_block and then caller), not continue here

iff2_unknown_txt:
    DB      "tst fail"
iff2_fixed_txt:
    DB      "correct "
iff2_bug_txt:
    DB      "CPU bug "
iff2_result_txt.sz EQU $-iff2_bug_txt

txt_verdict_inhibits:
    DB      "inhibits ISR\r"
txt_verdict_allows:
    DB      "allows ISR  \r"
txt_verdict.long_sz     EQU     $-txt_verdict_allows

head_txt:
    DB      "v4.0 2023-05-21 Ped7g, count\r"
    DB      "interrupts while executing\r"
    DB      "long block of DD/FD prefixes\r\r"
    DB      "BORDER is now B/W by OUT (C),0\r"
    DB      "ISR entries per /INT signal:"
.sz EQU     $-head_txt
head_txt3:
    DB      "\rLD A,I IFF2 reading: "
.sz EQU     $-head_txt3
head_txt4:
    DB      "\rLD A,R IFF2 reading: "
.sz EQU     $-head_txt4
head_txt2:
    DB      "\r\rblock of|count|verdict\r"
    DB      "--------+-----+----------------\r"
.sz EQU     $-head_txt2

test_data   S_TEST_DATA     { $00, $00, $00, {"NOP"}, TEST_FLAG_BENCHMARK }     ; nop chain
            S_TEST_DATA     { $DD, $DD, $00, {"DD"}, TEST_FLAG_INHIBITS }       ; DD chain
            S_TEST_DATA     { $FD, $FD, $00, {"FD"}, TEST_FLAG_INHIBITS }       ; FD chain
            S_TEST_DATA     { $DD, $FD, $00, {"DDFD"}, TEST_FLAG_INHIBITS }     ; DDFD chain
            S_TEST_DATA     { $37, $3F, $00, {"SCF+CCF"}, TEST_FLAG_ALLOWS }    ; scf, ccf chain (verify NOP-like)
            S_TEST_DATA     { $FB, $FB, $00, {"EI"}, TEST_FLAG_INHIBITS }       ; ei chain
            S_TEST_DATA     { $F3, $F3, $00, {"DI"}, TEST_FLAG_INHIBITS }       ; di chain (your emulator +1 here = LOL)
.end

code_end:   ; this is enough to store into TAP file, rest is initialised by code

global_err_flag:
    ds      1

    ; IM2 interrupt handler (must start at specific $xyxy address)
    IF low $ <= high $
        DS high $ - low $, 0    ; pad to $xyxy address for im2_isr
    ELSE
        DS (high $ - low $) + 257, 0    ; pad to $xyxy address for im2_isr
    ENDIF
im2_isr:
    ASSERT low im2_isr == high im2_isr
    DS      im2_isr_block_test.sz >? im2_isr_entries_test.sz

    ALIGN   256
im2_ivt:
    ds      257

    ALIGN   256
xx_block:
    ds      XX_BLOCK_SZ+16

    ;; produce SNA file with the test code
        SAVESNA "int_skip.sna", code_start

tkCODE      EQU     $AF
tkUSR       EQU     $C0
tkLOAD      EQU     $EF
tkCLEAR     EQU     $FD
tkRANDOMIZE EQU     $F9
tkREM       EQU     $EA

    ;; produce TAP file with the test code
        DEFINE tape_file "int_skip.tap"
        DEFINE prog_name "int_skip"

        ;; 10 CLEAR 36863:LOAD "int_skip"CODE
        ;; 20 RANDOMIZE USR 36864
        ORG     $5C00
tap_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
        ASSERT 36863 == CLEAR_ADR
.l10:   DB      tkCLEAR,"36863",$0E,0,0,low (CLEAR_ADR),high (CLEAR_ADR),0,':'
        DB      tkLOAD,'"'
.fname: DB      prog_name
        ASSERT  ($ - .fname) <= 10
        DB      '"',tkCODE,"\r"
.l10ln: EQU     $-.l10
        DB      0,20    ;; Line number 20
        DW      .l20ln
.l20:   DB      tkRANDOMIZE,tkUSR,"36864",$0E,0,0,low code_start,high code_start,0,"\r"
.l20ln: EQU     $-.l20
        DB      0,99    ;; Line number 99
        DW      .l99ln
.l99:   DB      tkREM,"https://github.com/MrKWatkins/ZXSpectrumNextTests/\r"
.l99ln: EQU     $-.l99
.l:     EQU     $-tap_bas

        EMPTYTAP tape_file
        SAVETAP  tape_file,BASIC,prog_name,tap_bas,tap_bas.l,1
        SAVETAP  tape_file,CODE,prog_name,code_start,code_end-code_start,code_start

    ;; produce TRD file with the test code
        DEFINE trd_file "int_skip.trd"

        ;; 10 CLEAR 36863:RANDOMIZE USR 15619:REM:LOAD "int_skip"CODE
        ;; 20 RANDOMIZE USR 36864
        ORG     $5C00
trd_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
        ASSERT 36863 == CLEAR_ADR
.l10:   DB      tkCLEAR,"36863",$0E,0,0,low (CLEAR_ADR),high (CLEAR_ADR),0,':'
        DB      tkRANDOMIZE,tkUSR,"15619",$0E,0,0,low 15619,high 15619,0,':'
        DB      tkREM,':',tkLOAD,'"'
.fname: DB      "int_skip"
        ASSERT  ($ - .fname) <= 8
        DB      '"',tkCODE,$0D
.l10ln: EQU     $-.l10
        DB      0,20    ;; Line number 20
        DW      .l20ln
        ASSERT  36864 == code_start
.l20:   DB      tkRANDOMIZE,tkUSR,"36864",$0E,0,0,low code_start,high code_start,0,"\r"
.l20ln: EQU     $-.l20
        DB      0,99    ;; Line number 99
        DW      .l99ln
.l99:   DB      tkREM,"https://github.com/MrKWatkins/ZXSpectrumNextTests/\r"
.l99ln: EQU     $-.l99
.l:     EQU     $-trd_bas

        EMPTYTRD trd_file
        SAVETRD  trd_file,"boot.B",trd_bas,trd_bas.l,10
        SAVETRD  trd_file,"int_skip.C",code_start,code_end-code_start
