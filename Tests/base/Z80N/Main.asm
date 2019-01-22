    device zxspectrum48

    org     $8000

    INCLUDE "..\..\Constants.asm"
    INCLUDE "..\..\TestFunctions.asm"
    INCLUDE "..\..\TestData.asm"
    INCLUDE "..\..\OutputFunctions.asm"
    INCLUDE "..\..\Macros.asm"      ;; FIXME remove in final

MEM_SCRAP_BUFFER    equ     $A000   ; area to be freely modified by tests
MEM_SCRAP_BUFFER2   equ     MEM_SCRAP_BUFFER+1024   ; if using multiple buffers, then 1k

TEST_OPT_BIT_TURBO  equ     0
TEST_OPT_BIT_FULL   equ     1

TestOptions:
;    db      (1<<TEST_OPT_BIT_FULL)
    db      (1<<TEST_OPT_BIT_FULL)|(1<<TEST_OPT_BIT_TURBO)

InstructionsData_FullTests:
    dw      0, TestFull_AddBcA
    dw      0, TestFull_AddDeA
    dw      0, TestFull_AddHlA
    dw      0, TestFull_Lddx, 0, TestFull_Ldix
    dw      TestFull_Ldpirx, TestFull_Ldws
    dw      TestFull_Mirror, TestFull_MulDE
    dw      0, 0
    dw      TestFull_Outinb, TestFull_Pixelad, TestFull_Pixeldn
    dw      0, TestFull_Setae, TestFull_Swapnib, TestFull_TestNn

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

TestCallWrapper:
    ; verify HL is not null
    ld      a,h
    or      l
    ret     z
    call    .WrappedTest
    call    DeinitHeartbeat
    ;; FIXME store results
    ret
.WrappedTest:
    jp      hl

;;;;;;;;;;;;;;;;;;;;;;;;; MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Start:
    call    StartTest
    call    RedrawMainScreen
    call    SetTurboModeByOption

    ;;FIXME all - do keyboard controls and run tests

    ; - read whole keyboard into some big array
    ; - check main keys, adjust options, etc
    ; - check test keys and run particular test (or display LOG!)
    ; - global debounce! ?! !
    ; - redrawn main screen to display test result
    ; - create "report result/errors" API and adjust tests to use it

    ; TestFull_TestNn, TestFull_Ldws, TestFull_AddHlA, TestFull_Ldpirx
    ld      hl,TestFull_Ldpirx
    call    TestCallWrapper

    call    EndTest

;;;;;;;;;;;;;;;;;;;;;;;; Tests themselves ;;;;;;;;;;;;;;;;;;;;;
;;FIXME add missing tests: ADD rr,**, LD*RX, NEXTREG_any, PUSH **
;    CSPECT_BRK     ;;FIXME

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
    ld      a,OUTINB_TEST_PORT>>8
    cp      b
    jr      nz,.PortNumDamaged
    ld      a,OUTINB_TEST_PORT&$FF
    cp      c
    jr      nz,.PortNumDamaged
    ; read value back from port to verify
    in      a,(c)
    cp      e           ; should be equal to old L (CF=0 if OK)
    jr      nz,.PortReadsBackOtherValue
    ; check if HL was advanced
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
    ld      a,RED
    out     (ULA_P_FE),a
    jr      $
.PortReadsBackOtherValue:
    ld      a,BLACK
    out     (ULA_P_FE),a
    jr      $
.HlDidNotAdvance:
    ld      a,BLUE
    out     (ULA_P_FE),a
    jr      $

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
    or      a           ; CF=0
    ex      de,hl
    sbc     hl,de
    ex      de,hl
    jr      nz,.errorFound
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
    ld      a,RED
    out     (ULA_P_FE),a
    jr      $

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
    ld      a,RED
    out     (ULA_P_FE),a
    jr      $

;;;;;;;;;;;;;;;;;;;;;;;; Test SETAE (instant) ;;;;;;;;;;;;;;;;;;
TestFull_Setae:
    INIT_HEARTBEAT_256
    ld      e,0         ; "X coordinate" (0..255)
    ld      b,$80       ; expected value
.FullTestLoop:
    db      $ED, $95    ; SETAE
    cp      b
    jr      nz,.errorFound
    rrc     b
    call    TestHeartbeat
    inc     e
    jp      nz,.FullTestLoop
    ret
.errorFound:
    ld      c,a
    ld      a,RED
    out     (ULA_P_FE),a
    jr      $           ; E: X-coord, B: expected mask, C: obtained mask

    savesna "!Z80N.sna", Start
