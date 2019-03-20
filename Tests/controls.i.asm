    MACRO REGISTER_KEY keyCode?, handlerAddress?
        ld      a,keyCode?
        ld      de,handlerAddress?
        call    RegisterKeyhandler
    ENDM

KEY_NONE    equ     $FF
KEY_CAPS    equ     0
KEY_Z       equ     1
KEY_X       equ     2
KEY_C       equ     3
KEY_V       equ     4
KEY_A       equ     5
KEY_S       equ     6
KEY_D       equ     7
KEY_F       equ     8
KEY_G       equ     9
KEY_Q       equ     10
KEY_W       equ     11
KEY_E       equ     12
KEY_R       equ     13
KEY_T       equ     14
KEY_1       equ     15
KEY_2       equ     16
KEY_3       equ     17
KEY_4       equ     18
KEY_5       equ     19
KEY_0       equ     20
KEY_9       equ     21
KEY_8       equ     22
KEY_7       equ     23
KEY_6       equ     24
KEY_P       equ     25
KEY_O       equ     26
KEY_I       equ     27
KEY_U       equ     28
KEY_Y       equ     29
KEY_ENTER   equ     30
KEY_L       equ     31
KEY_K       equ     32
KEY_J       equ     33
KEY_H       equ     34
KEY_SPACE   equ     35
KEY_SYMBOL  equ     36
KEY_M       equ     37
KEY_N       equ     38
KEY_B       equ     39
TOTAL_KEYS  equ     40

debounceState:
    db      0

registeredHandlers:
    ds      2*TOTAL_KEYS, 0

; A = key-code (KEY_xx defines), DE = address of key handler
; handler will receive keycode in DE (and HL = handler addres)
RegisterKeyhandler:
    cp      TOTAL_KEYS      ; check if A is valid 0..39 key-code
    ret     nc
    ; calculate address in handler table
    push    bc
    push    hl
    add     a,a
    ld      c,a
    ld      b,0
    ld      hl,registeredHandlers
    add     hl,bc
    ; store the handler pointer into table
    ld      (hl),e
    inc     hl
    ld      (hl),d
    pop     hl
    pop     bc
    ret

RefreshKeyboardState:   ; modifies everything
    ; get current debounce state, and decrement it (plus clamp it to 0)
    ld      a,(debounceState)
    sub     1
    adc     a,0
    ld      d,a         ; D is current debounce
    ld      hl,(KEY_NONE<<8) + 0    ; H = no key, L = first key (counter)
    ld      bc,ULA_P_FE + ($FE<<8)
.testEightRows:
    in      a,(c)
    call    .testFiveKeysInA
    rlc     b           ; next keyboard row
    jr      c,.testEightRows
    ld      a,d
    ld      (debounceState),a
    ; process pressed key (single-key only)
    ld      a,h
    cp      KEY_NONE
    ret     z
    ld      e,a         ; DE = keycode (KEY_xxx defines)
    ld      d,0
    ; look if some handler is hooked for this key
    ld      hl,registeredHandlers
    add     hl,de
    add     hl,de
    ld      a,(hl)
    inc     hl
    ld      h,(hl)
    ld      l,a
    or      h
    ret     z           ; nullptr there, no handler
    ; run the hooked key handler (with DE = keycode)
    jp      hl

.testFiveKeysInA:
    call    .testKeyInA
    call    .testTwoKeysInA
.testTwoKeysInA:
    call    .testKeyInA
.testKeyInA:
    rra
    push    af
    call    nc,.keyPressed
    pop     af
    inc     l
    ret

.keyPressed:
    ld      a,d
    ld      d,50        ; on key press reset debounce to some short while
    or      a
    ret     nz
    ld      h,l         ; remember the pressed key
    ret

; waits for any key
WaitForAnyKey:
    call    .readAllKeys
    jr      nz,WaitForAnyKey
.WaitForSomeKeyPress:
    call    .readAllKeys
    jr      z,.WaitForSomeKeyPress
.WaitForAllReleased:
    call    .readAllKeys
    jr      nz,.WaitForAllReleased
    ; set some debounce
    ld      a,20
    ld      (debounceState),a
    ret
.readAllKeys:
    xor     a           ; read all rows in single IN
    in      a,(ULA_P_FE)
    and     $1F
    xor     $1F         ; flip the bits: 0 = no press, 1 = key pressed (and sets ZF)
    ret
