; Depends on many things set in Main.asm (it was split into files afterward), so it
; may be somewhat difficult to read than would it be designed with some kind of API
; ... deal with it, it's just about 1+k LoC ... :P :D

; ";;DEBUG" mark instructions can be used to intentionally trigger error (test testing)

; This file has tests for: OUTINB | PUSH **

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

;;;;;;;;;;;;;;;;;;;;;;;; Test PUSH ** (2s) ;;;;;;;;;;;;;;;;;;
JP_OPCODE      equ     $C3

TestFull_PushW:
    INIT_HEARTBEAT_256
    ;; create fixed `push $XX..` skeleton to accelerate test loops (changing XX only)
    ld      bc,$ED8A    ; base part of opcode (in big endian)
    ld      de,0        ; current $nnnn value
    ld      hl,MEM_SCRAP_BUFFER2
.skeletonLoop:
    ; opcode: ED  8A  high = D  low = E
    ld      (hl),b
    inc     l
    ld      (hl),c
    inc     l           ; skip "high", this one will be modified for every test run
    inc     l
    dec     e           ; sets also ZF
    ld      (hl),e      ; write already modified E to get FF -> 0 sequence in PUSH
    inc     hl          ; needs HL to step over 256B boundaries and keep flags
    jp      nz,.skeletonLoop
    ; put at end JP returning back to test
    ld      (hl),JP_OPCODE
    inc     l
    ld      (hl),.ReturnHereAfterPush&$FF
    inc     l
    ld      (hl),.ReturnHereAfterPush>>8
    ;; Main test loop: now fill up the skeleton 256 times with HI byte going 0..255
.mainTestLoop:
    ; adjust set of push instructions for next test
    ld      hl,MEM_SCRAP_BUFFER2+2
    ld      b,4         ; loop 4x64 times = 256 in total
    ld      a,l
.createPushSequence:
    ld      (hl),d
    add     a,4
    ld      l,a         ; loops 64 times with L updated by 4
    jr      nc,.createPushSequence
    inc     h           ; next H
    djnz    .createPushSequence
    ;; run the test
    ; preserve original SP to return from test correctly
    ld      (.PUSHW_RESTORE_SP),sp
    ; set SP to target area and run push sequence
    ld      sp,MEM_SCRAP_BUFFER+2*256
    jp      MEM_SCRAP_BUFFER2
.ReturnHereAfterPush:
    ; restore SP
    ld      sp,$1234
.PUSHW_RESTORE_SP   equ $-2
    ;; test target area content, if push did what it should
    ld      hl,MEM_SCRAP_BUFFER
.VerifyLoop:            ; should contain 16b sequence $xx00, $xx01, ..., $xxFF
    ;res     6,e ;;DEBUG
    ld      a,e
    cp      (hl)
    jr      nz,.errorFoundLo
    inc     l
    ;res     5,d ;;DEBUG
    ld      a,d
    cp      (hl)
    jr      nz,.errorFoundHi
    inc     hl
    inc     e
    jr      nz,.VerifyLoop
    ; do the main 256x loop
    call    TestHeartbeat
    inc     d
    jp      nz,.mainTestLoop
    ret     ; test finished
    ; DE expected value, HL points somewhere into unexpected one (+0 for LO, +1 for HI)
.errorFoundHi:
    dec     l           ; restore HL to point to the problematic 16b value
.errorFoundLo:
    ld      a,(hl)      ; fetch unexpected value into HL
    inc     l
    ld      h,(hl)
    ld      l,a
    call    LogAdd2W    ; log(DE: expected value, HL: value obtained)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
