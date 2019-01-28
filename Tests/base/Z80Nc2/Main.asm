    device zxspectrum48

    org     $8000

    INCLUDE "..\..\Constants.asm"
    INCLUDE "..\..\TestFunctions.asm"
    INCLUDE "..\..\TestData.asm"
    INCLUDE "..\..\OutputFunctions.asm"
;    INCLUDE "..\..\Macros.asm"      ;; FIXME remove in final

MEM_LOG_DATA        equ     $7000   ; 4k buffer (index into log is 8b => 2k max)
MEM_LOG_TXT_BUFFER  equ     $7A00   ; some sub-buffer for texts wrapping

MEM_SCRAP_BUFFER    equ     $A000   ; area to be freely modified by tests
MEM_SCRAP_BUFFER2   equ     MEM_SCRAP_BUFFER+1024   ; if using multiple buffers, then 1k

TEST_OPT_BIT_TURBO  equ     0
TEST_OPT_BIT_FULL   equ     1

INSTRUCTIONS_CNT    equ     6

TestOptions:
    db      0       ; (1<<TEST_OPT_BIT_FULL)|(1<<TEST_OPT_BIT_TURBO)

InstructionsData_FullTests:
    dw      TestFull_Brlc                           ; BRLC DE,B
    dw      TestFull_Bsla                           ; BSLA DE,B
    dw      TestFull_Bsra                           ; BSRA DE,B
    dw      TestFull_Bsrf                           ; BSRF DE,B
    dw      TestFull_Bsrl                           ; BSRL DE,B
    dw      0                                       ; JP (C)

    INCLUDE "../Z80N/controls.i.asm"
    INCLUDE "../Z80N/errorLog.i.asm"
    INCLUDE "UI.i.asm"

;;;;;;;;;;;;;;;;;; switch 14MHz turbo mode ON or OFF ;;;;;;;;;;
SetTurboModeByOption:
    ; read current status of peripheral 2 NextReg
    ld      b,PERIPHERAL_2_NR_06
    ld      a,b
    call    ReadNextReg
    ; check the selected option by user
    ld      hl,TestOptions
    bit     TEST_OPT_BIT_TURBO,(hl)
    jr      nz,.SetTurboON
    ; turbo OFF (use only Z80 instructions in this part)
    and     $7F     ; disable turbo mode
    jp      WriteNextRegByIo    ; + ret
.SetTurboON:
    or      $80     ; enable turbo mode
    call    WriteNextRegByIo
    ; set turbo configuration to 14MHz
    ld      b,TURBO_CONTROL_NR_07
    ld      a,%10
    jp      WriteNextRegByIo    ; + ret

; returns HL=MEM_SCRAP_BUFFER and 256 bytes of data set (0, 1, 2, ..., 255)
Set0to255ScrapData:
    ld      hl,MEM_SCRAP_BUFFER
.setLoop:
    ld      (hl),l
    inc     l
    jp      nz,.setLoop
    ret

; returns HL=MEM_SCRAP_BUFFER and 512 bytes of data set (0, 1, 2, ..., 255, 0, ..., 255)
Set0to255TwiceScrapData:
    call    Set0to255ScrapData
    push    hl
    push    de
    push    bc
    ld      de,MEM_SCRAP_BUFFER+256
    ld      bc,256
    ldir
    pop     bc
    pop     de
    pop     hl
    ret

; does verify if BC=$01FF, HL=MEM_SCRAP_BUFFER+128, DE=MEM_SCRAP_BUFFER2+128
; returns ZF (ZF=1 if all registers were as expected), modifies HL,DE,BC
TestHlDeBcForBlockValues:
    ; check if BC=$01FF
    dec     b
    ret     nz
    inc     c
    ret     nz
    ; check if HL == MEM_SCRAP_BUFFER+128
    ld      bc,MEM_SCRAP_BUFFER+128
    or      a
    sbc     hl,bc
    ret     nz
    ; check if DE == MEM_SCRAP_BUFFER2+128
    ld      hl,MEM_SCRAP_BUFFER2+128
    or      a
    sbc     hl,de
    ret     ; and return final ZF

; does verify if BC=0, HL=MEM_SCRAP_BUFFER+128, DE=MEM_SCRAP_BUFFER2+128
; returns ZF (ZF=1 if all registers were as expected), modifies HL,DE,BC
TestHlDeBcAfterFullBlockValues:
    ; check if BC==0 (should be after repeat-block instructions) (preserve A and others)
    inc     b       ; turn BC=0 into BC=$01FF and test that with TestHlDeBcForBlockValues
    dec     c
    jr      TestHlDeBcForBlockValues

;;;;;;;;;;;;;;;; test runner helper functions ;;;;;;;;;;;;;;;;;;;;;;;;

; A: 0..22 index of line with instruction to test
RunZ80nTest:
    add     a,a     ; *2
    ld      e,a     ; DE = test index * 2
    ; fetch address of test
    ld      hl,InstructionsData_FullTests
    add     hl,de
    ld      a,(hl)
    inc     hl
    ld      h,(hl)
    ld      l,a     ; call the selected test (DE = test index * 2)
    ; continue with TestCallWrapper code
; HL = address of test to run (or null), DE = index of test * 2
TestCallWrapper:
    ; verify HL is not null
    ld      a,h
    or      l
    ret     z
    ; check current status (only NONE should run test)
    ld      ix,InstructionsData_Details
    add     ix,de
    add     ix,de
    ld      a,RESULT_OK
    cp      (ix+1)
    ret     z       ; test was run on all possible levels and there's nothing to show
    ld      a,RESULT_OK1
    cp      (ix+1)
    ret     z       ;;FIXME test if "fuller" level of test is to be called -> let it call (reset result?)
    ld      a,RESULT_OK2
    cp      (ix+1)
    ret     z       ;;FIXME test if "fuller" level of test is to be called -> let it call (reset result?)
    ; result here is either RESULT_NONE or RESULT_ERR
    ; highlight the picked instruction
    push    de
    push    hl
    ex      de,hl
    add     hl,hl   ; index*4
    add     hl,hl   ; index*8
    add     hl,hl   ; index*16
    add     hl,hl   ; index*32
    ld      de,MEM_ZX_ATTRIB_5800+32    ; instructions start from second line
    add     hl,de
    ld      (.AdjustInstructionNameAttributes+1),hl
    ld      a,P_BLACK|YELLOW
    call    .AdjustInstructionNameAttributes
    pop     hl
    pop     de
    ld      a,RESULT_ERR
    cp      (ix+1)
    jr      z,.ShowErrorLog     ; continue with display log if RESULT_ERR
    ; preserve current Error log index (to check, if test did log anything)
    ld      a,(LogLastIndex)
    ld      (.LogLastIndexBeforeTest+1),a   ; preserve it directly in `ld a,*`
    ; call the test itself
    push    de
    push    ix      ; preserve Details data pointer
    call    .WrappedTest
    pop     ix
    ; store result (or more like set to "OK", if it was not already set by test)
    ld      a,RESULT_NONE
    cp      (ix+1)
    jr      nz,.ResultAlreadySetByTest
    ld      (ix+1),RESULT_OK    ; full OK otherwise
.ResultAlreadySetByTest:
    ; check if there are some new log items (produced by the test)
    ld      hl,(LogLastIndex)   ; L = (LogLastIndex) (ignore H)
.LogLastIndexBeforeTest:
    ld      a,0
    cp      l
    jr      z,.NoNewLogItems
    ; store the index of first new log into test details data
    inc     a       ; (old index didn't belong to new items, adjust it)
    ld      (ix+2),a            ; store it into test details data
    ; seal the log-chain by setting "last" on last item
    call    LogSealPreviousChainOfItems
.NoNewLogItems:
    ; restore main screen (hide heartbeat)
    call    DeinitHeartbeat
    pop     de      ; restore index*2
    ; de-highlight the picked instruction
    ld      a,e
    rlca
    rlca
    rlca    ; index*16 in total
    and     P_RED   ; the only bit I'm interested (to produce CYAN for odd lines)
    xor     P_WHITE|BLACK
    call    .AdjustInstructionNameAttributes
    ; refresh the test result status on screen
    ld      b,e
    rrc     b       ; b = index, now do lazy-coder VRAM line calculation
    inc     b
    ld      hl,MEM_ZX_SCREEN_4000+CHARPOS_STATUS
.FindCorrectVramLine:
    call    AdvanceVramHlToNextLine
    djnz    .FindCorrectVramLine
    jp      PrintTestStatus     ; now just call UI function and return

.WrappedTest:
    ; call the test (HL: test address, DE = index*2, IX = test details data)
    jp      hl

.ShowErrorLog:
    ; display log (HL: test address, DE = index*2, IX = test details data)
    call    DisplayLogForOneTest
    call    WaitForAnyKey
    jp      RedrawMainScreen    ; restore main screen + return

.AdjustInstructionNameAttributes:
    ld      hl,0
    ld      b,CHARPOS_INS_END+1
.InstructionNameLoop:
    ld      (hl),a
    inc     l
    djnz    .InstructionNameLoop
    ret

;;;;;;;;;;;;;;;;;;;;;;;;; MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Start:
    call    StartTest
    call    LogInit
    call    SetupKeyControl
    call    RedrawMainScreen
    call    SetTurboModeByOption

    ;;FIXME:
    ; - implement "full" option and OK1/OK2 statuses (everything about it)
    ; - refactor together with Z80N test to share even more source files for code

.MainLoopPrototype:
    call    RefreshKeyboardState

    jr      .MainLoopPrototype

    call    EndTest

;;;;;;;;;;;;;;;;;;;;;;;; Tests themselves ;;;;;;;;;;;;;;;;;;;;;
; ";;DEBUG" mark instructions can be used to intentionally trigger error (test testing)

    INCLUDE "testsBarrelShifts.i.asm"  ; BRLC | BSLA | BSRA | BSRF | BSRL

    ;;FIXME add test for JP (C), probably just here

    savesna "!Z80Nc2.sna", Start
