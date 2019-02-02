    device zxspectrum48

    org     $8000

    INCLUDE "..\..\Constants.asm"
    INCLUDE "..\..\TestFunctions.asm"
    INCLUDE "..\..\TestData.asm"
    INCLUDE "..\..\OutputFunctions.asm"

MEM_LOG_DATA        equ     $7000   ; 4k buffer (index into log is 8b => 2k max)
MEM_LOG_TXT_BUFFER  equ     $7A00   ; some sub-buffer for texts wrapping

MEM_SCRAP_BUFFER    equ     $A000   ; area to be freely modified by tests
MEM_SCRAP_BUFFER2   equ     MEM_SCRAP_BUFFER+1024   ; if using multiple buffers, then 1k

TEST_OPT_BIT_TURBO  equ     0
TEST_OPT_BIT_FULL   equ     1

INSTRUCTIONS_CNT    equ     23

TestOptions:
    db      0       ; (1<<TEST_OPT_BIT_FULL)|(1<<TEST_OPT_BIT_TURBO)

InstructionsData_FullTests:
    dw      0, TestFull_AddBcA
    dw      0, TestFull_AddDeA
    dw      0, TestFull_AddHlA
    dw      TestFull_Lddrx, TestFull_Lddx, TestFull_Ldirx, TestFull_Ldix
    dw      TestFull_Ldpirx, TestFull_Ldws
    dw      TestFull_Mirror, TestFull_MulDE
    dw      0, 0
    dw      TestFull_Outinb, TestFull_Pixelad, TestFull_Pixeldn
    dw      0, TestFull_Setae, TestFull_Swapnib, TestFull_TestNn

    INCLUDE "controls.i.asm"
    INCLUDE "UI.i.asm"
    INCLUDE "errorLog.i.asm"

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
    ; - add missing tests: ADD rr,**, LD*RX, NEXTREG_any, PUSH **

.MainLoopPrototype:
    call    RefreshKeyboardState

    jr      .MainLoopPrototype

    call    EndTest

;;;;;;;;;;;;;;;;;;;;;;;; Tests themselves ;;;;;;;;;;;;;;;;;;;;;
; ";;DEBUG" mark instructions can be used to intentionally trigger error (test testing)

    INCLUDE "testsBlockCopy.i.asm"  ; LDWS | LDPIRX | LDDX | LDIX
    INCLUDE "testsArithmetic.i.asm" ; TEST | MIRROR | SWAPNIB | MUL D,E | ADD rr,A

;;;;;;;;;;;;;;;;;;;;;;;; Test OUTINB (instant) ;;;;;;;;;;;;;;;;;;
TestFull_Outinb:
    INIT_HEARTBEAT_256
OUTINB_TEST_PORT    equ     TBBLUE_REGISTER_SELECT_P_243B
    call    Set0to255ScrapData
    ld      bc,OUTINB_TEST_PORT
.FullTestLoop:
    ld      d,h         ; preserve HL
    ld      e,l
    db      $ED, $90    ; OUTINB ; out (bc),(hl++)
    ; compare BC if it holds
    ;inc     bc ;;DEBUG
    ld      a,OUTINB_TEST_PORT>>8
    cp      b
    jr      nz,.PortNumDamaged
    ld      a,OUTINB_TEST_PORT&$FF
    cp      c
    jr      nz,.PortNumDamaged
    ; read value back from port to verify
    in      a,(c)
    ;inc     a ;;DEBUG
    cp      e           ; should be equal to old L (CF=0 if OK)
    jr      nz,.PortReadsBackOtherValue
    ; check if HL was advanced
    ;dec     hl ;;DEBUG
    inc     de          ; expected HL
    sbc     hl,de       ; will set ZF=1 if HL==DE
    add     hl,de       ; restore HL (preserves ZF)
    jr      nz,.HlDidNotAdvance
    ; see if all values were sent+read
    call    TestHeartbeat
    xor     a
    cp      l
    jp      nz,.FullTestLoop
    ret
.PortNumDamaged:
    ; message with damaged port value (16b)
    push    ix
    ld      ix,.PortNumDamagedMsg
    ld      d,b
    ld      e,c
    call    LogAddMsg1W ; log(IX: msg, DE: damaged port)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
.PortReadsBackOtherValue:
    ; expected (8b) vs received (8b) value, if value reads different than expected
    ld      b,e
    ld      c,a         ; B is expected value, C received from port
    call    LogAdd2B
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
.HlDidNotAdvance:
    ; expected HL (16b) vs received HL (16b)
    call    LogAdd2W    ; log(DE: expected HL, HL: received HL)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
.PortNumDamagedMsg:
    db      'Port is not $243B any more',0

;;;;;;;;;;;;;;;;;;;;;;;; Test PIXELDN (1s) ;;;;;;;;;;;;;;;;;;
TestFull_Pixeldn:
    INIT_HEARTBEAT_256
    ; TODO - confirm what is correct behavior and make the test final
    ; ZEsarUX "wraps around after line 192" for every $2000 aligned area, i.e. 37E0->2000
    ; while this is intelligent design, it's also somewhat restrictive (on shadow buffers
    ; placement) and it's currently not what the real board does AFAIK (to-be-confirmed)

    ;TODO this is setup for ZEsarUX test compatibility
    ld      hl,31
    ld      bc,$BF01    ; do only 191 advances (to not test "down" from last line)

    ;TODO this is full RAM test setup
;     ld      hl,31
;     ld      bc,$0008   ; 8*256 = 2048 (amount of "32B lines" through full 64k RAM)

.FullTestLoop:
    push    hl
    push    bc
.FullTestLoopOneCharPos:
    ; calculate "next_line(HL)" by classic Z80 instructions (into DE)
    ld      e,l         ; copy E for common case (+256 only)
    ld      a,h
    inc     a
    ld      d,a         ; try +256
    and     $7
    jp      nz,.WithinCharLines ; should be OK, continue
    ld      a,e         ; move to next line on char-edge by +32
    add     a,32
    ld      e,a
    jp      c,.WithinCharLines  ; if it wrapped around, then D is already +8 = OK
    ld      a,h
    and     $F8
    ld      d,a         ; otherwise restore D into previous "third" of VRAM
.WithinCharLines:
    ; now try to use Z80N pixeldn (updates HL itself)
    db      $ED, $93    ; PIXELDN ; advances HL "one VRAM line down"
    ;inc     hl ;;DEBUG
    ex      de,hl
    or      a           ; CF=0
    sbc     hl,de
    jr      nz,.errorFound
    ex      de,hl
    djnz    .FullTestLoopOneCharPos
    dec     c
    jp      nz,.FullTestLoopOneCharPos
    call    TestHeartbeat
    pop     bc
    pop     hl
    dec     l           ; go through all possible char positions (0..31)
    jp      p,.FullTestLoop

    ;TODO this is extra part for ZEsarUX test compatibility
    ; do another $2000 area
    ld      l,31
    ld      a,$20
    add     a,h
    ld      h,a
    jp      nc,.FullTestLoop

    ret
.errorFound:
    add     hl,de       ; HL:expected "hl", DE:calculated "hl"
    ex      de,hl       ; log(de:expected, hl:calculated)
    call    LogAdd2W
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    pop     bc          ; terminate test (+release stack)
    pop     hl
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Test PIXELAD (1s) ;;;;;;;;;;;;;;;;;;
TestFull_Pixelad:
    INIT_HEARTBEAT_256  ; does actually few more than 256 beats
    ld      de,0        ; [D:y,E:x] = [0,0]
    ld      bc,MEM_ZX_SCREEN_4000   ; expected value
.FullTestLoopLine:
    ld      a,8
    push    bc
.FullTestLoopChar:
    db      $ED, $94    ; PIXELAD ; HL = VRAM address of pixel [E,D]
    ;inc     hl ;;DEBUG
    or      a           ; CF=0 -> sub hl,bc
    sbc     hl,bc
    jr      nz,.errorFound
    ; next pixel
    dec     a
    call    z,.UpdateExpected_Xpp
    inc     e
    jr      nz,.FullTestLoopChar
    call    TestHeartbeat
    pop     bc
    inc     b
    ld      a,b
    and     7
    call    z,.UpdateExpected_Yp8
    inc     d
    ld      a,191
    cp      d
    jr      nc,.FullTestLoopLine
    ret
.UpdateExpected_Xpp:
    inc     c
    ld      a,8
    ret
.UpdateExpected_Yp8:
    call    TestHeartbeatTwo
    ld      a,32
    add     a,c
    ld      c,a
    ret     z
    call    TestHeartbeat
    ld      a,b
    sub     8
    ld      b,a
    ret
.errorFound:
    add     hl,bc       ; BC:expected "hl", HL:calculated "hl", DE:coordinates
    push    de          ; move coordinates into BC
    push    bc          ; move expected "hl" into DE
    pop     de          ; i.e. ex bc,de
    pop     bc
    call    LogAdd3W    ; log(de:expected, hl:calculated, bc:coordinates)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    pop     bc          ; terminate test (+release stack)
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Test SETAE (instant) ;;;;;;;;;;;;;;;;;;
TestFull_Setae:
    INIT_HEARTBEAT_256
    ld      e,0         ; "X coordinate" (0..255)
    ld      b,$80       ; expected value
.FullTestLoop:
    db      $ED, $95    ; SETAE
    ;rrca ;;DEBUG
    cp      b
    jr      nz,.errorFound
    rrc     b
    call    TestHeartbeat
    inc     e
    jp      nz,.FullTestLoop
    ret
.errorFound:
    ld      c,a
    call    LogAdd3B    ; log(B: expected, C: calculated, E:X-coordinate)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

    savesna "!Z80N.sna", Start
