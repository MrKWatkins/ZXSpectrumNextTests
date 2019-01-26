; Depends on many things set in Main.asm (it was split into files afterward), so it
; may be somewhat difficult to read than would it be designed with some kind of API
; ... deal with it, it's just about 1+k LoC ... :P :D

; This file has tests for: LDWS | LDPIRX | LDDX | LDIX

;;;;;;;;;;;;;;;;;;;;;;;; Test LDWS (instant) ;;;;;;;;;;;;;;;;;;
TestFull_Ldws:
    INIT_HEARTBEAT_32
    ;; create initial data in scrap buffer
    FILL_AREA MEM_SCRAP_BUFFER+$100, $400, $11  ; put $11 everywhere "else"
    call    Set0to255ScrapData          ; and 0..255 sequence at beginning of scrap

    ;; just call the LDWS few times, checking for results afterward
    ld      hl,MEM_SCRAP_BUFFER+$FE     ; start near end of 256B block
    ld      de,MEM_SCRAP_BUFFER+$01     ; cross even source data
    call    .DoFourLdws
    call    .DoOneLdws
    ; (A0FE->A001) FE, (A0FF->A101) FF, (A000->A201) 00
    ; (A001->A301) (original value is from A0FE!) FE, (A002->A401) 02
    ;; check ending values of HL and DE (flags already checked)
    ld      bc,MEM_SCRAP_BUFFER+$03
    or      a
    sbc     hl,bc
    call    nz,.errorFound_AdvanceRegsHl    ; ending HL mismatch
    ld      hl,MEM_SCRAP_BUFFER+$01+$500
    or      a
    sbc     hl,de
    call    nz,.errorFound_AdvanceRegsDe    ; ending DE mismatch
    ;; check values written in memory
    ; convert expected $FE at $A301 into $01 (to form sequence FE..02 as group)
    ld      hl,MEM_SCRAP_BUFFER+$01+$300
    ld      a,(hl)
    cpl
    ld      (hl),a
    ; now check the whole sequence, should be: FE, FF, 00, 01, 02
    ld      hl,MEM_SCRAP_BUFFER+$01
    ld      a,$FE
.VerifyLoop:
    cp      (hl)
    jr      nz,.errorFound
    inc     h
    inc     a
    call    TestHeartbeatFour
    cp      3
    jr      nz,.VerifyLoop
    ret
.DoFourLdws:
    call    .DoTwoLdws
.DoTwoLdws:
    call    .DoOneLdws
.DoOneLdws:
    call    TestHeartbeatFour
    ld      bc,$01FF
    db      $ED, $A5    ; LDWS
    push    af          ; preserve flags
    ; check if BC didn't move
    dec     b
    call    nz,.errorFound_AdvanceRegsBc
    inc     c
    call    nz,.errorFound_AdvanceRegsBc
    ; compare resulting flags with flags from "INC D"
    pop     bc
    dec     d
    inc     d
    push    af
    ld      a,c         ; F from LDWS
    pop     bc          ; F from emulating INC D
    cp      c
    ret     z           ; OK if flags are identical
    ; error in flags detected
.errorFound_Flags:
    push    hl
    push    de
    push    ix
    ld      b,c         ; expected F (from INC)
    ld      c,a         ; real F from LDWS
    ld      ix,.errorFlagsMsg
    call    LogAddMsg2B ; log(B:expected flags, C:real flags, IX:msg)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ; add this one to log only once, remove the code by putting RET at beginning
    ld      a,201
    ld      (.errorFound_Flags),a
    pop     de
    pop     hl
    ret                 ; continue test (DE+HL preserved)
.errorFound_AdvanceRegsHl:
    push    de
    push    ix
    ld      ix,.errorAdvanceRegsHlMsg
    add     hl,bc
    ld      d,b         ; DE=expected "hl", HL=real "hl"
    ld      e,c
    call    LogAddMsg2W ; log(DE: expected hl, HL: real hl, IX:msg)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    pop     de
    ret                 ; continue test (DE preserved)
.errorFound_AdvanceRegsDe:
    push    ix
    ld      ix,.errorAdvanceRegsDeMsg
    add     hl,de
    ex      de,hl       ; DE=expected "de", HL=real "de"
    call    LogAddMsg2W ; log(DE: expected de, HL: real de, IX:msg)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; continue test (no need to preserve anything)
.errorFound:
    ld      b,a
    ld      c,(hl)
    call    LogAdd2B    ; log(B:expected, C:value in memory)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
.errorFound_AdvanceRegsBc:
    push    ix
    ld      ix,.errorAdvanceRegsBcMsg
    call    LogAddMsg   ; log(IX:msg)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ; add this one to log only once, remove the code by putting RET at beginning
    ld      a,201
    ld      (.errorFound_AdvanceRegsBc),a
    ret                 ; continue with test (HL+DE preserved)
.errorFlagsMsg:
    db      'Unexpected flags',0
.errorAdvanceRegsHlMsg:
    db      'Unexpected HL',0
.errorAdvanceRegsDeMsg:
    db      'Unexpected DE',0
.errorAdvanceRegsBcMsg:
    db      'BC unexpectedly modified',0

;;;;;;;;;;;;;;;;;;;;;;;; Test LDPIRX (2s) ;;;;;;;;;;;;;;;;;;
Ldpirx_Test_Pattern_src:
    db      $50, $51, $52, $53, $54, $55, $56, $57  ; do NOT modify, these're also in code

TestFull_Ldpirx:
    INIT_HEARTBEAT_256
    ; verify first that LDPIRX does modify HL/DE/BC (ignore data transfers)
    ld      ix,MEM_SCRAP_BUFFER+128
    ld      hl,MEM_SCRAP_BUFFER+128
    ld      de,MEM_SCRAP_BUFFER2+127
    ld      bc,1
    ld      a,(ix+7)    ; should skip write (A == (HL&$FFF8+E&7))
    db      $ED, $B7    ; LDPIRX
    call    TestHlDeBcAfterFullBlockValues
    call    nz,.errorFound_AdvanceRegs
    ; do one more, this time writing byte (but again just to verify HL/DE/BC advance)
    ld      hl,MEM_SCRAP_BUFFER+128
    ld      de,MEM_SCRAP_BUFFER2+127
    ld      bc,1
    ld      a,(ix+7)    ; A = (HL&$FFF8+E&7)
    cpl                 ; should write (A == ~(pattern value))
    db      $ED, $B7    ; LDPIRX
    call    TestHlDeBcAfterFullBlockValues
    call    nz,.errorFound_AdvanceRegs
    ;;; verify now actual data transfers
    ; create source data in MEM_SCRAP_BUFFER at offset +128 (and fill everything around)
    FILL_AREA   MEM_SCRAP_BUFFER, 256, $FF  ; fill 256B area with $FF
    ; copy the pattern-source data
    ld      hl,Ldpirx_Test_Pattern_src
    ld      de,MEM_SCRAP_BUFFER+128
    ld      bc,8
    ldir
    ; test all possible "A=0..255" vs 256B block fill
    xor     a
.TestALoop:
    push    af          ; preserve test A
    ld      hl,MEM_SCRAP_BUFFER2
    ld      bc,256      ; put one more ahead of block to have copy of fill-value
    cpl
    call    FillArea    ; fill target 256B area with ~A
    ; mix HL from 13 bits of pattern address, and 3 bits from A[7:5] (adding noise)
    ld      hl,MEM_SCRAP_BUFFER+128 ; top 13 bits point to the pattern data
    rlca
    rlca
    rlca
    and     $07
    or      l
    ld      l,a         ; bottom 3 bits from A[7:5] to test they don't affect pattern
    pop     af
    ; do the actual pattern fill with LDPIRX
    ld      de,MEM_SCRAP_BUFFER2
    ld      bc,256
    db      $ED, $B7    ; LDPIRX
    ; pattern should be filled there, now check it
    ld      hl,MEM_SCRAP_BUFFER2
    ld      b,$50       ; pattern value
    ld      c,a         ; "transparency" value
.VerifyLoop:
    ; check if the value in memory should be pattern or init value (and put it into A)
    ld      a,b
    cp      c
    jp      nz,.NotTestAValueExpected
    cpl
.NotTestAValueExpected:
    ; compare with the memory content (verification itself)
    cp      (hl)
    jr      nz,.errorFound
    ; next byte of pattern (code-defined, not reading patter from source data!)
    inc     b
    res     3,b         ; constraint it to $50..$57 values
    inc     l           ; next address
    jp      nz,.VerifyLoop
    call    TestHeartbeat
    ld      a,c         ; restore current A test value
    inc     a
    jr      nz,.TestALoop
    ret
.errorFound:
    jr      $
.errorFound_AdvanceRegs:
    ret

;;;;;;;;;;;;;;;;;;;;;;;; Test LDDX (2s) ;;;;;;;;;;;;;;;;;;
TestFull_Lddx:
    INIT_HEARTBEAT_256
    ; verify first that LDDX does modify HL/DE/BC (ignore data transfers)
    ld      hl,MEM_SCRAP_BUFFER+129
    ld      de,MEM_SCRAP_BUFFER2+127
    ld      bc,$0200
    ld      a,(hl)      ; should skip write (A == (HL))
    db      $ED, $AC    ; LDDX
    call    TestHlDeBcForBlockValues
    jr      nz,.errorFound_AdvanceRegs
    ; do one more, this time writing byte (but again just to verify HL/DE/BC advance)
    ld      hl,MEM_SCRAP_BUFFER+129
    ld      de,MEM_SCRAP_BUFFER2+127
    ld      bc,$0200
    ld      a,(hl)
    cpl                 ; should write (A == ~(HL))
    db      $ED, $AC    ; LDDX
    call    TestHlDeBcForBlockValues
    jr      nz,.errorFound_AdvanceRegs
    ;;; verify now actual data transfers
    ; create source data which will be used to initialize target buffer
    call    Set0to255TwiceScrapData
    ; test all possible "A=0..255" vs 0..255 block transfers
    xor     a
.TestALoop:
    ld      hl,MEM_SCRAP_BUFFER+$80 ; offset "old" data by $80
    ld      de,MEM_SCRAP_BUFFER2
    ld      bc,256
    ldir                ; reinit target area to contain "old" values
    ; use LDDX to copy the "new" values over "old" (except test A=xx item)
    ld      hl,MEM_SCRAP_BUFFER+255 ; start from "back" with LDDX
    ld      de,MEM_SCRAP_BUFFER2    ; reinit target area to contain "old" values
    ld      bc,$0100    ; while LDDX is doing BC--, the DJNZ will still do 256 loops(!)
.BlockLoop:
    db      $ED, $AC    ; LDDX
    djnz    .BlockLoop  ; loop 256 times (accounts also for BC-- of LDDX)
    ; block of data copied, now check if the correct byte was skipped (and replace it)
    ; The data were copied in backward way 255,254,...,0, so the skipped is at [~A] adr.
    ld      h,MEM_SCRAP_BUFFER2>>8
    cpl
    ld      l,a         ; offset MEM_SCRAP_BUFFER2+(~A) of skipped value
    xor     $80         ; "old" value should be like this
    cp      (hl)
    jr      nz,.errorFound
    xor     $7F         ; turn it into "new" value (removes also CPL)
    ld      (hl),a      ; to make full 255..0 block verification simple
    ; now check whole block if it contains 255..0 values
    ex      af,af       ; preserve current A test value
    ld      l,0
    ld      a,255
.VerifyBlock:
    cp      (hl)
    jr      nz,.errorFound
    dec     a
    inc     l
    jr      nz,.VerifyBlock
    call    TestHeartbeat
    ex      af,af       ; restore current A test value
    inc     a
    jr      nz,.TestALoop
    ret
.errorFound:
    jr      $
.errorFound_AdvanceRegs:
    jr      $

;;;;;;;;;;;;;;;;;;;;;;;; Test LDIX (2s) ;;;;;;;;;;;;;;;;;;
TestFull_Ldix:
    INIT_HEARTBEAT_256
    ; verify first that LDIX does modify HL/DE/BC (ignore data transfers)
    ld      hl,MEM_SCRAP_BUFFER+127
    ld      de,MEM_SCRAP_BUFFER2+127
    ld      bc,$0200
    ld      a,(hl)      ; should skip write (A == (HL))
    db      $ED, $A4    ; LDIX
    call    TestHlDeBcForBlockValues
    jr      nz,.errorFound_AdvanceRegs
    ; do one more, this time writing byte (but again just to verify HL/DE/BC advance)
    ld      hl,MEM_SCRAP_BUFFER+127
    ld      de,MEM_SCRAP_BUFFER2+127
    ld      bc,$0200
    ld      a,(hl)
    cpl                 ; should write (A == ~(HL))
    db      $ED, $A4    ; LDIX
    call    TestHlDeBcForBlockValues
    jr      nz,.errorFound_AdvanceRegs
    ;;; verify now actual data transfers
    ; create source data which will be used to initialize target buffer
    call    Set0to255TwiceScrapData
    ; test all possible "A=0..255" vs 0..255 block transfers
    xor     a
.TestALoop:
    ld      hl,MEM_SCRAP_BUFFER+$80 ; offset "old" data by $80
    ld      de,MEM_SCRAP_BUFFER2
    ld      bc,256
    ldir                ; reinit target area to contain "old" values
    ; use LDIX to copy the "new" values over "old" (except test A=xx item)
    ld      hl,MEM_SCRAP_BUFFER
    ld      de,MEM_SCRAP_BUFFER2    ; reinit target area to contain "old" values
    ld      bc,$0100    ; while LDIX is doing BC--, the DJNZ will still do 256 loops(!)
.BlockLoop:
    db      $ED, $A4    ; LDIX
    djnz    .BlockLoop  ; loop 256 times (accounts also for BC-- of LDIX)
    ; block of data copied, now check if the correct byte was skipped (and replace it)
    ld      h,MEM_SCRAP_BUFFER2>>8
    ld      l,a         ; A = skipped value (at offset MEM_SCRAP_BUFFER2+A)
    xor     $80         ; "old" value should be like this
    cp      (hl)
    jr      nz,.errorFound
    xor     $80         ; turn it into "new" value
    ld      (hl),a      ; to make full 0..255 block verification simple
    ; now check whole block if it contains 0..255 values
    ex      af,af       ; preserve current A test value
    ld      l,0
.VerifyBlock:
    ld      a,l
    cp      (hl)
    jr      nz,.errorFound
    inc     l
    jr      nz,.VerifyBlock
    call    TestHeartbeat
    ex      af,af       ; restore current A test value
    inc     a
    jr      nz,.TestALoop
    ret
.errorFound:
    jr      $
.errorFound_AdvanceRegs:
    jr      $
