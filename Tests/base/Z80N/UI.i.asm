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
    db      'U', KEY_U      ; LDDRX
    db      'I', KEY_I      ; LDDX
    db      'O', KEY_O      ; LDIRX
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
; byte 3 = temporary scratch area for test
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

HelpTxt:
    ;        0123456789A123456789A123456789A1
    db      ' ',0
    db      'Read the "!Z80N.txt" for details',0
    db      ' ',0
    db      'Press 2 to switch 14Mhz turbo.',0
    db      'Press 5 to run all tests (~5min)',0
    db      'Option 3 is not implemented yet.',0
    db      ' ',0
    db      'To run particular test or check',0
    db      'error log in case of "ERR" state',0
    db      'press the highlighted letter.',0
    db      ' ',0
    db      'Values in log are hexadecimal.',0
    db      ' ',0
    db      'For instruction details you can',0
    db      'check:',0
    db      'http://devnext.referata.com/wiki',0
    db      '/Extended_Z80_instruction_set',0
    db      ' ',0
    db      'Tests can be run only once.',0
    db      ' ',0
    db      '        Press any key',0
    db      0

    include "UIcode.i.asm"
