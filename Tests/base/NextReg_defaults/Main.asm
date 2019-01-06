    device zxspectrum48

    org	$6000

    INCLUDE "..\..\Constants.asm"

    ; data at beginning, as they will be 256B-aligned thanks to org $6000 "for free"
    ALIGN 256

NextRegDefaultRead:
    ; $FF = none NextReg (for READ), $FE = any default value, $FD = non zero default
    ; $FC = extra code should handle the test
    ; Other values are expected default value (must match strictly)
    ; NextReg $22 may rarely fail the test (when INT was high during read, timing issue)
    ;    x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xA  xB  xC  xD  xE  xF
    db  $FD,$FD,$FE,$FD,$FF,$FE,$00,$00,$10,$00,$FF,$FF,$FF,$FF,$FE,$FF ; $00..0F
    db  $00,$FF,$08,$0B,$E3,$00,$00,$00,$FC,$FC,$FC,$FF,$2A,$FF,$FE,$FE ; $10..1F
    db  $FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $20..2F
    db  $FF,$FF,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $30..3F
    db  $00,$00,$0F,$00,$FC,$FF,$FF,$FF,$FF,$FF,$00,$E3,$FF,$FF,$FF,$FF ; $40..4F
    db  $FD,$FD,$0A,$0B,$04,$05,$00,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $50..5F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $60..6F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $70..7F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $80..8F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $90..9F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $A0..AF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $B0..BF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $C0..CF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D0..DF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $E0..EF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $F0..FF

NextRegWriteInfo:       ; must follow NextRegDefaultRead in memory, at 256B boundary!
    ; $FF = none NextReg (for WRITE), $FE = too specific to test (skip write test),
    ; $FC = extra code should handle the test
    ; Values 00..7F are test value to be written to NextReg (no calculation)
    ; Values 80..FB are test value to be ORed with default read (only 7bits) and written
    ; Top bit can't be easily part of write test due to rules of test values (use $FC).
    ;
    ; The next table in memory tells, what should be read back after write.
    ;
    ; Some NextRegs are not tested, because their functionality is very specific for
    ; specific modes: $03, $04, ...
    ; $05 register writes back the same value (to not break user's config) = weak test
    ;    x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xA  xB  xC  xD  xE  xF
    db  $FF,$FF,$00,$FE,$FE,$80,$02,$01,$74,$08,$FF,$FF,$FF,$FF,$FF,$FF ; $00..0F
    db  $FE,$FE,$09,$0A,$25,$02,$55,$56,$FC,$FC,$FC,$FF,$07,$FF,$FF,$FF ; $10..1F
    db  $FF,$FF,$01,$02,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FF,$00,$FF,$FF ; $20..2F
    db  $FF,$FF,$66,$67,$3B,$00,$00,$0F,$3F,$0A,$FF,$FF,$FF,$FF,$FF,$FF ; $30..3F
    db  $70,$1F,$07,$68,$FC,$FF,$FF,$FF,$FF,$FF,$1F,$1F,$FF,$FF,$FF,$FF ; $40..4F
    db  $80,$80,$0A,$0B,$04,$05,$00,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $50..5F
    db  $00,$33,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $60..6F
    db  $FF,$FF,$FF,$FF,$FF,$00,$00,$0F,$3F,$0A,$FF,$FF,$FF,$FF,$FF,$FF ; $70..7F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $80..8F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $90..9F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $A0..AF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $B0..BF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $C0..CF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D0..DF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $E0..EF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01 ; $F0..FF

    ; Expected read values after WRITE test, must follow NextRegWriteInfo in memory
    ; $FF = do NOT test read, $FE = test against original value read
    ; Other values are precise values to be compared with value read from register
    ;    x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xA  xB  xC  xD  xE  xF
    db  $FF,$FF,$FF,$FF,$FF,$FE,$02,$01,$74,$08,$FF,$FF,$FF,$FF,$FF,$FF ; $00..0F
    db  $FF,$FF,$09,$0A,$25,$02,$55,$56,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF ; $10..1F
    db  $FF,$FF,$01,$02,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $20..2F
    db  $FF,$FF,$66,$67,$3B,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $30..3F
    db  $70,$02,$07,$68,$FF,$FF,$FF,$FF,$FF,$FF,$1F,$1F,$FF,$FF,$FF,$FF ; $40..4F
    db  $FE,$FE,$0A,$0B,$04,$05,$00,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $50..5F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $60..6F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $70..7F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $80..8F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $90..9F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $A0..AF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $B0..BF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $C0..CF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D0..DF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $E0..EF
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $F0..FF

    ALIGN 256
ResultToPaperColurConversion:
    ;   none, any-read, read-OK, read-ERR
    db  P_WHITE, P_CYAN|A_BRIGHT, P_GREEN|A_BRIGHT, P_RED
    db  P_WHITE|A_BRIGHT, P_CYAN, P_GREEN, P_RED        ; variants of result for W-skip
    db  P_MAGENTA|A_BRIGHT, P_CYAN|A_BRIGHT, P_GREEN|A_BRIGHT, P_YELLOW   ; variants of result for W-done
    db  P_MAGENTA|A_FLASH                               ; DEBUG

RESULT_NONE             equ 0
RESULT_DEF_READ_ANY     equ 1
RESULT_DEF_READ_OK      equ 2
RESULT_DEF_READ_ERR     equ 3
RESULT_WRITE_SKIP_FLAG  equ 4
RESULT_WRITE_DONE_FLAG  equ 8
RESULT_WRITE_VERIFY_ERR equ RESULT_DEF_READ_ERR
RESULT_DEBUG            equ 12

    INCLUDE "..\..\TestFunctions.asm"
    INCLUDE "..\..\OutputFunctions.asm"

Start:
    call Draw16x16GridWithHexaLabels

    call DrawLegend

    call StartTest

    ld      b,$00                   ; B = NextReg-to-test
    ld      hl,MEM_ZX_ATTRIB_5800   ; HL = ULA attribute cell position in 16x16 grid
    ld      ix,NextRegDefaultRead   ; IX = NextRegDefaultRead[register-to-test]
TestOneNextReg:
    ld      de,RESULT_NONE      ; D = 0 (value read), E = result enum
    ; pick READ info about NextReg-to-test
    ld      a,(ix)
    ld      c,a                 ; keep READ info also in C
    inc     a                   ; test for $FF => no next reg readable there
    jr      z,TestWrite
    ld      (hl),P_BLUE         ; turn the grid-element into PAPER BLUE (signal "read")
    cp      $FC+1               ; test for $FC => requires custom code for test
    jr      z,CustomReadDefaultTest
    ; generic READ test of default value
    ld      a,b
    call    ReadNextReg         ; A = NextReg[register-to-test]
    ld      d,a                 ; D = copy of value read from port
    cp      c                   ; compare with expected value
    jr      z,.ReadsCorrectDefaultValue     ; may accidentally colide with $FE and $FD (!)
        ; but the risk is so unlikely, and code simplicity gain high, that it's done.
    inc     c                   ; detect $FE => "any value" requirement
    inc     c
    jr      z,.ReadsAnyValue
    ; that leaves us with $FD "non zero" requirement
    inc     c                   ; detect $FD => "any non zero value" requirement
    jr      nz,.ReadIncorrectValue
    or      a                   ; test if value is non-zero
    jr      nz,.ReadsCorrectDefaultValue
.ReadIncorrectValue:
    ; expected value does not match, report error
    ld      e,RESULT_DEF_READ_ERR
    jr      TestWrite
.ReadsCorrectDefaultValue:
    ld      e,RESULT_DEF_READ_OK
    jr      TestWrite
.ReadsAnyValue:
    ld      e,RESULT_DEF_READ_ANY
TestWrite:
    ; pick WRITE info about NextReg-to-test
    inc     ixh
    ld      a,(ix)
    ld      c,a                 ; keep WRITE info also in C
    inc     a                   ; test for $FF => no next reg writeable there
    jr      z,DisplayResults
    inc     a                   ; test for $FE => NextReg too specific for test
    jr      z,.SpecificWriteFeatureSkipped
    cp      $FC+2               ; test for $FC => requires custom code for test
    jr      z,CustomWriteTest
    ; prepare value to be written (if top bit is set, it should be OR-ed with read value)
    ld      a,c
    bit     7,c                 ; test, if value should be OR-ed with read value)
    jr      z,.UseSpecifiedValue
    and     $7F                 ; keep only bottom 7 bits
    or      d
.UseSpecifiedValue:
    ; A=value to write, B=NextReg - write it to next reg (through I/O ports)
    call    WriteNextRegByIo
    set     3,e                 ; E |= 0x08 to signal write survival
    ; check if WRITE had expected effect (if testable, by reading the register back)
    inc     ixh
    ld      a,(ix)              ; READ-test info, keep copy also in C
    ld      c,a
    dec     ixh
    inc     a                   ; test for $FF => no test after write
    jr      nz,.DoTestRead
    ; drop result from green to cyan as write test is not performed
    ld      a,RESULT_DEF_READ_OK|RESULT_WRITE_DONE_FLAG
    cp      e
    jr      nz,DisplayResults
    ld      e,RESULT_DEF_READ_ANY|RESULT_WRITE_DONE_FLAG
    jr      DisplayResults
.DoTestRead:
    inc     a                   ; test for $FE => compare with value read first
    jr      nz,.TestReRead
    ld      c,d                 ; compare value set to first-read value
.TestReRead:
    ld      a,b
    call    ReadNextReg
    cp      c
    jr      z,DisplayResults
    ld      e,RESULT_WRITE_VERIFY_ERR
    jr      DisplayResults
.SpecificWriteFeatureSkipped:
    set     2,e                 ; E |= 0x04 to signal write-test-skip
DisplayResults:
    dec     ixh                 ; restore IX to the READ info table
    ; change grid cell colour according to result
    ld      d,ResultToPaperColurConversion>>8
    ld      a,(de)
    ld      (hl),a
    ; move to next register
    inc     ix
    inc     hl
    inc     b
    call    z,EndTest           ; terminate on B=0
    ; detect "new line" in terms of 16x16 grid
    ld      a,$0F
    and     b
    jr      nz,TestOneNextReg
    ld      a,16
    add     a,l
    ld      l,a
    jp      nc,TestOneNextReg
    inc     h
    jp      TestOneNextReg

CustomReadDefaultTest:
    ld      e,RESULT_DEF_READ_OK
    ld      a,b
    cp      $44
    jr      z,.Read9bPal
    ; 18..1A clip windows: all should read 0,255,0,191
    ld      iy,DataDefaultClipWindow
    ld      c,4
    call    CheckMultiReads
    jr      TestWrite
.Read9bPal:
    ; at this point palette index $40 was set to 0x70, one write on $41 (index => 0x71),
    ; palette sprite2 was selected by $43 write, so I would expect colour $7101 here
    ; (or $7100?) on real board, but needs confirmation that it works really like this.
    ld      iy,Data9bColourRead
    ld      c,2
    call    CheckMultiReads
    jr      TestWrite

; IY=data to compare with, C = data size, B = next reg to read
CheckMultiReads:
    ld      a,b
    call    ReadNextReg         ; A = NextReg[register-to-test]
    cp      (iy)                ; compare with expected values
    jr      z,.DataMatched      ; set error result if even one does not match
    ld      e,RESULT_DEF_READ_ERR
.DataMatched:
    inc     iy
    dec     c
    jr      nz,CheckMultiReads
    ret

CustomWriteTest:
    ld      a,b
    cp      $44
    jr      z,.Set9bPal
    ; 18..1A clip windows: write 4 coordinates: port^$1A, 278-port, 2*(port^$1A), 214-port
    ; prepare coordinates data into buffer
    ld      iy,DataWriteClipWindow
    ld      a,22                ; to end with (278-port) result (8b wrapped around)
    sub     b
    ld      (iy+1),a
    ld      a,214
    sub     b
    ld      (iy+3),a
    ld      a,b
    xor     $1A
    ld      (iy+0),a
    add     a,a
    ld      (iy+2),a
    ; write prepared data to nextReg
    ld      c,4
    call    .MultiWrites
    ; now verify the data were written successfully (plus reset clip-reg-index back to 0)
    ld      iy,DataWriteClipWindow
    ld      c,4
    call    CheckMultiReads
    ; do two more reads to move internal index of clip window register from 0 to 2
    ld      a,b
    call    ReadNextReg
    ld      a,b
    call    ReadNextReg
    jp      DisplayResults

.Set9bPal:
    ld      iy,Data9bColourWrite
    ld      c,2
    call    .MultiWrites
    ld      iy,Data9bColourVerify
    ld      c,2
    call    CheckMultiReads
    jp      DisplayResults

; IY=data to write, C = data size, B = next reg to read, does end with IY+=<size>
.MultiWrites:
    ld      a,(iy)
    ; A=value to write, B=NextReg - write it to next reg (through I/O ports)
    call    WriteNextRegByIo
    set     3,e                 ; E |= 0x08 to signal write survival
    inc     iy
    dec     c
    jr      nz,.MultiWrites
    ret

DataDefaultClipWindow:
    db      0, 255, 0, 191

Data9bColourRead:
    db      $71, $01

Data9bColourWrite:
    db      $79, $01

Data9bColourVerify:
    db      $72, $01

DataWriteClipWindow:
    db      0, 0, 0, 0

DrawLegend:
    ld      hl,LegendText
    ld      de,$4033
    call    OutStringAtDe       ; legend title
    ld      e,$73               ; +2 lines
.LineLoop:
    call    DrawLegendPaperBox
    call    OutStringAtDe
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    xor     a
    cp      (hl)
    jr      nz,.LineLoop
    ; draw the general "ReadMe.txt" message at bottom (HL points ahead of it)
    inc     hl
    ld      de,$5040
    call    OutStringAtDe
    ; color the label boxes
    ld      hl,$5873
    ld      de,LegendPapersData
    jr      .BoxColourLoopEntry
.BoxColourLoop:
    ld      (hl),a
    inc     de
    call    AdvanceAttrHlToNextLine
.BoxColourLoopEntry:
    ld      a,(de)
    or      a
    jr      nz,.BoxColourLoop
    ret

DrawLegendPaperBox:
    push    hl
    push    de
    ld      hl,LegendBoxGfx
    jr      .LoopEntry
.BoxLoop:
    ld      (de),a
    inc     hl
    inc     d
.LoopEntry:
    ld      a,(hl)
    or      a
    jr      nz,.BoxLoop
    pop     de
    pop     hl
    ret

LegendBoxGfx:
    db      $D5, $80, $01, $80, $01, $80, $01, $AB, 0

LegendText:
    db      '** Legend **',0
    db      ' no NextReg',0
    db      ' W      skip',0
    db      ' R+W      OK',0
    db      ' R+W  weakOK',0
    db      ' Wskip,R  OK',0
    db      ' Wskip,R wOK',0
    db      ' W      done',0
    db      ' R+W OK,dERR',0
    db      ' R/W/d ERROR',0
    db      ' R/W  freeze',0
    db      0                       ; empty string to terminate legend loop
    db      'For details check: ReadMe.txt',0

LegendPapersData:
    db      P_WHITE, P_WHITE|A_BRIGHT, P_GREEN|A_BRIGHT, P_CYAN|A_BRIGHT
    db      P_GREEN, P_CYAN, P_MAGENTA|A_BRIGHT, P_YELLOW, P_RED, P_BLUE
    db      0

    savesna "NRdefaul.sna", Start
