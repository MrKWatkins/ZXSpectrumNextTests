    device zxspectrum48

    org     $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"
    INCLUDE "../../controls.i.asm"

MEM_STACK_ADDRESS   equ     $9F00   ; needs C000..FFFF free for JP (C) test
MEM_JP_C_AREA       equ     $C000   ; target area to test JP (C) fully

MEM_LOG_DATA        equ     $7000   ; 4k buffer (index into log is 8b => 2k max)
MEM_LOG_TXT_BUFFER  equ     $7A00   ; some sub-buffer for texts wrapping

MEM_SCRAP_BUFFER    equ     $A000   ; area to be freely modified by tests
MEM_SCRAP_BUFFER2   equ     MEM_SCRAP_BUFFER+1024   ; if using multiple buffers, then 1k

INSTRUCTIONS_CNT    equ     6

InstructionsData_L1Tests:   ; partial tests to get whole running time near 10s
    dw      TestL1_Brlc                             ; BRLC DE,B
    dw      TestL1_Bsla                             ; BSLA DE,B
    dw      TestL1_Bsra                             ; BSRA DE,B
    dw      TestL1_Bsrf                             ; BSRF DE,B
    dw      TestL1_Bsrl                             ; BSRL DE,B
    dw      TestFull_JpInC                          ; JP (C) - fast enough to stay "full"

InstructionsData_FullTests:
    dw      TestFull_Brlc                           ; BRLC DE,B
    dw      TestFull_Bsla                           ; BSLA DE,B
    dw      TestFull_Bsra                           ; BSRA DE,B
    dw      TestFull_Bsrf                           ; BSRF DE,B
    dw      TestFull_Bsrl                           ; BSRL DE,B
    dw      TestFull_JpInC                          ; JP (C)

    INCLUDE "../Z80N/main.i.asm"
    INCLUDE "../Z80N/errorLog.i.asm"
    INCLUDE "UI.i.asm"

;;;;;;;;;;;;;;;;;;;;;;;;; MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Start:
    ld      sp,MEM_STACK_ADDRESS
    call    DetectTurboMode
    call    StartTest
    call    LogInit
    call    SetupKeyControl
    call    SetTurboModeByOption
    call    RedrawMainScreen

    call    HandleAutoStartOnce

.MainLoop:
    call    RefreshKeyboardState
    jr      .MainLoop

    call    EndTest

;;;;;;;;;;;;;;;;;;;;;;;; Tests themselves ;;;;;;;;;;;;;;;;;;;;;

    INCLUDE "testsBarrelShifts.i.asm"   ; BRLC | BSLA | BSRA | BSRF | BSRL
    INCLUDE "testsC2specials.i.asm"     ; JP (C)

    savesna "!Z80Nc2.sna", Start
