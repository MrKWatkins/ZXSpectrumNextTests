; (C): copyright 2022 Peter Ped Helcmanovsky, license: MIT
; name: test of CCF/SCF flag register value outcome being stable or random, with regard to video-frame position
; public git repo: https://github.com/MrKWatkins/ZXSpectrumNextTests/
;
; to assemble (with z00m's sjasmplus https://github.com/z00m128/sjasmplus/ v1.18.3+)
; run: sjasmplus ccf_per_scanline.asm
;
; history: 2022-02-01: v1.0 - initial version
;
; purpose: hunting down randomness of YF/XF values on some machines/CPUs after CCF/SCF instructions, this test
;  shows the random values in time-position within frame (first cca 64k T of frame, so 90% of it on regular ZX48)
;
; screen results:
; - each attribute row is 50-frame data collecting, with each char representing about 2000T into the frame
;   so whole line represents about 64000T (90% of frame time on zx48). If any single flag F value differs from
;   expected result during 50 frames, the char attribute will turn red, otherwise it will turn green.
; - the "expected values" from CCF/SCF are sampled once before doing 50-frames loop, roughly in the bottom-border
;   area of frame (T states 64-66k), if some randomness happen there, and then the CPU provides stable results,
;   the values will not match and whole line will turn most likely red.
; - the row starts with letter C or S depending if instruction CCF or SCF is being tested
; - then there's 16bit value range in hexa, representing the input "HL" values for the test code:
;   push hl : pop af : ccf (scf)
; - while XF/YF result after CCF/SCF is undefined (well, the whole XF/YF are technically undefined, not real flags),
;   this test doesn't depend on particular result, it's only testing if the result is always the same or fluctuates
;
; memory setup:
; - CLEAR 31000 ($7918), entry point $8000, test can be exited only by reset
; - main test code (operating mostly as IM2 interrupt service code) is in $8000..$8300 region
; - 256 byte buffers at $7E00 and $9000 are used to store expected flag values, 257 bytes IM2 IVT table at $9200
; - temporary scratch buffers modified by code: 8 bytes after loaded code, stack below $9000, needs 12 bytes in v1.0
;

        OPT --syntax=abf
        DEVICE ZXSPECTRUM48, 31000

ROM_ATTR_P          EQU     $5C8D
ROM_CLS             EQU     $0DAF
ROM_PRINT           EQU     $203C

IVT_BASE            EQU     $9200   ; table for IM2
HL_TEST_RANGE       EQU     23      ; 23 to get 1961T per attribute block, and it's prime number
TEST_AREA1          EQU     $9000   ; non-contented memory for area1 (and stack goes right below it)
TEST_AREA2          EQU     $7E00   ; contended memory for area2 (and scrap buffer to hide first row of full-red)
FRAMES_CNT          EQU     50      ; amount of frames to keep testing one HL range
TEST_ATTR_BASE      EQU     $5800+32*4
RULER_VRAM_BASE     EQU     $4000+$300+32*2 ; 1.5 line above TEST_ATTR_BASE area

        ORG $8000
    ;; init the test
code_start:
        di
    ; call ROM CLS and draw static pixels
        ld      a,$38               ; bright 0 : paper 7 : ink 0
        ld      (ROM_ATTR_P),a
        call    ROM_CLS
        ld      a,7
        out     (254),a             ; border 7
        ld      de,head_txt
        ld      bc,head_txt.sz
        call    ROM_PRINT           ; print header text
    ; preserve data needed to flip capital S<->C letters (xor both letters from ROM font printed at screen)
        ld      ix,$4020
        ld      de,fnt_xor_c_s
        ld      b,8
.store_fnt_xor_c_s:
        ld      a,(ix)
        xor     (ix+1)
        ld      (de),a
        inc     de
        inc     ixh
        djnz    .store_fnt_xor_c_s
    ; flip the starting SCF to CCF (as the test has "ccf" in name, and to verify the flip works)
        call    flip_ccf_scf
    ; print ruler with 2k, 4k, ... 64k
        ld      hl,RULER_VRAM_BASE
        ld      bc,$2002            ; B = 32 columns to print, C = 2k as first value
.ruler_loop:
        call    print_ruler_column
        inc     l                   ; next column VRAM address
        inc     c
        inc     c                   ; C += 2 (2k, 4k, 6k, ..
        djnz    .ruler_loop
        ld      sp,TEST_AREA1       ; move stack below TEST_AREA1, into uncontended memory
    ; create 257 bytes interrupt vector table pointing at ISR block_loop
        ld      hl,IVT_BASE+256
        ld      a,high block_loop
        ld      (hl),a
        dec     h
.set_ivt_loop:
        dec     l
        ld      (hl),a
        jr      nz,.set_ivt_loop
    ; setup IM2
        ld      a,h
        ld      i,a
        im      2
    ; continue with setup of next-row for test
        jr      entry_for_start

flip_ccf_scf:
    ; flip instructions themselves
        ld      a,(block_loop.scf1)
        xor     $08                 ; scf <-> ccf
        ld      (block_loop.scf1),a
        ld      (entry_for_start.scf2),a
    ; flip text at top of screen
        push    hl
        ld      de,$4020
        ld      hl,fnt_xor_c_s
.xor_loop:
        ld      a,(de)
        xor     (hl)
        ld      (de),a
        inc     hl
        inc     d
        bit     3,d
        jr      z,.xor_loop
        pop     hl
        ret

get_v_digit_fnt:
    ; A = digit value (0..9), put 8x4 vertical font address into DE
        add     a,a
        add     a,a                 ; A *= 4
        add     a,low v_fnt_0
        ld      e,a
        adc     a,high v_fnt_0
        sub     e
        ld      d,a
        ret

    ; IM2 interrupt handler block_loop (must start at specific $xyxy address), but keep frame_loop just ahead it
im2isr = $ + 5                      ; possible address to land ISR after 5 bytes of frame_loop
    IF low im2isr <= high im2isr
        DS high im2isr - low im2isr, 0          ; pad to $xyxy address for im2isr
    ELSE
        DS (high im2isr - low im2isr) + 257, 0  ; pad to $xyxy address for im2isr
    ENDIF
    ASSERT low block_loop == high block_loop

    ; frame test start
frame_loop:
.att+1: ld      hl,TEST_AREA2       ; start of current line in VRAM attributes (self-modify value)
        ei
        halt
    ; code execution continues in IM2 handler, starting at block_loop label, doesn't return here
    ; this point should be never reached here by "returning from ISR"

block_loop:
    ; block timing:
        ; =4+10+10 =24T block init
        ; =11+10+4+11+10+4+7+4+4+4+13 =82T per taken loop, 77T last loop
        ; =4+10+7+10+4+7+4+10 =56T block end
        ; total block time =75+82*n .. for n=23: 1961T
    ; block init
        exx
.hl+1:  ld      hl,TEST_AREA1       ; start of test value range (self-modify value)
        ld      bc,HL_TEST_RANGE<<8 ; C = 0 (no error), B = HL_TEST_RANGE
    ; busy-loop for single block (~2k T in total)
.test_loop:
        push    hl
        pop     af
.scf1:  scf
        push    af
        pop     de
        ld      a,e
        sub     (hl)                ; subtract expected F from actual F
        inc     l
        or      c                   ; accumulate any difference over range
        ld      c,a
        djnz    .test_loop
    ; ZF=1 when all did match, ZF=0 when there was difference detected (from last `or c`)
        exx
        jp      z,.block_ok
        ; "block-error" branch changing attribute color
        ld      (hl),$5F            ; bright 1, purple paper 3, white ink 7
        jp      .block_end
.block_ok:
        ; "block-OK" branch doing nothing, only keeping same timing including contention on VRAM (hl)
        ld      a,(hl)
        jp      .block_end
.block_end:
        inc     l
        ld      a,$1F
        and     l                   ; do 32 attribute blocks
        jp      nz,block_loop
    ; repeat the frame test B many times (coloring attribute blocks with differences to red)
        pop     af                  ; throw away return address from ISR
        djnz    frame_loop          ; do B many frame tests (executing again IM2 handler)
entry_for_start:
    ; set next HL range
        ld      b,HL_TEST_RANGE
        ld      hl,(block_loop.hl)
        ld      a,l
        add     a,b
        ld      l,a
        sbc     a,a                 ; alternate H between TEST_AREA1 and TEST_AREA2 every 256 bytes
        and     (high TEST_AREA1)^(high TEST_AREA2)
        xor     h
        ld      h,a
        ld      (block_loop.hl),hl  ; self-modify the start value for next test
    ; check for key being held, to flip SCF/CCF
        xor     a
        in      a,($FE)
        cpl
        and     $1F
        call    nz,flip_ccf_scf     ; extra ~600 T when key is being held, otherwise 36 T to test key
    ; produce expected test values (into buffer at HL)
.set_loop:
        push    hl
        pop     af
.scf2:  scf
        push    af
        pop     de
        ld      (hl),e
        inc     l
        djnz    .set_loop
    ; finalize attributes for previous line, turning cyan to green, keeping red intact
        ld      hl,(frame_loop.att)
        ld      a,l                 ; calculate mask to finalize attributes with
        add     a,a
        and     $40                 ; alternate starting bright for each line
        or      ~$48                ; clear bit 3 (and fix bright alternating)
        ld      b,32
.turn_green:
        ld      c,a
        and     (hl)
        ld      (hl),a              ; reset b3 (cyan -> green, purple -> red)
        ld      a,c
        xor     $40
        inc     hl
        djnz    .turn_green
    ; move to next attribute line (roll back to fourth line after last attribute line)
        ld      a,h
        cp      $5b
        jr      c,.next_line_is_ok
        ld      hl,TEST_ATTR_BASE   ; roll back at first line of result-area after last one
.next_line_is_ok:
        ld      (frame_loop.att),hl
    ; clear attributes to $68
        ld      bc,$2068            ; B = 32, C = $68 bright 1 : cyan paper 5, black ink 0
.set_attr_loop:
        ld      (hl),c
        inc     l
        djnz    .set_attr_loop
    ; calculate pixel address of current attribute line
        ld      hl,(frame_loop.att)
        ld      a,h
        rlca
        rla
        rlca
        xor     $80
        ld      h,a                 ; HL = first char at the next attribute row
    ; print "HL" range there
        ld      a,(block_loop.scf1) ; ccf $3F -> 'C' $43, scf $37 -> 'S' $53
        and     $08
        rlca
        xor     'S'
        call    print_ascii_char    ; print 'C' or 'S' to signal current instruction for next test
        inc     l                   ; space after C/S char
        ld      de,(block_loop.hl)
        call    print_hex_de
        ld      de,$3C00 + '.'*8
        call    print_rom_adr
        call    print_rom_adr
        ld      de,(block_loop.hl)
        ld      a,e
        add     a,HL_TEST_RANGE-1
        ld      e,a
        call    print_hex_de
    ; run 50 times frame_loop for the new range
        ld      b,FRAMES_CNT
        jp      frame_loop

print_hex_de:
    ; DE - value to be printed as four-digit hexa number, HL = VRAM address to print to, will be advanced
        ld      a,d
        call    print_hex_a
        ld      a,e
        ;   |
        ; fallthrough into print_hex_a
        ;   |
        ;   v
print_hex_a:                        ; A = value to print
        push    af
        .4 rrca
        call    print_hex_digit
        pop     af
        ;   |
        ; fallthrough into print_hex_digit
        ;   |
        ;   v
print_hex_digit:                    ; Convert nibble to ASCII
        and     $0f
        cp      10
        sbc     a,$69
        daa
        ;   |
        ; fallthrough into print_ascii_char
        ;   |
        ;   v
print_ascii_char:
        push    de,,hl
        ex      de,hl
        ld      h,high ($3C00/4)
        add     a,a
        ld      l,a
        add     hl,hl
        add     hl,hl               ; HL = ROM address of font data, DE = VRAM address
.fnt_adr_known:
        REPT 8
            ld      a,(hl)
            inc     l
            ld      (de),a
            inc     d
        ENDR
        pop     hl,,de
        inc     l                   ; advance to next char
        ret

print_rom_adr:                      ; HL = VRAM address, DE = font data (aligned by 8)
        push    de,,hl
        ex      de,hl
        jr      print_ascii_char.fnt_adr_known

print_ruler_column:
    ; C = number to print (2..64), HL = VRAM address
        push    hl
        ld      de,v_fnt_k
        call    print_v_8x4
        ld      a,c
        ld      d,-1
.tens_l:
        inc     d
        sub     10
        jr      nc,.tens_l
        push    de                  ; store 10^1 digit (tens) (can be also zero)
        add     a,10                ; 10^0 digit (ones)
        call    get_v_digit_fnt     ; font address of 10^0-digit
        call    print_v_8x4         ; print 10^0
        pop     af
        or      a
        ld      de,v_fnt_sp
        call    nz,get_v_digit_fnt  ; font address of 10^1-digit (or space for zero)
        call    print_v_8x4
        ld      (hl),%0000'0111     ; final underline above the attributes
        pop     hl
        ret

print_v_8x4:
        call    .x2
.x2:    call    .x1
.x1:    ld      a,(de)
        inc     de
        ld      (hl),a
        ;   |
        ; fallthrough into down_hl
        ;   |
        ;   v
down_hl:
        inc     h
        ld      a,h
        and     7
        ret     nz
        ld      a,32
        add     a,l
        ld      l,a
        ret     c
        ld      a,-8
        add     a,h
        ld      h,a
        ret

v_fnt_sp:
        DG      - ----- -#
        DG      - ----- -#
        DG      - ----- -#
        DG      - ----- -#
v_fnt_0:
        DG      - -###- -#
        DG      - #---# -#
        DG      - -###- -#
        DG      - ----- -#

        DG      - ##### -#
        DG      - -#--- -#
        DG      - ----- -#
        DG      - ----- -#

        DG      - -#--# -#
        DG      - #-#-# -#
        DG      - #--## -#
        DG      - ----- -#

        DG      - -#-#- -#
        DG      - #-#-# -#
        DG      - #---# -#
        DG      - ----- -#

        DG      - --#-- -#
        DG      - #-### -#
        DG      - -##-- -#
        DG      - ----- -#

        DG      - #--#- -#
        DG      - #-#-# -#
        DG      - ###-# -#
        DG      - ----- -#

        DG      - ---#- -#
        DG      - #-#-# -#
        DG      - -###- -#
        DG      - ----- -#

        DG      - ###-- -#
        DG      - #--## -#
        DG      - #---- -#
        DG      - ----- -#

        DG      - -#-#- -#
        DG      - #-#-# -#
        DG      - -#-#- -#
        DG      - ----- -#

        DG      - -###- -#
        DG      - #-#-# -#
        DG      - -#--- -#
        DG      - ----- -#
v_fnt_k:
        DG      - --#-# -#
        DG      - ---#- -#
        DG      - ##### -#
        DG      - ----- -#

BRIGHT  EQU     $13
AT      EQU     $16

head_txt:
        DB      "v1.0 2022-02-01 Ped7g, checks",13
        DB      BRIGHT,1,"SCF",BRIGHT,0," outcome stability per frame"
        DB      AT,8,16,"hold any key to"
        DB      AT,9,16,"switch CCF/SCF"
.sz:    EQU     $-head_txt

code_end:

    ; uninitialized variables (not part of TAP file)
fnt_xor_c_s:
        DS      8

        ASSERT  $ < (TEST_AREA1 - 32)       ; verify there's enough room for stack beyond the code

    ;; produce SNA file with test code
        SAVESNA "ccffrm.sna", code_start

CODE        EQU     $AF
USR         EQU     $C0
LOAD        EQU     $EF
CLEAR       EQU     $FD
RANDOMIZE   EQU     $F9
REM         EQU     $EA

    ;; produce TAP file with the test code
        DEFINE tape_file "ccffrm.tap"
        DEFINE prog_name "ccffrm"

        ;; 10 CLEAR 31000:LOAD "ccffrm"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
tap_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      CLEAR,"31000",$0E,0,0
        DW      31000
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
        DB      0,99    ;; Line number 99
        DW      .l99ln
.l99:   DB      REM,"https://github.com/MrKWatkins/ZXSpectrumNextTests/\r"
.l99ln: EQU     $-.l99
.l:     EQU     $-tap_bas

        EMPTYTAP tape_file
        SAVETAP  tape_file,BASIC,prog_name,tap_bas,tap_bas.l,1
        SAVETAP  tape_file,CODE,prog_name,code_start,code_end-code_start,code_start

    ;; produce TRD file with the test code
        DEFINE trd_file "ccffrm.trd"

        ;; 10 CLEAR 31000:RANDOMIZE USR 15619:REM:LOAD "ccffrm"CODE
        ;; 20 RANDOMIZE USR 32768
        ORG     $5C00
trd_bas:
        DB      0,10    ;; Line number 10
        DW      .l10ln  ;; Line length
.l10:   DB      CLEAR,"31000",$0E,0,0
        DW      31000
        DB      0,':'
        DB      RANDOMIZE,USR,"15619",$0E,0,0
        DW      15619
        DB      0,':',REM,':',LOAD,'"'
.fname: DB      "ccffrm"
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
        DB      0,99    ;; Line number 99
        DW      .l99ln
.l99:   DB      REM,"https://github.com/MrKWatkins/ZXSpectrumNextTests/\r"
.l99ln: EQU     $-.l99
.l:     EQU     $-trd_bas

        EMPTYTRD trd_file
        SAVETRD  trd_file,"boot.B",trd_bas,trd_bas.l,10
        SAVETRD  trd_file,"ccffrm.C",code_start,code_end-code_start
