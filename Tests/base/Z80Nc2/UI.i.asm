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
    db      'BRLC    DE,B',0
    db      'BSLA    DE,B',0
    db      'BSRA    DE,B',0
    db      'BSRF    DE,B',0
    db      'BSRL    DE,B',0
    db      'JP      (C)',0

; Two bytes per instruction: Char to display, location in key-array to test
InstructionsData_KeyLegends:
    db        0, KEY_NONE   ; BRLC DE,B
    db        0, KEY_NONE   ; BSLA DE,B
    db        0, KEY_NONE   ; BSRA DE,B
    db        0, KEY_NONE   ; BSRF DE,B
    db        0, KEY_NONE   ; BSRL DE,B
    db        0, KEY_NONE   ; JP (C)
;   db      'Y', KEY_Y      ; JP (C)

; four bytes per instruction, either real opcode byte, or special opcode equ
InstructionsData_Encoding:
    db      $ED, $2C, 0, 0                                      ; BRLC DE,B
    db      $ED, $28, 0, 0                                      ; BSLA DE,B
    db      $ED, $29, 0, 0                                      ; BSRA DE,B
    db      $ED, $2B, 0, 0                                      ; BSRF DE,B
    db      $ED, $2A, 0, 0                                      ; BSRL DE,B
    db      $ED, $98, 0, 0                                      ; JP (C)

; byte 0 = encoding bytes [2:0], special mask [7:3] (from top to bottom)
; byte 1 = result
; byte 2 = logIndex (first log index, 0 == no log)
; byte 3 = ??
InstructionsData_Details:
    db      $02, RESULT_NONE, 0, -1                             ; BRLC DE,B
    db      $02, RESULT_NONE, 0, -1                             ; BSLA DE,B
    db      $02, RESULT_NONE, 0, -1                             ; BSRA DE,B
    db      $02, RESULT_NONE, 0, -1                             ; BSRF DE,B
    db      $02, RESULT_NONE, 0, -1                             ; BSRL DE,B
    db      $02, RESULT_NONE, 0, -1                             ; JP (C)

HelpTxt:
    ;        0123456789A123456789A123456789A1
    db      ' ',0
    db      'Read "!Z80Nc2.txt" for details.',0
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

    include "../Z80N/UIcode.i.asm"
