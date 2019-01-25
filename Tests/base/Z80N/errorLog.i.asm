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
LOG_TYPE_LAST       equ     $20     ; item is last in the chain for one test
LOG_TYPE_W_SHIFT    equ     3       ; how many bits to shift for word-count

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
    ; clear W2 of newly allocated log item ("no msg")
    ld      (iy+LOG_ITEM_W2),0
    ld      (iy+LOG_ITEM_W2+1),0
    ; return with ZF=1 and index of new item
    cp      a
    ret
.logIsFull:
    ; return with ZF=0 (A == 0, because that's how I got here)
    cp      1
    ret

; adds new log item with one 8b value in B
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd1B:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),1    ; byte count = 1, word count = 0
    ld      (iy+LOG_ITEM_B0),b
    ret

; adds new log item with two 8b values, first in B, second in C
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd2B:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),2    ; byte count = 2, word count = 0
    ld      (iy+LOG_ITEM_B0),b
    ld      (iy+LOG_ITEM_W0),c
    ret

; adds new log item with two 8b values, first in B, second in C and one 16b in DE
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd2B1W:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),(1<<LOG_TYPE_W_SHIFT)+2  ; byte count = 2, word count = 1
    ld      (iy+LOG_ITEM_B0),b
    ld      (iy+LOG_ITEM_W0),c
    ld      (iy+LOG_ITEM_W1+1),d
    ld      (iy+LOG_ITEM_W1),e
    ret

; adds new log item with one 16b value in DE
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd1W:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),1<<LOG_TYPE_W_SHIFT  ; byte count = 0, word count = 1
    ld      (iy+LOG_ITEM_W0+1),d
    ld      (iy+LOG_ITEM_W0),e
    ret

; adds new log item with two 16b values, first in DE, second in HL
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd2W:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),2<<LOG_TYPE_W_SHIFT  ; byte count = 0, word count = 2
    ld      (iy+LOG_ITEM_W0+1),d
    ld      (iy+LOG_ITEM_W0),e
    ld      (iy+LOG_ITEM_W1+1),h
    ld      (iy+LOG_ITEM_W1),l
    ret

; adds new log item with one 8b, two 16b values, 8b in B, first word in DE, second in HL
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd1B2W:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),(2<<LOG_TYPE_W_SHIFT)+1  ; byte count = 1, word count = 2
    ld      (iy+LOG_ITEM_B0),b
    ld      (iy+LOG_ITEM_W0+1),d
    ld      (iy+LOG_ITEM_W0),e
    ld      (iy+LOG_ITEM_W1+1),h
    ld      (iy+LOG_ITEM_W1),l
    ret

; adds new log item with three 16b values, first word in DE, second in HL, third in BC
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAdd3W:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),3<<LOG_TYPE_W_SHIFT    ; byte count = 0, word count = 3
    ld      (iy+LOG_ITEM_W0+1),d
    ld      (iy+LOG_ITEM_W0),e
    ld      (iy+LOG_ITEM_W1+1),h
    ld      (iy+LOG_ITEM_W1),l
    ld      (iy+LOG_ITEM_W2+1),b
    ld      (iy+LOG_ITEM_W2),c
    ret

; adds new log item with msg in IX
; ZF=1: returns in A the index of new log item (and IY = address of item)
; ZF=0 => log is full (no item added)
LogAddMsg:
    call    LogAllocateNewItem      ; IY = new log item address, A = log index
    ret     nz      ; log is full
    ld      (iy+LOG_ITEM_TYPE),0    ; byte count = 0, word count = 0
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
