    device zxspectrum48,$7FFF

    org     $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"

LegendText:
    db      'Copper draws Swedish flags',0
    db      'by PAPER/BORDER 7 colour change.',0
    db      'Flags 16x10 at: [1,64] below ...',0
    db      '[242,118] above ... and more :)',0

CopperBytesTxt:
    db      'Copper ins. (max 0400):   ',0
CopperBytesTxt2:
    db      'Read back from registers: ',0

FlagData:
    db      %00000110,%00000000     ; 5:2:9 - blue, yellow, blue
    db      %00000110,%00000000
    db      %00000110,%00000000
    db      %00000110,%00000000
    db      %11111111,%11111111     ; lines are 4:2:4, middle is full yellow
    db      %11111111,%11111111
    db      %00000110,%00000000
    db      %00000110,%00000000
    db      %00000110,%00000000
    db      %00000110,%00000000

    ; 8 bit colour definitions
C_BLACK     equ     $00
C_WHITE     equ     $B6
C_BLUE      equ     $0E
C_YELLOW    equ     $F8
C_WHITE_BR  equ     $DB

animateLineCopperAdr:
    dw      0

    ; does use A and B registers (A stays set to value)
    MACRO   NEXTREG register?, value?
        ; implemented by Z80 instructions only, and using I/O port (intentionally)
        ld      b,register?
        ld      a,value?
        call    WriteNextRegByIo
    ENDM

Start:
    call    StartTest

    ; show MachineID and core version
    ld      de,MEM_ZX_SCREEN_4000
    ld      bc,MEM_ZX_SCREEN_4000+1*32
    ld      ix,$ED01        ; display also extended info after MachineId
    call    OutMachineIdAndCore_defLabels

        ;                           03:05:06:08
        ; David's board 18.1.:      33:43:C8:38

    ld      hl,LegendText
    ld      de,MEM_ZX_SCREEN_4000+2*32
    call    OutStringAtDe
    ld      de,MEM_ZX_SCREEN_4000+3*32
    call    OutStringAtDe
    ld      de,MEM_ZX_SCREEN_4000+5*32
    call    OutStringAtDe
    ld      de,MEM_ZX_SCREEN_4000+6*32
    call    OutStringAtDe

    ; Draw dots for "rulers" to judge Copper precision
    ld      bc,$0801
    ld      hl,MEM_ZX_SCREEN_4000+8*256-32      ; ABOVE beginning of second VRAM third
    ld      d,$88
    call    FillSomeUlaLines
    ld      bc,$0801
    ld      hl,MEM_ZX_SCREEN_4000+16*256+32-8   ; BELOW end of second VRAM third
    call    FillSomeUlaLines

    ; set up ULANext mode and reset palette (BORDER is already 7 from StartTest)
    ; auto-increment OFF, select first ULA palette, UlaNext ON
    NEXTREG PALETTE_CONTROL_NR_43, %10000001
    ; INK-mask 7 (will turn default attribute $38 into PAPER 7: INK 0)
    NEXTREG PALETTE_FORMAT_NR_42, %00000111
    ; INK 0 - black
    NEXTREG PALETTE_INDEX_NR_40, 0
    NEXTREG PALETTE_VALUE_NR_41, C_BLACK
    ; PAPER/BORDER 7 = ULA.white
    NEXTREG PALETTE_INDEX_NR_40, 128+7      ; index PAPER 7
    NEXTREG PALETTE_VALUE_NR_41, C_WHITE

    ; PALETTE_INDEX_NR_40 is still set to 128+7 (!)
    ; and should stay that way for whole test (if auto-increment OFF works)

    ; set up Copper control to "stop" + index 0 (STOP first, but should not matter)
    NEXTREG COPPER_CONTROL_HI_NR_62, 0      ; full stop + index zero
    NEXTREG COPPER_CONTROL_LO_NR_61, 0

    ; set up Copper data - set the TBBlue I/O port to COPPER_DATA_NR_60
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    ld      a,COPPER_DATA_NR_60
    out     (c),a
    inc     b           ; BC = TBBLUE_REGISTER_ACCESS_P_253B

    ; total instructions counter (should be not more than 1024!)
    push    iy
    ld      iy,0        ; count total instructions

    ; now fill up the flag-drawing instructions (5 flags ~= 990 instructions (!))
    ld      de,$0140    ; [1,64]    ; this one should be +1px off from ruler to right
    call    UploadFlagAtDe
    ld      de,$424D    ; [66,77]   ; move this to 66 in case you need to release few ins.
    call    UploadFlagAtDe
    ; do one flag partly over right border
    ld      de,$F85B    ; [248,91]
    call    UploadFlagAtDe
    ; do one flag over left border (skip DE coordinates calculation)
    ld      h,COPPER_WAIT_H + ($34<<1)    ; x-compare 52 = 416px pos = somewhere in left border
    ld      l,1         ; don't do NOOP after wait at all
    ld      e,$68       ; y: 104
    call    UploadFlag
    ; last flag right over the drawn dots
    ld      de,$F276    ; [242,118] ; this one should be +2px off from ruler to right
    call    UploadFlagAtDe

    call    AddExtraTests

    ; add HALT at the end of everything (will wait until the frame [0,0] restarts copper)
    ld      a,COPPER_HALT_B
    out     (c),a
    out     (c),a
    inc     iy          ; count total instructions

    ; read back total instructions from the $61+$62 registers to verify they are readable
    NEXTREG2A COPPER_CONTROL_LO_NR_61
    ld      l,a
    NEXTREG2A COPPER_CONTROL_HI_NR_62
    ld      h,a

    ; put the total instructions counters onto stack (read ones + counted in IY)
    push    hl
    push    iy

    ; start Copper ; reset PC + start, reset on every frame [0,0]
    NEXTREG COPPER_CONTROL_HI_NR_62, %11000000

    ; Output total amount of copper instructions used (manually counted)
    ld      de,MEM_ZX_SCREEN_4000+16*256+6*32
    ld      hl,CopperBytesTxt
    call    OutStringAtDe
    pop     hl
    ld      a,h
    call    OutHexaValue
    ld      a,l
    call    OutHexaValue
    ; Output total amount of copper instructions read back from NextRegs
    ld      de,MEM_ZX_SCREEN_4000+16*256+7*32
    ld      hl,CopperBytesTxt2
    call    OutStringAtDe
    pop     hl          ; this is actually byte-index, not instruction-count
    ld      a,h         ; rotate it to right by 1 bit and put high byte to A
    rr      h           ; if it is odd by some accident, the printed number will be 8xxx
    rr      l
    rra
    call    OutHexaValue
    ld      a,l
    call    OutHexaValue

    ; finish the test (the screen is updated automatically by Copper, no CPU work needed)
    pop     iy          ; restore BASIC IY for IM1 functioning correctly
    ld      c,$90       ; y = 144
AnimateLinePos:
    ei
    halt
    ld      b,0
.codeDelay:
    bit     0,(ix+0)    ; junk ; just making the delay loop duration longer
    bit     1,(ix+0)    ; junk ; just making the delay loop duration longer
    bit     2,(ix+0)    ; junk ; just making the delay loop duration longer
    ld      hl,(animateLineCopperAdr)
    ld      de,$C000    ; set copper-control bits to %11 to not cause disruption in the run
    add     hl,de       ; HL = address of byte with current line (144..159)
    djnz    .codeDelay
    ; mark the point where y of animated line is overwritten in code by bright-white paper
    NEXTREG PALETTE_VALUE_NR_41,C_WHITE_BR
    NEXTREG COPPER_CONTROL_LO_NR_61, l
    NEXTREG COPPER_CONTROL_HI_NR_62, h
    NEXTREG COPPER_DATA_NR_60, c        ; overwrite first y in first WAIT
    inc     hl
    inc     hl
    inc     hl
    inc     hl
    inc     c                           ; y+1 to reset to white
    NEXTREG COPPER_CONTROL_LO_NR_61, l
    NEXTREG COPPER_CONTROL_HI_NR_62, h
    NEXTREG COPPER_DATA_NR_60, c        ; overwrite second y in second WAIT
    ; confine y to 144..159 only (for next loop iteration)
    res     5,c
    set     4,c
    NEXTREG PALETTE_VALUE_NR_41,C_WHITE ; restore border back to white to mark end of code patching
    jr      AnimateLinePos

    call    EndTest

; add extra tests after last flag, checking peculiar details of copper code processing
; 1) add test of same line WAIT doing check for horizontal position being greater/equal
;   doing that at y = 140
; 2) add single blue line going from h=0 -> h=0 at y=144
;   - will be modified by code every frame to move y in 144..159 range
AddExtraTests:

    ;;; 1) test of WAIT using same line as current, but earlier horizontal compare value
    ld      de,C_WHITE + (PALETTE_VALUE_NR_41<<8)
    ld      hl,140 + ((COPPER_WAIT_H + (16<<1))<<8) ; y=140, x-compare 16 = 128px pos = in middle of pixels

    ; create single blue line 64 pixels long (x=128..192)
    out     (c),h
    out     (c),l   ; WAIT(h=16,y=140)
    inc     iy      ; count total instructions
    out     (c),d
    ld      a,C_BLUE
    out     (c),a   ; MOVE $41,C_BLUE
    inc     iy      ; count total instructions

    ; set yellow color after the blue line
    ld      h,COPPER_WAIT_H + (24<<1)   ; x-compare 24 = 192px pos (right 3/4 in pixels)
    out     (c),h
    out     (c),l   ; WAIT(h=24,y=140)
    inc     iy      ; count total instructions
    out     (c),d
    ld      a,C_YELLOW
    out     (c),a   ; MOVE $41,C_YELLOW
    inc     iy      ; count total instructions

    ; try to reset to white instantly by waiting for h=0 on the same line
    ; => should produce single yellow pixel
    ld      h,COPPER_WAIT_H + (0<<1)    ; x-compare 0 = 0px pos (should pass instantly)
    out     (c),h
    out     (c),l   ; WAIT(h=0,y=140)
    inc     iy      ; count total instructions
    out     (c),d
    out     (c),e   ; MOVE $41,C_WHITE
    inc     iy      ; count total instructions

    ;;; 2) line changing y position by code overwriting the copper code every frame
    push    iy      ; remember the position of the initial wait (copper address/2)
    ld      l,144   ; y=144
    out     (c),h
    out     (c),l   ; WAIT(h=0,y=144)
    inc     iy      ; count total instructions
    out     (c),d
    ld      a,C_BLUE
    out     (c),a   ; MOVE $41,C_BLUE
    inc     iy      ; count total instructions

    inc     l
    out     (c),h
    out     (c),l   ; WAIT(h=0,y=145)
    inc     iy      ; count total instructions
    out     (c),d
    out     (c),e   ; MOVE $41,C_WHITE
    inc     iy      ; count total instructions

    pop     hl
    scf
    adc     hl,hl   ; byte address of the "144" in copper memory
    ld      (animateLineCopperAdr),hl
    ret

; swedish flag: dimensions 5:2:9 horizontally, 4:2:4 vertically, proportion 5:8
; Googling for official colours in sRGB turned out to be lot more fun than I expected.
; Settling for (yellow) RGB(249, 205, 48) and (blue) RGB(22, 101, 161) in the end.

; Converting to ZXN display capabilities that will do 16x10 pixels (1px per ratio pt)
; yellow (7.7,6.4,1.5) = %111110001 and requires 9 bit definition ($F8 8b used :/ )
; blue (0.7,3.2,5.0) = %000011101 (will work as $0E 8 bit definition)

; copper code, does for every line of flag:
; * single wait instruction
; * then 2xNOOP are injected for every pixel position to be skipped
; * then 16x move instructions selecting blue or yellow colour are inserted (16 pixels)
; * then 1x move instruction selecting white colour is inserted (rest of line is white)
; Each flag has 10 lines = 180 instructions at least
; plus extra 20 NOOPs * (X-coordinate MOD 8)    (WAIT can target only char positions)
; - it would be possible to optimize this code a lot by introducing more waits instead
; of writing each pixel as MOVE, but this is simplest way to write code + any position

; BC: $253B (and have NR60 selected already), DE: x:y pixel position
UploadFlagAtDe:
    ld      a,d
    and     $07     ; X mod 8
    add     a,a     ; 2x noop = 2 dots = 1 pixel
    inc     a       ; +1 for loop test
    ld      l,a     ; L = amount of NOPs after Wait
    ld      a,d
    rrca
    rrca            ; put (x/8) into position for WAIT inst.
    and     $3E     ; keep only relevant bits
    or      COPPER_WAIT_H ; convert it to WAIT instruction (high byte)
    ld      h,a
    ; continue with UploadFlag code

; BC: $253B (and have NR60 selected already), H: WAIT instruction for start of line (+E),
; L: amount of nops after initial wait (at least one must be there)
UploadFlag:
    ld      a,e
    add     a,10
    ld      d,a     ; D = end E
    ld      ix,FlagData
.LineLoop:
    ; test if all lines were produced
    ld      a,e
    cp      d
    ret     z       ; last line reached, exit
    ; write WAIT for start of next line
    out     (c),h
    out     (c),e
    inc     iy      ; count total instructions
    inc     e       ; next line coordinate adjusted
    ; write L-1 many COPPER_NOOP instructions (to wait for correct pixel)
    push    hl      ; preserve HL (L will be used as counter for all inner loops)
    xor     a       ; 0 for NOOP programming
.InjectNoopsLoop:
    dec     l
    call    nz,.InjectNoop          ; will skip NOOP write for L=1
    jr      nz,.InjectNoopsLoop

    ; output 16 "pixels" of flag
    call    .OutputOneByteOfData    ; output 8 bits of flag data
    call    .OutputOneByteOfData    ; output other 8 bits of flag data
    ; output white colour after the flag
    ld      a,PALETTE_VALUE_NR_41
    out     (c),a
    ld      a,C_WHITE
    out     (c),a
    inc     iy      ; count total instructions

    pop     hl      ; restore L "NOOP counter"
    jr      .LineLoop

; A: 0, BC: TBBLUE_REGISTER_ACCESS_P_253B, IY: Copper instructions counter
.InjectNoop:        ; must preserve CPU FLAGS (ZF)!
    out     (c),a
    out     (c),a
    inc     iy      ; count total instructions
    ret

.OutputOneByteOfData:
    ld      l,8

.OutputOneBitOfData:
    ld      a,PALETTE_VALUE_NR_41
    out     (c),a   ; cooper.move instruction to NR41
    ld      a,C_BLUE
    rlc     (ix)    ; CF = bit of data
    jr      nc,.BlueColour
    ld      a,C_YELLOW
.BlueColour:
    out     (c),a
    inc     iy      ; count total instructions

    dec     l
    jr      nz,.OutputOneBitOfData
    inc     ix      ; next byte data

    ret

    savesna "!Copper.sna", Start
