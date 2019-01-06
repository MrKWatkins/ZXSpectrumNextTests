; Output routines - written in simple way and using only Z80 instructions (NO Z80N!)
; Routines depends on:
; - ZX48 ROM character map ($3D00..3FFF must be mapped in memory)
; - ZX48 ULA screen being at $4000 (classic ZX Spectrum 256x192 mode with attributes)
; - Z80 CPU (Z80N is NOT required)
; This is intentionally written in trivial way with minimal dependencies - in case you
; are emulator author, once your emulator fits the dependencies mentioned above, you
; may get visible output from base/* tests - if the test itself gets as far as output :)

; list of API functions (see their definition for arguments and details):
; * AdvanceVramHlByAChars           - HL += A chars, adjusts for VRAM thirds
; * AdvanceVramHlToNextChar         - HL += 1 char, adjusts for VRAM thirds
; * AdvanceVramHlToNextLine         - HL += 32 chars (next line), adjusts for VRAM thirds
; * AdvanceAttrHlToNextLine         - HL += 32
; * OutChar                         - output char A at VRAM (OutCurrentAdr)++
; * OutString                       - output zero-terminated string (HL) at OutCurrentAdr
; * OutStringAtDe                   - as OutString, but sets OutCurrentAdr to DE first
; * FillSomeUlaLines                - Fills C char-lines with pattern D (B columns only)
; * Draw16x16GridWithHexaLabels     - draws huge 16x16 char-grid in top-left corner

; VRAM address to output next char (string) at (keep it at first line of 8x8 grid!)
OutCurrentAdr:      dw      $4000   ; by default start at top left corner

; as AdvanceVramHlByAChars, but advances by +1 char
AdvanceVramHlToNextChar:
    ld      a,1
    ; continue with "AdvanceVramHlByAChars" subroutine code directly...

; advances HL by offset A as ULA VRAM line address, handling thirds of screen adjust
; (works reliably only for reasonable HL and A combinations, like +1..+32, etc.)
; modified: A (and HL obviously)
AdvanceVramHlByAChars:
    add     a,l             ; advance by offset A (when wraps within third, CF=1)
    ld      l,a
    ret     nc
    ld      a,8             ; VRAM third crossed, advance also H by 8 (next VRAM third)
    add     a,h
    ld      h,a
    ret

; as AdvanceVramHlByAChars, but advances by +32 chars (= new line)
AdvanceVramHlToNextLine:
    ld      a,32
    jr      AdvanceVramHlByAChars

; advances HL by 32 (works as "next line" in ZX attributes VRAM area)
; modifies: A and HL
AdvanceAttrHlToNextLine:
    ld      a,32
    add     a,l
    ld      l,a
    ret     nc
    inc     h
    ret

; A = ASCII char to output, output is done by XOR (!) mode, to "OutCurrentAdr" cell
OutChar:
    push    af
    push    hl
    push    de
    push    bc
    ; calculate ROM data address of ASCII code in A into DE
    ld      h,MEM_ROM_CHARS_3C00/(8*256)
    add     a,$80
    ld      l,a     ; hl = $780+A (for A=0..127) (for A=128..255 result is undefined)
    add     hl,hl
    add     hl,hl
    add     hl,hl   ; hl *= 8
    ex      de,hl   ; de = Address of character in ROM (8*($780+A)) = $3D00 for <space>
    ; output char to the VRAM
    ld      hl,(OutCurrentAdr)      ; hl = VRAM address to output next char
    push    hl
    ld      b,8
.CharLoop:
    ld      a,(de)
    inc     de
    xor     (hl)
    ld      (hl),a
    inc     h
    djnz    .CharLoop
    ; increment char position by one to right
    pop     hl                      ; hl = VRAM address to output next char
    call    AdvanceVramHlToNextChar
    ld      (OutCurrentAdr),hl      ; store new "next char at" VRAM address
    pop     bc
    pop     de
    pop     hl
    pop     af
    ret

; output zero terminated string from HL address into VRAM at DE (HL points after zero)
OutStringAtDe:
    ld      (OutCurrentAdr),de
    ; continue with "OutString" subroutine code directly...

; output zero terminated string from HL address (HL points after the zero at end)
; modifies: AF, HL
OutString:
    ld      a,(hl)
    inc     hl
    or      a
    ret     z
    call    OutChar
    jr      OutString

; Will fill C vram-char-lines (8px high), on each line B columns are set to D starting
; at HL address. The routine will advance also over thirds of VRAM. HL may start also
; in the middle of particular line (each next line will start at same indentation).
; This works also for attributes!
; D = byte to fill with (pixel pattern), B = columns per line, C = lines, HL = VRAM adr
; modifies: A, C, HL
FillSomeUlaLines:
    push    bc
.FillPartOfOneLine:         ; fill B chars on current line
    ld      (hl),d
    inc     l
    djnz    .FillPartOfOneLine
    pop     bc
    ; next line address
    ld      a,32
    sub     b
    call    AdvanceVramHlByAChars
    ; repeat until all lines are filled
    dec     c
    jr      nz,FillSomeUlaLines
    ret

; Draws big 16x16 chars grid with hexa labels, the grid lines overwrite VRAM, the labels
; are XOR-ed into screen = works best when screen is clear (no parametrization of this).
; modifies: AF, BC, DE, HL, (OutCurrentAdr), targets top-left corner of screen
Draw16x16GridWithHexaLabels:
    ; draw grid lines first, draw column lines
    ld      hl,$4000        ; top line of first character
    ld      de,$8004        ; fill pattern $80 (D), 4 = loop counter (E)
.GridLeftLines:             ; draw 4 dots per every char (dotted vertical grid line)
    push    hl
    ld      bc,$1111        ; 17 columns (B), 17 lines (C)
    call    FillSomeUlaLines
    pop     hl
    inc     h
    inc     h               ; +2 lines for next dot
    dec     e
    jr      nz,.GridLeftLines
    ; row lines
    dec     h               ; hl = $4700 (bottom line of first character)
    ld      d,$55           ; dot-line pattern
    ld      bc,$1210        ; 18 columns (B), 16 lines (C)
    call    FillSomeUlaLines
    ; output bottom side labels (column labels)
    ld      de,$5000
    ld      hl,.StrLine1
    call    OutStringAtDe
    ; output right side labels (row labels)
    ld      de,$4010
    ld      bc,.StrLine1    ; source of 0,1,2,... chars
.YLinesLabels:
    ; fetch character 0,1,...,F (they are zero terminated)
    ld      a,(bc)
    or      a
    ret     z               ; when zero terminator is hit, finish
    inc     bc
    ; modify line-label text in memory and output it
    ld      hl,.StrYLines
    ld      (hl),a
    call    OutStringAtDe
    ; do "newline" on target address
    ex      de,hl
    call    AdvanceVramHlToNextLine
    ex      de,hl
    jr      .YLinesLabels

.StrLine1:  db  "0123456789ABCDEF",0
.StrYLines: db  "xx",0
