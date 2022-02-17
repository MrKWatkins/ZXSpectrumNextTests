; (C): copyright 2022 Peter Ped Helcmanovsky, license: MIT
; name: test to see if block of bytes XX (0xDD/0xFD/0x00/0xDD+0xFD) does inhibit processing of /INT signal
; public git repo: https://github.com/MrKWatkins/ZXSpectrumNextTests/
;
; to assemble (with z00m's sjasmplus https://github.com/z00m128/sjasmplus/ v1.18.3+)
; run: sjasmplus int_skip.asm
;
; history: 2022-02-17: v1.0 - initial version
;
; purpose: to check if Z80 skips interrupt when it is inside long block of XX prefixes,
; where XX is one of the DD/FD values (test has also 00 "nop" block for comparison)
;
; Test requires ZX48/128 timing in 50Hz at 3.5MHz (Pentagon timing is close enough too?)
; Press keys 1/2/3/4 to modify the prefix opcode block.
;

    OPT --syntax=abf
    DEVICE ZXSPECTRUM48

STACK_TOP   EQU     $FF00
ROM_ATTR_P: EQU     $5C8D
ROM_CLS:    EQU     $0DAF
ROM_PRINT:  EQU     $203C

    ORG $8000
code_start:
    ; CLS + print info text
    ld      a,7<<3
    ld      (ROM_ATTR_P),a  ; ATTR-P = PAPER 7 : INK 0 : BRIGHT 0 : FLASH 0
    call    ROM_CLS
    ld      de,head_txt     ; text at top of screen
    ld      bc,head_txt.sz
    call    ROM_PRINT
    di
    ld      sp,STACK_TOP
    ; set default block to DD...
    ld      de,$DDDD
    call    set_block
    ld      hl,BLOCK_CHOICE_ATTR
    ld      (hl),$80|$38    ; flash "1" as current block
    ; setup IM2 - create 257 byte table
    ld      hl,im2_ivt
.set_ivt:
    ld      (hl),low im2_isr
    dec     l
    jr      nz,.set_ivt
    inc     h
    ld      (hl),low im2_isr
    ; setup IM2 - rest of the setup
    ld      a,high im2_ivt
    ld      i,a
    im      2

mainloop:
    ; black border
    xor     a
    out     ($FE),a
    ; read the keyboard, change xx_block if key is pressed
    ld      a,~(1<<3)
    in      a,($FE)         ; read 12345 keys
    cpl
    and     $0F             ; only "1234" are active
    call    nz,key_pressed
    ; halt + wait for ISR
    ei
    halt
    ; ISR will change border to white and delay a lot to make it visible
    ; back to black border, wait long enough to be near INT to run the DD block
    xor     a
    out     ($FE),a
    ld      bc,$0874
    call    delay
    ; green border, run the DD block which should inhibit the interrupts and skip it
    ld      a,4
    out     ($FE),a
    jp      xx_block

delay:
    nop
    dec     c
    jr      nz,delay
    djnz    delay
    ret

key_pressed:
    di
    push    af
    ; switch off the flashing attribute for current selection
    ld      a,$38
    ld      (BLOCK_CHOICE_ATTR+0*7),a
    ld      (BLOCK_CHOICE_ATTR+1*7),a
    ld      (BLOCK_CHOICE_ATTR+2*7),a
    ld      (BLOCK_CHOICE_ATTR+3*7),a
    pop     af
    ld      hl,BLOCK_CHOICE_ATTR-7
    ld      de,block_values-2
    ; select the new block and set it up
.key_loop:
    .7 inc  hl
    .2 inc  de
    rra
    jr      nc,.key_loop
    ld      (hl),$80|$38        ; make it flash
    ex      de,hl
    ld      e,(hl)
    inc     hl
    ld      d,(hl)              ; de = value to set
    ;  |
    ; fallthrough into set_block
    ;  |
    ;  v
; DE = values to set in the block, E/D/E/D/E...
set_block:
    ld      hl,xx_block
    ld      b,high 8000     ; about 8ki XX bytes will be set
.set_loop:
    ld      (hl),e
    inc     l
    ld      (hl),d
    inc     l
    jr      nz,.set_loop
    inc     h
    djnz    .set_loop
    ; append `nop : jp mainloop` after the block
    ld      (hl),$00
    inc     l
    ld      de,mainloop
    ld      (hl),$C3
    inc     l
    ld      (hl),e
    inc     l
    ld      (hl),d
    ret

block_values:
    DW      $DDDD, $FDFD, $0000, $FDDD

BLOCK_CHOICE_ATTR:  EQU     $5800+8*$20+0

head_txt:
    DB      "<- top border\r<- green/white: XX inhibits IM2\r"
    DB      "<- white: IM2 during XX\r<-\r<- (only for 50Hz @3.5MHz)\r<-\r\r"
    DB      "press key to change block:\r"
    DB      "1: DD, 2: FD, 3: 00, 4: DD+FD"
.sz EQU     $-head_txt

    ; IM2 interrupt handler (must start at specific $xyxy address)
    IF low $ <= high $
        DS high $ - low $, 0    ; pad to $xyxy address for im2_isr
    ELSE
        DS (high $ - low $) + 257, 0    ; pad to $xyxy address for im2_isr
    ENDIF
im2_isr:
    ASSERT low im2_isr == high im2_isr
    push    af,,bc
    ld      a,7
    out     ($FE),a             ; white border
    ld      bc,$061F
    call    delay
    pop     bc,,af
    ei
    ret

code_end:   ; this is enough to store into TAP file, rest is initialised by code

    ALIGN   256
im2_ivt:
    ds      257

    ALIGN   256
xx_block:

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

        ;; 10 CLEAR 32767:LOAD "int_skip"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
tap_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      tkCLEAR,"32767",$0E,0,0,low (code_start-1),high (code_start-1),0,':'
        DB      tkLOAD,'"'
.fname: DB      prog_name
        ASSERT  ($ - .fname) <= 10
        DB      '"',tkCODE,"\r"
.l10ln: EQU     $-.l10
        DB      0,20    ;; Line number 20
        DW      .l20ln
.l20:   DB      tkRANDOMIZE,tkUSR,"32768",$0E,0,0,low code_start,high code_start,0,"\r"
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

        ;; 10 CLEAR 31000:RANDOMIZE USR 15619:REM:LOAD "int_skip"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
trd_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      tkCLEAR,"32767",$0E,0,0,low (code_start-1),high (code_start-1),0,':'
        DB      tkRANDOMIZE,tkUSR,"15619",$0E,0,0,low 15619,high 15619,0,':'
        DB      tkREM,':',tkLOAD,'"'
.fname: DB      "int_skip"
        ASSERT  ($ - .fname) <= 8
        DB      '"',tkCODE,$0D
.l10ln: EQU     $-.l10
        DB      0,20    ;; Line number 20
        DW      .l20ln
        ASSERT  32768 == code_start
.l20:   DB      tkRANDOMIZE,tkUSR,"32768",$0E,0,0,low code_start,high code_start,0,"\r"
.l20ln: EQU     $-.l20
        DB      0,99    ;; Line number 99
        DW      .l99ln
.l99:   DB      tkREM,"https://github.com/MrKWatkins/ZXSpectrumNextTests/\r"
.l99ln: EQU     $-.l99
.l:     EQU     $-trd_bas

        EMPTYTRD trd_file
        SAVETRD  trd_file,"boot.B",trd_bas,trd_bas.l,10
        SAVETRD  trd_file,"int_skip.C",code_start,code_end-code_start
