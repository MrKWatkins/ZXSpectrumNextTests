; Depends on many things set in Main.asm (it was split into files afterward), so it
; may be somewhat difficult to read than would it be designed with some kind of API
; ... deal with it, it's just about 1+k LoC ... :P :D

; ";;DEBUG" mark instructions can be used to intentionally trigger error (test testing)

; This file has tests for: TEST | MIRROR | SWAPNIB | MUL D,E | ADD rr,A | ADD rr,**

;;;;;;;;;;;;;;;;;;;;;;;; Test TEST * (2s) ;;;;;;;;;;;;;;;;;;
TestFull_TestNn:
    INIT_HEARTBEAT_256
    ld      bc,0        ; TEST B,C for 256x256 combinations
.FullTestLoopNextNn:
    ld      a,c
    ld      (.Z80NInstTest+2),a ; set NN (=C) in test instruction
.FullTestLoop:
    ; do TEST A,C manually by Z80 instructions
    ld      a,b
    and     c           ; set F
    ld      a,b         ; restore A
    push    af          ; put result on stack
    pop     hl          ; put expected result into HL
.Z80NInstTest:
    db      $ED, $27, $00   ; TEST $00
    ;res     6,a ;;DEBUG
    push    af
    pop     de
    or      a           ; enforce CF=0
    sbc     hl,de
    jr      nz,.errorFound
    djnz    .FullTestLoop
    call    TestHeartbeat
    inc     c
    jp      nz,.FullTestLoopNextNn
    ret
.errorFound:
    add     hl,de       ; reconstruct expected AF
    ex      de,hl       ; put expected/received AF into correct registers for Logging
    ld      b,c         ; B = $nn
    call    LogAdd1B2W  ; B:$nn DE:expected AF HL:received AF
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Test MIRROR (instant) ;;;;;;;;;;;;;;;;;;
TestFull_Mirror:
    INIT_HEARTBEAT_256
    ld      b,0
.FullTestLoop:
    ; do MIRROR (B->A) manually by Z80 instructions
    rrc     b
    rla
    rrc     b
    rla
    rrc     b
    rla
    rrc     b
    rla
    rrc     b
    rla
    rrc     b
    rla
    rrc     b
    rla
    rrc     b
    rla
    ;rrca ;;DEBUG
    db      $ED, $24    ; MIRROR A
    ; now A should be back; equal to B value
    cp      b
    jr      nz,.errorFound
    call    TestHeartbeat
    djnz    .FullTestLoop
    ret
.errorFound:
    ld      c,a     ; B is expected value, C is fail-check value
    call    LogAdd2B
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret             ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Test SWAPNIB (instant) ;;;;;;;;;;;;;;;;;;
TestFull_Swapnib:
    INIT_HEARTBEAT_256
    ld      b,0
.FullTestLoop:
    ld      a,b
    rrca                ; do SWAPNIB manually by Z80 instructions
    rrca
    rrca
    rrca
    ;rlca ;;DEBUG
    db      $ED, $23    ; SWAPNIB  ; swap(a[3:0], a[7:4])
    ; now A should be back to original value
    cp      b
    jr      nz,.errorFound
    call    TestHeartbeat
    djnz    .FullTestLoop
    ret
.errorFound:
    ld      c,a         ; B is expected value, C is calculated
    call    LogAdd2B
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Test MUL D,E (1s) ;;;;;;;;;;;;;;;;;;
TestFull_MulDE:
    INIT_HEARTBEAT_256
    ld      bc,0
.FullTestLoopSetHl_A:
    ld      hl,0
    xor     a           ; A=0, CF=0 (!)
.FullTestLoop:
    ld      d,c
    ld      e,a
    db      $ED, $30    ; MUL D,E   ; DE = D*E
    ;res     5,d ;;DEBUG
    ex      de,hl       ; 4T
    sbc     hl,de       ; 15T  ZF=1, CF=0 if OK
    jr      nz,.errorFound  ; 12/7T
    ex      de,hl       ; 4T = 30T test when OK
    add     hl,bc       ; update expected result in HL (CF=0)
    inc     a
    jp      nz,.FullTestLoop
    call    TestHeartbeat
    inc     c
    jp      nz,.FullTestLoopSetHl_A
    ret
.errorFound:
    ld      b,c
    ld      c,a
    add     hl,de       ; restore result back
    ex      de,hl       ; put it into DE
    call    LogAdd2B1W  ; log(B: "D", C: "E", DE: "D*E")
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Test ADD BC,A (a bit more than 1:20) ;;;;;;;;;;;;;;;;;;
TestFull_AddBcA:
    INIT_HEARTBEAT_256
    push    ix
    ld      ix,.FullTestLoop
.FullTestLoopSetA:
    xor     a           ; A=0
.FullTestLoopResetHl:
    ld      hl,(.FullTestLoop+1)    ; reset expected value
.FullTestLoop:
    ld      bc,$0000
    db      $ED, $33    ; ADD BC,A
    ;inc     bc ;;DEBUG
    or      a           ; 4T force-reset CF as it's state is undefined
    sbc     hl,bc       ; 15T  ZF=1 if OK
    add     hl,bc       ; 11T restore HL (if OK), ZF is preserved from SBC
    jr      nz,.errorFound  ; 12/7T = 37T test when OK
    inc     hl          ; update expected result in HL
    inc     a
    jp      nz,.FullTestLoop
    inc     (ix+1)
    jp      nz,.FullTestLoopResetHl
    call    TestHeartbeat
    inc     (ix+2)
    jp      nz,.FullTestLoopSetA
    pop     ix
    ld      (ix+1),RESULT_OK    ; force result to full OK
    ret
.errorFound:
    push    bc
    pop     hl          ; HL = result
    ld      b,a
    ld      de,(.FullTestLoop+1)
    call    LogAdd1B2W  ; log(B:"A", DE:original BC, HL: BC+A result)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Partial test ADD BC,A (3s) ;;;;;;;;;;;;;;;;;;
TestL1_AddBcA:          ; ADD BC,A has only two levels (L1 and Full)
    INIT_HEARTBEAT_256
    ld      a,RESULT_OK1
    cp      (ix+1)
    ret     z           ; if Level1 was already run, don't twice
.L1TestLoopSetA:
    xor     a           ; A=0
    ld      hl,(.L1TestLoop+1)    ; reset expected value
.L1TestLoop:
    ld      bc,$0000
    db      $ED, $33    ; ADD BC,A
    ;inc     bc ;;DEBUG
    or      a
    sbc     hl,bc       ; ZF=1
    add     hl,bc       ; restore HL (if OK), ZF is preserved from SBC
    jr      nz,.errorFound
    inc     hl          ; update expected result in HL
    inc     a
    jp      nz,.L1TestLoop
    ; increment base BC by 41 (prime number, will jump over 65536 range in 1598 loops)
    ld      hl,.L1TestLoop+1
    ld      a,41
    add     a,(hl)
    ld      (hl),a
    jp      nc,.L1TestLoopSetA
    call    TestHeartbeat
    inc     hl
    inc     (hl)
    jp      nz,.L1TestLoopSetA
    ld      (ix+1),RESULT_OK1   ; this was only partial test, there's 1 more level
    ret
.errorFound:
    push    bc
    pop     hl          ; HL = result
    ld      b,a
    ld      de,(.L1TestLoop+1)
    call    LogAdd1B2W  ; log(B:"A", DE:original BC, HL: BC+A result)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Test ADD DE,A (a bit more than 1:15) ;;;;;;;;;;;;;;;;;;
TestFull_AddDeA:
    INIT_HEARTBEAT_256
    push    ix
    ld      ix,.FullTestLoop
.FullTestLoopSetA:
    xor     a           ; A=0
.FullTestLoopResetHl:
    ld      hl,(.FullTestLoop+1)    ; reset expected value
.FullTestLoop:
    ld      de,$0000
    db      $ED, $32    ; ADD DE,A
    ;inc     de ;;DEBUG
    ex      de,hl
    or      a
    sbc     hl,de       ; ZF=1
    jr      nz,.errorFound
    ex      de,hl
    inc     hl          ; update expected result in HL
    inc     a
    jp      nz,.FullTestLoop
    inc     (ix+1)
    jp      nz,.FullTestLoopResetHl
    call    TestHeartbeat
    inc     (ix+2)
    jp      nz,.FullTestLoopSetA
    pop     ix
    ld      (ix+1),RESULT_OK    ; force result to full OK
    ret
.errorFound:
    ld      b,a
    ; restore result of addition
    add     hl,de
    ld      de,(.FullTestLoop+1)
    call    LogAdd1B2W  ; log(B:"A", DE:original DE, HL: DE+A result)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Partial test ADD DE,A (3s) ;;;;;;;;;;;;;;;;;;
TestL1_AddDeA:          ; ADD DE,A has only two levels (L1 and Full)
    INIT_HEARTBEAT_256
    ld      a,RESULT_OK1
    cp      (ix+1)
    ret     z           ; if Level1 was already run, don't twice
.L1TestLoopSetA:
    xor     a           ; A=0
    ld      hl,(.L1TestLoop+1)    ; reset expected value
.L1TestLoop:
    ld      de,$0000
    db      $ED, $32    ; ADD DE,A
    ;inc     de ;;DEBUG
    ex      de,hl
    or      a
    sbc     hl,de       ; ZF=1
    jr      nz,.errorFound
    ex      de,hl
    inc     hl          ; update expected result in HL
    inc     a
    jp      nz,.L1TestLoop
    ; increment base DE by 41 (prime number, will jump over 65536 range in 1598 loops)
    ld      hl,.L1TestLoop+1
    ld      a,41
    add     a,(hl)
    ld      (hl),a
    jp      nc,.L1TestLoopSetA
    call    TestHeartbeat
    inc     hl
    inc     (hl)
    jp      nz,.L1TestLoopSetA
    ld      (ix+1),RESULT_OK1   ; this was only partial test, there's 1 more level
    ret
.errorFound:
    ld      b,a
    ; restore result of addition
    add     hl,de
    ld      de,(.L1TestLoop+1)
    call    LogAdd1B2W  ; log(B:"A", DE:original DE, HL: DE+A result)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Test ADD HL,A (a bit more than 1:12) ;;;;;;;;;;;;;;;;;;
TestFull_AddHlA:
    ; this "ADD HL,A" test was written first, and started as straightforward simple
    ; emulation of ADD HL,A vs real instruction... then I measured it would take about
    ; 20min to run it for all [HL,A] combinations, which seemed a bit way too much, so
    ; instead this optimized one evolved.
    ; Will take something under 5min (about 1:12 in 14MHz mode)
    INIT_HEARTBEAT_256
    push    ix
    ld      ix,.FullTestLoop
.FullTestLoopSetA:
    xor     a           ; A=0
.FullTestLoopResetDe:
    ld      de,(.FullTestLoop+1)    ; reset expected value
.FullTestLoop:
    ld      hl,$0000
    db      $ED, $31    ; ADD HL,A
    ;inc     hl ;;DEBUG
    or      a
    sbc     hl,de       ; ZF=1
    jr      nz,.errorFound
    inc     de          ; update expected result in DE
    inc     a
    jp      nz,.FullTestLoop
    inc     (ix+1)
    jp      nz,.FullTestLoopResetDe
    call    TestHeartbeat
    inc     (ix+2)
    jp      nz,.FullTestLoopSetA
    pop     ix
    ld      (ix+1),RESULT_OK    ; force result to full OK
    ret
.errorFound:
    ld      b,a
    ; restore result of addition
    add     hl,de
    ld      de,(.FullTestLoop+1)
    call    LogAdd1B2W  ; log(B:"A", DE:original HL, HL: HL+A result)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Partial test ADD HL,A (3s) ;;;;;;;;;;;;;;;;;;
TestL1_AddHlA:          ; ADD HL,A has only two levels (L1 and Full)
    INIT_HEARTBEAT_256
    ld      a,RESULT_OK1
    cp      (ix+1)
    ret     z           ; if Level1 was already run, don't twice
.L1TestLoopSetA:
    xor     a           ; A=0
    ld      de,(.L1TestLoop+1)    ; reset expected value
.L1TestLoop:
    ld      hl,$0000
    db      $ED, $31    ; ADD HL,A
    ;inc     hl ;;DEBUG
    or      a
    sbc     hl,de       ; ZF=1
    jr      nz,.errorFound
    inc     de          ; update expected result in DE
    inc     a
    jp      nz,.L1TestLoop
    ; increment base HL by 41 (prime number, will jump over 65536 range in 1598 loops)
    ld      hl,.L1TestLoop+1
    ld      a,41
    add     a,(hl)
    ld      (hl),a
    jp      nc,.L1TestLoopSetA
    call    TestHeartbeat
    inc     hl
    inc     (hl)
    jp      nz,.L1TestLoopSetA
    ld      (ix+1),RESULT_OK1   ; this was only partial test, there's 1 more level
    ret
.errorFound:
    ld      b,a
    ; restore result of addition
    add     hl,de
    ld      de,(.L1TestLoop+1)
    call    LogAdd1B2W  ; log(B:"A", DE:original HL, HL: HL+A result)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Partial test ADD HL,** (0.6s) ;;;;;;;;;;;;;;;;;;
TestL1_AddHlW:          ; partial L1 test (65536 iterations through all $nnnn)
    INIT_HEARTBEAT_256
    ld      a,RESULT_OK1
    cp      (ix+1)
    ret     z           ; if Level1 was already run, don't twice
    ; init test variables
    ld      de,$357B    ; expected/base value in HL
    ld      bc,0
.L1TestLoop:
    ld      h,d
    ld      l,e
    ld      (.NnnnValue),bc
    db      $ED, $34    ; ADD HL,** ; undefined flags ATM (may be changed later)
.NnnnValue:
    db      0, 0
    ;res     7,h ;;DEBUG
    ex      de,hl
    add     hl,bc
    or      a
    sbc     hl,de
    jr      nz,.errorFound
    inc     c
    jp      nz,.L1TestLoop
    call    TestHeartbeat
    inc     b
    jp      nz,.L1TestLoop
    ld      (ix+1),RESULT_OK1   ; this was only partial test
    ret
.errorFound:
    add     hl,de       ; restore expected result in HL
    ex      de,hl       ; DE:expected, HL:real, BC:$nnnn
    call    LogAdd3W    ; log(DE: expected, HL: result, BC: $nnnn)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Partial test ADD DE,** (0.6s) ;;;;;;;;;;;;;;;;;;
TestL1_AddDeW:          ; partial L1 test (65536 iterations through all $nnnn)
    INIT_HEARTBEAT_256
    ld      a,RESULT_OK1
    cp      (ix+1)
    ret     z           ; if Level1 was already run, don't twice
    ; init test variables
    ld      de,$47E2    ; expected/base value in DE
    ld      bc,0
.L1TestLoop:
    ld      h,d         ; copy expected/base into HL
    ld      l,e
    ld      (.NnnnValue),bc
    db      $ED, $35    ; ADD DE,** ; undefined flags ATM (may be changed later)
.NnnnValue:
    db      0, 0
    ;res     7,d ;;DEBUG
    add     hl,bc
    or      a
    sbc     hl,de
    jr      nz,.errorFound
    inc     c
    jp      nz,.L1TestLoop
    call    TestHeartbeat
    inc     b
    jp      nz,.L1TestLoop
    ld      (ix+1),RESULT_OK1   ; this was only partial test
    ret
.errorFound:
    add     hl,de       ; restore expected result in HL
    ex      de,hl       ; DE:expected, HL:real, BC:$nnnn
    call    LogAdd3W    ; log(DE: expected, HL: result, BC: $nnnn)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test

;;;;;;;;;;;;;;;;;;;;;;;; Partial test ADD BC,** (0.6s) ;;;;;;;;;;;;;;;;;;
TestL1_AddBcW:          ; partial L1 test (65536 iterations through all $nnnn)
    INIT_HEARTBEAT_256
    ld      a,RESULT_OK1
    cp      (ix+1)
    ret     z           ; if Level1 was already run, don't twice
    ; init test variables
    ld      bc,$C277    ; expected/base value in BC
    ld      de,0
.L1TestLoop:
    ld      h,b         ; copy expected/base into HL
    ld      l,c
    ld      (.NnnnValue),de
    db      $ED, $36    ; ADD BC,** ; undefined flags ATM (may be changed later)
.NnnnValue:
    db      0, 0
    ;set     7,b ;;DEBUG
    add     hl,de
    or      a
    sbc     hl,bc
    jr      nz,.errorFound
    inc     e
    jp      nz,.L1TestLoop
    call    TestHeartbeat
    inc     d
    jp      nz,.L1TestLoop
    ld      (ix+1),RESULT_OK1   ; this was only partial test
    ret
.errorFound:
    add     hl,bc       ; restore expected result in HL = HL:expected, DE:$nnnn, BC:real result
    ex      de,hl       ; DE:expected, HL:$nnnn, BC:real result
    push    bc
    pop     hl          ; DE:expected, HL:real result, BC:real result
    ld      bc,(.NnnnValue)
    call    LogAdd3W    ; log(DE: expected, HL: result, BC: $nnnn)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
