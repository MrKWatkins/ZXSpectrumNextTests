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
; * GetRomAddressOfChar             - HL = ROM char gfx address of A
; * OutChar                         - output char A at VRAM (OutCurrentAdr)++
; * OutL2Char                       - output char A at DE with colour C in Layer2 way
; * OutL2CharIn3ColsAndAdvanceE     - output char A at DE (3 colours), advance E += 8
; * OutHexaDigit                    - output value A[3:0] as hexa-digit at OutCurrentAdr
; * OutHexaValue                    - output value A as two hexa-digits at OutCurrentAdr
; * OutDecimalValue                 - output value A as one-three decimal digits at OutC..
; * OutString                       - output zero-terminated string (HL) at OutCurrentAdr
; * OutStringAtDe                   - as OutString, but sets OutCurrentAdr to DE first
; * OutL2StringIn3ColsAtDE          - output zero-terminated string (HL) at DE for Layer2
; * OutL2StringsIn3Cols             - output multiple zero-terminated strings for Layer2
; * OutMachineIdAndCore             - output MachineID and core version at DE into ULA
; * OutMachineIdAndCore_defLabels   - as previous, but with default labels
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

; A = ASCII char (0..127), will calculate into HL address of char data ($3D00 for space)
; for A==7 ("bell") full-square data are used from this code (even without ROM mapped)
GetRomAddressOfChar:
    cp      7
    jr      z,.returnFullSquareForBellCharacter
    ld      h,MEM_ROM_CHARS_3C00/(8*256)
    add     a,$80
    ld      l,a     ; hl = $780+A (for A=0..127) (for A=128..255 result is undefined)
    add     hl,hl
    add     hl,hl
    add     hl,hl   ; hl *= 8
    ret
.returnFullSquareForBellCharacter:
    ld      hl,.FakeFullSquare
    ret
.FakeFullSquare:
    db      $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; A = ASCII char to output, output is done by XOR (!) mode, to "OutCurrentAdr" cell
OutChar:
    push    af
    push    hl
    push    de
    push    bc
    ; calculate ROM data address of ASCII code in A into DE
    call    GetRomAddressOfChar
.withCustomGfxData:
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

; A = ASCII char, C = Layer2 colour, DE = target VRAM address
OutL2Char:
    push    af
    push    hl
    push    de
    push    bc
    ; calculate ROM data address of ASCII code in A into DE
    call    GetRomAddressOfChar
    ex      de,hl   ; HL = VRAM target address, DE = ROM charmap with letter data
    ; output char to the VRAM
    ld      b,8
.LinesLoop:
    ld      a,(de)
    push    hl
.PixelLoop:
    sla     a
    jr      nc,.SkipDotFill
    ld      (hl),c
.SkipDotFill:
    inc     hl      ; inc HL to keep ZF from `SLA A`
    jr      nz,.PixelLoop
    pop     hl
    inc     h
    inc     e
    djnz    .LinesLoop
    pop     bc
    pop     de
    pop     hl
    pop     af
    ret

; A = ASCII char, DE = target VRAM address
; B = text colour, C = soft-shadow colour (C+1 must be hard-shadow colour)
; modifies: A, DE
OutL2CharIn3ColsAndAdvanceE:
    push    bc
    inc     e
    call    OutL2Char
    dec     e
    inc     d
    call    OutL2Char
    inc     c           ; C = hard-shadow colour
    inc     e
    call    OutL2Char
    ld      c,b         ; C = text colour
    dec     d
    dec     e
    call    OutL2Char
    ; increment char position by one to right
    ld      a,8
    add     a,e
    ld      e,a
    pop     bc
    ret

; output value in A[3:0] as hexa-digit at "OutCurrentAdr", modifies OutCurrentAdr
OutHexaDigit:
    push    af
    ; convert 0..15 value in A to ASCII character for hexa-digit
    or      $F0             ; nifty trick from:
    daa                     ; http://map.grauw.nl/sources/external/z80bits.html
    add     a,$A0
    adc     a,$40
    call    OutChar
    pop     af
    ret

; output value in A as two hexa-digits (without any prefix/suffix), at "OutCurrentAdr"
; modifies OutCurrentAdr and flags only (A is preserved)
OutHexaValue:
    call    .OutFourBits
.OutFourBits:
    ; swap nibbles (by Z80 instructions only, for "base" tests usage)
    rrca
    rrca
    rrca
    rrca
    call    OutHexaDigit
    ret

; output value in A as one to three 0-9 characters at "OutCurrentAdr"
; this is naive subtraction-loop implementation just to get the result, not fast/smart
; modifies OutCurrentAdr and AF
OutDecimalValue:
    push    de
    push    bc
    ld      e,0
    ld      bc,$FF00 | 100          ; b = -1, c = 100
    call    .FindDecimalDigit
    call    .OutDecDigitIfNonZero
    ld      a,c
    ld      bc,$FF00 | 10           ; b = -1, c = 10
    call    .FindDecimalDigit
    call    .OutDecDigitIfNonZero
    ; output final digit (even zero)
    ld      a,c
    pop     bc
    pop     de
    jr      .OutDecDigit
.FindDecimalDigit:
    inc     b
    sub     c       ; if A is less than current 10th power, CF will be set
    jr      nc,.FindDecimalDigit
    add     c       ; fix A back above zero (B is OK, as it started at -1)
    ret
.OutDecDigitIfNonZero:
    ld      c,a
    ld      a,b
    or      e       ; test also against previously displayed digits, to catch any non-zero
    ld      e,a     ; remember the new mix
    ret     z
    ld      a,b
.OutDecDigit:
    add     a,'0'
    jp      OutChar

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

; HL = ASCIIZ string, DE = target VRAM address
; B = text colour, C = soft-shadow colour (C+1 must be hard-shadow colour)
; modifies: AF, DE, HL
OutL2StringIn3ColsAtDE:
    ld      a,(hl)
    inc     hl
    or      a
    ret     z
    call    OutL2CharIn3ColsAndAdvanceE
    jr      OutL2StringIn3ColsAtDE

; HL = byte stream of: X-pos, Y-pos, ASCIIZ string, terminated by X-pos==$FF
; B = text colour, C = soft-shadow colour (C+1 must be hard-shadow colour)
; modifies: AF, HL
OutL2StringsIn3Cols:
    push    de
.stringsLoop:
    ; x-pos ($FF = end)
    ld      e,(hl)
    inc     hl
    ; test for $FF
    inc     e
    jr      z,.finish
    dec     e
    ; y-pos
    ld      d,(hl)
    inc     hl
    call    OutL2StringIn3ColsAtDE
    jr      .stringsLoop
.finish:
    pop     de
    ret

; DE = VRAM address for machineID output (will take strlen(label) + two chars for "10")
; BC = VRAM address for core output (strlen(core) + 6 + 0..3 characters)
; does modify: HL, OutCurrentAdr, AF
OutMachineIdAndCore_defLabels:
    ld      hl,OutMachineIdAndCoreDefaultLabels
    ; continue with OutMachineIdAndCore code

; HL = two C-strings with labels for MachineID and Core (use "db 0, 0" for no labels)
; DE = VRAM address for machineID output (will take strlen(label) + two chars for "10")
; BC = VRAM address for core output (strlen(core) + 6 + 0..3 characters)
; if (IX == $ED01), then extended info is outputted after MachineID
; does modify: HL, OutCurrentAdr, AF
OutMachineIdAndCore:
    call    OutStringAtDe
    NEXTREG2A MACHINE_ID_NR_00  ; NEXTREG2A is defined in TestFunctions.asm, which should
                                ; be included by this point already (include Output after)
    call    OutDecimalValue     ; output machineID (one to three chars, usually 10 or 8)

    ; check if extended info is requested
    push    ix
    pop     de
    ld      a,d
    cp      $ED
    jr      nz,.NoExtendedMachineInfo
    dec     e                   ; only "1" extra info currently recognized
    jr      nz,.NoExtendedMachineInfo
    ld      a,' '
    call    OutChar
    ld      a,'['
    call    OutChar
    NEXTREG2A MACHINE_TYPE_NR_03
    call    OutHexaValue
    ld      a,':'
    call    OutChar
    NEXTREG2A PERIPHERAL_1_NR_05
    call    OutHexaValue
    ld      a,':'
    call    OutChar
    NEXTREG2A PERIPHERAL_2_NR_06
    call    OutHexaValue
    ld      a,':'
    call    OutChar
    NEXTREG2A PERIPHERAL_3_NR_08
    call    OutHexaValue
    ld      a,']'
    call    OutChar

.NoExtendedMachineInfo:
    ld      d,b
    ld      e,c
    call    OutStringAtDe       ; HL points to "core" label now
    ; output major core version number
    NEXTREG2A NEXT_VERSION_NR_01
    push    af
    rrca
    rrca
    rrca
    rrca
    and     $0F
    call    OutDecimalValue
    ld      a,'.'
    call    OutChar
    ; output minor core version number
    pop     af
    and     $0F
    cp      10
    ; output values 0..9 as "HexaValue" so there will be leading zero
    push    af
    call    c,OutHexaValue
    pop     af                  ; restore CF after OutHexaValue call (if it happened)
    call    nc,OutDecimalValue  ; values over 10 print as decimal
    ld      a,'.'
    call    OutChar
    ; output sub-minor core version number
    NEXTREG2A NEXT_VERSION_MINOR_NR_0E
    call    OutDecimalValue
    ret

OutMachineIdAndCoreDefaultLabels:
    db      "machineID:",0
    db      "core:",0

; Will fill C vram-char-lines (8px high), on each line B columns are set to D starting
; at HL address. The routine will advance also over thirds of VRAM. HL may start also
; in the middle of particular line (each next line will start at same indentation).
; This works also for attributes!
; D = byte to fill with (pixel pattern), B = columns per line, C = lines, HL = VRAM adr
; modifies: A, C, HL
FillSomeUlaLines:
    push    hl
    push    bc
.FillPartOfOneLine:         ; fill B chars on current line
    ld      (hl),d
    inc     l
    djnz    .FillPartOfOneLine
    pop     bc
    pop     hl
    ; next line address
    call    AdvanceVramHlToNextLine
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
    ld      hl,$5000        ; set up target address
    ld      (OutCurrentAdr),hl
    ld      a,$F0
.ColumnLabels:
    call    OutHexaDigit
    inc     a
    jr      nz,.ColumnLabels
    ; output right side labels (row labels)
    ld      hl,$4010
    ld      a,$F0
.YLinesLabels:
    ld      (OutCurrentAdr),hl
    call    OutHexaDigit    ; output hexa digit
    push    af
    ld      a,'x'           ; followed by "x" char to form "4x" string
    call    OutChar
    call    AdvanceVramHlToNextLine ; do it while AF is on stack
    pop     af
    inc     a
    jr      nz,.YLinesLabels
    ret
