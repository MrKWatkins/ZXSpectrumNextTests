; MEM_LOG_DATA 2k buffer is defined by code including this (must be 256B aligned!)
; log structure: sequential items (one test can have multiple items, last item
; of particular test has set bit "last" in type).

; one item:
; +0    1B      type
;                   bits 7-6: reserved (invalid counts are not checked, use API only!)
;                   bit 5: last item for particular test
;                   bit 4-3: count of words stored in item
;                   bit 2-0: count of bytes stored in item
; +1    1B      b0
; +2    2B      w0
; +4    2B      w1
; +6    2B      w2/stringPtr
; total 8B size
;
; 3b + 2b = max amount 7 for 8b values and 3 for 16b values (not at the same time!)
; msg is displayed, when 8b+16b do not reach into w2, but w2 != nullptr
; 8b values use b0, lo(w0), hi(w0), lo(w1), hi(w1), lo(w2), hi(w2) (7 values max)
; 16b values are using remaining (after 8b) free "wX" (ignoring half-free wX-1)

LOG_ITEM_TYPE       equ     0       ; 1B [2:1:2:3] = reserved:last:wordCount,byteCount
LOG_ITEM_B0         equ     1       ; 1B
LOG_ITEM_W0         equ     2       ; 2B
LOG_ITEM_W1         equ     4       ; 2B
LOG_ITEM_W2         equ     6       ; 2B / if not nullptr and beyond wordCount => msgPtr
LOG_ITEM_SIZE       equ     8       ; total size

LOG_TYPE_EMPTY      equ     $3F     ; special type constant
LOG_TYPE_B_CNT_MASK equ     $07
LOG_TYPE_W_SHIFT    equ     3       ; how many bits to shift for word-count
LOG_TYPE_W_CNT_MASK equ     $03<<LOG_TYPE_W_SHIFT
LOG_TYPE_LAST       equ     $20     ; item is last in the chain for one test
LOG_TYPE_LAST_BIT   equ     5

LogLastIndex:
    db      0

; call at beginning of the app
LogInit:
    push    iy
    ld      a,0
    ld      (LogLastIndex),a
    call    LogGetItemAddress
    ld      (iy+LOG_ITEM_TYPE),LOG_TYPE_EMPTY  ; mark it as empty
    pop     iy
    ret

;A: index to calculate, returns address in IY
LogGetItemAddress:
    push    af
    push    hl
    ld      l,a
    ld      h,0
    add     hl,hl
    add     hl,hl
    add     hl,hl       ; HL = index * 8
    ld      a,MEM_LOG_DATA>>8
    add     a,h
    ld      h,a         ; address MEM_LOG_DATA added
    push    hl          ; move it to IY
    pop     iy          ; (avoided IY during calc. to use only official Z80 instructions)
    pop     hl          ; restore original HL
    pop     af
    ret

; will mark the last inserted item as "last" of the items per single test
; call this after test (or ahead of new one), redundant calls are OK
LogSealPreviousChainOfItems:
    push    iy
    ld      a,(LogLastIndex)
    call    LogGetItemAddress
    ld      a,LOG_TYPE_LAST
    or      (iy+LOG_ITEM_TYPE)
    ld      (iy+LOG_ITEM_TYPE),a
    pop     iy
    ret

; Gets new log item, returns:
; ZF=1: IY = new log item address, A = new log item index
; ZF=0: log is full, don't add anything
LogAllocateNewItem:
    ld      a,(LogLastIndex)
    inc     a
    jr      z,.logIsFull
    ld      (LogLastIndex),a
    call    LogGetItemAddress
    ; set nullptr to W2 of newly allocated log item ("no msg")
    ld      (iy+LOG_ITEM_W2),0
    ld      (iy+LOG_ITEM_W2+1),0
    ; return with ZF=1 and index of new item
    cp      a
    ret
.logIsFull:
    ; return with ZF=0 (A == 0, because that's how I got here)
    cp      1
    ret

    MACRO ALLOCATE_NEW_ITEM item_type
        call    LogAllocateNewItem  ; IY = new log item address, A = log index
        ret     nz                  ; log is full
        ld      (iy+LOG_ITEM_TYPE),item_type
    ENDM

; adds new log item with one 8b value in B
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd1B:
    ALLOCATE_NEW_ITEM 1     ; byte count = 1, word count = 0
.onlyStore:
    ld      (iy+LOG_ITEM_B0),b
    ret

; adds new log item with two 8b values, first in B, second in C
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd2B:
    ALLOCATE_NEW_ITEM 2     ; byte count = 2, word count = 0
.onlyStore:
    ld      (iy+LOG_ITEM_W0),c
    jr      LogAdd1B.onlyStore

; adds new log item with three 8b values, {B, C, E}
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd3B:
    ALLOCATE_NEW_ITEM 3     ; byte count = 3, word count = 0
    ld      (iy+LOG_ITEM_W0+1),e
    jr      LogAdd2B.onlyStore

; adds new log item with two 8b values, first in B, second in C and one 16b in DE
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd2B1W:
    ALLOCATE_NEW_ITEM 2+(1<<LOG_TYPE_W_SHIFT)   ; byte count = 2, word count = 1
    ld      (iy+LOG_ITEM_W1+1),d
    ld      (iy+LOG_ITEM_W1),e
    jr      LogAdd2B.onlyStore

; adds new log item with one 16b value in DE
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd1W:
    ALLOCATE_NEW_ITEM 1<<LOG_TYPE_W_SHIFT       ; byte count = 0, word count = 1
.onlyStore:
    ld      (iy+LOG_ITEM_W0+1),d
    ld      (iy+LOG_ITEM_W0),e
    ret

; adds new log item with two 16b values, first in DE, second in HL
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd2W:
    ALLOCATE_NEW_ITEM 2<<LOG_TYPE_W_SHIFT       ; byte count = 0, word count = 2
.onlyStore:
    ld      (iy+LOG_ITEM_W1+1),h
    ld      (iy+LOG_ITEM_W1),l
    jr      LogAdd1W.onlyStore

; adds new log item with one 8b, two 16b values, 8b in B, first word in DE, second in HL
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd1B2W:
    ALLOCATE_NEW_ITEM 1+(2<<LOG_TYPE_W_SHIFT)   ; byte count = 1, word count = 2
    ld      (iy+LOG_ITEM_B0),b
    jr      LogAdd2W.onlyStore

; adds new log item with three 16b values, first word in DE, second in HL, third in BC
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd3W:
    ALLOCATE_NEW_ITEM 3<<LOG_TYPE_W_SHIFT       ; byte count = 0, word count = 3
    ld      (iy+LOG_ITEM_W2+1),b
    ld      (iy+LOG_ITEM_W2),c
    jr      LogAdd2W.onlyStore

; adds new log item with msg in IX
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAddMsg:
    ALLOCATE_NEW_ITEM 0     ; byte count = 0, word count = 0
.onlySetMsg:
    push    hl      ; preserve HL
    push    ix      ; HL = IX
    pop     hl
    ld      (iy+LOG_ITEM_W2+1),h
    ld      (iy+LOG_ITEM_W2),l
    pop     hl
    ret

; adds new log item with one 8b value in B and msg in IX
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAddMsg1B:
    call    LogAdd1B                ; IY = new log item address, A = log index
    ret     nz      ; log is full
    jr      LogAddMsg.onlySetMsg

; adds new log item with two 8b values, first in B, second in C and msg in IX
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAddMsg2B:
    call    LogAdd2B                ; IY = new log item address, A = log index
    ret     nz      ; log is full
    jr      LogAddMsg.onlySetMsg

; adds new log item with one 16b value in DE and msg in IX
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAddMsg1W:
    call    LogAdd1W    ; IY = new log item address, A = log index
    ret     nz          ; log is full
    jr      LogAddMsg.onlySetMsg

; adds new log item with two 16b values, first in DE, second in HL and msg in IX
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAddMsg2W:
    call    LogAdd2W    ; IY = new log item address, A = log index
    ret     nz          ; log is full
    jr      LogAddMsg.onlySetMsg

; display log (HL: test address, DE = index*2, IX = test details data)
DisplayLogForOneTest:
    ; clear the log area
    ld      bc,$17 + ((31-CHARPOS_ENCODING)<<8)
    ld      d,0
    ld      hl,MEM_ZX_SCREEN_4000+1*32+CHARPOS_ENCODING
    call    .DoAllEightPixelLinesUlaFill
    ld      bc,$0117
    ld      d,$80
    ld      hl,MEM_ZX_SCREEN_4000+1*32+CHARPOS_ENCODING-1
    call    .DoAllEightPixelLinesUlaFill
    ld      bc,$0117
    ld      d,$01
    ld      hl,MEM_ZX_SCREEN_4000+1*32+31
    call    .DoAllEightPixelLinesUlaFill
    ld      bc,$7 + ((33-CHARPOS_ENCODING)<<8)
    ld      d,A_BRIGHT|P_YELLOW|BLACK
    ld      hl,MEM_ZX_ATTRIB_5800+1*32+CHARPOS_ENCODING-1
    call    FillSomeUlaLines
    ld      c,8
    ld      hl,MEM_ZX_ATTRIB_5800+8*32+CHARPOS_ENCODING-1
    call    FillSomeUlaLines
    ld      c,8
    ld      hl,MEM_ZX_ATTRIB_5800+16*32+CHARPOS_ENCODING-1
    call    FillSomeUlaLines
    ld      d,$FF
    ld      c,1
    ld      hl,MEM_ZX_SCREEN_4000+1*32+CHARPOS_ENCODING-1
    call    FillSomeUlaLines
    ld      c,1
    ld      hl,MEM_ZX_SCREEN_4000+192*32-1*32+CHARPOS_ENCODING-1
    call    FillSomeUlaLines
    ; show log item content, DE = VRAM position of new line
    ld      de,MEM_ZX_SCREEN_4000+2*32+CHARPOS_ENCODING
    ld      a,(ix+2)
.ShowAllLogItems:
    push    af
    call    LogGetItemAddress   ; IY = first log item
    ; get amount of bytes and word and see if message was added to the item
    ld      a,(iy+LOG_ITEM_TYPE)
    cp      LOG_TYPE_EMPTY      ; verify it is not the special "empty" type
    jp      z,.SkipItem
    and     (LOG_TYPE_B_CNT_MASK|LOG_TYPE_W_CNT_MASK)
    ld      c,a
    .(LOG_TYPE_W_SHIFT) srl c   ; c = words count (3x srl)
    and     LOG_TYPE_B_CNT_MASK
    ld      b,a                 ; b = bytes count
    ; check if the item contains also text message
    rra     ; CF was 0 from AND
    add     a,c                 ; amount of total words occupied
    cp      3
    jr      nc,.NoMessage       ; 3+ words occupied makes message impossible
    ld      l,(iy+LOG_ITEM_W2)  ; hl = w2
    ld      h,(iy+LOG_ITEM_W2+1)
    ld      a,l
    or      h
    jr      z,.NoMessage        ; w2 != nullptr if message is added
    ; display message - wrap it first
    push    ix
    push    de
    push    bc
    ld      de,MEM_LOG_TXT_BUFFER
    jr      .WrapNewLineContinue
.WrapNewLine:   ; insert end of substring
    xor     a
    ld      (de),a
    inc     de
.WrapNewLineContinue:
    ; skip spaces starting new line
    dec     hl
    ld      a,' '
.SkipStartingSpace:
    inc     hl
    cp      (hl)
    jr      z,.SkipStartingSpace
    ; copy N character into new substring
    ld      bc,(31-CHARPOS_ENCODING)<<8 ; C = 0 (chars since last good spot to wrap)
.BuildSubstringLoop:
    ld      a,(hl)
    ld      (de),a
    or      a                   ; check for end of the string
    jr      z,.WholeStringWrapped
    ; see if there's good spot to wrap at this char
    inc     c                   ; update wrap counter (chars added to substring)
    cp      '@'
    jr      nc,.DoNotWrapHere
    cp      ':'
    jr      nc,.DoWrapHere
    cp      '0'
    jr      nc,.DoNotWrapHere
    cp      ')'
    jr      nc,.DoWrapHere
    cp      '"'
    jr      nc,.DoNotWrapHere
.DoWrapHere:
    ld      c,0                 ; this is good spot to wrap, remember it
.DoNotWrapHere:
    inc     hl
    inc     de
    djnz    .BuildSubstringLoop
    ; run out of space on current line, see if also end of string was reached
    xor     a
    cp      (hl)
    jr      z,.WholeStringWrapped
    ; check if the old line did end well wrapped
    cp      c
    jr      z,.WrapNewLine
    ; there's more of the string to print, wrap it reasonably
    ld      a,31-CHARPOS_ENCODING
    cp      c                   ; CF=0
    jr      z,.WrapNewLine      ; there was no good spot to wrap, just keep it as is
    ; return C chars back and start again on new line
    ex      de,hl
    sbc     hl,bc               ; revert DE (CF=0 from `cp c`), B=0 from DJNZ, CF=0 again
    ex      de,hl
    sbc     hl,bc               ; revert HL
    jr      .WrapNewLine
.WholeStringWrapped:
    inc     de
    ld      (de),a              ; add empty string at the very end
    pop     bc
    pop     de
    pop     ix
    ; display all sub-messages produced by wrapping
    ld      hl,MEM_LOG_TXT_BUFFER
.PrintAllSubstrings:
    call    OutStringAtDe
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    ld      a,(hl)
    or      a
    jr      nz,.PrintAllSubstrings
.NoMessage:
    ; display bytes
    ld      (OutCurrentAdr),de  ; set VRAM position for Out...
    push    iy
    pop     hl
    inc     hl                  ; HL=iy+LOG_ITEM_B0
    xor     a
    cp      b
    jr      z,.NoBytesToDisplay
.DisplayBytes:
    ld      a,(hl)
    inc     hl
    call    OutHexaValue
    ld      a,' '
    call    OutChar
    djnz    .DisplayBytes
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
.NoBytesToDisplay:
    ; display words on new line
    ld      b,c
    ld      (OutCurrentAdr),de  ; set VRAM position for Out...
    xor     a
    cp      b
    jr      z,.SkipItem         ; no words to display
    ; align HL so it points to the next word element
    bit     0,l
    jr      z,.DisplayWords     ; HL is already aligned
    inc     hl
.DisplayWords:
    ld      c,(hl)
    inc     hl
    ld      a,(hl)
    inc     hl
    call    OutHexaValue
    ld      a,c
    call    OutHexaValue
    ld      a,' '
    call    OutChar
    djnz    .DisplayWords
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    ; next log item
.SkipItem:
    pop     af
    inc     a                   ; index of next log item
    ; check if the shown item was last in chain, and loop if not
    bit     LOG_TYPE_LAST_BIT,(iy+LOG_ITEM_TYPE)
    jp      z,.ShowAllLogItems
    ; display "press any key" at bottom of log window
    ld      de,MEM_ZX_SCREEN_4000+(128+6)*32+CHARPOS_ENCODING+1
    ld      hl,.PressAnyKeyTxt
    call    OutStringAtDe
    ret
.DoAllEightPixelLinesUlaFill:
    push    hl
    push    bc
    call    FillSomeUlaLines
    pop     bc
    pop     hl
    inc     h
    ld      a,h
    and     7
    jr      nz,.DoAllEightPixelLinesUlaFill
    ret
.PressAnyKeyTxt:
    db      'Press any key.',0
