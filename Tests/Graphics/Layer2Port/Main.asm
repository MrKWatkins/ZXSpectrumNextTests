    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2
    ds      32, $55     ; reserved space for stack
stack:
    dw      $AAAA

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"

LegendNr12:
    db      ' Visible Layer 2 (NextReg 0x12)', 0
LegendNr13:
    db      ' Shadow Layer 2  (NextReg 0x13)', 0
LegendTests:
    db      ' *** write-over-ROM 16kiB',0
    db      ' *** write-over-ROM 48kiB',0
    db      ' *** read-over-ROM 16kiB (data)',0
    db      ' *** read-over-ROM 48kiB (data)',0
    db      '   * read-over-ROM (code)',0
    db      '   * read-over-ROM (IM1 in L2)',0
LegendBankOffset:
    db      ' Bank offset (b4=1 I/O 0x123B)', 0
    db      '[      ] r+w-over-ROM 16ki 0x12',0
    db      '[      ] r+w-over-ROM 48ki 0x12',0
    db      0
    db      '[      ] r+w-over-ROM 16ki 0x13',0
    db      '[      ] r+w-over-ROM 48ki 0x13',0
.lines      equ     6

Start:
    ld      sp,stack
    NEXTREG_nn  TURBO_CONTROL_NR_07,3       ; 28MHz
    call    StartTest
    ld      de,MEM_ZX_SCREEN_4000+32*8*16+7*32+5    ; bottom right corner
    ld      bc,MEM_ZX_SCREEN_4000+32*8*16+7*32+19
    call    OutMachineIdAndCore_defLabels
    ;; preparing ULA screen for output
    BORDER  CYAN
    call    OutputLegend
    ;; preparing initial state of machine before tests
    BORDER  BLUE
    ; setup transparency features - make pink transparent and visible as fallback
    NEXTREG_nn GLOBAL_TRANSPARENCY_NR_14, $E3
    NEXTREG_nn TRANSPARENCY_FALLBACK_COL_NR_4A, $E3
    ; reset Layer2 scroll registers and set up clip window (to hide code/test values)
    NEXTREG_nn LAYER2_XOFFSET_NR_16, 0
    NEXTREG_nn LAYER2_YOFFSET_NR_17, 0
    NEXTREG_nn CLIP_WINDOW_CONTROL_NR_1C,$01    ; reset index in L2 clip
    NEXTREG_nn CLIP_LAYER2_NR_18,7              ; [7,1] -> [55,176] is enough for results
    NEXTREG_nn CLIP_LAYER2_NR_18,55
    NEXTREG_nn CLIP_LAYER2_NR_18,1
    NEXTREG_nn CLIP_LAYER2_NR_18,176
    ; init banks + make layer 2 visible
    NEXTREG_nn  LAYER2_RAM_BANK_NR_12,9
    NEXTREG_nn  LAYER2_RAM_SHADOW_BANK_NR_13,12
    ld      bc,LAYER2_ACCESS_P_123B
    ld      a,LAYER2_ACCESS_L2_ENABLED
    out     (c),a
    ; banks 9, 10, 11 => visible Layer 2 (fill with 0xE3 = transparent)
    ; banks 12, 13, 14 => shadow layer 2 (fill with 0xE0 = red)
    call    FillLayer2Banks
    ; banks 15, 16, 17 => fill as 8kiB pages with 0x11, 0x12, .., 0x16
    ld      a,15*2
    ld      hl,$E000
    ld      bc,$0611
.MarkRamLoop:
    NEXTREG_A   MMU7_E000_NR_57
    inc     a
    ld      (hl),c
    inc     c
    djnz    .MarkRamLoop
    ; map banks 15, 16, 17 to whole region $0000..$BFFF with MMU
    NEXTREG_nn  MMU0_0000_NR_50,15*2
    NEXTREG_nn  MMU1_2000_NR_51,15*2+1
    NEXTREG_nn  MMU2_4000_NR_52,15*2+2
    NEXTREG_nn  MMU3_6000_NR_53,15*2+3
    NEXTREG_nn  MMU4_8000_NR_54,15*2+4
    NEXTREG_nn  MMU5_A000_NR_55,15*2+5
    ;; running tests one by one
    BORDER  YELLOW
    ld      e,$F0       ; all tests OK so far (top four bits must stay set to 1, zero bit = some error)
    call    TestWriteOverRom
    call    TestReadOverRom
    call    TestReadOverRomCode
    call    TestReadOverRomIm1
    ;;; read+write together?
    call    TestBankOffsetRead

    ; reset the L2 port settings
        ld      bc,LAYER2_ACCESS_P_123B
        ld      a,LAYER2_ACCESS_BANK_OFFSET|0
        out     (c),a
        ld      a,LAYER2_ACCESS_L2_ENABLED|LAYER2_ACCESS_SHADOW_OVER_ROM
        out     (c),a       ; but set "shadow" mode to exercise emulators more

    ;; test done - do total border RED/GREEN depending on some error detected
    ld      a,e
    cp      $F0
    ld      a,GREEN
    jr      z,.AllTestsOk
    ld      a,RED
.AllTestsOk:
    out     (254),a
    jp      EndTest

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;test write-over-rom

    MACRO Test8kiPage address?, writeVal?, readVal?
        ld      hl,address?
        ld      (hl),writeVal?
        rlc     d
        ld      a,(hl)
        cp      readVal?
        jr      nz,800F
        set     4,d         ; set "1" to bit in D when OK (read)
800:
    ENDM

    MACRO VerifyWrite page?, value?
        NEXTREG_nn MMU7_E000_NR_57,page?
        rlc     d
        ld      a,($E000)
        cp      value?
        jr      nz,801F
        set     4,d
801:
    ENDM

    MACRO Test16kiBank bankSelect?, bankNumber?, wAdr?, wVal1?, wVal2?, rVal1?, rVal2?, resultAdr?, resultBank?
        ; map bank for write
        ld      bc,LAYER2_ACCESS_P_123B
        ld      a,LAYER2_ACCESS_L2_ENABLED|bankSelect?
        out     (c),a
        ;write first byte of each 8kiB page ($F9.. values)
        ;read address + verify [$11..] (write didn't affect regular RAM)
        ld      d,0         ; clear result (all bad)
        Test8kiPage wAdr?+$0000, wVal1?, rVal1?
        Test8kiPage wAdr?+$2000, wVal2?, rVal2?
        ; map the Layer2 memory with regular MMU to $E000 and verify written values
        VerifyWrite bankNumber?*2, wVal1?
        VerifyWrite bankNumber?*2+1, wVal2?
        ; cumulative result
        ld      a,resultBank?
        ld      hl,resultAdr?
        call    CumulateErrorAndDisplay
    ENDM

TestWriteOverRom:
    ; normal Layer 2 (NextReg $12)
.m1 EQU LAYER2_ACCESS_WRITE_OVER_ROM
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_BANK_0,  9, $0000, $F9, $FA, $11, $12, $E808,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_BANK_1, 10, $0000, $FB, $FC, $11, $12, $E810,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_BANK_2, 11, $0000, $FD, $FE, $11, $12, $E818,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_48K,     9, $0000, $E9, $EA, $11, $12, $F00B,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_48K,    10, $4000, $EB, $EC, $13, $14, $F013,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_48K,    11, $8000, $ED, $EE, $15, $16, $F01B,  9*2
    ; shadow Layer 2 (NextReg $13)
.m2 EQU LAYER2_ACCESS_WRITE_OVER_ROM|LAYER2_ACCESS_SHADOW_OVER_ROM
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_BANK_0, 12, $0000, $D9, $DA, $11, $12, $E808, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_BANK_1, 13, $0000, $DB, $DC, $11, $12, $E810, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_BANK_2, 14, $0000, $DD, $DE, $11, $12, $E818, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_48K,    12, $0000, $C9, $CA, $11, $12, $F00B, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_48K,    13, $4000, $CB, $CC, $13, $14, $F013, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_48K,    14, $8000, $CD, $CE, $15, $16, $F01B, 10*2
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test read-over-rom

TestReadOverRom:
    ; the same Test16kiBank macro can be used also to test "read-over"
    ; testing if write goes through into mapped RAM, and if read is overshadowed by Layer2
    ; normal Layer 2 (NextReg $12)
.m1 EQU LAYER2_ACCESS_READ_OVER_ROM
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_BANK_0, 15, $0000, $19, $1A, $E9, $EA, $F808,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_BANK_1, 15, $0000, $1B, $1C, $EB, $EC, $F810,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_BANK_2, 15, $0000, $1D, $1E, $ED, $EE, $F818,  9*2
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_48K,    15, $0000, $19, $1A, $E9, $EA, $E00B,  9*2+1
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_48K,    16, $4000, $1B, $1C, $EB, $EC, $E013,  9*2+1
    Test16kiBank .m1|LAYER2_ACCESS_OVER_ROM_48K,    17, $8000, $1D, $1E, $ED, $EE, $E01B,  9*2+1
    ; shadow Layer 2 (NextReg $13)
.m2 EQU LAYER2_ACCESS_READ_OVER_ROM|LAYER2_ACCESS_SHADOW_OVER_ROM
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_BANK_0, 15, $0000, $29, $2A, $C9, $CA, $F808, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_BANK_1, 15, $0000, $2B, $2C, $CB, $CC, $F810, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_BANK_2, 15, $0000, $2D, $2E, $CD, $CE, $F818, 10*2
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_48K,    15, $0000, $29, $2A, $C9, $CA, $E00B, 10*2+1
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_48K,    16, $4000, $2B, $2C, $CB, $CC, $E013, 10*2+1
    Test16kiBank .m2|LAYER2_ACCESS_OVER_ROM_48K,    17, $8000, $2D, $2E, $CD, $CE, $E01B, 10*2+1
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test read-over-rom for CPU executing code

    MACRO TestCodeInLayer L2bank?, bank_access?, resultAdr?, resultBank?
        ld      d,$00           ; clear result (all bad)
        ; switch off all the Layer 2 settings (just keep display)
        ld      bc,LAYER2_ACCESS_P_123B
        ld      a,LAYER2_ACCESS_L2_ENABLED
        out     (c),a
        ; code test - set up the test code in the first layer 2 bank (targetting ROM $007D)
        NEXTREG_nn MMU7_E000_NR_57,L2bank?
        push    de
        ld      hl,RomShadowTestCodeSource
        ld      de,$E000+$7D
        ld      bc,RomShadowTestCodeSourceLength
        ldir
        pop     de
        ; verify there is ROM mapped as expected (`cp $21 : ret nc`)
        NEXTREG_nn MMU0_0000_NR_50,$FF ; map ROM back
        NEXTREG_nn MMU1_2000_NR_51,$FF
        ld      hl,RomExpectedCodeSourceEnd-1   ; pointer into expected values
        ld      bc,$007D+RomShadowTestCodeSourceLength-1    ; pointer into ROM
        REPT 3  ; test three bytes of ROM code: 3x
            ld      a,(bc)
            cpd     ; HL--, BC--
            jr      nz,.UnexpectedRomContent
        ENDR
        ; call the ROM code
        ld      a,'!'
        call    $7D     ; CF=0 ROM, CF=1 L2
        jr      c,.NotRomResult
        set     7,d
.NotRomResult:
        ; set read-over-rom
        ld      bc,LAYER2_ACCESS_P_123B
        ld      a,LAYER2_ACCESS_L2_ENABLED|LAYER2_ACCESS_READ_OVER_ROM|bank_access?
        out     (c),a
        ; call the Layer 2 code
        ld      a,'!'
        call    $7D     ; CF=0 ROM, CF=1 L2
        jr      nc,.NotReadL2Result
        set     6,d
.NotReadL2Result:
        ; set write-over-rom
        ld      bc,LAYER2_ACCESS_P_123B
        ld      a,LAYER2_ACCESS_L2_ENABLED|LAYER2_ACCESS_WRITE_OVER_ROM|bank_access?
        out     (c),a
        ; call the ROM code
        ld      a,'!'
        call    $7D     ; CF=0 ROM, CF=1 L2
        jr      c,.NotRomResult2
        set     5,d
.NotRomResult2:
        ; set read+write-over-rom
        ld      bc,LAYER2_ACCESS_P_123B
        ld      a,LAYER2_ACCESS_L2_ENABLED|LAYER2_ACCESS_READ_OVER_ROM|LAYER2_ACCESS_WRITE_OVER_ROM|bank_access?
        out     (c),a
        ; call the Layer 2 code
        ld      a,'!'
        call    $7D     ; CF=0 ROM, CF=1 L2
        jr      nc,.NotReadL2Result2
        set     4,d
.NotReadL2Result2:
.UnexpectedRomContent:
        ld      a,resultBank?
        ld      hl,resultAdr?
        call    CumulateErrorAndDisplay
    ENDM

TestReadOverRomCode:
    TestCodeInLayer  9*2, LAYER2_ACCESS_OVER_ROM_BANK_0, $E818, 9*2+1
    TestCodeInLayer 12*2, LAYER2_ACCESS_SHADOW_OVER_ROM|LAYER2_ACCESS_OVER_ROM_BANK_0, $E818, 10*2+1
    ret

RomShadowTestCodeSource:
    cp      $FF
    ret
RomShadowTestCodeSourceLength EQU $ - RomShadowTestCodeSource

RomExpectedCodeSource:      ; ROM code which is expected (ZX48 ROM)
    cp      $21
    ret     nc
RomExpectedCodeSourceEnd:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test read-over-rom for CPU executing IM1 code

TestReadOverRomIm1:
    ; set up the IM1 handler in the third layer2's bank (targetting ROM $0038)
    push    de
    ; normal Layer 2
    NEXTREG_nn MMU7_E000_NR_57,11*2
    ld      de,$E000+$38
    ld      hl,RomShadowTestIm1Source
    ld      bc,RomShadowTestIm1SourceLength
    ldir
    ; shadow Layer 2
    NEXTREG_nn MMU7_E000_NR_57,14*2
    ld      de,$E000+$38
    ld      hl,RomShadowTestIm1Source
    ld      bc,RomShadowTestIm1SourceLength
    ldir
    pop     de
    ; normal Layer 2 - TEST is here
    ld      d,$00           ; clear result (all bad)
    ; set read-over-ROM
    ld      bc,LAYER2_ACCESS_P_123B
    ld      a,LAYER2_ACCESS_L2_ENABLED|LAYER2_ACCESS_READ_OVER_ROM|LAYER2_ACCESS_OVER_ROM_BANK_2
    out     (c),a
    ; EI + 4x HALT + DI
    ei
    .4 halt     ; each IM1 should set one bit in D
    di
    ; print result
    ld      a,9*2+1
    ld      hl,$F01B
    call    CumulateErrorAndDisplay
    ; shadow Layer 2 - TEST is here
    ld      d,$00           ; clear result (all bad)
    ; make normal layer 2 handler to fail
    NEXTREG_nn MMU7_E000_NR_57,11*2
    xor     a
    ld      ($E03A),a       ; `nop` instead of set 4,d
    ld      ($E03B),a
    ; set read-over-ROM
    ld      bc,LAYER2_ACCESS_P_123B
    ld      a,LAYER2_ACCESS_L2_ENABLED|LAYER2_ACCESS_READ_OVER_ROM|LAYER2_ACCESS_SHADOW_OVER_ROM|LAYER2_ACCESS_OVER_ROM_BANK_2
    out     (c),a
    ; EI + 4x HALT + DI
    ei
    .4 halt     ; each IM1 should set one bit in D
    di
    ; clear the visible part of Layer2
    push    de
    NEXTREG_nn MMU7_E000_NR_57,11*2
    ld      hl,$E000+$38
    ld      de,$E000+$38+1
    ld      bc,RomShadowTestIm1SourceLength
    ld      (hl),$E3
    ldir
    pop     de
    ; print result
    ld      a,10*2+1
    ld      hl,$F01B
    jp      CumulateErrorAndDisplay

RomShadowTestIm1Source:
    ; this is intentionally modifying the "result" register directly from interrupt code
    rlc     d
    set     4,d
    ei
    ret
RomShadowTestIm1SourceLength EQU $ - RomShadowTestIm1Source

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test new bank-offset of core3.1+ with read-over-rom mapping

TestBankOffsetRead:
    ; set up memory banks for the bank-offset tests again
        BORDER  BLUE
        ld      ix,$F000
        ld      a,9*2
.setMemoryLoop:             ; mark even 8k pages (odd are not tested)
        NEXTREG_A   MMU7_E000_NR_57
        cpl
        ld      (ix+1),a
        cpl
        ld      (ix),a
        inc     a
        inc     a
        cp      (13+9)*2
        jr      nz,.setMemoryLoop
    ; revert the memory mapping to default rom:5:2:x
        NEXTREG_nn  MMU0_0000_NR_50,255
        NEXTREG_nn  MMU1_2000_NR_51,255
        NEXTREG_nn  MMU2_4000_NR_52,5*2+0
        NEXTREG_nn  MMU3_6000_NR_53,5*2+1
        NEXTREG_nn  MMU4_8000_NR_54,2*2+0
        NEXTREG_nn  MMU5_A000_NR_55,2*2+1
    ; run tests
        BORDER  YELLOW
    ; test visible L2 layer first (both 16ki and 48ki tests in one subroutine)
        ld      iy,(11*2<<8)+9*2    ; test value - visible first bank + result page number
        ld      hl,$E809            ; result output address
        ld      a,LAYER2_ACCESS_OVER_ROM_BANK_0
        call    Test16kiAnd48kiBankOffsets
    ; test shadow L2 layer first (both 16ki and 48ki tests in one subroutine)
        ld      iy,((11*2+1)<<8)+12*2   ; test value - shadow first bank + result page
        ld      hl,$E009            ; result output address
        ld      a,LAYER2_ACCESS_OVER_ROM_BANK_0|LAYER2_ACCESS_SHADOW_OVER_ROM
    ;  |
    ; fallthrough into Test16kiAnd48kiBankOffsets and return from there
    ;  |
Test16kiAnd48kiBankOffsets:
    ; IN:
    ;  IYL = test-value and first page of first bank (8*2 for bank0 offset 0 NR$12=8)
    ;  IYH = 8ki page number for result output (for MMU7_E000 slot)
    ;  HL = result output address, E = global error tracking
    ;  A = visible/shadow value for port $123B (Layer2 port)
    ;  IX = check address in MMU7 slot ($F000 in this test)
    ; OUT: HL += $0300 (+3 lines below), updated E
    ; MOD: AF, BC, l2port, IYL
        or      LAYER2_ACCESS_L2_ENABLED|LAYER2_ACCESS_WRITE_OVER_ROM|LAYER2_ACCESS_READ_OVER_ROM
        push    iy
    ; do the three 16ki tests (base mapping changes, r+w test address is fixed $1000..+1)
.loopNextBankType:
    ; change the layer2 port mapping bank0/1/2 with desired mode
        ld      bc,LAYER2_ACCESS_P_123B
        out     (c),a
        call    TestEightBankOffsets
        inc     iyl             ; starting at +1 bank later
        inc     iyl
        add     a,$40           ; next bank offset
        cp      LAYER2_ACCESS_OVER_ROM_48K
        jr      c,.loopNextBankType
    ; do the three 48ki tests (base mapping fixed, r+w test address: $1000, $5000, $9000)
        ld      bc,LAYER2_ACCESS_P_123B
        out     (c),a           ; A = the 48ki mapping constant from last ADD above
        pop     iy              ; restore test value - visible first bank
.loop48kiBankType:
        call    TestEightBankOffsets
        inc     iyl             ; starting at +1 bank later
        inc     iyl
        ld      a,(TestEightBankOffsets.aR+1)
        add     a,$40
        ld      (TestEightBankOffsets.aR+1),a
        ld      (TestEightBankOffsets.aW+1),a
        cp      $C0
        jr      c,.loop48kiBankType
    ; reset test addresses inside TestEightBankOffsets subroutine
        ld      a,$10
        ld      (TestEightBankOffsets.aR+1),a
        ld      (TestEightBankOffsets.aW+1),a
        ret

TestEightBankOffsets:
    ; IN:
    ;  IYL = test-value and first page of first bank (8*2 for bank0 offset 0 NR$12=8)
    ;  IYH = 8ki page number for result output (for MMU7_E000 slot)
    ;  HL = result output address, E = global error tracking
    ;  I/O $123B (Layer2 port) = read+write mapping for visible or shadow layer as desired
    ;  IX = check address in MMU7 slot ($F000 in this test)
    ; OUT: HL += $0300 (+3 lines below), updated E
    ; MOD: BC
        push    af
        push    hl
        push    iy
        ld      a,LAYER2_ACCESS_BANK_OFFSET|0
.doNextBankOffset:
        ld      bc,LAYER2_ACCESS_P_123B
        out     (c),a
        ld      bc,%110'000'00'000'110'00   ; red:green (Bad:Correct)
        ex      af,af
.aR=$+1:ld      a,($1000)
        cp      iyl
        call    DisplayResultDot
        ld      bc,%111'000'00'000'111'00   ; red:green (Bad:Correct)
        ld      a,iyl
.aW=$+1:ld      ($1001),a
        NEXTREG_A MMU7_E000_NR_57
        cp      (ix+1)
        call    DisplayResultDot
        inc     l
        inc     l
        inc     iyl
        inc     iyl
        ex      af,af
        inc     a
        cp      LAYER2_ACCESS_BANK_OFFSET|8
        jr      nz,.doNextBankOffset
        pop     iy
        pop     hl
        inc     h               ; +3 pixel lines down
        inc     h
        inc     h
        pop     af
        ret

DisplayResultDot:
    ; IYH = 8ki page number for result output (for MMU7_E000 slot)
    ; ZF = correctness, HL = target adr, BC = colors (bad:correct)
    ; E = global result tracking (will be damaged in case of incorrect result
    ; output: HL+=2, updated E, modifies: AF, MMU7_E000 mapping
        ld      a,iyh
        NEXTREG_A MMU7_E000_NR_57
        ld      a,c             ; "correct" color
        jr      z,.isCorrectResult
        res     7,e             ; mark error in total result
        ld      a,b             ; "bad" color
.isCorrectResult:
        ld      (hl),a          ; draw 2x2 dot
        inc     h
        ld      (hl),a
        inc     l
        ld      (hl),a
        dec     h
        ld      (hl),a
        inc     l
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utility functions

CumulateErrorAndDisplay:    ; A = bank to write result to, HL = address to draw at
    NEXTREG_A MMU7_E000_NR_57
    ; cumulate the error results in register E
    ld      a,d
    and     e
    ld      e,a
    ; display results (rectangle 7x8 split into 4 parts horizontally green/red)
    ;;; continue into DisplayResultSquare
DisplayResultSquare:        ; D = %xxxx'0000 => results, x=1 OK, x=0 BAD
    call    .TwoValues      ; two values + two values = (all) four values
.TwoValues:
    call    .OneValue       ; one + one value = two values
.OneValue:
    ld      a,%111'000'00   ; red
    rl      d
    jr      nc,.wasBad
    ld      a,%000'111'00   ; green
.wasBad:
    call    .OnePixelRow    ; one + one row = two rows
    and     %110'110'11     ; darken the color a bit for second row
.OnePixelRow:
    ld      b,6
    push    hl
.rowLoop:
    ld      (hl),a
    inc     l
    djnz    .rowLoop
    pop     hl
    inc     h
    ret

; display legend in ULA screen text
OutputLegend:
    ; new part of test - bank offset legend
    ld      de,MEM_ZX_SCREEN_4000+32*8*16   ; third third
    ld      hl,LegendBankOffset
    ld      b,LegendBankOffset.lines
.bankOfsLegendLoop:
    call    OutStringAtDe
    ld      a,e
    add     a,32
    ld      e,a
    djnz    .bankOfsLegendLoop
    ; old parts of test
    ld      de,MEM_ZX_SCREEN_4000
    ld      hl,LegendNr12
    call    OutStringAtDe
    ld      de,MEM_ZX_SCREEN_4000+32*8*8    ; second third
    ld      hl,LegendNr13
    call    OutStringAtDe
    ; display lines for separate tests
    ld      de,MEM_ZX_SCREEN_4000+32        ; second line
    call    .BatchLoop
    ld      de,MEM_ZX_SCREEN_4000+32*8*8+32 ; ninth line
.BatchLoop:
    ld      b,6
    ld      hl,LegendTests
.StringLoop:
    call    OutStringAtDe
    ld      a,e
    add     a,32
    ld      e,a
    djnz    .StringLoop
    ret

FillLayer2Banks:
    ld      a,9*2
.fillVisibleL2:
    ld      c,$E3
    call    .fill8kiB
    inc     a
    cp      12*2
    jr      nz,.fillVisibleL2
.fillShadowL2:
    ld      c,$E0
    call    .fill8kiB
    inc     a
    cp      15*2
    jr      nz,.fillShadowL2
    ret
.fill8kiB:  ; A = page to map into MMU7, C = color to fill, modifies HL,DE,BC
    NEXTREG_A   MMU7_E000_NR_57
    ld      hl,$E000
    ld      de,$E001
    ld      (hl),c
    ld      bc,$1FFF
    ldir
    ret

    ASSERT  $ < $E000
    savesna "L2Port.sna", Start
