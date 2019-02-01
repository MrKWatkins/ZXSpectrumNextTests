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
    ; Clip-window registers $18..$1A require also writing to read them, so they are
    ; tested fully in the custom-write mode, skipping read-only phase.
    ;    x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xA  xB  xC  xD  xE  xF
    db  $FD,$FD,$FE,$FD,$FF,$FE,$FE,$00,$10,$00,$FF,$FF,$FF,$FF,$FE,$FF ; $00..0F
    db  $00,$FF,$08,$0B,$E3,$00,$00,$00,$FF,$FF,$FF,$FF,$C6,$FF,$FE,$FE ; $10..1F
    db  $FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00 ; $20..2F
    db  $00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $30..3F
    db  $00,$00,$0F,$00,$01,$FF,$FF,$FF,$FF,$FF,$00,$E3,$0F,$FF,$FF,$FF ; $40..4F
    db  $FD,$FD,$0A,$0B,$04,$05,$00,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $50..5F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$00,$00,$FF,$00,$00 ; $60..6F
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
    db  $FE,$FE,$09,$0A,$25,$02,$55,$56,$FC,$FC,$FC,$FC,$08,$FF,$FF,$FF ; $10..1F
    db  $FF,$FF,$01,$02,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FF,$00,$FF,$01 ; $20..2F
    db  $03,$06,$02,$01,$7B,$00,$00,$0F,$3F,$0A,$FF,$FF,$FF,$FF,$FF,$FF ; $30..3F
    db  $70,$1F,$07,$68,$FC,$FF,$FF,$FF,$FF,$FF,$1F,$20,$0E,$FF,$FF,$FF ; $40..4F
    db  $80,$80,$0A,$0B,$04,$05,$00,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $50..5F
    db  $00,$33,$01,$FF,$FF,$FF,$FF,$FF,$40,$FF,$FF,$60,$0F,$FF,$5B,$5C ; $60..6F
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
    db  $FF,$FF,$09,$0A,$25,$02,$55,$56,$FF,$FF,$FF,$FF,$06,$FF,$FF,$FF ; $10..1F
    db  $FF,$FF,$01,$02,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01 ; $20..2F
    db  $03,$06,$02,$01,$7B,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $30..3F
    db  $70,$02,$07,$68,$FF,$FF,$FF,$FF,$FF,$FF,$1F,$20,$0E,$FF,$FF,$FF ; $40..4F
    db  $FE,$FE,$0A,$0B,$04,$05,$00,$01,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $50..5F
    db  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$40,$FF,$FF,$60,$0F,$FF,$1B,$1C ; $60..6F
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
ResultToPaperColourConversion:
    ;   none, any-read, read-OK, read-ERR
    db  P_WHITE, P_CYAN|A_BRIGHT, P_GREEN|A_BRIGHT, P_RED|A_BRIGHT
    db  P_WHITE|A_BRIGHT, P_CYAN, P_GREEN, P_RED|A_BRIGHT   ; variants of result for W-skip
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

DataDefaultClipWindow:
    db      0, 255, 0, 191
    db      0, 0, 0, 0          ; buffer for new coordinates (phase1) (at +4 address)
    db      0, 0, 0, 0          ; buffer for new coordinates (phase2) (at +8 address)

DataTilemapClipWindow:
    db      0, 159, 0, 255
    db      0, 0, 0, 0          ; buffer for new coordinates (phase1) (at +4 address)
    db      0, 0, 0, 0          ; buffer for new coordinates (phase2) (at +8 address)

Data9bColourWrite:
    db      $79, $01

LegendBoxGfx:
    db      $D5, $80, $01, $80, $01, $80, $01, $AB

LegendPapersData:
    db      P_WHITE, P_WHITE|A_BRIGHT, P_GREEN|A_BRIGHT, P_CYAN|A_BRIGHT
    db      P_GREEN, P_CYAN, P_MAGENTA|A_BRIGHT, P_YELLOW, P_RED|A_BRIGHT, P_BLUE|A_BRIGHT
LegendPapersDataSize    equ $ - LegendPapersData

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
    ; count of legend-labels is deducted from LegendPapersDataSize -> keep it synced
LegendMachineId:
    db      'MachineID:',0
    db      'core',0
ReadmeNoticeText:
    db      'For details check: ReadMe.txt',0

    INCLUDE "..\..\TestFunctions.asm"
    INCLUDE "..\..\OutputFunctions.asm"

Start:
    call StartTest

    call Draw16x16GridWithHexaLabels

    call DrawLegend
    ; Set output address for bad values logging (into last third of screen)
    ld      hl,$5020
    ld      (OutCurrentAdr),hl

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
    ld      (hl),P_BLUE|A_BRIGHT    ; turn the grid-cell into PAPER BLUE: signal "read"
    cp      $FC+1               ; test for $FC => requires custom code for test
    jp      z,CustomReadDefaultTest
    ; generic READ test of default value
    ld      a,b
    call    ReadNextReg         ; A = NextReg[register-to-test]
    ld      d,a                 ; D = copy of value read from port
    ld      (ix),a              ; also store it directly in default-read table
        ; will be used at the very end of test to display HW info, plus backup for debug.
    cp      c                   ; compare with expected value
    jr      z,.ReadsCorrectDefaultValue ; may accidentally collide with $FE and $FD (!)
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
    ; output the wrong value into log
    ld      c,P_YELLOW
    call    OutErrValue
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
    ld      (hl),P_BLUE|A_BRIGHT    ; turn the grid-cell into PAPER BLUE: signal "write"
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
    ; output the wrong value into log
    ld      c,P_RED|A_BRIGHT
    call    OutErrValue
    jr      DisplayResults
.SpecificWriteFeatureSkipped:
    set     2,e                 ; E |= 0x04 to signal write-test-skip
DisplayResults:
    dec     ixh                 ; restore IX to the READ info table
    ; change grid cell colour according to result
    ld      d,ResultToPaperColourConversion>>8
    ld      a,(de)
    ld      (hl),a
    ; move to next register
    inc     ix
    inc     hl
    inc     b                   ; terminate on B=0
    jp      z,DrawMachineInfoAndFinish
    ; detect "new line" in terms of 16x16 grid
    ld      a,$0F
    and     b
    jp      nz,TestOneNextReg
    ld      a,16
    add     a,l
    ld      l,a
    jp      nc,TestOneNextReg
    inc     h
    jp      TestOneNextReg

CustomReadDefaultTest:
    ; currently no Read-phase custom code is used
    ld      e,RESULT_DEBUG
    ; output the wrongly defined NextReg into log
    ld      c,P_MAGENTA|A_BRIGHT
    ld      a,b
    call    OutErrValue.OutAOnce
    jr      TestWrite

CustomWriteTest:
    ld      a,b
    cp      $1B
    jr      c,.ClipWindowCustomTest
    jr      z,.TilemapClipWindowCustomTest
    cp      $44
    jr      z,.Set9bPal
    ld      e,RESULT_DEBUG
    ; output the wrongly defined NextReg into log
    ld      c,P_MAGENTA|A_BRIGHT
    ld      a,b
    call    OutErrValue.OutAOnce
    jp      DisplayResults

; set 9bit palette custom test
.Set9bPal:
    ; write colour $79, $00
    ld      a,$79
    call    WriteNextRegByIo
    ld      a,$00
    call    WriteNextRegByIo
    set     3,e                 ; E |= 0x08 to signal write survival
    ; index was auto-incremented to $72 (colour $72, $01 by default)
    ; verify-write: read $44, should result into $01 byte ("second" of $72 colour)
    ld      a,b
    call    ReadNextReg
    dec     a                   ; test for expected $01 value
    jp      z,DisplayResults
    ld      e,RESULT_DEF_READ_ERR
    ; output the wrong value into log
    inc     a                   ; restore the value
    ld      c,P_RED|A_BRIGHT
    call    OutErrValue
    jp      DisplayResults      ; else set error result

; 1B clip window for tilemap
.TilemapClipWindowCustomTest:
    ; prepare new coordinates data into buffer (twice, at +4 and +8 offsets)
    ld      iy,DataTilemapClipWindow
    jr      .continueWithCustomClipWindowTest

; 18..1A clip windows: write 4 coordinates: port^$1A, 278-port, 2*(port^$1A), 214-port
; (also validates the default {0, 255, 0, 191} content
.ClipWindowCustomTest:
    ; prepare new coordinates data into buffer (twice, at +4 and +8 offsets)
    ld      iy,DataDefaultClipWindow
.continueWithCustomClipWindowTest:
    ld      a,22                ; to end with (278-port) result (8b wrapped around)
    sub     b
    ld      (iy+1+4),a          ; X2
    ld      (iy+1+8),a
    ld      a,214
    sub     b
    ld      (iy+3+4),a          ; Y2
    ld      (iy+3+8),a
    ld      a,b
    xor     $1A
    ld      (iy+0+4),a          ; X1
    ld      (iy+0+8),a
    add     a,a
    ld      (iy+2+4),a          ; Y1
    ld      (iy+2+8),a
    ; the sub-index of particular clip window register is incremented only upon write
    ; so the following test has to both verify default value and then write new value
    ld      de,(P_YELLOW<<8) + RESULT_DEF_READ_OK   ; D = colour for LOG output
    call    .ReadWriteClipWindowTest
    set     3,e                 ; E |= 0x08 to signal write survival
    ; do the second round of read+write (new value check, new value write) = verification
    ld      d,P_RED|A_BRIGHT    ; D = colour for LOG output
    call    .ReadWriteClipWindowTest
    ; do Register-$18 more writes just to bump index of clip register to 0..3
    ld      a,b
    and     $03
    ld      c,a                 ; c = 0..3 for NextRegs $18..$1B
    jr      z,.NoMoreExtraWrites
.DoExtraWritesLoop:
    ld      a,(iy+0)
    call    WriteNextRegByIo
    inc     iy
    dec     c
    jr      nz,.DoExtraWritesLoop
.NoMoreExtraWrites:
    ; check if some LOG was emitted, if yes, output NextReg number too
    ld      a,RESULT_WRITE_SKIP_FLAG-1
    and     e
    cp      RESULT_DEF_READ_ERR
    jp      nz,DisplayResults
    ; display NextRegNumber in LOG
    ld      a,b
    ld      c,P_CYAN
    call    OutErrValue.OutAOnce
    jp      DisplayResults
.ReadWriteClipWindowTest:
    ld      c,4
.ReadWriteClipWindowLoop:       ; will test default value and write new value then
    ld      a,b
    call    ReadNextReg
    cp      (iy)
    jr      z,.ClipWindowDataMatched
    ld      e,RESULT_DEF_READ_ERR   ; set error result if even one does not match
    ; output the wrong value into log
    push    bc
    ld      c,d
    call    OutErrValue.OutAOnce
    pop     bc
.ClipWindowDataMatched:
    ld      a,(iy+4)
    ; A=value to write, B=NextReg - write it to next reg (through I/O ports)
    call    WriteNextRegByIo
    inc     iy
    dec     c
    jr      nz,.ReadWriteClipWindowLoop
    ret

DrawMachineInfoAndFinish:
    ; reset LoRes scroll registers (does affect ULA screen since core 2.00.25+)
    ld      a,0
    ld      b,LORES_XOFFSET_NR_32
    call    WriteNextRegByIo
    ld      a,0
    ld      b,LORES_YOFFSET_NR_33
    call    WriteNextRegByIo
    ; fix MMU1 mapping to make my life easier when testing with CSpect emulator
    ld      a,$FF
    ld      b,MMU1_2000_NR_51
    call    WriteNextRegByIo
    ; Display MachineID and core version values
    ld      ix,NextRegDefaultRead
    ld      hl,MEM_ZX_SCREEN_4000 + 32*64 + (14-8)*32 + 29    ; char pos [14,29] (2nd 1/3)
    ld      (OutCurrentAdr),hl
    ld      a,(ix+MACHINE_ID_NR_00)
    call    OutDecimalValue
    ; show major version number (upper 4 bits)
    ld      hl,MEM_ZX_SCREEN_4000 + 32*64 + (15-8)*32 + 23    ; char pos [15,23] (2nd 1/3)
    ld      a,(ix+NEXT_VERSION_NR_01)
    rrca
    rrca
    rrca
    rrca
    and     $0F
    ; move version output one char to right when major is less than 10
    ld      de,0
    cp      10
    adc     hl,de
    ld      (OutCurrentAdr),hl
    call    OutDecimalValue
    ld      a,'.'
    call    OutChar
    ; show minor version number (bottom 4 bits)
    ld      a,(ix+NEXT_VERSION_NR_01)
    and     $0F
    call    OutDecimalValue
    ld      a,'.'
    call    OutChar
    ; show sub-minor version number
    ld      a,(ix+NEXT_VERSION_MINOR_NR_0E)
    call    OutDecimalValue
    jp      EndTest

DrawLegend:
    ld      hl,LegendText
    ld      de,$4033
    call    OutStringAtDe       ; legend title
    ld      e,$73               ; +2 lines
    ld      c,LegendPapersDataSize  ; B is used by DrawLegendPaperBox
.LineLoop:
    call    DrawLegendPaperBox
    call    OutStringAtDe
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    dec     c
    jr      nz,.LineLoop
    ; draw the HW info labels (HL now points at LegendMachineId)
    ld      b,2
.MachineInfoLabelLoop:
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    call    OutStringAtDe
    djnz    .MachineInfoLabelLoop
    ; draw the general "ReadMe.txt" message at bottom (HL already points at it)
    ld      de,$50C0            ; and HL = ReadmeNoticeText
    call    OutStringAtDe
    ; color the label boxes
    ld      hl,MEM_ZX_ATTRIB_5800+(3*32)+19     ; char pos [3,19]
    ld      de,LegendPapersData
    ld      b,LegendPapersDataSize
.BoxColourLoop:
    ld      a,(de)
    ld      (hl),a
    inc     de
    call    AdvanceAttrHlToNextLine
    djnz    .BoxColourLoop
    ret

DrawLegendPaperBox:
    push    hl
    push    de
    ld      hl,LegendBoxGfx
    ld      b,8
.BoxLoop:
    ld      a,(hl)
    ld      (de),a
    inc     hl
    inc     d
    djnz    .BoxLoop
    pop     de
    pop     hl
    ret

; A = value to output, C = attribute, B = nextReg, modifies A and C (!)
; The attribute addressing is very hacky (expecting OutCurrentAdr to belong to last third)
; I mean, this whole routine is one huge hack, working only under precise conditions...
OutErrValue:
    call    .OutAOnce           ; write the wrong value
    ld      a,b                 ; show also NextReg value right after it
    ld      c,P_CYAN
.OutAOnce:
    push    hl
    ld      hl,(OutCurrentAdr)  ; convert $50xx -> $5Axx
    set     1,h
    set     3,h
    ; set attributes
    ld      (hl),c
    inc     l
    ld      (hl),c
    ; detect if next write would reach $50C0 character (where the ReadMe notice is)
    inc     l
    jp      p,.LogNotFullYet
    bit     6,l
    jr      z,.LogNotFullYet
    ; if yes, disable further log output
    ld      hl,OutErrValue      ; self-modify routine entry to just return next time
    ld      (hl),201            ; "RET" instruction code
.LogNotFullYet:
    pop     hl
    jp      OutHexaValue

    savesna "!NextReg.sna", Start
