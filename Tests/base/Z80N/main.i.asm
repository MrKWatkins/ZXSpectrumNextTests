TEST_OPT_BIT_TURBO  equ     0
TEST_OPT_BIT_FULL   equ     1
TEST_OPT_BIT_ASTART equ     7

TestOptions:
    db      0       ; (1<<TEST_OPT_BIT_FULL)|(1<<TEST_OPT_BIT_TURBO)
    ;db      (1<<TEST_OPT_BIT_ASTART)|(1<<TEST_OPT_BIT_TURBO)

InstructionsData_CurrentLevelTests:
    dw      InstructionsData_L1Tests

;;;;;;;;;;; detects if Turbo mode is already selected ;;;;;;;;;
DetectTurboMode:    ; if selected, it will be kept + autostart
    ld      a,TURBO_CONTROL_NR_07
    call    ReadNextReg
    and     $03
    ret     z       ; no turbo detected
    ; turbo detected, make the option ON (it will set the turbo to 28MHz (from 7/14/28MHz))
    ld      hl,TestOptions
    set     TEST_OPT_BIT_TURBO,(hl)
    set     TEST_OPT_BIT_ASTART,(hl)    ; and add auto-start of tests
    ret

;;;;;;;;;;;;;;;;;; switch 28MHz turbo mode ON or OFF ;;;;;;;;;;
SetTurboModeByOption:
    ; read current status of peripheral 2 NextReg, enable turbo and 50/60Hz keys (F3+F8)
    ld      b,PERIPHERAL_2_NR_06
    ld      a,b
    call    ReadNextReg
    or      %1010'1000          ; F3 + F8 + Multiface enabled
    call    WriteNextRegByIo
    ; check the selected option by user
    ld      hl,TestOptions
    bit     TEST_OPT_BIT_TURBO,(hl)
    ld      a,%11               ; 28MHz
    jr      nz,.SetTurboON
    ld      a,%00               ; 3.5MHz
.SetTurboON:
    ld      b,TURBO_CONTROL_NR_07
    jp      WriteNextRegByIo    ; + ret

;;;;;;; picks choosen levels test ;;;;;;;;;;;;
SetTestsModeByOption:
    ld      hl,TestOptions
    ld      de,InstructionsData_FullTests
    bit     TEST_OPT_BIT_FULL,(hl)
    jr      nz,.FullTestsSelected
    ld      de,InstructionsData_L1Tests     ; partial tests selected
.FullTestsSelected:
    ld      (InstructionsData_CurrentLevelTests),de
    ret

; returns HL=MEM_SCRAP_BUFFER and 512 bytes of data set (0, 1, 2, ..., 255, 0, ..., 255)
Set0to255TwiceScrapData:
    ; set second set of 256 bytes
    ld      hl,MEM_SCRAP_BUFFER+256
    call    Set0to255ScrapData.setLoop
    ; set first set + return with expected HL
    ;; continue with Set0to255ScrapData
; returns HL=MEM_SCRAP_BUFFER and 256 bytes of data set (0, 1, 2, ..., 255)
Set0to255ScrapData:
    ld      hl,MEM_SCRAP_BUFFER
.setLoop:
    ld      (hl),l
    inc     l
    jp      nz,.setLoop
    ret

; does verify if BC=0, HL=MEM_SCRAP_BUFFER+128, DE=MEM_SCRAP_BUFFER2+128
; returns ZF (ZF=1 if all registers were as expected), modifies HL,DE,BC
TestHlDeBcAfterFullBlockValues:
    ; check if BC==0 (should be after repeat-block instructions) (preserve A and others)
    inc     b       ; turn BC=0 into BC=$01FF and test that with TestHlDeBcForBlockValues
    dec     c
    ;;continue with TestHlDeBcForBlockValues
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

;;;;;;;;;;;;;;;; test runner helper functions ;;;;;;;;;;;;;;;;;;;;;;;;

; A: 0..22 index of line with instruction to test
RunZ80nTest:
    add     a,a     ; *2
    ld      e,a     ; DE = test index * 2
    ; fetch address of test
    ld      hl,(InstructionsData_CurrentLevelTests)
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
    ld      a,(ix+1)
    cp      RESULT_OK
    ret     z       ; test was run on all possible levels and there's nothing to show
    ; RESULT_OK1 and RESULT_OK2 should pass through into the test
    ; the partial tests are responsible of detecting the state and ignore the call
    cp      RESULT_NONE
    jr      z,.KeepStatusDisplayed
    cp      RESULT_ERR
    jr      z,.KeepStatusDisplayed
    ;; but RESULT_OK1 and RESULT_OK2 should remove the current status from screen to get
    ; correct result after test is run (or not run)
    push    hl
    push    de
    call    .RefreshCurrentTestStatusAhead
    pop     de
    pop     hl
.KeepStatusDisplayed:
    ;; highlight the picked instruction
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
.RefreshCurrentTestStatusAhead:
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

; will check if autostart bit is set, clear it and run all tests if requested
HandleAutoStartOnce:
    ; check if auto-start of tests is selected (by machine being in turbo mode)
    ld      hl,TestOptions
    bit     TEST_OPT_BIT_ASTART,(hl)
    ret     z
    res     TEST_OPT_BIT_ASTART,(hl)
    jp      GoKeyHandler
