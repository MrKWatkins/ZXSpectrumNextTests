; possible results (levels of OK are how many tests sub-parts were skipped)
    ; levels are only wanna-be feature, at this moment all tests are "full" (OK0)
    ; these are offsets into ResultStringBase texts definitions
RESULT_NONE     equ     3
RESULT_ERR      equ     0
RESULT_OK       equ     4
RESULT_OK1      equ     7
RESULT_OK2      equ     11

    ALIGN   16
ResultStringBase:
    db      'ERR',0,'OK',0,'OK1',0,'OK2',0

; if opcode is "special", these are offsets into SpecialOpcodeMnemonics string
OPCODE_TXT_NONE     equ     0
OPCODE_TXT_VALUE    equ     2
OPCODE_TXT_LOW      equ     4
OPCODE_TXT_HIGH     equ     6
OPCODE_TXT_REG      equ     8

    ALIGN   16
SpecialOpcodeMnemonics:
    db      '  nnlohirr'

; attribute line offsets in the VRAM to control-key position
KEY_ATTR_OFS_HELP   equ     0
KEY_ATTR_OFS_TURBO  equ     5
KEY_ATTR_OFS_FULL   equ     10
KEY_ATTR_OFS_RUN    equ     15
KEY_ATTR_OFS_CORE   equ     22
KEY_ATTR_OFS_INSTR  equ     27

CHARPOS_INS_END     equ     13
CHARPOS_ENCODING    equ     15
CHARPOS_INS_KEY     equ     KEY_ATTR_OFS_INSTR
CHARPOS_STATUS      equ     29

MachineInfoLabels:
    ;        0123456789A123456789A123456789A1
    db      '1Hlp 2T14 3Ful 5Go m',0,'c',0

InstructionMnemonics:
    db      'ADD     BC,**',0
    db      'ADD     BC,A',0
    db      'ADD     DE,**',0
    db      'ADD     DE,A',0
    db      'ADD     HL,**',0
    db      'ADD     HL,A',0
    db      'LDDRX',0
    db      'LDDX',0
    db      'LDIRX',0
    db      'LDIX',0
    db      'LDPIRX',0
    db      'LDWS',0
    db      'MIRROR',0
    db      'MUL     D,E',0
    db      'NEXTREG *r,*n',0
    db      'NEXTREG *r,A',0
    db      'OUTINB',0
    db      'PIXELAD',0
    db      'PIXELDN',0
    db      'PUSH    **',0
    db      'SETAE',0
    db      'SWAPNIB',0
    db      'TEST    *',0

; Two bytes per instruction: Char to display, location in key-array to test
InstructionsData_KeyLegends:
    db        0, KEY_NONE   ; ADD BC,$nnnn
    db      'W', KEY_W      ; ADD BC,A
    db        0, KEY_NONE   ; ADD DE,$nnnn
    db      'R', KEY_R      ; ADD DE,A
    db        0, KEY_NONE   ; ADD HL,$nnnn
    db      'Y', KEY_Y      ; ADD HL,A
    db        0, KEY_NONE   ; LDDRX
    db      'I', KEY_I      ; LDDX
    db        0, KEY_NONE   ; LDIRX
    db      'P', KEY_P      ; LDIX
    db      'A', KEY_A      ; LDPIRX
    db      'S', KEY_S      ; LDWS
    db      'D', KEY_D      ; MIRROR
    db      'F', KEY_F      ; MUL D,E
    db        0, KEY_NONE   ; NEXTREG $rr,$n
    db        0, KEY_NONE   ; NEXTREG $rr,A
    db      'J', KEY_J      ; OUTINB
    db      'K', KEY_K      ; PIXELAD
    db      'L', KEY_L      ; PIXELDN
    db        0, KEY_NONE   ; PUSH $nnnn
    db      'X', KEY_X      ; SETAE
    db      'C', KEY_C      ; SWAPNIB
    db      'V', KEY_V      ; TEST $nn

; four bytes per instruction, either real opcode byte, or special opcode equ
InstructionsData_Encoding:
    db      $ED, $36, OPCODE_TXT_LOW, OPCODE_TXT_HIGH           ; ADD BC,$nnnn
    db      $ED, $33, 0, 0                                      ; ADD BC,A
    db      $ED, $35, OPCODE_TXT_LOW, OPCODE_TXT_HIGH           ; ADD DE,$nnnn
    db      $ED, $32, 0, 0                                      ; ADD DE,A
    db      $ED, $34, OPCODE_TXT_LOW, OPCODE_TXT_HIGH           ; ADD HL,$nnnn
    db      $ED, $31, 0, 0                                      ; ADD HL,A
    db      $ED, $BC, 0, 0                                      ; LDDRX
    db      $ED, $AC, 0, 0                                      ; LDDX
    db      $ED, $B4, 0, 0                                      ; LDIRX
    db      $ED, $A4, 0, 0                                      ; LDIX
    db      $ED, $B7, 0, 0                                      ; LDPIRX
    db      $ED, $A5, 0, 0                                      ; LDWS
    db      $ED, $24, 0, 0                                      ; MIRROR
    db      $ED, $30, 0, 0                                      ; MUL D,E
    db      $ED, $91, OPCODE_TXT_REG, OPCODE_TXT_VALUE          ; NEXTREG $rr,$n
    db      $ED, $92, OPCODE_TXT_REG, 0                         ; NEXTREG $rr,A
    db      $ED, $90, 0, 0                                      ; OUTINB
    db      $ED, $94, 0, 0                                      ; PIXELAD
    db      $ED, $93, 0, 0                                      ; PIXELDN
    db      $ED, $8A, OPCODE_TXT_HIGH, OPCODE_TXT_LOW           ; PUSH $nnnn
    db      $ED, $95, 0, 0                                      ; SETAE
    db      $ED, $23, 0, 0                                      ; SWAPNIB
    db      $ED, $27, OPCODE_TXT_VALUE, 0                       ; TEST $nn

; byte 0 = encoding bytes [2:0], special mask [7:3] (from top to bottom)
; byte 1 = result
; byte 2 = logIndex (first log index, 0 == no log)
; byte 3 = ??
InstructionsData_Details:
    db      $34, RESULT_NONE, 0, -1                            ; ADD BC,$nnnn
    db      $02, RESULT_NONE, 0, -1                            ; ADD BC,A
    db      $34, RESULT_NONE, 0, -1                            ; ADD DE,$nnnn
    db      $02, RESULT_NONE, 0, -1                            ; ADD DE,A
    db      $34, RESULT_NONE, 0, -1                            ; ADD HL,$nnnn
    db      $02, RESULT_NONE, 0, -1                            ; ADD HL,A
    db      $02, RESULT_NONE, 0, -1                            ; LDDRX
    db      $02, RESULT_NONE, 0, -1                            ; LDDX
    db      $02, RESULT_NONE, 0, -1                            ; LDIRX
    db      $02, RESULT_NONE, 0, -1                            ; LDIX
    db      $02, RESULT_NONE, 0, -1                            ; LDPIRX
    db      $02, RESULT_NONE, 0, -1                            ; LDWS
    db      $02, RESULT_NONE, 0, -1                            ; MIRROR
    db      $02, RESULT_NONE, 0, -1                            ; MUL D,E
    db      $34, RESULT_NONE, 0, -1                            ; NEXTREG $rr,$n
    db      $23, RESULT_NONE, 0, -1                            ; NEXTREG $rr,A
    db      $02, RESULT_NONE, 0, -1                            ; OUTINB
    db      $02, RESULT_NONE, 0, -1                            ; PIXELAD
    db      $02, RESULT_NONE, 0, -1                            ; PIXELDN
    db      $34, RESULT_NONE, 0, -1                            ; PUSH $nnnn
    db      $02, RESULT_NONE, 0, -1                            ; SETAE
    db      $02, RESULT_NONE, 0, -1                            ; SWAPNIB
    db      $23, RESULT_NONE, 0, -1                            ; TEST $nn

;;;;;;;;;;;;;; test heartbeat progress bar routines ;;;;;;;;;;;;;

Heartbeat_Line0Attribs:
    ds      32
Heartbeat_InitialAttribute:
    db      A_BRIGHT|P_BLACK|BLACK

    ; macros to initialize heartbeat to expect at least N-many beats. It's OK-ish to
    ; call Heartbeat more than N times, but the progress bar will be "full" after N.

    MACRO INIT_HEARTBEAT_256
        ld      a,A_BRIGHT|P_BLACK|BLACK
        call    InitHeartbeat
    ENDM

    MACRO INIT_HEARTBEAT_32     ; this is minimal size, there's no less than 32
        ld      a,A_BRIGHT|P_WHITE|WHITE
        call    InitHeartbeat
    ENDM

InitHeartbeat:
    push    af
    push    hl
    push    de
    push    bc
    ld      (Heartbeat_InitialAttribute),a
    ; backup current attributes of first line
    ld      hl,MEM_ZX_ATTRIB_5800
    ld      de,Heartbeat_Line0Attribs
    ld      bc,32
    ldir
    ; reset current beat position
    ld      hl,MEM_ZX_ATTRIB_5800
    ld      (TestHeartbeat.CurrentBeatPos+1),hl
    ; "clear" first line
    ld      de,MEM_ZX_ATTRIB_5800+1
    ld      bc,31
    ld      (hl),P_MAGENTA|MAGENTA      ; make first line pixels "invisible"
    ldir
    pop     bc
    pop     de
    pop     hl
    pop     af
    ret

TestHeartbeatFour:
    call    TestHeartbeatTwo
TestHeartbeatTwo:
    call    TestHeartbeat
; preserves everything (by using stack)
TestHeartbeat:
    push    af
    push    hl
.CurrentBeatPos:
    ld      hl,0
    ld      a,h
    or      l
    jr      z,.FullProgressBarOrUninitialized
    ld      a,(Heartbeat_InitialAttribute)
    bit     6,(hl)      ; check for BRIGHT = no bright = first time this square
    jr      z,.SetUpNewColour
    ; already some progress there, just increment by "one"
    ld      a,(hl)
    add     a,P_BLUE|BLUE
    jp      p,.SetUpNewColour   ; when top bit (A_FLASH) becomes set, it's over...
    ; move to next square, if possible
    inc     l
    ld      a,l
    cp      32
    jr      nc,.Full
    ld      (.CurrentBeatPos+1),hl
    ld      a,(Heartbeat_InitialAttribute)
.SetUpNewColour:
    ld      (hl),a
.FullProgressBarOrUninitialized:
    pop     hl
    pop     af
    ret
.Full:
    ld      hl,0
    ld      (.CurrentBeatPos+1),hl
    jr      .FullProgressBarOrUninitialized

DeinitHeartbeat:
    ; restore attributes of first line (making pixels probably visible)
    ld      hl,Heartbeat_Line0Attribs
    ld      de,MEM_ZX_ATTRIB_5800
    ld      bc,32
    ldir
    ret

;;;;;;;;;;;;;; main screen full-redraw routine ;;;;;;;;;;;;;;;;;;

RedrawMainScreen:
    ld      a,GREEN
    out     (ULA_P_FE),a
    ; create attribute stripes to make lines easier to read
    FILL_AREA   MEM_ZX_ATTRIB_5800+1*32, 3*32, P_WHITE|BLACK    ; restore "white" on 2nd+4th
    FILL_AREA   MEM_ZX_ATTRIB_5800+2*32, 32, P_CYAN|BLACK       ; cyan at third line
    ; copy this white/cyan paper over full screen
    ld      hl,MEM_ZX_ATTRIB_5800+2*32
    ld      de,MEM_ZX_ATTRIB_5800+4*32
    ld      bc,32*24-4*32
    ldir
    ; make top line green
    FILL_AREA   MEM_ZX_ATTRIB_5800, 32, P_GREEN|BLACK ; cyan at second line
    ;; this main screen drawing expect first line of screen to be clear(!)
    ; create vertical lines (over full screen, because I'm super lazy)
    ld      a,$08
    ld      hl,MEM_ZX_SCREEN_4000
    push    hl
    push    hl
    pop     ix
    ld      (ix+CHARPOS_ENCODING-1),a
    ld      (ix+CHARPOS_ENCODING+2),a
    ld      (ix+CHARPOS_ENCODING+5),a
    ld      (ix+CHARPOS_ENCODING+8),a
    ld      (ix+CHARPOS_INS_KEY-1),a
    ld      (ix+CHARPOS_STATUS-1),a
    ; now copy first line over full screen, so it will also clear it
    ld      de,MEM_ZX_SCREEN_4000+32
    ld      bc,32*191
    ldir
    ; erase first line pixels
    pop     hl
    ld      bc, 32
.ClearLine0Loop:
    xor     a
    ld      l,a
    call    FillArea
    inc     h
    ld      a,h
    cp      $48
    jr      nz,.ClearLine0Loop
    ; highlight control keys
    ld      ix,MEM_ZX_ATTRIB_5800
    set     6,(ix+KEY_ATTR_OFS_HELP)    ; set BRIGHT bit of attributes
    set     6,(ix+KEY_ATTR_OFS_TURBO)
    set     6,(ix+KEY_ATTR_OFS_FULL)
    set     6,(ix+KEY_ATTR_OFS_RUN)
    ; update options status
    call    UpdateToplineOptionsStatus
    ld      de,32
    ld      b,23
    ld      hl,InstructionsData_KeyLegends
    xor     a
.HighlightKeysLoop:
    add     ix,de
    cp      (hl)
    jr      z,.skipInstructionKeyHighlight
    set     6,(ix+KEY_ATTR_OFS_INSTR)
.skipInstructionKeyHighlight:
    inc     hl
    inc     hl
    djnz    .HighlightKeysLoop

    ; show Main line legend, MachineID and core version
    ld      de,MEM_ZX_SCREEN_4000
    ld      bc,MEM_ZX_SCREEN_4000+KEY_ATTR_OFS_CORE
    ; move core version +1 pos right if sub-minor version is under 100
    NEXTREG2A NEXT_VERSION_MINOR_NR_0E
    cp      100
    jr      nc,.SubMinorAboveEqual100
    inc     c
.SubMinorAboveEqual100:
    ld      ix,0        ; simple info only
    ld      hl,MachineInfoLabels
    call    OutMachineIdAndCore

    ;; print instruction table
    ; print instruction mnemonics
    ld      b,23
    ld      de,MEM_ZX_SCREEN_4000+32
    ld      hl,InstructionMnemonics
.PrintInstructionMnemonics:
    call    OutStringAtDe
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    djnz    .PrintInstructionMnemonics

    ;; print instruction opcodes, key-shortcut and status
    ld      de,0            ; number of instruction*4
    ld      hl,MEM_ZX_SCREEN_4000+32+CHARPOS_STATUS
.PrintInstructionDetails:
    push    hl
    ld      ix,InstructionsData_Details
    add     ix,de
    ; display status
    call    PrintTestStatus ; 3-letter statuses may advance OutCurrentAdr to next third!
    ; display key
    ld      a,l
    sub     CHARPOS_STATUS-CHARPOS_INS_KEY
    ld      l,a
    ld      (OutCurrentAdr),hl  ; set up VRAM position (whole HL to reset VRAM third!)
    push    hl
    ld      hl,InstructionsData_KeyLegends
    rrc     e
    add     hl,de   ; += instruction_inde*2
    rlc     e
    ld      a,(hl)  ; shortcut-key ASCII
    or      a
    call    nz,OutChar
    pop     hl
    ; display instruction encoding
    ld      a,l
    sub     CHARPOS_INS_KEY-CHARPOS_ENCODING
    ld      (OutCurrentAdr),a   ; set up VRAM output position
    ld      a,(ix)  ; encoding bytes [2:0], special mask [7:3] (from top to bottom)
    ld      c,a     ; special mask into C
    and     7
    ld      b,a     ; bytes count into B
    ld      ix,InstructionsData_Encoding
    add     ix,de
    ; b = number of bytes, c = special mask (at top bits)
.PrintSingleOpcodeByte:
    ld      a,(ix)
    inc     ix
    rl      c
    jr      c,.SpecialOpcodeByte
    ; ordinary opcode byte
    call    OutHexaValue
    jr      .SkipVerticalLineInOpcodes
.SpecialOpcodeByte:
    add     a,SpecialOpcodeMnemonics&$FF
    ld      l,a
    ld      h,SpecialOpcodeMnemonics>>8
    ld      a,(hl)
    call    OutChar
    inc     hl
    ld      a,(hl)
    call    OutChar
.SkipVerticalLineInOpcodes:
    ld      a,' '
    call    OutChar
    djnz    .PrintSingleOpcodeByte
    pop     hl
    ; advance to "next line"
    call    AdvanceVramHlToNextLine
    ld      a,4
    add     a,e
    ld      e,a
    cp      23*4
    jr      nz,.PrintInstructionDetails
    ret

UpdateToplineOptionsStatus:
    ; update "turbo" attributes
    ld      hl,MEM_ZX_ATTRIB_5800+KEY_ATTR_OFS_TURBO+1
    ld      a,(TestOptions)
    and     1<<TEST_OPT_BIT_TURBO
    ld      a,P_BLACK|GREEN
    jr      nz,.TurboIsOn
    ld      a,P_GREEN|BLACK
.TurboIsOn:
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     l
    ld      (hl),a
    ; update "full" attributes
    ld      l,KEY_ATTR_OFS_FULL+1
    ld      a,(TestOptions)
    and     1<<TEST_OPT_BIT_FULL
    ld      a,P_BLACK|GREEN
    jr      nz,.FullIsOn
    ld      a,P_GREEN|BLACK
.FullIsOn:
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     l
    ld      (hl),a
    ret

;IX: instruction details data, HL: VRAM address for output
PrintTestStatus:
    ld      (OutCurrentAdr),hl  ; set up VRAM output position
    push    hl
    ; display status
    ld      a,(ix+1)    ; fetch status
    cp      RESULT_ERR
    jr      nz,.KeepBorderAsIs
    ; set red border in case any "ERR" status is displayed
    ld      a,RED
    out     (ULA_P_FE),a
    ld      a,RESULT_ERR    ; restore value
.KeepBorderAsIs:
    ; print status string
    add     a,ResultStringBase&$FF
    ld      l,a
    ld      h,ResultStringBase>>8
    call    OutString
    pop     hl
    ret

;;;;;;;;;;;;;;;; key controls routines (setup + handlers) ;;;;;;;;;;;;

SetupKeyControl:
    ld      a,KEY_2
    ld      de,TurboKeyHandler
    call    RegisterKeyhandler
    ld      a,KEY_3
    ld      de,FullKeyHandler
    call    RegisterKeyhandler
    ;;FIXME register also KEY_1 (help) and KEY_5 (go)
    ; register all single-test keys
    ld      hl,InstructionsData_KeyLegends
    ld      de,SingleTestKeyHandler
    ld      b,23
.RegisterSingleTestHandlersLoop:
    inc     hl
    ld      a,(hl)
    inc     hl
    call    RegisterKeyhandler      ; KEY_NONE will be rejected by Register function
    djnz    .RegisterSingleTestHandlersLoop
    ret

TurboKeyHandler:
    ; flip turbo ON/OFF option
    ld      a,(TestOptions)
    xor     1<<TEST_OPT_BIT_TURBO
    ld      (TestOptions),a
    ; refresh main screen top line status
    call    UpdateToplineOptionsStatus
    ; switch the turbo ON/OFF actually
    jp      SetTurboModeByOption    ; + ret

FullKeyHandler:     ; "Full" is selecting faster/slower test variants
    ; flip full ON/OFF option
    ld      a,(TestOptions)
    xor     1<<TEST_OPT_BIT_FULL
    ld      (TestOptions),a
    ; refresh main screen top line status
    jp      UpdateToplineOptionsStatus  ; + ret

SingleTestKeyHandler:               ; DE = keycode
    ; find which test line was picked
    ld      hl,InstructionsData_KeyLegends
    ld      b,23
.findTestLoop:
    inc     hl
    ld      a,(hl)
    inc     hl
    cp      e
    jr      z,.testFound
    djnz    .findTestLoop
    ; test not found?! how??
    ret
.testFound:
    ld      a,23
    sub     b       ; A = 0..22 number of test
    jp      RunZ80nTest
