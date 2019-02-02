; Depends on many things set in Main.asm

; ";;DEBUG" mark instructions can be used to intentionally trigger error (test testing)

; This file has tests for: JP (C)

;;;;;;;;;;;;;;;;;;;;;;;; Test JP (C) (instant) ;;;;;;;;;;;;;;;;;;
; this will trash memory at C000..FFFF range unfortunately, but there's no easy way around
; it will also slightly modify other spots of memory, trying to pick quite bening ones.

MEM_JP_ADR      equ     $FFFD       ; desired placement of JP (C) instruction
JP_C_ENCODED    equ     $98ED       ; opcode of JP (C) instruction
RET_OPCODE      equ     201
CPL_OPCODE      equ     47

TestFull_JpInC:
    INIT_HEARTBEAT_256

    ; how this test works:

    ; fills whole C000..FFFF area with RET instruction
    ; FFFD and FFFE bytes are set to "ED 98" = JP (C) (FFFF is kept as RET)

    ; The test loop going A=0..255 will output A to NextReg port $243B, CPL the A,
    ; put single CPL instruction at expected landing point, and "call" the JP(C).

    ; After it returns by reaching any "ret" instruction, the A is compared with original
    ; value sent to the port (in total 2x CPL should have executed = value equals).

    ; Then the old target CPL is replaced with RET again, and code loops 256 times (A++)

    ; The "PC" used by the instruction already points at next instruction, so "JP (C)"
    ; positioned at the very end of the 16k area, will actually jump into the next 16k
    ; area (like into 0000..3FFF area for "JP (C)" at FFFE or FFFF)!

    ; After this initial loop through 0..255 is done, the code will further exercise
    ; (by similar means) other areas of memory, and also "leak" into next area if
    ; "JP (C)" is at $*FFE address at the very end of previous block.

    FILL_AREA MEM_JP_C_AREA, $4000, RET_OPCODE    ; fill C000..FFFD area with RET
    ld      hl,JP_C_ENCODED
    ld      (MEM_JP_ADR),hl
    xor     a                       ; A = 0
    ld      hl,MEM_JP_C_AREA        ; HL = target address for particular "A" value
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
.LoopInC000area:
    out     (c),a                   ; write A on (BC) I/O port
    ld      (hl),CPL_OPCODE         ; put CPL at expected landing
    ;ld      (hl),RET_OPCODE ;;DEBUG
    ld      d,a                     ; remember expected A in D
    cpl                             ; do CPL once "here"
    call    MEM_JP_ADR              ; "call" the JP (C) -> should do CPL "there" + RET
    cp      d
    jr      nz,.errorFound
    call    TestHeartbeat           ; will do heartbeat 256 times here
    ld      (hl),RET_OPCODE         ; turn CPL back into RET
    ld      de,1<<6                 ; add to get next target address
    add     hl,de                   ; next target address
    inc     a                       ; next A and loop
    jr      nz,.LoopInC000area
    ; if the whole loop worked, it probably works, check ugly details... other areas first
    ; copy the short piece of test code into all location which will be tested
    ld      hl,.OtherRegionTestCode
    ld      de,$4000                ; use VRAM for first test (4000..7FFF)
    ld      bc,.ORTC_SIZE
    ldir
    ld      hl,.OtherRegionTestCode
    ld      de,MEM_SCRAP_BUFFER     ; use "SCRAP" $A000 for second test (8000..BFFF)
    ld      bc,.ORTC_SIZE
    ldir
    ld      hl,.OtherRegionTestCode
    ld      de,MEM_JP_C_AREA-1-.ORTC_JPOFS
        ; this will make JP land at BFFF, and create "98 sbc a,b : C9 ret" at C000 (!)
    ld      bc,.ORTC_SIZE
    ldir
    ld      hl,$8000                ; inject extra RET at $8000 in case the "next area"
    ld      (hl),RET_OPCODE         ; test fails like this (over DI from TestFunctions.asm)
    ; VRAM jump of faith (for IN(C)=0 -> JP $4000 should happen)
    xor     a
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    out     (c),a
    call    $4000+.ORTC_JPOFS
    ;inc     a ;;DEBUG
    inc     a
    ld      de,$4000
    ld      b,0
    call    nz,.errorFoundOtherArea
    ; clear the mess in VRAM
    FILL_AREA MEM_ZX_SCREEN_4000, .ORTC_SIZE, 0
    ; try SCRAP area (A000) jump of faith (for IN(C)=$80 -> JP $A000 should happen)
.SCRAP_IN_VALUE  equ     (MEM_SCRAP_BUFFER&$3FFF)/(1<<6)
    ld      a,.SCRAP_IN_VALUE
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    out     (c),a
    call    MEM_SCRAP_BUFFER+.ORTC_JPOFS
    ;inc     a ;;DEBUG
    cp      $FF^.SCRAP_IN_VALUE
    ld      de,MEM_SCRAP_BUFFER&$C000
    ld      b,.SCRAP_IN_VALUE
    call    nz,.errorFoundOtherArea
    ; check if "next section" happens when jump is at very end of current section
    xor     a               ; A=0, CF=0
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    out     (c),a
    call    MEM_JP_C_AREA-1 ; for IN(C)=0 -> JP $C000 should happen (from JP at $BFFF)
    ;inc     a ;;DEBUG
    cp      -$24            ; sbc a,b -> 0 - $24 - CF:0 = -$24
    jr      nz,.errorFoundNextArea
    ret
.errorFound:
    push    bc
    ld      b,d
    ld      c,a
    ex      de,hl
    pop     hl
    call    LogAdd2B2W  ; log(B: in(C) value, C: A, DE:JP target address, HL: port used)
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
.OtherRegionTestCode:
    cpl
    ret
.ORTC_JPOFS equ $ - .OtherRegionTestCode
    db      $ED, $98    ; JP (C)    ; $98 is "sbc a,b"
    ret
.ORTC_SIZE  equ $ - .OtherRegionTestCode
.OtherAreaFailMsg:
    db      'Test failed in area:',0
.errorFoundOtherArea:
    ; "calculate" HL as "end of area" by DE+$3F00 and L=$FF
    ld      a,$3F
    add     a,d
    ld      h,a
    ld      l,$FF
    push    ix
    ld      ix,.OtherAreaFailMsg
    call    LogAddMsg1B2W   ; log(B: in(C) value, DE: area_start, HL: area_end, IX: msg)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
.NextAreaFailMsg:
    db      'PC was not advanced to next area.',0
.errorFoundNextArea:
    push    ix
    ld      ix,.NextAreaFailMsg
    call    LogAddMsg   ; log(IX: msg)
    pop     ix
    ld      (ix+1),RESULT_ERR   ; set result to ERR
    ret                 ; terminate test
