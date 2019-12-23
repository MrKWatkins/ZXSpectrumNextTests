; This is general Z80 + DMA chip interactive test (trying to detect TBBlue board
; for convenience of user, but should work on regular ZX Spectrum too)
;
; This is fully interactive test intended for experiments with different
; init/command sequences of DMA and reporting its internal state after
; each step, as the Misc/ZilogDMA did show there are some quirks in real
; Zilog DMA chip, and testing them out without interactive tool turned out
; to be quite cumbersome and slow.

;     DEFINE  BUILD_TAP

    device zxspectrum48

    org     $8000
BinStart:
    jp      Start

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

CUSTOM_CHAR_0       EQU     0
CUSTOM_CHAR_RRPTR   EQU     1
CUSTOM_CHAR_WRPTR   EQU     2
CUSTOM_CHAR_RRWRPTR EQU     3   ; WR+RR
CUSTOM_CHAR_AMM     EQU     4   ; adjust --
CUSTOM_CHAR_APP     EQU     5   ; adjust ++
CUSTOM_CHAR_AFIX    EQU     6   ; adjust +0
CUSTOM_CHAR_SRCA    EQU     7   ; src char for attribute
CUSTOM_CHAR_DSTA    EQU     8   ; dst char for attribute
CUSTOM_CHAR_EPIX    EQU     9   ; empty pixels char
CUSTOM_CHAR_DIRR    EQU     10  ; ->
CUSTOM_CHAR_DIRL    EQU     11  ; <-
CUSTOM_CHAR_STD     EQU     12  ; standard value "S"
CUSTOM_CHAR_ENTER   EQU     13

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; global state data

    STRUCT StateData_Port
adjust              BYTE    2       ; 0="--", 1="++", 2="+0"
timing              BYTE    0xFF    ; 0xFF is special value (standard timing)
adr                 WORD    0
    ENDS

    STRUCT StateData_Partial
a                   StateData_Port
b                   StateData_Port  { 1 }
mode                BYTE    %01     ; %00 = byte, %01 = continuous, %10 = burst
direction           BYTE    $0A     ; $0A=A->B $0B=A<-B
length              WORD    0
    ENDS


    STRUCT StateData
isCByteStandard     BYTE    1       ; 1=custom byte is "standard" (dynamic per purpose)
customByte          BYTE    $00     ; specific custom byte entered (not standard)
isPixelTransfer     BYTE    1       ; source/destination data are 1=pixels/0=attributes
edit                StateData_Partial   ; currently edited values by user (not uploaded)
wr                  StateData_Partial   ; currently uploaded values by user
portAtype           BYTE    0       ; $00/$08 = mem/IO
portBtype           BYTE    0       ; $00/$08 = mem/IO
rrStatus            BYTE    0
rrCnt               WORD    0
rrAadr              WORD    0
rrBadr              WORD    0
    ENDS

s       StateData

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; redraw whole screen (full init of top third)

RedrawScreen:
    ; will redraw upper third of screen fully, will also reset destination area bytes
    ; A mem.....v+....V+..............
    ; .##############################.
    ; B mem.......-V....-v............
    ; .%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%.
    ; ??↲↲ pix WR0124↲  A?t?Tt?? mburs
    ; WR3 WR5 Test:qwer B?y?Ty?? l1234
    ; LOAD F-RDY ENA RST-S RST-M a1234
    ; CONT DIS RST RST-A RST-B d?b1234
    push    bc
    ; clear+set attributes of upper third
    ld      hl,RedrawAttributeData
    ld      de,MEM_ZX_ATTRIB_5800
    ld      bc,8*32
    call    ScrollUpBottomTwoThirdsByRow.unrolled32LDI
    jp      pe,$-3
    ; clear pixels of first third
    ld      hl,MEM_ZX_SCREEN_4000
    ld      de,MEM_ZX_SCREEN_4000+1
    ld      (hl),l
    ldi
    ld      bc,66*31    ; = 2046 + LDI above = 2047
    call    ScrollUpBottomTwoThirdsByRow.unrolled31LDI
    jp      pe,$-3
    ; print all default texts
    ld      hl,MEM_ZX_SCREEN_4000+$20*4
    ld      (OutCurrentAdr),hl      ; also set address for OutChar
    ld      hl,RedrawTextData
    ld      b,4*32
.redrawText:
    ld      a,(hl)
    inc     hl
    call    OutCharWithCustomGfx
    djnz    .redrawText
    pop     bc
    ; reset source/destination areas
    call    RedrawTransferAreas
    call    RedrawValues
    ret

RedrawTextData:
    DB  '  ',13,13,' pix WR0124',13,'  A t Tt   m    '
    DB  'WR3 WR5 Test:qwer B y Ty   l    '
    DB  'LOAD F-RDY ENA RST-S RST-M a    '
    DB  'CONT DIS RST RST-A RST-B d b    '

RedrawAttributeData:
    ; test area block
    BLOCK   32, P_WHITE     ; L0
    BLOCK   32, P_CYAN      ; L1
    BLOCK   32, P_WHITE     ; L2
    BLOCK   32, P_CYAN      ; L3
    ; commands/values block
    ; 38 = white, 28 = cyan, 78 = bright white (regular key) 70 = bright yellow (shift), 58 = bright magenta (caps shift)
    HEX     38 38 70 58 38 78 38 38 38 38 38 01 01 01 01 78 38 38 70 01 78 01 38 70 01 01 38 78 01 01 01 01
    HEX     38 38 58 38 38 38 58 38 38 38 38 38 38 78 78 78 78 38 70 01 78 01 38 70 01 01 38 78 01 01 01 01
    HEX     58 38 38 38 38 58 38 38 38 38 38 58 38 38 38 38 38 38 38 58 38 38 38 38 38 58 38 78 01 01 01 01
    HEX     58 38 38 38 38 58 38 38 38 58 38 38 38 38 38 38 38 58 38 38 38 38 38 58 38 78 01 78 01 01 01 01

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; redraw transfer areas (resetting the values in source and destination)

RedrawTransferAreas:
    push    bc
    ; clear attributes in both source and destination area
    ld      hl,MEM_ZX_ATTRIB_5800+$20*1
    call    .fillAttributesArea
    ld      hl,MEM_ZX_ATTRIB_5800+$20*3
    call    .fillAttributesArea
    ; clear pixels in both source and destination area
    ; fill with: in pixel mode char "pixel data" / in attributes using "src/dst DMA" char
    ld      a,(ix + StateData.isPixelTransfer)
    inc     a       ; A = %10 for pixel=1, %01 for pixel=0
    and     (ix + StateData.wr.direction)   ; $0A A->B, $0B A<-B
    ; A = %00 for A->B attr, %01 for B->A attr  %10 for pixel=1
    rlca    ; *=2
    push    af
    add     a,low SolidClearData1
    ld      l,a
    ld      h,high SolidClearData1
    ld      e,(hl)
    inc     l
    ld      d,(hl)
    ld      hl,MEM_ZX_SCREEN_4000+$20*1
    call    .ClearPixelArea
    pop     af
    add     a,low SolidClearData2
    ld      l,a
    ld      h,high SolidClearData2
    ld      e,(hl)
    inc     l
    ld      d,(hl)
    ld      hl,MEM_ZX_SCREEN_4000+$20*3
    call    .ClearPixelArea
    ; setup source area
    ld      a,(ix + StateData.isPixelTransfer)
    add     a,low SrcDataAdr
    ld      l,a
    ld      h,high SrcDataAdr
    ld      d,(hl)
    ld      a,(ix + StateData.wr.direction)
    and     1
    rrca
    rrca
    or      $21     ; A = $21 for A->B, $61 for A<-B
    ld      e,a
    ; DE = address of source data -> fill now, HL = SrcDataAdr + isPixelTransfer
    ; - pixel: customByte = solid fill, SS = standard pattern
    ; - attr: customByte = solid fill, SS = standard pattern
    call    .DrawSourceData
    pop     bc
    ret

.fillAttributesArea:
    ld      (hl),P_CYAN
    inc     l
    ld      de,A_BRIGHT|P_YELLOW | (P_YELLOW<<8)
    ld      b,15
.fillAttributesArea_loop:
    ld      (hl),e
    inc     l
    ld      (hl),d
    inc     l
    djnz    .fillAttributesArea_loop
    ld      (hl),P_CYAN
    ret

.ClearPixelArea:
    push    hl
    ld      c,8
.fill8Lines:
    push    hl
    ld      (hl),0
    inc     l
    ld      a,(de)
    inc     e
    ld      b,30
.fillOneLine:
    ld      (hl),a
    inc     l
    djnz    .fillOneLine
    ld      (hl),b
    pop     hl
    inc     h
    dec     c
    jr      nz,.fill8Lines
    pop     hl
    ret

.DrawSourceData:
    ld      b,30
    ld      a,(ix + StateData.isCByteStandard)
    or      a
    jr      z,.fillWithCustomByte
    ; standard byte for pixels %1000'0010 += 2
    ; standard byte for attributes %01'100'000 += 1
    ld      a,(ix + StateData.isPixelTransfer)
    inc     a
    ld      (.fillWithStandardPattern_IncBy),a
    inc     l
    inc     l       ; HL = SrcDataInitValue+isPixelTransfer (reusing older HL)
    ld      a,(hl)
.fillWithStandardPattern_Loop:
    ld      (de),a
    inc     e
.fillWithStandardPattern_IncBy: EQU $ + 1
    add     a,0
    djnz    .fillWithStandardPattern_Loop
    ret
.fillWithCustomByte:
    ld      a,(ix + StateData.customByte)
.fillWithCustomByte_Loop:
    ld      (de),a
    inc     e
    djnz    .fillWithCustomByte_Loop
    ret

    ALIGN   16
SolidClearData1:
    DW      Char_AttrSrcData, Char_AttrDstData, Char_PixelData
SolidClearData2:
    DW      Char_AttrDstData, Char_AttrSrcData, Char_PixelData
SrcDataAdr:
    DB      $58, $43
SrcDataInitValue:
    DB      %01'100'000, %1000'0010

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; redraw variable values, with correct colour-state-encoding

RedrawValues:
    push    bc
    ;; redraw the address symbols
    ; "erase" old PortA positions by using white on white attribute color
    ld      hl,MEM_ZX_ATTRIB_5800+$20*0
    ld      de,MEM_ZX_ATTRIB_5800+$20*0+1
    ld      (hl),P_WHITE|WHITE
    call    ScrollUpBottomTwoThirdsByRow.unrolled31LDI
    ld      hl,MEM_ZX_SCREEN_4000+$20*0

    ; redraw PortA symbols at new positions
    ld      a,(ix + StateData.wr.a.adjust)
    ld      b,a     ; B = 0/1/2(3)
    cp      1
    sbc     a,a     ; [0, 1, 2, 3] -> [-1, 0, 0, 0]
    ld      c,a     ; C = position adjust for the --/++/+0 char (-1/+0)
    ld      de,(s.rrAadr)
    call    TestAdrToXPos
    add     a,c
    ld      iyl,a
    ld      de,(s.wr.a.adr)
    call    TestAdrToXPos
    add     a,c
    ld      iyh,a   ; A = IYH = WRpos--++, IYL = RRpos--++, B = adjustment, C=-1/+0 adj.
    call    DrawAdrPointers

    ; redraw general PortA label
    ld      de,MEM_ZX_ATTRIB_5800+$20*0
    ld      b,'A'
    ld      c,(ix + StateData.portAtype)    ; $00/$08 mem/IO
    call    DrawPortInfo

    ; "erase" old PortB positions by using white on white attribute color
    ld      hl,MEM_ZX_ATTRIB_5800+$20*2
    ld      de,MEM_ZX_ATTRIB_5800+$20*2+1
    ld      (hl),P_WHITE|WHITE
    call    ScrollUpBottomTwoThirdsByRow.unrolled31LDI
    ld      hl,MEM_ZX_SCREEN_4000+$20*2

    ; redraw PortB symbols at new positions
    ld      a,(ix + StateData.wr.b.adjust)
    ld      b,a     ; B = 0/1/2(3)
    cp      1
    sbc     a,a     ; [0, 1, 2, 3] -> [-1, 0, 0, 0]
    ld      c,a     ; C = position adjust for the --/++/+0 char (-1/+0)
    ld      de,(s.rrBadr)
    call    TestAdrToXPos
    add     a,c
    ld      iyl,a
    ld      de,(s.wr.b.adr)
    call    TestAdrToXPos
    add     a,c
    ld      iyh,a   ; A = IYH = WRpos--++, IYL = RRpos--++, B = adjustment, C=-1/+0 adj.
    call    DrawAdrPointers

    ; redraw general PortB label
    ld      de,MEM_ZX_ATTRIB_5800+$20*2
    ld      b,'B'
    ld      c,(ix + StateData.portBtype)    ; $00/$08 mem/IO
    call    DrawPortInfo

;FIXME all remaining

    pop     bc
    ret

TestAdrToXPos:
    ld      a,3     ;FIXME DEBUG
    xor     4
    ld      (TestAdrToXPos+1),a
    ;FIXME all
    ret

DrawPortInfo:    ; HL = $4000, DE = $5800, B = 'A'/'B', C = $00/$08 mem/IO
    ; check if left or right side are free to draw at (check attributes for white+white)
    inc     e
    ld      a,(de)
    cp      P_WHITE|WHITE
    jr      nz,.tryRightSide
    inc     e
    inc     e
    ld      a,(de)
    cp      P_WHITE|WHITE
    jr      nz,.tryRightSide
    ; left side is free, draw there
    xor     a
    call    Clear4Char
    xor     a
    call    OutBCharAtA
    inc     hl
    jr      .printType
.tryRightSide:
    ld      a,e     ; e is +1 or +3 from previous test
    or      $1F     ; force it to end of line
    dec     a
    ld      e,a
    ld      a,(de)
    cp      P_WHITE|WHITE
    ret     nz      ; right side is full too
    dec     e
    dec     e
    ld      a,(de)
    cp      P_WHITE|WHITE
    ret     nz      ; right side is full too
    ; right side is free, draw there
    ld      a,32-4
    call    Clear4Char
    ld      a,32-1
    call    OutBCharAtA
    ld      a,32-4
    add     a,l
    ld      l,a
.printType:
    ld      (OutCurrentAdr),hl
    rrc     c
    ld      b,0
    ld      hl,.typeStrings
    add     hl,bc
    jp      OutString
.typeStrings:
    DB      'mem',0
    DB      'io',0

;; will draw various combination of pointers with --/++/+0 adjustments (if at valid pos)
; same pos = special arrow "-W+", next to other "-vV+"/"-Vv+", separate pos "-v+ -V+"
DrawAdrPointers:
    ; A = IYH = WRpos--++, IYL = RRpos--++, B = adjustment, C=-1/+0 adj., HL = $4000
    cp      iyl
    jr      z,.samePositions
    ; different positions
    cp      31
    jr      nc,.onlyRRPos   ; WR pos is not in valid position (0..30)
    inc     a
    cp      iyl
    jr      z,.WRposNextFromLeft    ; [WRpos, RRpos] (+0, +1)
    dec     a
    dec     a
    cp      iyl
    jr      z,.WRposNextFromRight   ; [RRpos, WRpos] (+0, +1)
    inc     a
    ; separate-enough positions, WR pointer valid, RR pointer not checked
    call    Clear2Char
    push    bc
    call    .drawSeparateWrPtr
    pop     bc
    ;
    ; fallthrough into .onlyRRPos
    ;
.onlyRRPos:
    ld      a,iyl
    cp      31
    ret     nc      ; neither in valid position (0..30)
    call    Clear2Char
    ld      a,iyl
    push    af
    push    bc
    ld      b,CUSTOM_CHAR_RRPTR
    jr      .singlePtrOnly

.drawSeparateWrPtr:
    ld      a,iyh
    push    af
    push    bc
    ld      b,CUSTOM_CHAR_WRPTR
    jr      .singlePtrOnly

.WRposNextFromLeft:     ; both positions are then valid
    dec     a
    call    Clear4Char
    push    bc
    call    .drawSeparateWrPtr  ; will draw "--V" or "V++" at iyh
    pop     bc
    ld      a,c
    inc     a
    jr      nz,.onlyRRPos   ; will clear the ++ part and draw "v++"
    ; draw only "v" in case of "--" case
    ld      a,iyl
    inc     a
.justRRPosSymbol:
    ld      b,CUSTOM_CHAR_RRPTR
    jr      OutBCharAtA

.WRposNextFromRight:    ; both positions are then valid
    call    Clear4Char
    push    bc
    call    .drawSeparateWrPtr  ; will draw "--V" or "V++" at iyh
    pop     bc
    ld      a,c
    inc     a
    jr      z,.onlyRRPos   ; will clear the -- part and draw "--v"
    ; draw only "v" in case of "++" case
    ld      a,iyl
    jr      .justRRPosSymbol

.samePositions:
    ld      a,iyh
    cp      31
    ret     nc      ; not in valid position (0..30)
    call    Clear2Char
    ld      a,iyh
    push    af
    push    bc
    ld      b,CUSTOM_CHAR_RRWRPTR
.singlePtrOnly:
    sub     c
    call    OutBCharAtA
    pop     bc
    ld      a,CUSTOM_CHAR_AMM
    add     a,b
    ld      b,a
    pop     af
    add     a,c
    inc     a
    ;
    ; fallthrough into OutBCharAtA
    ;
OutBCharAtA:
    push    hl
    add     a,l
    ld      l,a
    ld      (OutCurrentAdr),hl
    ld      a,b
    call    OutCharWithCustomGfx
    pop     hl
    ret

Clear2Char:     ; HL = base address (VRAM), A will be added (must not CF=1)
    push    bc
    push    hl
    add     a,l
    ld      l,a
    xor     a
    ld      b,4
.c2loop:
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     h
    ld      (hl),a
    dec     l
    ld      (hl),a
    inc     h
    djnz    .c2loop
    ld      a,h
    add     a,$10
    ld      h,a
    ld      a,P_WHITE
    ld      (hl),a
    inc     l
    ld      (hl),a
    pop     hl
    pop     bc
    ret

Clear4Char:     ; HL = base address (VRAM), A will be added (must not CF=1)
    push    bc
    push    hl
    add     a,l
    ld      l,a
    xor     a
    ld      b,4
.c4loop:
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     h
    ld      (hl),a
    dec     l
    ld      (hl),a
    dec     l
    ld      (hl),a
    dec     l
    ld      (hl),a
    inc     h
    djnz    .c4loop
    ld      a,h
    add     a,$10
    ld      h,a
    ld      a,P_WHITE
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     l
    ld      (hl),a
    inc     l
    ld      (hl),a
    pop     hl
    pop     bc
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; scroll bottom two thirds of screen, and clear bottom line

ScrollUpBottomTwoThirdsByRow:
    push    bc
    ; scroll first 8 rows by one row up
    ld      hl,MEM_ZX_SCREEN_4000+$800+$20
    ld      de,MEM_ZX_SCREEN_4000+$800
    ld      bc,$800-$20
    call    .unrolled32LDI
    jp      pe,$-3
    ; copy row 16 to row 15 (on the edge between thirds), HL = MEM_ZX_SCREEN_4000+$1000
    ld      de,MEM_ZX_SCREEN_4000+$800+$20*7
    ld      a,8
.Line16Scroll:
    ld      c,$20
    call    .unrolled32LDI
    ld      e,-$20
    ld      l,c
    inc     h
    dec     a
    jr      nz,.Line16Scroll
    ; scroll remaining 7 rows in second third
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20
    ld      e,b     ; de = MEM_ZX_SCREEN_4000+$1000
    ld      bc,$800-$20
    call    .unrolled32LDI
    jp      pe,$-3
    ; clear bottom line, HL = $5800, DE = $57E0, BC = 0, A = 0
    ld      d,$50
    ld      a,8
.clearLine23AfterScroll:
    ld      h,d
    ld      l,-$20
    ld      e,-$1F
    ld      (hl),c
    ld      c,31
    call    .unrolled31LDI
    dec     a
    jr      nz,.clearLine23AfterScroll
    ; scroll attributes
    ld      hl,MEM_ZX_ATTRIB_5800+$20*9
    ld      de,MEM_ZX_ATTRIB_5800+$20*8
    ld      bc,$20*15
    call    .unrolled32LDI
    jp      pe,$-3
    ; set final line attributes to default, DE = $5AE0
    ld      h,d
    ld      l,e
    inc     e
.clearWithAttributeValue    EQU     $ + 1
    ld      a,P_WHITE|BLACK
    ld      (hl),a
    call    .unrolled31LDI
    ld      a,(.clearWithAttributeValue)
    xor     P_WHITE^P_CYAN          ; alternate white/cyan paper colour
    ld      (.clearWithAttributeValue),a
    pop     bc
    ret
.unrolled32LDI:
    ldi
.unrolled31LDI:
    .31 ldi
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; utility functions

OutCharWithCustomGfx:
    cp      CUSTOM_CHAR_END ; custom chars are 0..CUSTOM_CHAR_END-1
    jp      nc,OutChar      ; reuse regular OutChar for common ASCII codes
    push    af
    push    hl
    push    de
    push    bc
    ld      h,CustomCharsGfx/(8*256)
    add     a,(CustomCharsGfx/8) & $FF
    ld      l,a
    add     hl,hl
    add     hl,hl
    add     hl,hl   ; hl *= 8
    jp      OutChar.withCustomGfxData

    ALIGN   256
CustomCharsGfx:
    ; zero char
    DG      # # # # # # # #
    DG      # # . . . . # #
    DG      # . # # # . . #
    DG      # . # # . # . #
    DG      # . # . # # . #
    DG      # . . # # # . #
    DG      # # . . . . # #
    DG      # # # # # # # #
    ; 1: current RR pointer
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . . . # . . . .
    DG      . . . # . . . .
    DG      . . . # . . . .
    DG      . # # # # # . .
    DG      . . # # # . . .
    DG      . . . # . . . .
    ; 2: current WR pointer
    DG      . . . # . . . .
    DG      . . . # . . . .
    DG      # # # # # # # .
    DG      . # . . . # . .
    DG      . . # . # . . .
    DG      . . . # . . . .
    DG      . . . . . . . .
    DG      . . . . . . . .
    ; 3: current RR+WR pointer (same position)
    DG      . . . # . . . .
    DG      . . . # . . . .
    DG      # # # # # # # .
    DG      . # . . . # . .
    DG      . . # . # . . .
    DG      . # # # # # . .
    DG      . . # # # . . .
    DG      . . . # . . . .
    ; 4: --
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      # # # . # # # .
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . . . . . . . .
    ; 5: ++
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . # . . . # . .
    DG      # # # . # # # .
    DG      . # . . . # . .
    DG      . . . . . . . .
    DG      . . . . . . . .
    ; 6: +0 (fixed)
    DG      . . . . . . . .
    DG      . . . . . # . .
    DG      . . . . # . # .
    DG      . # . . # . # .
    DG      # # # . # . # .
    DG      . # . . # . # .
    DG      . . . . . # . .
    DG      . . . . . . . .
    ; 7: attribute DMA source data
Char_AttrSrcData:
    DG      . . . . . . . .
    DG      . # # # # # # .
    DG      . # # # # # # .
    DG      . # # . . # # .
    DG      . # # . . # # .
    DG      . # # # # # # .
    DG      . # # # # # # .
    DG      . . . . . . . .
    ; 8: attribute DMA destination target
Char_AttrDstData:
    DG      . . . . . . . .
    DG      . . . # # . . .
    DG      . . # # # # . .
    DG      . # . # # # # .
    DG      . # # # # # # .
    DG      . . # # # # . .
    DG      . . . # # . . .
    DG      . . . . . . . .
    ; 9: empty pixel source/destination area char
Char_PixelData:
    DG      . . . . . . . .
    DG      # # # # # # # #
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      # # # # # # # #
    DG      . . . . . . . .
    DG      . . . . . . . .
    ; 10: direction ->
    DG      . . . . . . . .
    DG      . . . # . . . .
    DG      . . . . # . . .
    DG      . # # # # # . .
    DG      . . . . . . # .
    DG      . # # # # # . .
    DG      . . . . # . . .
    DG      . . . # . . . .
    ; 11: direction <-
    DG      . . . . . . . .
    DG      . . . . # . . .
    DG      . . . # . . . .
    DG      . . # # # # # .
    DG      . # . . . . . .
    DG      . . # # # # # .
    DG      . . . # . . . .
    DG      . . . . # . . .
    ; 12: "standard" value (differs for different purposes)
    DG      # # # # # # # #
    DG      # # . . . . # #
    DG      # . # # # # # #
    DG      # # . . . . # #
    DG      # # # # # # . #
    DG      # . # # # # . #
    DG      # # . . . . # #
    DG      # # # # # # # #
    ; 13: enter
    DG      . . . . # # # .
    DG      . . . . # # # .
    DG      . . . . # # # .
    DG      . # . # # # . .
    DG      . # # # # . . .
    DG      . # # # . . . .
    DG      . # # # # . . .
    DG      . . . . . . . .
    ;
;     DG      . . . . . . . .
;     DG      . . . . . . . .
;     DG      . . . . . . . .
;     DG      . . . . . . . .
;     DG      . . . . . . . .
;     DG      . . . . . . . .
;     DG      . . . . . . . .
;     DG      . . . . . . . .
CUSTOM_CHAR_END     EQU     ($ - CustomCharsGfx)/8

;;;;;;;;;;;;;;;;;; OLD CODE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ATTR_NO_DMA EQU     P_GREEN|RED             ; green without ink, red with ink
ATTR_DMA    EQU     P_RED|GREEN             ; green with ink, red without ink (bright)
ATTR_DMA_B  EQU     A_BRIGHT|ATTR_DMA       ; bright variant (to mark start/end bytes)
ATTR_IO     EQU     A_BRIGHT|P_RED|YELLOW
ATTR_BAD    EQU     P_RED|RED               ; red+red no bright (filler in source area)

    MACRO FILL_DMA_CHAR_DOTS adr?, columns?, rows?
        ld      hl,adr?
        ld      bc,((columns?)<<8) | (rows?)
        ld      d,$40
        call    FillSomeUlaLines
    ENDM

ReadAndShowDmaByte:
    in      a,(c)
.valueInA:
    call    OutHexaValue
.updateAttribute:
    ; every second value has bright paper (calculate by IX address)
    ld      a,ixl
    rrca
    rrca
    rrca
    and     A_BRIGHT
    or      P_CYAN|BLACK
    ld      (ix+0),a
    ld      (ix+1),a
    inc     ix
    inc     ix
    ret

AutoDetectTBBlue:
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    ld      a,MACHINE_ID_NR_00
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
    in      a,(c)   ; read desired NextReg state
    cp      8
    jr      z,.emulator
    cp      10
    ret     nz      ; not TBBlue
.emulator:
    dec     b
    ld      a,NEXT_VERSION_NR_01
    out     (c),a
    inc     b
    in      a,(c)
    cp      $FF     ; CF=1 for non $FF (Next core version 15.15.x will fail this test)
    ret     nc
    ; modify default port to $6B on TBBlue boards
    ld      a,ZXN_DMA_P_6B
    ld      (DmaPortData),a
    ret

Start:
    ; auto-detect DMA port heuristic
    di
    call    AutoDetectTBBlue
StartAfterPortChange:
    call    StartTest
    ; restore DmaSrcData1B data if this is restarted by "P" key
    ld      a,ATTR_DMA_B
    ld      (DmaSrcData1B),a
    ;; screen init
    BORDER  CYAN
    ; create dots in all DMA squares to make counting easier
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*1+6, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*1+18, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*1+30, 1, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*1+6, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*1+18, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*1+30, 1, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*6+13, 4+4+2, 1
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*6+13, 4, 1
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*6+18, 4, 1
    ; display all text in the layout
    ld      de,MEM_ZX_SCREEN_4000
    ld      hl,LegendaryText
    call    OutStringAtDe
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20*7+11
    ld      (OutCurrentAdr),hl
    ld      a,(DmaPortData)
    call    OutHexaValue
    ; attributes - odd lines stripes
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20,$20,P_CYAN|BLACK
    ld      hl,MEM_ZX_ATTRIB_5800
    ld      de,MEM_ZX_ATTRIB_5800+$20*2
    ld      bc,32*22
    ldir
    ; extra attributes for "IO is yellow" line
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*5,$20,P_CYAN|WHITE
    ; attributes - blocks info area
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*15+0,$20*8,A_BRIGHT|P_WHITE|BLUE
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*16+0,$20*3,P_WHITE|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*20+0,$20*1,P_WHITE|BLACK
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*16+1,14,P_CYAN|BLACK
    ; attributes - test areas for each basic mode
line = 1
    REPT 8
        FILL_AREA   MEM_ZX_ATTRIB_5800+$20*line+5,6,ATTR_NO_DMA
        FILL_AREA   MEM_ZX_ATTRIB_5800+$20*line+17,6,ATTR_NO_DMA
        FILL_AREA   MEM_ZX_ATTRIB_5800+$20*line+29,3,ATTR_NO_DMA
line = line + 1
        IF 5 == line
line = line + 4
        ENDIF
    ENDR
    ; attributes - test areas for short-init tests
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*6+12,12,ATTR_NO_DMA
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*14+12,11,ATTR_NO_DMA

    ;; do the full init of DMA chip and helper settings in NextRegs and I/O ports
    BORDER  YELLOW

    ; switch DMA to Zilog mode (and enable all keys: turbo, 50/60Hz, NMI)
    ; use only regular Z80 instructions, so it can survive even on ZX48/ZX128
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    ld      a,PERIPHERAL_2_NR_06
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
    in      a,(c)   ; read desired NextReg state
    or      %1110'1000          ; enable F8, F3 and NMI buttons, Zilog DMA mode
    out     (c),a   ; write new value
    ; switch timing of ZX Next to 128 model
    dec     b       ; register select
    ld      a,MACHINE_TYPE_NR_03
    out     (c),a
    inc     b
    in      a,(c)   ; read Machine type register
    and     %0'000'0'111
    or      %1'010'1'000    ; lock "native" ZX128+3 timing
    out     (c),a   ; write new value

    ; init AY register to value which will be used for I/O port tests
    ld      bc,AY_REG_P_FFFD
    xor     a
    out     (c),a
    ld      bc,AY_DATA_P_BFFD
    ld      a,ATTR_IO
    out     (c),a

    ; init DMA - full re-init of everything
    ld      hl,DmaFullInit
DmaPortData EQU $+1         ; self-modify storage
    ld      bc,(DmaFullInitSz<<8)|Z80_DMA_PORT_MB02
    otir

    ; do the read of DMA port while nothing was requested yet
    ld      hl,MEM_ZX_SCREEN_4000+$20*7+0
    ld      (OutCurrentAdr),hl
    ld      ix,MEM_ZX_ATTRIB_5800+$20*7+0
    call    ReadAndShowDmaByte
    ; request status of DMA after full init
    ld      a,DMA_READ_STATUS_BYTE
    out     (c),a
    call    ReadAndShowDmaByte
    ; set read-status bytes to only status + LSB bytes
    ld      hl,(DMA_READ_MASK_FOLLOWS<<8) | %0'01'01'01'1   ; status + lsb counter + lsb adrA + lsb adrB
    out     (c),h
    out     (c),l
    ; start the read sequence already, try to read status (should be ignored b/c sequence)
    ld      hl,(DMA_START_READ_SEQUENCE<<8) | DMA_READ_STATUS_BYTE
    out     (c),h
    out     (c),l
    ; the sequence will be read and shown after first transfer

    ;; do the basic tests (full inits), A -> B direction
    ; outer loop init values
AtoB_WR0    EQU     %0'1111'1'01
    DEFARRAY SRC_ADR        DmaSrcData4B, DmaSrcData4B+3, DmaSrcData1B, AY_REG_P_FFFD
    DEFARRAY DST_ADR_BASE   MEM_ZX_ATTRIB_5800+$20*1, MEM_ZX_ATTRIB_5800+$20*2, MEM_ZX_ATTRIB_5800+$20*3, MEM_ZX_ATTRIB_5800+$20*4
    DEFARRAY DATA_SZ        3, 3, 3, 3
    DEFARRAY SRC_MODE       %0'1'01'0'100, %0'1'00'0'100, %0'1'10'0'100, %0'1'10'1'100 ; m+, m-, m0, IO(+0) (port A)
    ; inner loop init values
    DEFARRAY DST_ADR_OFS    6, 18+3, 30
    DEFARRAY DST_MODE       %0'1'01'0'000, %0'1'00'0'000, %0'1'10'0'000 ; m+, m-, m0 (port B)
    ; setup all A -> B 4x3 tests
outer_loop_i = 0
    REPT    4
inner_loop_i = 0
        REPT 3
            nop : ; DW $01DD    ; break
            ; WR0 = A->B transfer, start addres port A, block length
            ld      a,AtoB_WR0
            ld      hl,SRC_ADR[outer_loop_i]
            ld      de,DATA_SZ[outer_loop_i]
            out     (c),a           ; in zxnDMA continuous mode WR0 can be first write
            out     (c),l           ; start address port A
            out     (c),h
            out     (c),e           ; block length (real length, because zxnDMA mode)
            out     (c),d
            ; WR1 = port A mode + timing 2
            ld      de,SRC_MODE[outer_loop_i] | $0200
            out     (c),e
            out     (c),d
            ; WR2 = port B mode + timing 2
            ld      de,DST_MODE[inner_loop_i] | $0200
            out     (c),e
            out     (c),d
            ; WR4 = continuous mode, start address port B
            ld      a,%1'01'0'11'01
            ld      hl,DST_ADR_BASE[outer_loop_i] + DST_ADR_OFS[inner_loop_i]
            out     (c),a
            out     (c),l
            out     (c),h
            IF DST_MODE[inner_loop_i] & %0'0'10'0'000   ; for fixed destination reg do the opposite LOAD first
                ld      hl,%0'0000'0'01 | (DMA_LOAD<<8)
                out     (c),l       ; B->A transfer
                out     (c),h       ; LOAD
                set     2,l
                out     (c),l       ; A->B transfer
            ENDIF
            ld      a,DMA_LOAD      ; load the internal counters with the settings
            out     (c),a
            ld      a,DMA_FORCE_READY   ; force ready
            out     (c),a
            ld      a,DMA_ENABLE    ; start the transfer
            out     (c),a
            ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
            out     (c),a
            nop
            IF 0 == inner_loop_i && 0 == outer_loop_i
                ; after very first test, show the read-sequence values + one more
                ld      b,5
                call    ReadAndShowDmaByte
                djnz    $-3
                ; and make new read sequence pending
                ld      a,DMA_START_READ_SEQUENCE
                out     (c),a
            ENDIF
inner_loop_i = inner_loop_i + 1
        ENDR
outer_loop_i = outer_loop_i + 1
    ENDR

    ;; do the basic tests (full inits), B -> A direction ; reusing A -> B constants
    ; init values which are different from A->B test
BtoA_WR0    EQU     %0'1111'0'01
    UNDEFINE SRC_MODE
    DEFARRAY SRC_MODE       %0'0'01'0'000, %0'0'00'0'000, %0'0'10'0'000, %0'0'10'1'000 ; m+, m-, m0, IO(+0) (port B)
    UNDEFINE DST_MODE
    DEFARRAY DST_MODE       %0'0'01'0'100, %0'0'00'0'100, %0'0'10'0'100 ; m+, m-, m0 (port A)

    ; setup all B -> A 4x3 tests
outer_loop_i = 0
    REPT    4
inner_loop_i = 0
        REPT 3
            nop : ; DW $01DD    ; break
            ; WR0 = B->A transfer, start addres port A, block length
            ld      a,BtoA_WR0
            ld      hl,DST_ADR_BASE[outer_loop_i] + DST_ADR_OFS[inner_loop_i] + $20*8
            ld      de,DATA_SZ[outer_loop_i]
            out     (c),a           ; in zxnDMA continuous mode WR0 can be first write
            out     (c),l           ; start address port A
            out     (c),h
            out     (c),e           ; block length (real length, because zxnDMA mode)
            out     (c),d
            ; WR1 = port B mode
            ld      a,SRC_MODE[outer_loop_i]
            out     (c),a
            ; WR2 = port A mode
            ld      a,DST_MODE[inner_loop_i]
            out     (c),a
            ; WR4 = continuous mode, start address port B
            ld      a,%1'01'0'11'01
            ld      hl,SRC_ADR[outer_loop_i]
            out     (c),a
            out     (c),l
            out     (c),h
            IF DST_MODE[inner_loop_i] & %0'0'10'0'000   ; for fixed destination reg do the opposite LOAD first
                ld      hl,%0'0000'1'01 | (DMA_LOAD<<8)
                out     (c),l       ; A->B transfer
                out     (c),h       ; LOAD
                res     2,l
                out     (c),l       ; B->A transfer
            ENDIF
            ld      a,DMA_LOAD      ; load the internal counters with the settings
            out     (c),a
            ld      a,DMA_FORCE_READY   ; force ready
            out     (c),a
            ld      a,DMA_ENABLE    ; start the transfer
            out     (c),a
            ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
            out     (c),a
            nop
inner_loop_i = inner_loop_i + 1
        ENDR
outer_loop_i = outer_loop_i + 1
    ENDR

    ;; short-init tests

    ; expected state from last B -> A test:
    ; WR0 B->A, port A adr: MEM_ZX_ATTRIB_5800+$20*12+30 = $599E, length = 3, port A mem+0
    ; port B adr: $FFFD, port B I/O+0, continuous mode

    ; change current full-init from last B->A test to "-- mode, bottom right 4x1"
    ; Port A adr (*LSB): $59D5, port A mem-- (*), port B adr (*): DmaSrcData4B, port B mem++ (*)
    nop : ; DW $01DD    ; break
    ; WR0 = B->A transfer, LSB start addres port A
    ld      hl,(%0'0001'0'01<<8)|$D5
    out     (c),h           ; there was already DISABLE at end of previous test, so this should work
    out     (c),l           ; start address port A (LSB)
    ; WR1 = port B mode, WR2 = port A mode
    ld      hl,%0'0'01'0'000'0'0'00'0'100
    out     (c),h           ; WR1 = mem++ (port B, src)
    out     (c),l           ; WR2 = mem-- (port A, dst)
    ; WR4 = continuous mode, start address port B
    ld      a,%1'01'0'11'01
    ld      hl,DmaSrcData4B
    out     (c),a
    out     (c),l
    out     (c),h
    ld      a,DMA_LOAD      ; load the internal counters with the patched settings
    out     (c),a
    ld      a,DMA_FORCE_READY   ; force ready
    out     (c),a
    ld      a,DMA_ENABLE    ; start the transfer
    out     (c),a
    ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
    out     (c),a

    ; set LSB DST_ADR $59CD, dst mode mem++, load + enable (same SRC data and mode)
    nop : ; DW $01DD    ; break
    ; WR0 = B->A transfer, LSB start addres port A
    ld      hl,(%0'0001'0'01<<8)|$CD
    out     (c),h           ; there was already DISABLE at end of previous test, so this should work
    out     (c),l           ; start address port A (LSB)
    ; WR2 = port A mode mem++
    ld      a,%0'0'01'0'100
    out     (c),a           ; WR2 = mem++ (port A, dst)
    ld      a,DMA_LOAD      ; load the internal counters with the patched settings
    out     (c),a
    ld      a,DMA_FORCE_READY   ; force ready
    out     (c),a
    ld      a,DMA_ENABLE    ; start the transfer
    out     (c),a
    ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
    out     (c),a

    ;; short init 4+4+2 block using CONTINUE command

    ; set MSB DST_ADR $58CD, MSB SRC_ADR DmaSrcData9B (has same LSB as DmaSrcData4B), load + enable
    nop : ; DW $01DD    ; break
    ; WR0 = B->A transfer, MSB start addres port A
    ld      hl,(%0'0010'0'01<<8)|$58
    out     (c),h           ; there was already DISABLE at end of previous test, so this should work
    out     (c),l           ; start address port A (MSB)
    ; WR4 = continuous mode, start address port B (MSB)
    ld      hl,(%1'01'0'10'01<<8)|(high DmaSrcData9B)
    out     (c),h           ; WR4
    out     (c),l           ; SRC_ADR MSB (port B)
    ld      a,DMA_LOAD      ; load the internal counters with the patched settings
    out     (c),a
    ld      a,DMA_FORCE_READY   ; force ready
    out     (c),a
    ld      a,DMA_ENABLE    ; start the transfer
    out     (c),a
    ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
    out     (c),a
    ; show the read-sequence values + one more after first transfer
    ld      b,5
    call    ReadAndShowDmaByte
    djnz    $-3
    ; and make new read sequence pending
    ld      a,DMA_START_READ_SEQUENCE
    out     (c),a

    jr      .CSpectDiesSkip

    ; just "continue" (unfortunately this kills the code on #CSpect 2.11.8)
    ; change: actually it does "useless" start address setup of port A/B to verify
    ; they don't get loaded when they should not (with "continue" only)
    nop : ; DW $01DD    ; break
    ; WR0 = start address A
    ld      de,MEM_ZX_ATTRIB_5800+$20*6 ; "error spot" over "short init" text
    ld      a,%0'0011'0'01
    out     (c),a           ; there was already DISABLE at end of previous test, so this should work
    out     (c),e           ; start address port A
    out     (c),d           ; start address port A
    ; WR4 = continuous mode, start address port B
    ld      a,%1'01'0'11'01
    out     (c),a
    out     (c),e           ; start address port B
    out     (c),d           ; start address port B
    ; just "continue"
    ld      a,DMA_CONTINUE  ; reset length, but continue with pointers
    out     (c),a
    ld      a,DMA_FORCE_READY   ; force ready
    out     (c),a
    ld      a,DMA_ENABLE    ; start the transfer
    out     (c),a
    ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
    out     (c),a
    ; show the read-sequence values after first "continue" transfer
    ld      b,4
    call    ReadAndShowDmaByte
    djnz    $-3

    ; set LSB length (does set also port A+B addresses to "error sport"), continue w/o load
    nop : ; DW $01DD    ; break
    ld      hl,(%0'0111'0'01<<8)|$01
    out     (c),h           ; there was already DISABLE at end of previous test, so this should work
    out     (c),e           ; start address port A
    out     (c),d           ; start address port A
    out     (c),l           ; block length (LSB)
    ; WR4 = continuous mode, start address port B
    ld      a,%1'01'0'11'01
    out     (c),a
    out     (c),e           ; start address port B
    out     (c),d           ; start address port B
    ld      a,DMA_CONTINUE  ; reset length, but continue with pointers (no LOAD!)
    out     (c),a
    ld      a,DMA_FORCE_READY   ; force ready
    out     (c),a
    ld      a,DMA_ENABLE    ; start the transfer
    out     (c),a
    ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
    out     (c),a

.CSpectDiesSkip:

    ;; set up the slow burst DMA + interrupt
    ; setup interrupt to change colors (every interrupt = 50/60Hz), and CPU speed (2s)
    ld      a,IM2_IVT
    ld      i,a
    im      2
    ; reset color for first block to be red
    ld      a,RED
    ld      (DmaSrcData1B),a
BorderPerformanceTest:
    ei
    halt
    ; interrupt will also display top border effect and wait near start of PAPER area

    ; setup the transfers to BORDER port with 2T timings of ports (mem -> IO (border))
    ld      hl,DmaBorderTimingPerformance_2T
    ld      b,DmaBorderTimingPerformance_2TSz
    otir

    BORDER  WHITE       ; wait cca 1+7 scanlines
    ld      b,16
    djnz    $
    BORDER  GREEN
    ld      b,104
    djnz    $

    ; setup the transfers to BORDER port with 2T timings of ports (mem -> IO (border))
    BORDER  YELLOW
;     ld      hl,DmaBorderTimingPerformance_ST
;     ld      b,DmaBorderTimingPerformance_STSz
;     otir

    BORDER  WHITE
    ld      b,16
    djnz    $
    BORDER  BLUE

    call    FigureOutRealStateOfDmaChip

    ;;;;;; NEW CODE
    push    ix

    ld      ix,s
    ;; FIXME DEBUG
    ld      b,25
.waitFrames:
    halt
    djnz    .waitFrames

    call    ScrollUpBottomTwoThirdsByRow

    ; FIXME DEBUG random text output
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20*7
    ld      (OutCurrentAdr),hl
.DEBUG_randomOut    EQU $ + 1
    ld      hl,0
    ld      b,31
1:
    ld      a,(hl)
    inc     hl
    call    OutCharWithCustomGfx
    djnz    1B
    ld      (.DEBUG_randomOut),hl

    call    RedrawScreen

    BORDER  BLACK
    pop     ix
    ;;;;;; END OF NEW CODE

    ; check for press of "P" to restart the whole test with the other port
    ld      a,%11011111
    in      a,(ULA_P_FE)
    rra
    jp      c,BorderPerformanceTest
    ; flip the port to the other one (between $6B and $0B)
    di
    ld      a,(DmaPortData)
    xor     Z80_DMA_PORT_DATAGEAR^Z80_DMA_PORT_MB02
    ld      (DmaPortData),a
    ; revert FigureOutRealStateOfDmaChip to working state (it did self-disable)
    ld      a,$3E       ; "LD a,$nn"
    ld      (FigureOutRealStateOfDmaChip+1),a
    ; restart the test completely
    jp      StartAfterPortChange

FigureOutRealStateOfDmaChip:
    ; allow "ret z" (needs "xor a") to have 17+4+11 = 32T (after the routine is disabled)
    xor     a
    ld      a,$C8                               ; "ret z" after "xor a"
    ld      (FigureOutRealStateOfDmaChip+1),a   ; disable routine for second call
    ; read anything from port (nothing requested) (start new line at +6 to previous reads)
    ld      hl,MEM_ZX_SCREEN_4000+$800+$20*5+0
    ld      (OutCurrentAdr),hl
    ld      ix,MEM_ZX_ATTRIB_5800+$20*13+0
    call    ReadAndShowDmaByte
    ; read full 7 bytes after init sequence (7 may be valid if read mask is reset) (8B total)
    ld      a,DMA_START_READ_SEQUENCE
    out     (c),a
    ld      b,4
    call    ReadAndShowDmaByte
    djnz    $-3
    ld      a,' '
    call    OutChar
    call    OutChar
    call    ReadAndShowDmaByte.updateAttribute
    call    ReadAndShowDmaByte      ; read one unexpected byte extra
    ld      a,' '
    call    OutChar
    call    OutChar
    call    ReadAndShowDmaByte.updateAttribute
    ld      hl,DMA_READ_MASK_FOLLOWS | $7F00
    out     (c),l
    out     (c),h
    ld      a,DMA_START_READ_SEQUENCE
    out     (c),a
    ld      b,7
    call    ReadAndShowDmaByte
    djnz    $-3
    ; adjust total T-states
    xor     (hl)
    ret

;; DMA init + transfer sequences used to reset DMA and to init the flashing border blocks

DmaFullInit:
    BLOCK 6, DMA_RESET      ; 6x DMA_RESET (to get out of any regular state, if 5B data are expected)
    DB  %0'0000'1'01        ; WR0 = A->B transfer (no extra bytes, yet)
    DB  %0'1'01'0'100, 0x0E ; WR1 = A memory, ++, cycle length=2
    DB  %0'1'01'0'000, 0x0E ; WR2 = B memory, ++, cycle length=2
    DB  $80                 ; WR3 = 0 (reset and switch off interrupts)
    DB  %1'01'0'00'01       ; WR4 = continuous mode
    DB  %10'0'0'0010        ; WR5 = stop after block, /CE only
DmaFullInitSz EQU $ - DmaFullInit

DmaBorderTimingPerformance_2T:
    DB  DMA_DISABLE
    DB  %0'1111'0'01        ; WR0 = B->A transfer, port A address, length
    DW  DmaSrcData1B        ; source data address
    DW  2917                ; block length (2918*5 = 14590T => 64 scanlines if 228T per line)
    DB  %0'1'10'0'100, 0x0E ; WR1 = A memory, +0, timing 2T
    DB  %0'1'10'1'000, 0x0E ; WR2 = B I/O, +0, timing 2T
    DB  %1'01'0'11'01       ; WR4 = continuous mode, port B address
    DW  ULA_P_FE
    DB  DMA_LOAD            ; load port B (fixed address)
    DB  %0'0000'1'01        ; WR0 = A->B transfer
    DB  %10'0'0'0010        ; WR5 = end after block, /CE only
    DB  DMA_LOAD            ; load also port A (fixed address)
    DB  DMA_FORCE_READY, DMA_ENABLE     ; ship it!
DmaBorderTimingPerformance_2TSz EQU $ - DmaBorderTimingPerformance_2T

DmaBorderTimingPerformance_ST:  ; same source/destination/length addresses
    DB  DMA_DISABLE
    DB  %0'0000'1'01        ; WR0 = A->B transfer
    DB  %0'0'10'0'100       ; WR1 = A memory, +0, timing "standard"
    DB  %0'0'10'1'000       ; WR2 = B I/O, +0, timing "standard"
    DB  DMA_CONTINUE        ; continue like previous transfer
    DB  DMA_FORCE_READY, DMA_ENABLE     ; ship it!
DmaBorderTimingPerformance_STSz EQU $ - DmaBorderTimingPerformance_ST

LegendaryText:
    ;    01234567012345670123456701234567
    DB  "A -> B        m+ = m++, m- = m--"
    DB  "m+m+  \A\A\A\A  m+m-  \A\A\A\A  m+m0  \A "
    DB  "m-m+  \A\A\A\A  m-m-  \A\A\A\A  m-m0  \A "
    DB  "m0m+  \A\A\A\A  m0m-  \A\A\A\A  m0m0  \A "
    DB  "IOm+  \A\A\A\A  IOm-  \A\A\A\A  IOm0  \A "
    DB  "(IO is yellow colour when OK)   "
    DB  "Short init:  \A\A\A\A\A\A\A\A\A\A  (4+4+2)"
    DB  "                                "
    DB  "B -> A     m0=const, IO=I/O port"
    DB  "m+m+  \A\A\A\A  m+m-  \A\A\A\A  m+m0  \A "
    DB  "m-m+  \A\A\A\A  m-m-  \A\A\A\A  m-m0  \A "
    DB  "m0m+  \A\A\A\A  m0m-  \A\A\A\A  m0m0  \A "
    DB  "IOm+  \A\A\A\A  IOm-  \A\A\A\A  IOm0  \A "
    DB  "                                "
    DB  "Short cont:  \A\A\A\A \A\A\A\A  (4+4)   "
    DB  "First flashing border block:    "
    DB  " *4T: 6.5 rows   6T:  9.5 rows  "
    DB  "  5T: 8.0 rows   7T: 11.3 rows  "
    DB  " (* = desired outcome)          "
    DB  "Second block is standard timing?"
    DB  " if 3+3T: 9.5 rows, UA858D is 4T"
    DB  "Both blocks are 2918B transfer  "
    DB  "from memory to I/O ULA port $FE "
    DB  "DMA port: $   Press P to change."
    DB  0

;; DMA sequence to send the border letters "DMA" into top border area

DmaBorderText:
    DB  DMA_DISABLE
    DB  %0'1111'0'01        ; WR0 = B->A transfer, port A address, length
    DW  BorderTextGfx       ; source data address
    DW  BorderTextGfxSz     ; block length (will transfer +1 bytes, there is one "red" after this)
    DB  %0'1'01'0'100, 0x0E ; WR1 = A memory, ++, timing 2T
    DB  %0'1'10'1'000, 0x0E ; WR2 = B I/O, +0, timing 2T
    DB  %1'01'0'11'01       ; WR4 = continuous mode, port B address
    DW  ULA_P_FE
    DB  DMA_LOAD            ; load port B (fixed address)
    DB  %0'0000'1'01        ; WR0 = A->B transfer
    DB  %10'0'0'0010        ; WR5 = end after block, /CE only
    DB  DMA_FORCE_READY, DMA_ENABLE     ; ship it!
DmaBorderTextSz EQU $ - DmaBorderText

    DB  2
BorderTextGfx:
       ;0               8               16              24              32              40     |44      48              56 = 57B total
    DB    4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,5,5,0,0,0,5,0,0,0,5,0,0,5,5,0,0,5,0,5,0,5,0,5,0,5,0,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,5,5,5,0,0,5,0,0,0,5,0,0,5,5,0,0,0,5,0,5,0,5,0,5,0,5,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,7,7,0,0,7,7,0,7,7,0,7,7,7,7,0,5,0,7,0,5,0,5,0,5,0,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,5,0,5,5,0,5,5,0,5,5,0,5,0,0,5,0,0,7,0,7,0,5,0,5,0,5,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,0,7,7,0,7,7,7,7,7,0,7,0,0,7,0,7,0,5,0,7,0,5,0,5,0,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,0,0,7,0,7,7,7,7,7,0,7,0,0,7,0,0,5,0,5,0,7,0,5,0,7,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,0,0,7,0,7,0,7,0,7,0,7,0,0,7,0,5,0,7,0,5,0,7,0,7,0,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,0,0,7,0,7,0,7,0,7,0,7,7,7,7,0,0,7,0,7,0,5,0,7,0,5,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,0,0,7,0,7,0,0,0,7,0,7,7,7,7,0,7,0,5,0,7,0,5,0,5,0,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,0,7,7,0,7,0,0,0,7,0,7,7,7,7,0,0,5,0,5,0,7,0,5,0,7,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,5,0,5,5,0,5,0,0,0,5,0,5,0,0,5,0,5,0,5,0,5,0,7,0,7,0,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,7,7,7,0,0,7,0,0,0,7,0,7,0,0,7,0,0,5,0,5,0,5,0,7,0,5,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,5,5,5,0,0,5,0,0,0,5,0,5,0,0,5,0,5,0,5,0,5,0,5,0,5,0,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,5,0,0,5,5,0,0,0,5,0,0,0,5,0,5,0,0,5,0,0,5,0,5,0,5,0,5,0,5,0,0,5,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,6
BorderTextGfxSz EQU     $ - BorderTextGfx
    DB  2

    ALIGN   256, $CC            ; align to boundary
    BLOCK   256, ATTR_BAD       ; markers to signal extra/wrong bytes transfer
DmaSrcData4B:
    ; source pattern, 2x bright, non-bright, 1x bright
    DB      ATTR_DMA_B, ATTR_DMA_B, ATTR_DMA, ATTR_DMA_B
    ALIGN   256, ATTR_BAD       ; fill the red+red marker also after the source
DmaSrcData1B:
    DB      ATTR_DMA_B
    ALIGN   256, ATTR_BAD       ; fill the red+red marker also after the source
DmaSrcData9B:
    DB      ATTR_DMA_B, ATTR_DMA_B, ATTR_DMA, ATTR_DMA
    DB      ATTR_DMA, ATTR_DMA, ATTR_DMA, ATTR_DMA
    DB      ATTR_DMA, ATTR_DMA_B
    ALIGN   256, ATTR_BAD       ; fill the red+red marker also after the source

    ALIGN   256
IM2_IVT     EQU high $
IM2_HANDLER EQU ((IM2_IVT+1)<<8)|(IM2_IVT+1)
    BLOCK   257, IM2_IVT+1

Im2TempByte DB  0
    org     IM2_HANDLER
Im2Handler:
    push    af
    push    bc
    push    hl
.TimeCnt    EQU $+1
    ld      a,0
    inc     a
    cp      25                  ; 0.5s wait
    jp      nc,.twoSecPassed
    ; make the result different, but keep T states identical for both code paths
    ld      hl,Im2TempByte
    jp      .updateTimeCnt
.twoSecPassed:
    ld      hl,DmaSrcData1B
    jp      .updateTimeCnt

.updateTimeCnt:
    ld      c,a
    sbc     a,a                 ; $00 when CF=0, $FF when CF=1
    and     c                   ; keep or reset time counter
    ld      (.TimeCnt),a
    ; chage color (for BORDER change)
    ld      a,(hl)
    inc     a
    and     $07
    ld      (hl),a
    ;; do the top border text part + wait till PAPER
    ; do the top border color based on the port currently used (black=MB02, yellow=Datagear)
    ld      a,(DmaPortData)
    ld      c,a                 ; also sets C = DMA port
    rrca
    rrca
    rrca
    rrca
    and     7
    out     (ULA_P_FE),a
    ; wait few lines (to almost reach PAPER area)   ; timed for toastrack + UA858D
    ld      b,36
    djnz    $       ; 13/8T  35*13 + 8 = 463T
    djnz    $       ; 255*13 + 8 = 3323T
    djnz    $       ; 255*13 + 8 = 3323T
    nop             ; 4T
    nop             ; 4T
    nop             ; 4T

;     nop : nop : nop   ; extra shift for zeseruse

    ; do the border effect with DMA transfer
    ld      hl,DmaBorderText
    ld      b,DmaBorderTextSz
    otir            ; 21/16
    ; return from interrupt
    pop     hl
    pop     bc
    pop     af
    ei
    ret

    IFNDEF BUILD_TAP
        savesna "dmaDebug.sna", Start
    ELSE
        savebin "dma8000.bin", BinStart, $-BinStart
        shellexec "bin2tap -o dmaDebug.tap -a 32768 -b -r 32768 dma8000.bin && rm dma8000.bin"
    ENDIF

/*
; original "DMA3" demo by Busy - DMA init sequence for drawing into border area
; does run at 2T/2T timing on UA858D chip, does NOT run on Zilog (early WR3, no load of fixed #FE)
109    82af c3c7cb     com    db   #c3,#c7,#cb  ;reset, reset_pA, reset_pB
110    82b2 7d                db   #7d          ;WR0 A->B, transfer, adr, length
111    82b3 8b92       add    dw   video        ;adr
112    82b5 7b0d       len    dw   vilen        ;len
113    82b7 54                db   #54          ;WR1 mem++, timing
114    82b8 0e                db   cas          ;cas 0x0E -> 0000'1110  /WR/RD ends 1/2 early, /MREQ/IORQ full
115    82b9 68                db   #68          ;WR2 I/O, fixed, timing
116    82ba 0e                db   cas          ;cas 0x0E
117    82bb c0                db   #c0          ;WR3 = enable (premature?)
118    82bc ad                db   #ad          ;WR4 = continuous mode, portB adr
119    82bd fe00              dw   #fe          ;#FE (border/ULA port)
120    82bf 82                db   #82          ;WR5 = stop on end, /CE, ready active low
121    82c0 cfb387            db   #cf,#b3,#87  ;LOAD, FORCE_READY, ENABLE

; my fixed version to work also on Zilog (should), verified by Busy himself with UA858D
com    db   #c3          ;reset (does reset also port timing)
       db   #79          ;WR0 B->A, transfer, adr, length  (B->A to load portB!)
add    dw   video        ;adr
len    dw   vilen        ;len
       db   #54          ;WR1 mem++, timing
       db   cas          ;cas 0x0E -> /WR/RD ends 1/2 early, /MREQ/IORQ full, 2 cycles
       db   #68          ;WR2 I/O, fixed increment, timing
       db   cas          ;cas 0x0E
       db   #80          ;WR3 reset WR3 (interrupt=0) to get stable output time from UA858D chip
       db   #ad          ;WR4 = continuous mode, portB adr
       dw   #fe          ;#FE (border/ULA port)
       db   #82          ;WR5 = stop on end, /CE, ready active low
       db   #cf          ;LOAD fixed portB (must be "source" to load)
       db   #05          ;WR0 A->B, transfer
       db   #cf,#b3,#87  ;LOAD, FORCE_READY, ENABLE (second LOAD is not really needed on UA858D)
*/
