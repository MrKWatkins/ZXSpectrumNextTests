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
    ldirx
    bsra    de,b            ; NEXT opcodes of course added
    cp      a,'a'
s:  ; some label
// also C line comments supported
    call    s, s            ; conditional call/jp/jr/ret highlights also condition
         ; "s" is actually unofficial alias for "m" supported by some assembler ("ns"=p)
    ret     nz

    and     a, 7+(3<<1)
    and     lo(.localLabel) ; operators are defined, but rules to pick them are missing

MACRO leMacron
    defb    $DD
    db      1
    nextreg $15, $0
ENDM

    ; in case you accidentally write non-instruction, it will highlight as label! :D
    jnz     s               ; still makes it lot more easier to catch
    leMacron                ; but so do also correctly used macros

.localLabel
    hex     F32712bcd3561   ; unpaired digit is not hexa-colour
    hex     50d             ; but "d" is then highlighted as "register" in this case
!alsoThis   jp  @andThat

    include "../zx/Constants.asm"   ; includes are NOT parsed = weak auto-completition :/

; still quite happy how very first version turned out. Ok, line 42 is final answer, bye.