; test of syntax highlight (unfortunately what is highlighted does not make it correct
; in every Z80 assembler, so use proper syntax according to your target assembler)
    device zxspectrum48     ; directive of sjasmplus
    org     $A800           ; hexa, also: 0xA800, 0A800h
    pcorg   43008           ; decimal (forgot to add 33d, but who uses *that*?)
    opt     some snasm directive (option gets colour of label, like this text)
With relaxed syntax of Z80 assemblers, "label" is pretty much "default" result

    ld      hl, %1001110000111111   ; binary, also: 0011b
    ld      de, ?7777       ; octal, also: 77o 77q
    ld      bc, %1111_0000  ; wishful thinking for num-group separator (C++ now has it)
    db      'apostrophe "text"', "quotes 'text'", 0
    ldirx
    bsra    de,b            ; NEXT opcodes of course added (can have different colour)
    cp      a,'a'           ;"TODO" in comments exists (also FIXME and FIX ME).
s:  ; some label
// also C line comments supported
    call    s, s            ; conditional call/jp/jr/ret highlights also condition
        ; "s" is actually unofficial alias for "m" supported by some assembler ("ns"=p)
    ret     nz              ; control-flow instructions are extra colour
    rlc     (ix-128),e      ; unofficial Z80 instructions are highlighted extra
    res     5,(ix+6),a      ; ruining the argument highlighting in this version (FIXME?)
    res     5,(ix+30)       ; compared to official instruction

    and     a, 7+(3<<1)
    and     lo(.localLabel) ; FIXME: operators are mostly defined, but rules are missing

MACRO leMacron
    defb    $DD, 1
    nextreg $15, $0
ENDM

    ; in case you accidentally write non-instruction, it will highlight as label! :D
    jnz     s               ; still makes it lot more easier to catch
    leMacron                ; but so do also correctly used macros
.localLabel
    hex     F32712bcd3561   ; unpaired digit or non-digit is highlighted as "error"
!alsoThis   jp  @andThat

    include "../zx/Constants.asm"   ; includes are NOT parsed = weak auto-completition :/

; still quite happy how very first version turned out. Ok, line 42 is final answer, bye.