; (C) copyright 2023 Peter Ped Helcmanovsky, license: MIT
; name: Test keyboard and Sinclair Joystick reading on all-key/specific ULA ports
; public git repo: https://github.com/MrKWatkins/ZXSpectrumNextTests/
;
; history: 2023-04-22: v1.1 - adding full port scan and more robust main routine (weak/strong msg)
;          2023-04-19: v1.0 - initial version
;
; purpose: to confirm the observed behaviour of several +2 machines:
;   code `xor a : in a,(254)` does NOT see the Sinclair joystick 1/2 presses on grey +2 model!
; to assemble (with z00m's sjasmplus https://github.com/z00m128/sjasmplus/ v1.20.2+)
; run: sjasmplus ulavssjs.asm
;
; screen results:
; - shows live readings of three ports: 0x00FE (all keys), 0xEFFE (keys 67890), 0xF7FE (keys 54321)
;   (scanning all 256 0x??FE ports in background for about ~50ms until these three are stable)
; - if ever the press read from EFFE or F7FE is missing in 00FE
;   the extra message "difference detected" is displayed
;   this means the SJS joystick sends results only to specific EFFE or F7FE port, but not into full
;   matrix reading on port 00FE
; - if the message is in cyan-on-white without all-port results, the port readings did change too
;   quickly after detecting the condition, during three more full port scans
; - if the message is in cyan-on-red, it means there were three more full port scans reporting
;   the same situation, and the all-port list is displayed with all ports having extra-press
;   (compared to 00FE) highlighted in red.
;
; memory setup:
; - CLEAR $7FFF, entry point $8000, disabled interrupt, using BASIC loader stack
;

    DEFINE SNA_FILENAME "ULAvsSJS.sna"
    DEFINE TAP_FILENAME "ULAvsSJS.tap"
    DEFINE TRD_FILENAME "ULAvsSJS.trd"
    OPT --syntax=abf
    DEVICE zxspectrum48, $7FFF

ROM_ATTR_P:     EQU     $5C8D
ROM_DF_SZ:      EQU     $5C6B
ROM_CLS:        EQU     $0DAF
ROM_PRINT:      EQU     $203C
ATTR_00FE:      EQU     $5800 + 3*32 + 12
ATTR_F7FE:      EQU     $5800 + 4*32 + 12
ATTR_EFFE:      EQU     $5800 + 5*32 + 12
ATTR_DIFF:      EQU     $5800 + 7*32 +  1
ATTR_NOW:       EQU     $5800 + 7*32 + 24
ATTR_RESTART:   EQU     $5800 + 23
ATTR_256_PORTS: EQU     $5800 + 8*32 +  0
COL_PRESSED:    EQU     %01'010'101     ; bright-red-cyan
COL_WEAK:       EQU     %00'111'101     ; white-cyan for weak difference
COL_HIDE:       EQU     %00'111'111     ; white-white
COL_PORT_DIFF1: EQU     COL_PRESSED   ; bright red cyan
COL_PORT_MATCH1:EQU     %01'111'000     ; bright white black
COL_PORT_DIFF2: EQU     %00'010'111     ; red white
COL_PORT_MATCH2:EQU     %00'111'000     ; white black
SCAN_N:         EQU     4               ; 4x full 256 ports are scanned to confirm difference
STABILISE_CNT:  EQU     32              ; 32x full port reading (about 50ms)

    ORG     $8000
code_start:
        di
        call    init_screen
        ld      a,COL_HIDE
    ; start live reading of inputs and evaluating the weirdness on +2 joysticks
main_loop:
    ; fill "*now*" after difference detected attributes with current A (to make it live-updated)
        ld      hl,ATTR_NOW
        ld      bc,$06FE        ; leave BC == $00FE for test
.fill_now_loop:
        ld      (hl),a
        inc     l
        djnz    .fill_now_loop
    ; update read_buffer content and reset stabilisation counter
.reset_read:
        ld      (hl),a          ; (!) final "* now *" attribute OR writes into read_buffer (!)
        ld      de,STABILISE_CNT | ($1F<<8)
    ; read full 256 ports into memory buffer
.read_loop:
        ; BC = $00FE here
        ld      hl,scan_buffer_end
        indr
    ; check the three ports 00FE, EFFE, F7FE if they provide stable results for longer period
        ld      hl,read_buffer  ; check $00FE
        ld      a,(scan_buffer_end)
        xor     (hl)
        and     d
        ld      a,(scan_buffer_end)
        jr      nz,.reset_read
        inc     l               ; check $EFFE
        ld      a,(scan_buffer_end-256+$EF)
        xor     (hl)
        and     d
        ld      a,(scan_buffer_end-256+$EF)
        jr      nz,.reset_read
        inc     l               ; check $F7FE
        ld      a,(scan_buffer_end-256+$F7)
        xor     (hl)
        and     d
        ld      a,(scan_buffer_end-256+$F7)
        jr      nz,.reset_read
    ; read all ports until stable results are provided for longer period, provide result in [C,D,E]
        dec     e
        jr      nz,.read_loop
        ld      e,a             ; read [00FE,EFFE,F7FE] into [C,D,E]
        dec     l
        ld      d,(hl)
        dec     l
        ld      c,(hl)
    ; C = 00FE, D = EFFE, A = E = F7FE value, display it live
        ld      hl,ATTR_F7FE
        call    display_pressed
        ld      a,d
        ld      hl,ATTR_EFFE
        call    display_pressed
        ld      a,c
        ld      hl,ATTR_00FE
        call    display_pressed
    ; check for key "R" to restart whole test (clears screen)
        ld      a,~(1<<2)
        in      a,($FE)
        and     %01000
        jr      z,code_start
    ; evaluate if the weird difference between readings is present, then uncover extra message
        ld      a,d
        and     e               ; all zero bits in EFFE and F7FE should be also zero in 00FE
        and     c
        xor     c
        and     $1F             ; non-zero bit here is from 00FE reading not having zero from EF/F7
        ld      a,COL_HIDE
        jr      z,main_loop
    ; weird difference detected (reading from SJS port not visible in 00FE), uncover message
        ld      a,(ATTR_DIFF)
        cp      COL_PRESSED
        jr      z,main_loop     ; strong message already displayed, keep updating only live status
    ; if not strongly detected, try to sample full 256 ports again and again
    ; read 3x $xxFE ports into memory (takes about 25% of frame time = ~4ms between first/last read)
        ld      hl,scan_buffer_end-256  ; read it below the initial full scan from main loop
        ld      a,SCAN_N-1
        ld      bc,$00FE
.scan_loop:
        out     (c),a
        indr
        dec     a
        jr      nz,.scan_loop
        ind                     ; final $00FE to complete the readings
        out     (c),a           ; black during check
    ; checks if first and last $00FE read differs, ignore the whole scan then
        ld      a,(scan_buffer_end)
        inc     hl              ; HL = scan_buffer
        xor     (hl)
        and     $1F
        jr      nz,weak_difference_detected
    ; looks like readings may be stable, check all buffers every value if they did hold 4x same
.check_loop:
        ld      h,high scan_buffer
        ld      c,(hl)          ; last read is value to check against
        DUP SCAN_N-1
                inc     h
                ld      a,(hl)
                xor     c
                and     $1F
                jr      nz,weak_difference_detected
        EDUP
        inc     l
        jr      nz,.check_loop
    ; all N scans are identical, display per-port readings
        ld      de,ATTR_256_PORTS
        ld      c,(hl)  ; 00FE reading in C
.show_port_loop:
    ; color the odd port (bright colors)
        ld      a,(hl)
        and     c
        xor     c
        and     $1F
        ld      a,COL_PORT_DIFF1
        jr      nz,.scan_differs_from_00_1
        ld      a,COL_PORT_MATCH1
.scan_differs_from_00_1:
        ld      (de),a
        inc     e
        ld      (de),a
        inc     e
        inc     l
    ; color the even port (bright colors)
        ld      a,(hl)
        and     c
        xor     c
        and     $1F
        ld      a,COL_PORT_DIFF2
        jr      nz,.scan_differs_from_00_2
        ld      a,COL_PORT_MATCH2
.scan_differs_from_00_2:
        ld      (de),a
        inc     e
        ld      (de),a
        inc     de
        inc     l
        jr      nz,.show_port_loop
    ; uncover message - strong difference uncovers it completely in red, weak only white+cyan msg
strong_difference_detected:
        ld      a,2
        out     (254),a
        ld      a,COL_PRESSED
        ld      hl,ATTR_DIFF
        ld      b,$15           ; bright-red-cyan, 21x
.msg_loop:
        ldi     (hl),a          ; fake
        djnz    .msg_loop
        jp      main_loop       ; A = color to show "* now *" live reading as well

weak_difference_detected:
        ld      a,6
        out     (254),a
        ld      a,COL_WEAK
        ld      hl,ATTR_DIFF + 1
        ld      b,$14
        jr      strong_difference_detected.msg_loop

; A = port value, HL = attribute address for b0, destroys B, HL, AF
display_pressed:
        ld      b,5
.loop:
        rra
        push    af
        sbc     a,a             ; $FF released, $00 pressed
        and     %01'111'111     ; convert it to bright-white-white for released
        or      COL_PRESSED     ; and bright-red-cyan for pressed
        ldd     (hl),a          ; fake
        pop     af
        djnz    .loop
        ret

; print string terminated by $FF (and having all chars -1) from DE address
print_FFstr.loop:
        rst     $10
print_FFstr:
        ld      a,(de)
        inc     de
        cp      $FF
        jr      nz,.loop
        ret

; HL = value to print with `rst $10`
; printHexWord:
;         ld      a,h
;         call    printHexByte
;         ld      a,l
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

init_screen:
        ld      a,7<<3          ; FLASH 0 : BRIGH 0 : PAPER 7 : INK 0
        ld      (ROM_ATTR_P),a  ; set ATTR-P
        call    ROM_CLS
        ld      de,head_txt     ; print all texts on screen
        call    print_FFstr
    ; print 00..FF in bottom area for full-port scan when difference is detected
        xor     a
        ld      (ROM_DF_SZ),a   ; make bottom screen size 0 rows (to avoid "scroll?" prompt)
.all_ports_loop:
        push    af
        call    printHexByte
        pop     af
        inc     a
        jr      nz,.all_ports_loop
        ld      a,5
        out     (254),a         ; BORDER 5
        ld      (ATTR_RESTART),a
        ret

head_txt:
        DB      "v1.1 2023-04-22 Ped7g (Restart)",13
        DB      "use longer presses of key/joy",13
        DB      "Reading keyboard ports:",13
        DB      "0x00FE: ##### (whole 8x5 matrix)",13
        DB      "0xF7FE: ##### (54321)",13
        DB      "0xEFFE: ##### (67890)",13,13
        DB      $10,7,"  difference detected   * now *",13  ; INK 7 to hide this
        DB      $FF

code_end:

    ; 256 port scan buffers (not part of tap/sna/trd file, can be uninitialised)
        ALIGN   256
scan_buffer:
        DS      SCAN_N * 256
scan_buffer_end:
        DS      1
read_buffer:
        DS      3

    ;; produce SNA file with test code
        SAVESNA SNA_FILENAME, code_start

    ;; produce TAP file with the test code
CODE        EQU     $AF
USR         EQU     $C0
LOAD        EQU     $EF
CLEAR       EQU     $FD
RANDOMIZE   EQU     $F9
REM         EQU     $EA

        DEFINE prog_name "ULAvsSJS"

        ;; 10 CLEAR 32767:LOAD  "ULAvsSJS"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
tap_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      CLEAR,"32767",$0E,0,0
        DW      code_start-1
        DB      0,':'
        DB      LOAD," \""
.fname: DB      prog_name
        ASSERT  ($ - .fname) <= 10
        DB      '"',CODE,$0D
.l10ln: EQU     $-.l10
        DB      0,20    ;; Line number 20
        DW      .l20ln
.l20:   DB      RANDOMIZE,USR,"32768",$0E,0,0
        DW      code_start
        ASSERT  32768 == code_start
        DB      0,$0D
.l20ln: EQU     $-.l20
        DB      0,99    ;; Line number 99
        DW      .l99ln
.l99:   DB      REM,"https://github.com/MrKWatkins/ZXSpectrumNextTests/\r"
.l99ln: EQU     $-.l99
.l:     EQU     $-tap_bas

        EMPTYTAP TAP_FILENAME
        SAVETAP  TAP_FILENAME,BASIC,prog_name,tap_bas,tap_bas.l,1
        SAVETAP  TAP_FILENAME,CODE,prog_name,code_start,code_end-code_start,code_start

    ;; produce TRD file with the test code

        ;; 10 CLEAR 32767:RANDOMIZE USR 15619:REM:LOAD "ULAvsSJS"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
trd_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      CLEAR,"32767",$0E,0,0
        DW      code_start-1
        DB      0,':'
        DB      RANDOMIZE,USR,"15619",$0E,0,0
        DW      15619
        DB      0,':',REM,':',LOAD,'"'
.fname: DB      prog_name
        ASSERT  ($ - .fname) <= 8
        DB      '"',CODE,$0D
.l10ln: EQU     $-.l10
        DB      0,20    ;; Line number 20
        DW      .l20ln
        ASSERT  32768 == code_start
.l20:   DB      RANDOMIZE,USR,"32768",$0E,0,0
        DW      code_start
        DB      0,$0D
.l20ln: EQU     $-.l20
        DB      0,99    ;; Line number 99
        DW      .l99ln
.l99:   DB      REM,"https://github.com/MrKWatkins/ZXSpectrumNextTests/\r"
.l99ln: EQU     $-.l99
.l:     EQU     $-trd_bas

        EMPTYTRD TRD_FILENAME
        SAVETRD  TRD_FILENAME,"boot.B",trd_bas,trd_bas.l,10
        SAVETRD  TRD_FILENAME,"ULAvsSJS.C",code_start,code_end-code_start
