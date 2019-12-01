    device zxspectrum48

    org     $C000       ; must be in last 16k as I'm using all-RAM mapping for Layer2
    ds      32, $55     ; reserved space for stack
stack:
    dw      $AAAA

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

ATTR_CODE_TEST_BAD  EQU P_RED|WHITE
ATTR_CODE_TEST_OK   EQU P_GREEN|WHITE

Start:
    ld      sp,stack
    NEXTREG_nn  TURBO_CONTROL_NR_07,3       ; 28MHz
    call    StartTest
    ld      de,MEM_ZX_SCREEN_4000+18
    ld      bc,MEM_ZX_SCREEN_4000+32+18
    call    OutMachineIdAndCore_defLabels
    ;; do the code-only test first and write result on screen after
    BORDER  YELLOW
    ; enable timex port $FF read (disable floating bus)
    ld      a,PERIPHERAL_3_NR_08
    call    ReadNextReg
    or      (1<<2)
    NEXTREG_A PERIPHERAL_3_NR_08

    ;; write different values to 0x69 and read them back from the mirrored ports
    ld      ix,CodeTestsTotal
    ld      iy,MEM_ZX_ATTRIB_5800+32

WriteToNextReg0x69Test:
    MACRO TEST_VALUE_W value?
        inc     (ix)    ; increment total tests
        ld      (iy),ATTR_CODE_TEST_BAD
        ld      iyh,$44
        ld      (iy),value?
        inc     iyh
        NEXTREG_nn DISPLAY_CONTROL_NR_69,value?
        ; read values back - wait short while to see if board needs time to apply write
        ld      b,32
        djnz    $
        ; can't read shadow ULA reg, set it explicitly to correct value (but in top bit!)
        ld      d,(value? & $40)<<1
        ; read Layer 2
        ld      bc,LAYER2_ACCESS_P_123B
        in      a,(c)
        rra
        rra
        rr      d       ; D:7 = Layer2 enabled, D:6 = ULA shadow
        ; read Timex port
        ld      bc,255
        in      a,(c)
        and     $3F
        or      d       ; A = layer2:shadow:timex5-0
        ; compare with original value
        ld      (iy),a
        ld      iyh,$58
        cp      value?
        jr      nz,.wrongValue
        inc     (ix + 1)    ; increment passed tests
        ld      (iy),ATTR_CODE_TEST_OK
.wrongValue:
        inc     iy
    ENDM

    TEST_VALUE_W %00000000    ; L2 0, ULAshadow 0, timex color 0, mode 0
    TEST_VALUE_W %01000000    ; L2 0, ULAshadow 1, timex color 0, mode 0
    TEST_VALUE_W %10000000    ; L2 1, ULAshadow 0, timex color 0, mode 0
    TEST_VALUE_W %00010110    ; L2 0, ULAshadow 0, timex color 2, mode 6
    TEST_VALUE_W %11101000    ; L2 1, ULAshadow 1, timex color 5, mode 0

ReadFromNextReg0x69Test:
    MACRO TEST_VALUE_R value?
        inc     (ix)    ; increment total tests
        ld      (iy),ATTR_CODE_TEST_BAD
        ld      iyh,$44
        ld      (iy),value?
        inc     iyh
        ; write layer 2 bit
        ld      bc,LAYER2_ACCESS_P_123B
        in      a,(c)
        IF value? & $80
        or      2
        ELSE
        and     ~2
        ENDIF
        out     (c),a
        ; write ula shadow bit
        ld      a,(value?&$40)>>(6-3)   ; set other bits to 0, seems to be current value
        ld      bc,$7FFD
        out     (c),a
        ; write timex bits
        ld      a,value? & $3F
        out     (255),a
        ; read value back - wait short while to see if board needs time to apply writes
        ld      b,32
        djnz    $
        ld      a,DISPLAY_CONTROL_NR_69
        call    ReadNextReg
        ; compare with original value
        ld      (iy),a
        ld      iyh,$58
        cp      value?
        jr      nz,.wrongValue
        inc     (ix + 1)    ; increment passed tests
        ld      (iy),ATTR_CODE_TEST_OK
.wrongValue:
        inc     iy
    ENDM

    TEST_VALUE_R %00000000    ; L2 0, ULAshadow 0, timex color 0, mode 0
    TEST_VALUE_R %01000000    ; L2 0, ULAshadow 1, timex color 0, mode 0
    TEST_VALUE_R %10000000    ; L2 1, ULAshadow 0, timex color 0, mode 0
    TEST_VALUE_R %00010110    ; L2 0, ULAshadow 0, timex color 2, mode 6
    TEST_VALUE_R %11101000    ; L2 1, ULAshadow 1, timex color 5, mode 0

    ; switch everything off/zero (to see results display)
    NEXTREG_nn DISPLAY_CONTROL_NR_69,0

    ;; display results of code-only tests
    ; change border color
    ld      a,(ix)
    cp      (ix + 1)
    ld      a,RED
    jr      nz,.didNotPassAll
    ld      a,GREEN
.didNotPassAll:
    BORDER  a
    ; display decimal values total/passed
    ld      de,MEM_ZX_SCREEN_4000
    ld      hl,LabelTestsTxt
    call    OutStringAtDe
    ld      a,(ix + 1)
    call    OutDecimalValue
    ld      a,'/'
    call    OutChar
    ld      a,(ix)
    call    OutDecimalValue
    ld      hl,MEM_ZX_SCREEN_4000+32+$100
    ld      a,%0000'0001
    ld      b,(ix)
.rulerLoop1:
    ld      (hl),a
    inc     l
    djnz    .rulerLoop1
    ld      hl,MEM_ZX_SCREEN_4000+32+$200
    ld      a,%0001'0001
    ld      b,(ix)
.rulerLoop2:
    ld      (hl),a
    inc     l
    djnz    .rulerLoop2
    
;     ld      de,MEM_ZX_SCREEN_4000+32
;     ld      (OutCurrentAdr),de
;     ld      b,(ix)
; .HashingAllTests:
;     ld      a,'#'
;     call    OutChar
;     djnz    .HashingAllTests

    ;; prepare visual test
    MACRO FILL_L2_BOX adr?,dither?,width?,height?,ditherSize?
        ld      hl,adr?
        ld      de,dither?
        ld      bc,(width?<<8)|height?
        ld      a,ditherSize?
        call    FillL2Box
    ENDM
L2_GREEN_DITHER EQU %000'101'00'000'111'00

PrepareVisualTest:
    call    OutputLegendaryTextsFromData
    ;; setup Copper code to switch modes infinitelly on particular lines
    NEXTREG_nn  COPPER_CONTROL_HI_NR_62,0   ; STOP copper + index.high = 0
    NEXTREG_nn  COPPER_CONTROL_LO_NR_61,0   ; index.low = 0
    ld      b,CopperCodeLength
    ld      hl,CopperCode
.SetupCopperLoop:
    ld      a,(hl)
    inc     hl
    NEXTREG_A   COPPER_DATA_NR_60
    djnz    .SetupCopperLoop
    NEXTREG_nn  COPPER_CONTROL_HI_NR_62,$C0 ; START copper, reset at Vblank
    ;; draw Layer 2 parts
    NEXTREG_nn  LAYER2_RAM_BANK_NR_12,9     ; banks 9,10,11 for Layer 2
    NEXTREG_nn  GLOBAL_TRANSPARENCY_NR_14,$E3       ; pink $E3 is transparent color
    NEXTREG_nn  TRANSPARENCY_FALLBACK_COL_NR_4A,$E3 ; fallback would show also pink $E3
    ; fill full layer 2 with red $E0 first, clear transparent active row, draw green box
    NEXTREG_nn  MMU4_8000_NR_54,9*2
    NEXTREG_nn  MMU5_A000_NR_55,9*2+1
    FILL_AREA $8000, $4000, $E0
    FILL_AREA $8000+$1800, $0800, $E3       ; clear char-row 3 with transparent $E3
    FILL_L2_BOX $8000+$1968, L2_GREEN_DITHER, $18, $06, 1   ; green box at row 3
    NEXTREG_nn  MMU4_8000_NR_54,10*2
    NEXTREG_nn  MMU5_A000_NR_55,10*2+1
    FILL_AREA $8000, $4000, $E0
    FILL_AREA $8000+$0800, $1000, $E3       ; clear char-rows 9 and 10 with transparent
    FILL_L2_BOX $8000+$0968, L2_GREEN_DITHER, $18, $06, 1   ; green box at row 9
    FILL_L2_BOX $8000+$1168, L2_GREEN_DITHER, $18, $06, 1   ; green box at row 10
    NEXTREG_nn  MMU4_8000_NR_54,11*2
    NEXTREG_nn  MMU5_A000_NR_55,11*2+1
    FILL_AREA $8000, $4000, $E0
    jp      EndTest

OutputLegendaryTextsFromData:
    ; setup first Bank 7 texts (first batch of inputs in data)
    NEXTREG_nn  MMU2_4000_NR_52,7*2
    ; clear the shadow VRAM first, can contain noise (from NextZXOS, etc)
    FILL_AREA $4000, $1B00, $0  ; including attributes to black:black
    ld      hl,LabelsVisualData
    call    .LegendaryLoopEntry
    ; now setup the regular ULA texts (second batch of inputs)
    NEXTREG_nn  MMU2_4000_NR_52,5*2
    jr      .LegendaryLoopEntry
    ; process the ASCII text data
.LegendaryLoop:
    call    OutStringAtDe
.LegendaryLoopEntry:
    ld      e,(hl)
    inc     hl
    ld      d,(hl)
    inc     hl
    ld      a,(hl)
    or      a
    jr      nz,.LegendaryLoop
    inc     hl
    ; process the attributes data
    jr      .AttributedLoopEntry

.AttributedLoop:
    ; HL = def data, DE = VRAM, BC = columns:lines, A = fill pattern
    push    hl
    ex      de,hl
    ld      d,a
    ; HL = VRAM adr, D = fill pattern, B = columns, C = lines (advances per char +8px)
    call    FillSomeUlaLines
    pop     hl
.AttributedLoopEntry:
    ld      e,(hl)
    inc     hl
    ld      d,(hl)
    inc     hl
    ld      c,(hl)
    inc     hl
    ld      b,(hl)
    inc     hl
    ld      a,(hl)
    inc     hl
    or      a
    jr      nz,.AttributedLoop
    ret

CodeTestsTotal:     DB  0
CodeTestsPassed:    DB  0   ; must follow CodeTestsTotal, don't move it

LabelTestsTxt:      DB  'Tests OK: ', 0

LabelsVisualData:
    ; Bank 7 data first
    DW MEM_ZX_SCREEN_4000+32*4              : DB 'ULA shadow:  ###', 0
    DW MEM_ZX_SCREEN_4000+2048+32*1         : DB 'L2 + shadow:      ###', 0
    DW 0                                    : DB 0  ; batch terminator
    ; Bank 7 Attributes data
    DW MEM_ZX_ATTRIB_5800+32*4              : DB 1, 32, P_WHITE|BLACK
    DW MEM_ZX_ATTRIB_5800+32*4+13           : DB 1, 3, P_GREEN|WHITE
    DW MEM_ZX_ATTRIB_5800+32*9              : DB 1, 32, P_WHITE|BLACK
    DW MEM_ZX_ATTRIB_5800+32*9+18           : DB 1, 3, P_GREEN|WHITE
    DW 0, 0                                 : DB 0  ; attr batch terminator

    ; Bank 5 data
    DW MEM_ZX_SCREEN_4000+32*3              : DB 'Layer 2:', 0
    DW MEM_TIMEX_SCR1_6000+32*5             : DB 'Timex scr1:  ###', 0
    DW MEM_TIMEX_SCR0_4000+32*6             : DB 'Timex HiCol: ###', 0

    ; "Timex HiRes Black/White"
    DW MEM_TIMEX_SCR0_4000+32*7             : DB 'TmxHRsBakWie', 0
    DW MEM_TIMEX_SCR1_6000+32*7             : DB 'ie ie lc/ht', 0

    ; "Timex Hires Blue/Yellow"
    DW MEM_TIMEX_SCR0_4000+2048+32*0        : DB 'TmxHRsBu/elw', 0
    DW MEM_TIMEX_SCR1_6000+2048+32*0        : DB 'ie ie leYlo', 0

    DW MEM_TIMEX_SCR1_6000+2048+32*2        : DB 'L2 + T scr1:      ###', 0
    DW 0                                    : DB 0  ; batch terminator
    ; Bank 5 Attributes data
    DW MEM_ZX_ATTRIB_5800+$2000+32*5        : DB 1, 32, P_WHITE|BLACK
    DW MEM_ZX_ATTRIB_5800+$2000+32*5+13     : DB 1, 3, P_GREEN|WHITE
    ; HiColor needs manual split (too lazy to write special routine for single line)
    DW MEM_TIMEX_SCR1_6000+256*0+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*0+32*6+13    : DB 1, 3, P_GREEN|WHITE
    DW MEM_TIMEX_SCR1_6000+256*1+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*1+32*6+13    : DB 1, 3, P_GREEN|WHITE
    DW MEM_TIMEX_SCR1_6000+256*2+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*2+32*6+13    : DB 1, 3, P_GREEN|YELLOW
    DW MEM_TIMEX_SCR1_6000+256*3+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*3+32*6+13    : DB 1, 3, P_GREEN|CYAN
    DW MEM_TIMEX_SCR1_6000+256*4+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*4+32*6+13    : DB 1, 3, P_GREEN|RED
    DW MEM_TIMEX_SCR1_6000+256*5+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*5+32*6+13    : DB 1, 3, P_GREEN|BLUE
    DW MEM_TIMEX_SCR1_6000+256*6+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*6+32*6+13    : DB 1, 3, P_GREEN|BLACK
    DW MEM_TIMEX_SCR1_6000+256*7+32*6       : DB 1, 32, P_WHITE|BLACK
    DW MEM_TIMEX_SCR1_6000+256*7+32*6+13    : DB 1, 3, P_GREEN|WHITE
    ; L2 + T scr1
    DW MEM_ZX_ATTRIB_5800+$2000+32*10       : DB 1, 32, P_WHITE|BLACK
    DW MEM_ZX_ATTRIB_5800+$2000+32*10+18    : DB 1, 3, P_GREEN|WHITE
    DW 0, 0                                 : DB 0  ; attr batch terminator

CopperCode:     ;; remember the copper instructions are big endian (bytes: WAIT/REGISTER, scanline/value)
    DW  $0069   ; at [0,0] switch all off, defaul ULA classic
    DW  COPPER_WAIT_H|($18<<8), $8069  ; Layer 2 ON, shadow OFF, ULA classic (Timex scr0)
    DW  COPPER_WAIT_H|($20<<8), $4069  ; Layer 2 OFF, shadow ON, ULA classic (Timex scr0)
    DW  COPPER_WAIT_H|($28<<8), $0169  ; Layer 2 OFF, shadow OFF, Timex scr1
    DW  COPPER_WAIT_H|($30<<8), $0269  ; Layer 2 OFF, shadow OFF, Timex HiCol
    DW  COPPER_WAIT_H|($38<<8), $0669  ; Layer 2 OFF, shadow OFF, Timex HiRes Black/White
    DW  COPPER_WAIT_H|($40<<8), $0E69  ; Layer 2 OFF, shadow OFF, Timex HiRes Blue/Yellow
    DW  COPPER_WAIT_H|($48<<8), $C069  ; Layer 2 ON, shadow ON, ULA classic (Timex scr0)
    DW  COPPER_WAIT_H|($50<<8), $8169  ; Layer 2 ON, shadow OFF, Timex scr1
    DW  COPPER_WAIT_H|($58<<8), $0069  ; all off (default ULA classic) (rest of the screen)
    DW  COPPER_HALT_B|(COPPER_HALT_B<<8)
CopperCodeLength EQU $ - CopperCode

    ASSERT  $ < $E000
    savesna "NReg0x69.sna", Start
