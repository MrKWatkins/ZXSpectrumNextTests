; Depends on many things set in Main.asm (it was split into files afterward), so it
; may be somewhat difficult to read than would it be designed with some kind of API
; ... deal with it, it's just about 1+k LoC ... :P :D

; ";;DEBUG" mark instructions can be used to intentionally trigger error (test testing)

; This file has tests for: PIXELDN | PIXELAD | SETAE

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
