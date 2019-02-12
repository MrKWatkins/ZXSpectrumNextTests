    device zxspectrum48

    org     $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"
    INCLUDE "../../controls.i.asm"

MEM_STACK_ADDRESS   equ     $9F00
MEM_LOG_DATA        equ     $7000   ; 4k buffer (index into log is 8b => 2k max)
MEM_LOG_TXT_BUFFER  equ     $7A00   ; some sub-buffer for texts wrapping

MEM_SCRAP_BUFFER    equ     $A000   ; area to be freely modified by tests
MEM_SCRAP_BUFFER2   equ     MEM_SCRAP_BUFFER+1024   ; if using multiple buffers, then 1k

INSTRUCTIONS_CNT    equ     23

InstructionsData_L1Tests:
    dw      TestL1_AddBcW, TestL1_AddBcA
    dw      TestL1_AddDeW, TestL1_AddDeA
    dw      TestL1_AddHlW, TestL1_AddHlA
    dw      TestFull_Lddrx, TestFull_Lddx, TestFull_Ldirx, TestFull_Ldix
    dw      TestFull_Ldpirx, TestFull_Ldws
    dw      TestFull_Mirror, TestFull_MulDE
    dw      TestFull_NextRegNn, TestFull_NextRegA
    dw      TestFull_Outinb, TestFull_Pixelad, TestFull_Pixeldn
    dw      TestFull_PushW, TestFull_Setae, TestFull_Swapnib, TestFull_TestNn

InstructionsData_FullTests:
;;TODO "ADD rr,**" are currently available only in "partial" variant, as the full one would take hours...
; - maybe add two levels of "full" option to have more thorough partial than current one (OK1/OK2)?
    dw      TestL1_AddBcW, TestFull_AddBcA
    dw      TestL1_AddDeW, TestFull_AddDeA
    dw      TestL1_AddHlW, TestFull_AddHlA
    dw      TestFull_Lddrx, TestFull_Lddx, TestFull_Ldirx, TestFull_Ldix
    dw      TestFull_Ldpirx, TestFull_Ldws
    dw      TestFull_Mirror, TestFull_MulDE
    dw      TestFull_NextRegNn, TestFull_NextRegA
    dw      TestFull_Outinb, TestFull_Pixelad, TestFull_Pixeldn
    dw      TestFull_PushW, TestFull_Setae, TestFull_Swapnib, TestFull_TestNn

    INCLUDE "../Z80N/main.i.asm"
    INCLUDE "../Z80N/errorLog.i.asm"
    INCLUDE "../Z80N/UI.i.asm"

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

    ;;;;;;;;;;;;;;;;;;;;;;;; Tests ;;;;;;;;;;;;;;;;;;;;;

    INCLUDE "testsBlockCopy.i.asm"  ; LDWS | LDPIRX | LDDX | LDDRX | LDIRX | LDIX
    INCLUDE "testsArithmetic.i.asm" ; TEST | MIRROR | SWAPNIB | MUL D,E | ADD rr,A | ADD rr,**
    INCLUDE "testsSpecials.i.asm"   ; NEXTREG *r,*n | NEXTREG *r,A | OUTINB | PUSH **
    INCLUDE "testsPixelRelated.i.asm"   ; PIXELDN | PIXELAD | SETAE

    savesna "!Z80N.sna", Start
