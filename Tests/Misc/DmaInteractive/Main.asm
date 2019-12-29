; This is general Z80 + DMA chip interactive test (trying to detect TBBlue board
; for convenience of user, but should work on regular ZX Spectrum too)
;
; This is fully interactive test intended for experiments with different
; init/command sequences of DMA and reporting its internal state after
; each step, as the Misc/ZilogDMA did show there are some quirks in real
; Zilog DMA chip, and testing them out without interactive tool turned out
; to be quite cumbersome and slow.
;
; This may be also useful to experiment with init sequences of DMA transfers
; for your own code.
;
; When using custom-byte values, or asking the test to do transfers outside
; of test areas, you risk the damage of the test itself. Generally don't enable
; transfers outside of test areas, or double check the values. The test itself
; resides in memory from address $8000 to $97FF.
; While the test will try to parse custom bytes sent to DMA and interpret them
; to keep the current state fresh, it will not try to protect itself.

;     DEFINE  BUILD_TAP

    device zxspectrum48

    org     $8000
BinStart:
    jp      Start

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../OutputFunctions.asm"
    INCLUDE "../../controls.i.asm"

DMA_END_SEQUENCE    EQU     $FF ; will match as WR6 command, but doesn't exist (invalid)

LAST_CMD_BUF_SZ     EQU     7

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

ATTR_UNCOMMITED     EQU     A_BRIGHT|P_BLUE|WHITE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; global state data

    STRUCT StateData_Port
adjust              BYTE    1       ; 0="--", 1="++", 2="+0"
timing              BYTE    $FF     ; 0xFF is special value (standard timing)
adr                 WORD
    ENDS

    STRUCT StateData_Partial
a                   StateData_Port  {,,MEM_ZX_ATTRIB_5800+$20*1+13}
b                   StateData_Port  {,,MEM_ZX_ATTRIB_5800+$20*3+13}
mode                BYTE    %01     ; %00 = byte, %01 = continuous, %10 = burst
direction           BYTE    $0A     ; $0A=A->B $0B=A<-B
length              WORD    $0002   ; 3-bytes transfers for test purposes
    ENDS


    STRUCT StateData
isEditMode          BYTE    0       ; 0=normal UI, 0!=edit mode (cursor at position)
isCByteStandard     BYTE    1       ; 1=custom byte is "standard" (dynamic per purpose)
customByte          BYTE    $00     ; specific custom byte entered (not standard)
isPixelTransfer     BYTE    0       ; source/destination data are 1=pixels/0=attributes
edit                StateData_Partial   ; currently edited values by user (not committed)
wr                  StateData_Partial   ; WR values (known to the test) (committed values)
diff                WORD    -1      ; bits from 8: mode, dir, length, B.tim, B.adj, B.adr, A.tim, A.adj, A.adr
portAtype           BYTE    0       ; $00/$08 = mem/IO
portBtype           BYTE    0       ; $00/$08 = mem/IO
rrStatus            BYTE    0
rrCnt               WORD    0
rrAadr              WORD    0
rrBadr              WORD    0
awaitingWriteBytes  BYTE    0
writeScrAdr         WORD    0
lastCmdBuffer       BLOCK   LAST_CMD_BUF_SZ, $FF
caps                BYTE    $FF     ; $FF = regular key, $00 = caps shift
symbol              BYTE    $FF     ; $FF = regular key, $00 = symbol shift
    ENDS

s                   StateData       ; working state of the test
stateInitSet        StateData       ; read-only init-data for test restarts (⌥p)

playSequence        DW      DmaEmptySequence

    STRUCT WR6_CMD_DATA
name                WORD            ; name of command (string to display)
length              BYTE    1       ; how many bytes the command has
                    ALIGN   4
    ENDS

cmd_name_invalid    DZ      '!INVALID!'
cmd_name_83         DZ      'DISABLE'   ; DMA_DISABLE
cmd_name_87         DZ      'ENABLE'    ; DMA_ENABLE
cmd_name_8B         DZ      'CL.STATUS' ; DMA_REINIT_STATUS_BYTE
cmd_name_A3         DZ      'RST D.INT' ; DMA_RESET_DISABLE_INTERUPTS
cmd_name_A7         DZ      'ST.RD.SEQ' ; DMA_START_READ_SEQUENCE
cmd_name_AB         DZ      'INT ENABL' ; DMA_ENABLE_INTERUPTS
cmd_name_AF         DZ      'INT DISAB' ; DMA_DISABLE_INTERUPTS
cmd_name_B3         DZ      'FORCE RDY' ; DMA_FORCE_READY
cmd_name_B7         DZ      'EN.A.RETI' ; DMA_ENABLE_AFTER_RETI
cmd_name_BB         DZ      'RD MASK='  ; DMA_READ_MASK_FOLLOWS
cmd_name_BF         DZ      'RD STATUS' ; DMA_READ_STATUS_BYTE
cmd_name_C3         DZ      'RESET'     ; DMA_RESET
cmd_name_C7         DZ      'RESET A t' ; DMA_RESET_PORT_A_TIMING
cmd_name_CB         DZ      'RESET B t' ; DMA_RESET_PORT_B_TIMING
cmd_name_CF         DZ      'LOAD'      ; DMA_LOAD
cmd_name_D3         DZ      'CONTINUE'  ; DMA_CONTINUE

    ALIGN           128
WR6_cmd_data_table:
    WR6_CMD_DATA    { cmd_name_83 }
    WR6_CMD_DATA    { cmd_name_87 }
    WR6_CMD_DATA    { cmd_name_8B }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_A3 }
    WR6_CMD_DATA    { cmd_name_A7 }
    WR6_CMD_DATA    { cmd_name_AB }
    WR6_CMD_DATA    { cmd_name_AF }
    WR6_CMD_DATA    { cmd_name_B3 }
    WR6_CMD_DATA    { cmd_name_B7 }
    WR6_CMD_DATA    { cmd_name_BB, 2 }
    WR6_CMD_DATA    { cmd_name_BF }
    WR6_CMD_DATA    { cmd_name_C3 }
    WR6_CMD_DATA    { cmd_name_C7 }
    WR6_CMD_DATA    { cmd_name_CB }
    WR6_CMD_DATA    { cmd_name_CF }
    WR6_CMD_DATA    { cmd_name_D3 }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }
    WR6_CMD_DATA    { cmd_name_invalid }

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DMA logic utility functions

SendDmaByte:
    ;; TODO: this doesn't recognize some of the possible extra bytes (interrupt control byte)
    ; store the byte in the lastCmdBuffer
    ld      hl,(s.lastCmdBuffer+1)
    ld      (s.lastCmdBuffer),hl
    ld      hl,(s.lastCmdBuffer+3)
    ld      (s.lastCmdBuffer+2),hl
    ld      hl,(s.lastCmdBuffer+5)
    ld      (s.lastCmdBuffer+4),hl
    ld      (s.lastCmdBuffer+6),a
    ; check if this is first byte of new command/write
    ; if yes, scroll, init the new command/write, identify length, display, ...
    ld      b,a
    ld      a,(s.awaitingWriteBytes)
    or      a
    jp      nz,.nextGroupByte
    ; new command
    call    ScrollUpBottomTwoThirdsByRow
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20*7
    ld      (OutCurrentAdr),hl
    ; identify the command and print it's basic name, and get the count of bytes expected
    ld      a,b
    xor     %1000'0011
    and     %1000'0011
    jr      nz,.notWR6
    ; WR6 (command) detected - print name, setup expected bytes, set OutCurrentAdr
    ld      a,'c'
    call    OutChar
    ld      a,' '
    call    OutChar
    ld      a,b
    cp      DMA_RESET
    jr      nz,.notResetCommand
    ld      (ix + StateData.wr.a.timing),$FF
    ld      (ix + StateData.wr.b.timing),$FF
    jr      .stateUpdated
.notResetCommand:
    cp      DMA_RESET_PORT_A_TIMING
    jr      nz,.notResetPortACommand
    ld      (ix + StateData.wr.a.timing),$FF
    jr      .stateUpdated
.notResetPortACommand:
    cp      DMA_RESET_PORT_B_TIMING
    jr      nz,.stateUpdated
    ld      (ix + StateData.wr.b.timing),$FF
.stateUpdated:
    and     %0111'1100
    add     a,low WR6_cmd_data_table
    ld      l,a
    ld      h,high WR6_cmd_data_table
    ld      e,(hl)
    inc     hl
    ld      d,(hl)
    inc     hl
    ex      de,hl
    call    OutString
    ld      a,(de)
    rlca
    neg
    add     a,$20*7+14
    ld      (OutCurrentAdr),a
    ld      a,(de)
    jp      .finishNewCommand
.notWR6:
    ld      a,'W'
    call    OutChar
    ld      a,'R'
    call    OutChar
    ld      a,b
    and     %1000'0011
    jr      nz,.notWR1or2
    ; WR1 or WR2
    ld      a,b
    rrca
    rrca
    rra                 ; A = %00006aaI ; CF=1 WR1, CF=0 WR2, 6 = D6 (+1B), aa=adjust, I=mem/IO
    jr      nc,.isWR2
    ; WR1
    push    af
    ld      a,1
    ld      (s.lastCmdBuffer+5),a   ; create bytes 01 WR1 in buffer
    ld      a,b
    and     8
    ld      (s.portAtype),a
    ld      a,'1'
    call    OutChar
    pop     af
    rra
    and     3
    ld      (s.wr.a.adjust),a
    jr      .finishWR1and2
.isWR2:
    push    af
    ld      a,2
    ld      (s.lastCmdBuffer+5),a   ; create bytes 02 WR2 in buffer
    ld      a,b
    and     8
    ld      (s.portBtype),a
    ld      a,'2'
    call    OutChar
    pop     af
    rra
    and     3
    ld      (s.wr.b.adjust),a
.finishWR1and2:
    ld      a,' '
    call    OutChar
    ld      a,b
    rlca
    rlca
    and     1
    inc     a
    jr      .finishNewCommand
.notWR1or2:
    bit     7,b
    jr      nz,.notWR0
    ; WR0
    xor     a
    ld      (s.lastCmdBuffer+5),a   ; create bytes 00 WR0 in buffer
    ld      a,'0'
    call    OutChar
    ld      a,' '
    call    OutChar
    ld      a,CUSTOM_CHAR_DIRR
    bit     2,b
    jr      nz,.dirAtoB
    inc     a
.dirAtoB:
    ld      (s.wr.direction),a
    ; calculate how many extra bytes are expected
    ld      l,b
    ld      a,1
    rl      l
    rl      l
    adc     a,0
    rl      l
    adc     a,0
    rl      l
    adc     a,0
    rl      l
    adc     a,0
    jr      .finishNewCommand
.notWR0:
    ; WR3, WR4, WR5     ; A = %1000'00xx (xx = 0,1,2)
    add     a,'3'+$80   ; -> '3', '4', '5'
    call    OutChar
    ld      a,' '
    call    OutChar
    ld      a,1         ; awaiting only this one byte
    bit     0,b
    jr      z,.finishNewCommand     ; WR3 and WR5 are done like this (no parsing)
    ; WR4
    ld      a,3
    ld      (s.lastCmdBuffer+5),a   ; create bytes 03 WR4 in buffer
    ld      a,b
    rlca
    rlca
    rlca
    and     3
    ld      (s.wr.mode),a
    ld      a,1
    bit     2,b
    jr      z,.noPortBadrLSB
    inc     a
.noPortBadrLSB:
    bit     3,b
    jr      z,.finishNewCommand
    inc     a
.finishNewCommand:
    ld      hl,(OutCurrentAdr)
    ld      (s.writeScrAdr),hl
.nextGroupByte:
    dec     a
    push    af
    ld      (s.awaitingWriteBytes),a
    ld      hl,(s.writeScrAdr)
    ld      (OutCurrentAdr),hl
    ld      a,b
    call    OutHexaValue
    ld      hl,(OutCurrentAdr)
    ld      (s.writeScrAdr),hl
    ; send it to DMA port (immediately)
    out     (c),a
    pop     af
    ret     nz
    ;; this was the last byte of the command sequence - do the aftermath stuff
        ; if command was DMA_READ_STATUS_BYTE ... only status byte should be read. Ignored now
    ; scan the command sequence and if WR0124, refresh internal state accordingly
    ld      hl,s.lastCmdBuffer-1
    ld      a,$FF
.searchCmdByteLoop:
    inc     hl
    cp      (hl)
    jr      z,.searchCmdByteLoop
    and     (hl)                ; $FF&value = value && ZF=1 when 0
    inc     hl
    ld      b,(hl)              ; WRx itself
    jr      z,.updateWR0State
    ld      de,s.wr.a.timing
    dec     a
    jr      z,.updateWR12State
    ld      de,s.wr.b.timing
    dec     a
    jr      z,.updateWR12State
    dec     a
    jr      nz,.WRstateUpdated
    ; updateWR4State
    bit     2,b
    jr      z,.updateWR4_adrMSB
    inc     hl
    ld      a,(hl)              ; portB address LSB
    ld      (s.wr.b.adr),a
.updateWR4_adrMSB:
    bit     3,b
    jr      z,.WRstateUpdated
    inc     hl
    ld      a,(hl)              ; portB address MSB
    ld      (s.wr.b.adr+1),a
    jr      .WRstateUpdated
.updateWR0State:
    bit     3,b
    jr      z,.updateWR0_adrMSB
    inc     hl
    ld      a,(hl)              ; portA address LSB
    ld      (s.wr.a.adr),a
.updateWR0_adrMSB:
    bit     4,b
    jr      z,.updateWR0_lenLSB
    inc     hl
    ld      a,(hl)              ; portA address MSB
    ld      (s.wr.a.adr+1),a
.updateWR0_lenLSB:
    bit     5,b
    jr      z,.updateWR0_lenMSB
    inc     hl
    ld      a,(hl)              ; Length LSB
    ld      (s.wr.length),a
.updateWR0_lenMSB:
    bit     6,b
    jr      z,.WRstateUpdated
    inc     hl
    ld      a,(hl)              ; Length MSB
    ld      (s.wr.length+1),a
    jr      .WRstateUpdated
.updateWR12State
    bit     6,b
    jr      z,.WRstateUpdated
    inc     hl
    ld      a,(hl)              ; Timing byte
    ld      (de),a
.WRstateUpdated:
    ; clear the last command buffer
    ld      hl,$FFFF
    ld      (s.lastCmdBuffer),hl
    ld      (s.lastCmdBuffer+2),hl
    ld      (s.lastCmdBuffer+4),hl
    ld      (s.lastCmdBuffer+5),hl
    ; read the DMA internal state
    ld      a,DMA_START_READ_SEQUENCE
    out     (c),a
    ld      hl,s.rrStatus
    ld      b,7
    inir
    ; output the DMA internal state to the end of line
    ld      hl,OutCurrentAdr+1
    ld      (hl),high (MEM_ZX_SCREEN_4000+$1000+$20*7+15)
    dec     hl
    ld      (hl),low (MEM_ZX_SCREEN_4000+$1000+$20*7+15)
    ld      a,(s.rrStatus)
    call    OutHexaValue
    inc     (hl)
    ld      a,(s.rrCnt+1)
    call    OutHexaValue
    ld      a,(s.rrCnt)
    call    OutHexaValue
    inc     (hl)
    ld      a,(s.rrAadr+1)
    call    OutHexaValue
    ld      a,(s.rrAadr)
    call    OutHexaValue
    inc     (hl)
    ld      a,(s.rrBadr+1)
    call    OutHexaValue
    ld      a,(s.rrBadr)
    call    OutHexaValue
    ; modify attributes of read values to use blue ink
    ld      hl,MEM_ZX_ATTRIB_5800+$20*23+15
    ld      b,32-15
.SetBlueInkLoop:
    inc     (hl)            ; assumes black ink! :)
    inc     l
    djnz    .SetBlueInkLoop
    ; refresh the display with values in upper third of screen
    jp      RedrawValues

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
    ; create small line between top third and rest
    ld      hl,MEM_ZX_SCREEN_4000+$700+$20*7+0
    ld      b,32-7
.solidLineLoop:
    ld      (hl),%11111111
    inc     l
    djnz    .solidLineLoop
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
    jp      RedrawValues

RedrawTextData:
    DB  '  ',13,13,' Pix WR0124',13,'  A T tT   M    '
    DB  'WR3 WR5 Test:QWER B Y tY   L    '
    DB  'LOAD F-RDY ENA RST-S RST-M A    '
    DB  'CONT DIS RST RST-A RST-B D B    '

RedrawAttributeData:
    ; test area block
    BLOCK   32, P_WHITE     ; L0
    BLOCK   32, P_CYAN      ; L1
    BLOCK   32, P_WHITE     ; L2
    BLOCK   32, P_CYAN      ; L3
    ; commands/values block
    ; 38 = white, 28 = cyan, 78 = bright white (regular key) 70 = bright yellow (shift), 58 = bright magenta (caps shift)
    HEX     38 38 70 58 38 78 38 38 38 38 38 38 38 38 38 78 38 38 70 38 78 38 38 70 38 38 38 78 38 38 38 38
    HEX     38 38 58 38 38 38 58 38 38 38 38 38 38 78 78 78 78 38 70 38 78 38 38 70 38 38 38 78 38 38 38 38
    HEX     58 38 38 38 38 58 38 38 38 38 38 58 38 38 38 38 38 38 38 58 38 38 38 38 38 58 38 78 38 38 38 38
    HEX     58 38 38 38 38 58 38 38 38 58 38 38 38 38 38 38 38 58 38 38 38 38 38 58 38 78 38 78 38 38 38 38

    ALIGN   2
RedrawAttributeBg:
    DB      P_BLUE      ; base filler for attribute transfers
    DB      P_YELLOW    ; base filler for pixel transfers

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; redraw transfer areas (resetting the values in source and destination)

RedrawTransferAreas:
    push    bc
    ; clear attributes in both source and destination area
    ld      a,(s.isPixelTransfer)
    add     a,low RedrawAttributeBg
    ld      l,a
    ld      h,high RedrawAttributeBg
    ld      a,(hl)
    ld      d,a
    or      A_BRIGHT
    ld      e,a     ; DE = attribute values for filler
    ld      hl,MEM_ZX_ATTRIB_5800+$20*1
    call    .fillAttributesArea
    ld      hl,MEM_ZX_ATTRIB_5800+$20*3
    call    .fillAttributesArea
    ; clear pixels in both source and destination area
    ; fill with: in pixel mode char "pixel data" / in attributes using "src/dst DMA" char
    ld      a,(s.isPixelTransfer)
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
    ld      a,(s.isPixelTransfer)
    add     a,low SrcDataAdr
    ld      l,a
    ld      h,high SrcDataAdr
    ld      d,(hl)
    ld      a,(s.wr.direction)
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
    ld      a,(s.isCByteStandard)
    or      a
    jr      z,.fillWithCustomByte
    ; standard byte for pixels %1000'0010 += 2
    ; standard byte for attributes %01'100'000 += 1
    ld      a,(s.isPixelTransfer)
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
    ld      a,(s.customByte)
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
; swap transfer areas (keeping the values, but flips source/destination area)

SwapTransferAreas:
    ld      hl,$5821
    ld      de,$5861
    ld      c,1
    call    .swap30bytes
    ld      hl,$4021
    ld      de,$4061
    ld      c,8
.swap30bytes:
    push    hl
    push    de
    push    bc
    ld      b,30
.swapByte:
    ld      c,(hl)
    ld      a,(de)
    ld      (hl),a
    ld      a,c
    ld      (de),a
    inc     l
    inc     e
    djnz    .swapByte
    pop     bc
    pop     de
    pop     hl
    inc     h
    inc     d
    dec     c
    jr      nz,.swap30bytes
    ret

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
    ld      a,(s.wr.a.adjust)
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

    ; highlight also "edit" address of port A by brightness in attribute
    ld      hl,MEM_ZX_ATTRIB_5800+$20*0
    ld      de,(s.edit.a.adr)
    call    DrawEditAdrPointer

    ; "erase" old PortB positions by using white on white attribute color
    ld      hl,MEM_ZX_ATTRIB_5800+$20*2
    ld      de,MEM_ZX_ATTRIB_5800+$20*2+1
    ld      (hl),P_WHITE|WHITE
    call    ScrollUpBottomTwoThirdsByRow.unrolled31LDI
    ld      hl,MEM_ZX_SCREEN_4000+$20*2

    ; redraw PortB symbols at new positions
    ld      a,(s.wr.b.adjust)
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

    ; highlight also "edit" address of port B by brightness in attribute
    ld      hl,MEM_ZX_ATTRIB_5800+$20*2
    ld      de,(s.edit.b.adr)
    call    DrawEditAdrPointer

    ; redraw custom byte content
    ld      hl,MEM_ZX_SCREEN_4000+$20*4+0
    ld      (OutCurrentAdr),hl
    xor     a
    call    Clear2Char
    ld      a,(s.isEditMode)
    or      a
    jr      z,.notInEditMode
    add     a,low (MEM_ZX_ATTRIB_5800+$20*4-1)
    ld      l,a
    ld      h,high (MEM_ZX_ATTRIB_5800+$20*4+0)
    ld      (hl),A_FLASH|A_BRIGHT|P_WHITE|BLACK
.notInEditMode:
    ld      a,(s.isCByteStandard)
    dec     a
    jr      z,.showStandardByte
    ld      a,(s.customByte)
    call    OutHexaValue
    jr      .customByteDrawn
.showStandardByte:
    ld      a,CUSTOM_CHAR_STD
    call    OutCharWithCustomGfx
    call    OutCharWithCustomGfx
.customByteDrawn:

    ; port data (adjust, timing)
    ld      hl,MEM_ZX_SCREEN_4000+$20*4+19
    ld      iy,s.edit.a
    call    DrawPortData
    ld      hl,MEM_ZX_SCREEN_4000+$20*5+19
    ld      iy,s.edit.b
    call    DrawPortData

    ; draw transfer direction
    ld      hl,MEM_ZX_SCREEN_4000+$20*7+26
    xor     a
    call    Clear1Char
    ld      b,(ix + StateData.edit.direction)
    xor     a
    call    OutBCharAtA

    ; draw mode
    ld      hl,MEM_ZX_SCREEN_4000+$20*4+28
    ld      (OutCurrentAdr),hl
    xor     a
    ld      b,a
    call    Clear4Char
    ld      a,(s.edit.mode)
    add     a,a
    add     a,a
    add     a,a
    ld      c,a
    ld      hl,ModeStringsPer8B
    add     hl,bc
    call    OutString

    ; draw length, addressA, addressB words
    ld      hl,MEM_ZX_SCREEN_4000+$20*5+28
    ld      de,s.edit.length+1
    call    DrawWordValue

    ld      hl,MEM_ZX_SCREEN_4000+$20*6+28
    ld      de,s.edit.a.adr+1
    call    DrawWordValue

    ld      hl,MEM_ZX_SCREEN_4000+$20*7+28
    ld      de,s.edit.b.adr+1
    call    DrawWordValue

    ; colorize the values which are not commited
    ; diff WORD => from 8: mode, dir, length, B.tim, B.adj, B.adr, A.tim, A.adj, A.adr
    call    RefreshDiffBits
    ; reset all WR0124 indicators to regular white+black
    ld      hl,$3838
    ld      (MEM_ZX_ATTRIB_5800+$20*4+11),hl
    ld      (MEM_ZX_ATTRIB_5800+$20*4+13),hl
    ; WR0: %01 in D1D0 ("transfer") - this test does not support/show other options!
    ; direction D2: 0 = A<-B, 1 = A->B, port A adr: D4D3, length: D6D5
    ld      hl,MEM_ZX_ATTRIB_5800+$20*4+11
    ld      bc,(1<<8) | %1'1'000'001    ; WR0: dir, length, A.adr
    call    MarkUncommitedDifference
    ; WR1: D3: A-type (not in diff), A-adjust D5D4, A-timing D6+byte
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*4+12)
    ld      bc,(1<<8) | %0'0'000'110    ; WR1: A.tim, A.adj
    call    MarkUncommitedDifference
    ; WR2: D3: B-type (not in diff), B-adjust D5D4, B-timing D6+byte
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*4+13)
    ld      bc,(1<<8) | %0'0'110'000    ; WR2: B.tim, B.adj
    call    MarkUncommitedDifference
    ; WR4: mode D6D5, port B adr: D3D2
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*4+14)
    ld      a,(s.diff + 1)
    rra
    ld      a,(s.diff)
    rla     ; shift diff + add mode bit
    ld      bc,(1<<8) | %0'001'000'1    ; WR4: B.adr (shifted), mode
    call    MarkUncommitedDifference.customDiffVal
    ; port A adjustement
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*4+19)
    ld      bc,(1<<8) | %0'0'000'010
    call    MarkUncommitedDifference
    ; port A timing
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*4+21)
    ld      bc,(1<<8) | %0'0'000'100
    call    MarkUncommitedDifference
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*4+24)
    ld      b,2
    call    MarkUncommitedDifference
    ; port B adjustement
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*5+19)
    ld      bc,(1<<8) | %0'0'010'000
    call    MarkUncommitedDifference
    ; port B timing
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*5+21)
    ld      bc,(1<<8) | %0'0'100'000
    call    MarkUncommitedDifference
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*5+24)
    ld      b,2
    call    MarkUncommitedDifference
    ; transfer mode
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*5-4)
    ld      bc,(4<<8) | %0'0'000'001
    ld      a,(s.diff + 1)
    call    MarkUncommitedDifference.customDiffVal
    ; length
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*6-4)
    ld      bc,(4<<8) | %0'1'000'000
    call    MarkUncommitedDifference
    ; A.adr
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*7-4)
    ld      bc,(4<<8) | %0'0'000'001
    call    MarkUncommitedDifference
    ; B.adr
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*8-4)
    ld      bc,(4<<8) | %0'0'001'000
    call    MarkUncommitedDifference
    ; direction
    ld      l,low (MEM_ZX_ATTRIB_5800+$20*8-6)
    ld      bc,(1<<8) | %1'0'000'000
    call    MarkUncommitedDifference

    pop     bc
    ret

ModeStringsPer8B:
    DB      'byte',0,0,0,0
    DB      'cont',0,0,0,0
    DB      'burs',0,0,0,0
    DB      'inva',0,0,0,0

TestAdrToXPos:      ; DE = memory address (or I/O port, treated as memory address :) )
    ; returns A 1..30 (column) for addresses within testing range, 128 for other
    ; Port A attributes: 5821 .. 583E
    ; Port B attributes: 5861 .. 587E
    ; Port A pixels: 4321 .. 433E
    ; Port B pixels: 4361 .. 437E
    ld      a,$43
    cp      d
    jr      z,.HighAddressInTestRange
    ld      a,$58
    cp      d
    jr      z,.HighAddressInTestRange
.addressOutsideOfTestRange:
    ld      a,128
    ret
.HighAddressInTestRange:
    ld      a,e
    cp      $21
    jr      c,.addressOutsideOfTestRange
    cp      $7E+1
    jr      nc,.addressOutsideOfTestRange
    cp      $3E+1
    jr      c,.LowAddressInTestRange
    cp      $61
    jr      c,.addressOutsideOfTestRange
.LowAddressInTestRange:
    and     $1F
    ret

MarkUncommitedDifference:   ; HL = target address start, B = length to mark, C = mask
    ld      a,(s.diff)
.customDiffVal:
    and     c
    ret     z
.markLoop:
    ld      (hl),ATTR_UNCOMMITED
    inc     l
    djnz    .markLoop
    ret

RefreshDiffBits:
    ; diff WORD => bits from 8: mode, dir, length, B.tim, B.adj, B.adr, A.tim, A.adj, A.adr
    xor     a
    ld      hl,(s.edit.mode)
    ld      de,(s.wr.mode)
    call    .testByte
    ld      (s.diff + 1),a
    xor     a
    ld      hl,(s.edit.direction)
    ld      de,(s.wr.direction)
    call    .testByte
    ld      hl,(s.edit.length)
    ld      de,(s.wr.length)
    call    .testWord
    ld      hl,(s.edit.b.timing)
    ld      de,(s.wr.b.timing)
    call    .testByte
    ld      hl,(s.edit.b.adjust)
    ld      de,(s.wr.b.adjust)
    call    .testByte
    ld      hl,(s.edit.b.adr)
    ld      de,(s.wr.b.adr)
    call    .testWord
    ld      hl,(s.edit.a.timing)
    ld      de,(s.wr.a.timing)
    call    .testByte
    ld      hl,(s.edit.a.adjust)
    ld      de,(s.wr.a.adjust)
    call    .testByte
    ld      hl,(s.edit.a.adr)
    ld      de,(s.wr.a.adr)
    call    .testWord
    ld      (s.diff),a
    ret

.testByte:  ; L vs E
    ld      d,h     ; make D/H irrelevant to the comparison
    ;
    ; fallthrough into .testWord
    ;
.testWord:  ; HL vs DE
    rlca    ; make space for new diff-bit and set CF=0
    sbc     hl,de
    ret     z
    inc     a
    ret

DrawWordValue:
    ld      (OutCurrentAdr),hl
    xor     a
    call    Clear4Char
    ld      a,(de)
    call    OutHexaValue
    dec     de
    ld      a,(de)
    jp      OutHexaValue

DrawPortData:
    xor     a
    call    Clear1Char
    ld      a,2
    call    Clear1Char
    ld      a,5
    call    Clear2Char
    ld      a,(iy + StateData_Port.adjust)
    add     a,CUSTOM_CHAR_AMM
    ld      b,a
    xor     a
    call    OutBCharAtA
    inc     l
    inc     l
    ld      (OutCurrentAdr),hl
    ld      a,(iy + StateData_Port.timing)
    xor     $FF
    jr      z,.standardTiming
    and     3
    inc     a
    call    OutHexaDigit
    inc     l
    inc     l
    inc     l
    ld      (OutCurrentAdr),hl
    ld      a,(iy + StateData_Port.timing)
    jp      OutHexaValue
.standardTiming:
    ld      a,'3'
    call    OutChar
    ld      b,CUSTOM_CHAR_STD
    ld      a,3
    call    OutBCharAtA
    ld      a,4
    jp      OutBCharAtA

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

;; highlights source/destination address DE by using bright attribute (for "edit")
DrawEditAdrPointer: ; DE = edit.portA.adr, HL = VRAM attributes line address
    call    TestAdrToXPos
    cp      32
    ret     nc      ; edit pos is outside of valid range (how???)
    ld      e,a
    ld      d,0
    add     hl,de
    ld      a,(hl)
    or      A_BRIGHT
    ld      (hl),a
    ret

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

Clear1Char:     ; HL = base address (VRAM), A will be added (must not CF=1)
    push    hl
    add     a,l
    ld      l,a
    xor     a
    ld      (hl),a
    inc     h
    ld      (hl),a
    inc     h
    ld      (hl),a
    inc     h
    ld      (hl),a
    inc     h
    ld      (hl),a
    inc     h
    ld      (hl),a
    inc     h
    ld      (hl),a
    inc     h
    ld      (hl),a
    ld      a,h
    add     a,$11
    ld      h,a
    ld      a,P_WHITE
    ld      (hl),a
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

PatchAttrExtra:             ; HL = base attribute VRAM address, DE = patch data
    ld      a,(de)
    inc     de
    inc     a
    ret     z
    add     a,l
    ld      l,a
    ld      a,(de)
    inc     de
    ld      (hl),a
    jr      PatchAttrExtra

DisplayError:
    push    hl
    call    ScrollUpBottomTwoThirdsByRow
    ld      hl,MEM_ZX_ATTRIB_5800+$20*23+0
    ld      b,32
.AttrLoop:
    ld      (hl),P_RED|WHITE
    inc     l
    djnz    .AttrLoop
    pop     hl
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    jp      OutStringAtDe

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; keyboard handler + key handlers

MyRefreshKeyboardState:
    ; refresh caps-shift, and symbol-shift first, then run the Refresh from controls.i.asm
    ld      bc,ULA_P_FE + ($FE<<8)
    in      a,(c)
    rra
    sbc     a,a
    ld      (s.caps),a
    cpl
    jr      z,.capsIsPressed    ; ZF is still set from SBC, A=FF when CS=0
    ; refresh symbol shit status, but allow it only when caps is released
    ld      b,$7F
    in      a,(c)
    rra
    rra
    sbc     a,a
.capsIsPressed:
    ld      (s.symbol),a
    jp      RefreshKeyboardState

handleKey_Q:            ; test scenario1, caps=redraw+reinit
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jp      nc,RedrawScreen ; redraw upper third of screen fully (including "CLS")
    ; test scenario 1
    ld      hl,TestScenario1
    ld      (playSequence),hl
    ld      a,'1'
    ;
    ; fallthrough into FinishTestScenarioSetup
    ;
FinishTestScenarioSetup:
    push    af
    call    ScrollUpBottomTwoThirdsByRow
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    ld      hl,TestScenarioTxt
    call    OutStringAtDe
    pop     af
    jp      OutChar

handleKey_W:            ; test scenario2
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    ret     nc
    ; test scenario 2
    ld      hl,TestScenario2
    ld      (playSequence),hl
    ld      a,'2'
    jr      FinishTestScenarioSetup

handleKey_E:            ; test scenario3, caps=DMA_ENABLE
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jr      nc,.dma_enable
    ; test scenario 3
    ld      hl,TestScenario3
    ld      (playSequence),hl
    ld      a,'3'
    jr      FinishTestScenarioSetup
.dma_enable:
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,DMA_ENABLE
    jp      SendDmaByte

handleKey_R:            ; test scenario4, caps=DMA_RESET
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jr      nc,.dma_reset
    ; test scenario 4
    ld      hl,TestScenario4
    ld      (playSequence),hl
    ld      a,'4'
    jr      FinishTestScenarioSetup
.dma_reset:
    ld      (ix + StateData.edit.a.timing),$FF
    ld      (ix + StateData.edit.b.timing),$FF
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,DMA_RESET
    jp      SendDmaByte

handleKey_ENTER:                ; commit WR0124, caps=Send byte to DMA, symbol=edit byte
    rlc     (ix + StateData.symbol)
    jr      c,.noSymbolShift
.enterEditMode:
    ld      (ix + StateData.isEditMode),1
    ld      (ix + StateData.isCByteStandard),1
    ld      (ix + StateData.customByte),0
    call    RedrawValues
    jp      SetKeyHandlers_EditMode
.noSymbolShift:
    rlc     (ix + StateData.caps)
    jr      c,.noCapsShift
.capsEnter:
    ;caps + Enter -> send custom byte to DMA
    ld      a,(s.isCByteStandard)
    or      a
    jr      nz,.refuseToSendStdByte ; standard byte value can't be sent to DMA
    ld      a,(s.customByte)
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    jp      SendDmaByte
.refuseToSendStdByte:
    ld      hl,ErrTxt_StdToDma
    jp      DisplayError
.noCapsShift:
    call    handleKey_4
    call    handleKey_2
    call    handleKey_1
    ;
    ; fallthrough into handleKey_0
    ;
handleKey_0:            ; commit WR0
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    ret     nc
    ld      a,(s.diff)
    and     %1'1'000'001        ; WR0: dir, length, A.adr
    ret     z
    jp      p,.directionDidNotChange
    ; direction change, flip the source/destination data in VRAM
    call    SwapTransferAreas
.directionDidNotChange:
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      b,%00000'01'0       ; future "D8=%0 + D1D0=%01" (for WR0 byte)
    ld      hl,DmaSetWr0Sequence
    ld      iy,s.edit.length+1
    call    .addDataBitAndByte
    dec     iy
    call    .addDataBitAndByte
    ld      iy,s.edit.a.adr+1
    call    .addDataBitAndByte
    dec     iy
    call    .addDataBitAndByte
    ld      a,(s.edit.direction)
    sub     CUSTOM_CHAR_DIRL    ; CF=1 A->B, CF=0 B->A
    ld      a,b
    rla                         ; direction bit
    rlca                        ; rotate them all to final positions
    rlca
    ld      (hl),a              ; final WR0 byte
    ld      (playSequence),hl   ; start the replay of the dynamically prepared data
    ret
.addDataBitAndByte:
    ld      a,(iy)
    cp      (iy + (StateData.wr-StateData.edit))
    jr      z,.sameByte         ; CF=0
    ld      (hl),a
    dec     hl
    scf                         ; CF=1 (byte will be sent)
.sameByte:
    rl      b
    ret

handleKey_1:            ; commit WR1, caps=EDIT (custom byte)
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jp      nc,handleKey_ENTER.enterEditMode
    ld      a,(s.diff)
    and     %0'0'000'110        ; WR1: A.tim, A.adj
    ret     z
    ld      iy,s.edit.a
    ld      d,(ix + StateData.portAtype)
    ld      a,$40               ; set future D2=0 (port A)
    jr      handleKey_WR1_WR2_setPort

handleKey_2:            ; commit WR2
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    ret     nc
    ld      a,(s.diff)
    and     %0'0'110'000        ; WR2: B.tim, B.adj
    ret     z
    ld      iy,s.edit.b
    ld      d,(ix + StateData.portBtype)
    xor     a                   ; clear future D2=0 (port B)
    ;
    ; fallthrough into handleKey_WR1_WR2_setPort
    ;
handleKey_WR1_WR2_setPort:
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      e,(iy + StateData_Port.timing)  ; E = new timing
    or      a,(iy + StateData_Port.adjust)  ; add adjust data
    rlca
    rlca
    rlca
    rlca                        ; position adjust data and port bit
    or      d                   ; add port type
    inc     e                   ; check if timing is standard byte, then leave it out
    jp      z,SendDmaByte
    push    de
    or      $40                 ; timing byte will follow (even if it's not different)
    call    SendDmaByte
    pop     de
    ld      a,e
    dec     a                   ; A = timing byte (restored)
    jp      SendDmaByte

handleKey_4:            ; commit WR4
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    ret     nc
    ld      a,(s.diff + 1)
    rra
    ld      a,(s.diff)
    rla     ; shift diff + add mode bit
    and     %0'001'000'1
    ret     z           ; no difference in WR4, don't commit it
    ld      a,(s.edit.mode)
    rrca
    rrca
    rrca
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    bit     3,(ix + StateData.diff)
    jr      nz,.commitWr4WithAdr
    or      %1'00'0'00'01       ; just WR4 without address
    jp      SendDmaByte
.commitWr4WithAdr:
    or      %1'00'0'11'01       ; WR4 with B.adr
    call    SendDmaByte
    ld      a,(s.edit.b.adr)
    call    SendDmaByte
    ld      a,(s.edit.b.adr+1)
    jp      SendDmaByte

handleKey_M:            ; chg mode, caps=DMA_READ_MASK_FOLLOWS
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jr      nc,.startSetReadMaskReplay
    ; cycle modes: %00 = byte, %01 = continuous, %10 = burst
    ld      a,(s.edit.mode)
    cp      2
    sbc     a,-2
    and     3
    ld      (s.edit.mode),a
    jp      RedrawValues
.startSetReadMaskReplay:
    ld      hl,DmaResetReadMaskOnly
    ld      (playSequence),hl
    ret

handleKey_D:            ; flip direction, caps=DMA_DISABLE
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jr      nc,.dmaDisable
    ; flip direction
    ld      a,(s.edit.direction)
    xor     1
    ld      (s.edit.direction),a
    jp      RedrawValues
.dmaDisable:
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,DMA_DISABLE
    jp      SendDmaByte

handleKey_A:            ; chg A.adr, shift=A.adjust, caps=DMA_RESET_PORT_A_TIMING
    ld      a,DMA_RESET_PORT_A_TIMING
    ld      iy,s.edit.a
.handleIt:
    rlc     (ix + StateData.caps)
    jr      nc,.dma_reset_p
    rlc     (ix + StateData.symbol)
    jr      nc,.adjust
    ; do address +=4 and wrap around all the time
    ; Port A attributes:    5821 .. 583E, Port B attributes:    5861 .. 587E
    ; Port A pixels:        4321 .. 433E, Port B pixels:        4361 .. 437E
    ld      a,(iy + StateData_Port.adr)
    add     a,4
    bit     5,a
    jr      nz,.doNotWrap
    sub     32
.doNotWrap:
    ld      (iy + StateData_Port.adr),a
    jp      RedrawValues
.adjust:
    ld      a,(iy + StateData_Port.adjust)  ; cycle through 0,1,2
    cp      2
    sbc     a,-2
    and     3
    ld      (iy + StateData_Port.adjust),a
    jp      RedrawValues
.dma_reset_p:
    ld      (iy + StateData_Port.timing),$FF
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    jp      SendDmaByte

handleKey_B:            ; chg B.adr, shift=B.adjust, caps=DMA_RESET_PORT_B_TIMING
    ld      a,DMA_RESET_PORT_B_TIMING
    ld      iy,s.edit.b
    jr      handleKey_A.handleIt

handleKey_L:            ; chg length, caps=DMA_LOAD
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jr      nc,.dma_load
    ; change length: cycle through 1..4 (and reset high byte to 0)
    ld      (ix + StateData.edit.length+1),0
    ld      a,(s.edit.length)
    and     3
    inc     a
    ld      (s.edit.length),a
    jp      RedrawValues
.dma_load:
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,DMA_LOAD
    jp      SendDmaByte

handleKey_T:            ; chg A.timing, shift=load custom A.timing
    ld      iy,s.edit.a
.handleIt:
    rlc     (ix + StateData.caps)
    ret     nc
    rlc     (ix + StateData.symbol)
    jr      nc,.customTiming
    ; cycle timing (T-states) through 4,3,2T (%00, %01, %10)
    ld      a,(iy + StateData_Port.timing)
    inc     a           ; increment the value (going 4T, 3T, 2T) (and checks for $FF)
    jr      nz,.wasNotStandard
    ld      a,$0E       ; from standard go straight to $0E custom timing value
.wasNotStandard:
    ld      b,a         ; now check if he incremented value didn't reach %11, if yes, fix
    inc     a
    and     3           ; ZF=1 if the new value has %11 (illegal 1T)
    ld      a,b
    jr      nz,.isStillValid
    xor     3
.isStillValid:
    ld      (iy + StateData_Port.timing),a
    jp      RedrawValues
.customTiming:
    ld      a,(s.isCByteStandard)
    or      a
    ld      a,(s.customByte)
    jr      z,.customTimingFromByte
    ld      a,$0E
.customTimingFromByte:
    ld      (iy + StateData_Port.timing),a
    jp      RedrawValues

handleKey_Y:            ; chg B.timing, shift=load custom B.timing
    ld      iy,s.edit.b
    jr      handleKey_T.handleIt

handleKey_P:            ; flip pixels/attributes, caps=flip port+restart
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    jr      c,.flipPixels
    ; flip the port to the other one (between $6B and $0B)
    ld      a,(DmaPortData)
    xor     Z80_DMA_PORT_DATAGEAR^Z80_DMA_PORT_MB02
    ld      (DmaPortData),a
    ; restart the test completely
    jp      StartAfterPortChange
.flipPixels:
    ld      a,(s.isPixelTransfer)
    xor     1
    ld      (s.isPixelTransfer),a   ; flip the pixel flag
    ; adjust the source/destination addresses
    ld      hl,SrcDataAdr
    ld      c,a
    ld      b,0
    add     hl,bc
    ld      a,(hl)
    ld      b,a         ; target VRAM high byte for new addresses
    xor     $58^$43     ; calculate the "other" value for comparison with current adr.
    cp      (ix + StateData.edit.a.adr+1)
    jr      nz,.PortAhasCustomAddress
    ld      (ix + StateData.edit.a.adr+1),b     ; patch standard address
.PortAhasCustomAddress:
    cp      (ix + StateData.edit.b.adr+1)
    jr      nz,.PortBhasCustomAddress
    ld      (ix + StateData.edit.b.adr+1),b     ; patch standard address
.PortBhasCustomAddress:
    ; commit the modified addresses
    call    RefreshDiffBits
    call    handleKey_4 ; this sends DMA commands directly
    call    handleKey_0 ; this prepares replay buffer
    ; redraw the screen
    call    RedrawTransferAreas
    jp      RedrawValues        ; this may be wasteful as WR0 write *may* follow
        ; but if WR0 does not follow (custom port A address), then this is needed

handleKey_H:            ; outputs couple of hexa values from dst area (from first != 0)
    rlc     (ix + StateData.symbol)
    ret     nc
    rlc     (ix + StateData.caps)
    ret     nc
    ; scroll info lines
    call    ScrollUpBottomTwoThirdsByRow
    ; alternate bright/non-bright per each digit pair
    ld      hl,MEM_ZX_ATTRIB_5800+$20*23+5
    ld      b,7
.highlightPairsOfHexa:
    set     6,(hl)
    inc     l
    set     6,(hl)
    inc     l
    inc     l
    inc     l
    djnz    .highlightPairsOfHexa
    ; calculate destination address
    ld      a,(s.isPixelTransfer)
    add     a,low SrcDataAdr
    ld      l,a
    ld      h,high SrcDataAdr
    ld      h,(hl)
    ld      a,(s.wr.direction)
    and     1
    rrca
    rrca
    xor     $60     ; A = $60 for A->B, $20 for A<-B
    ld      l,a
    ; search for first non-zero value
    ld      b,30-14
.searchForNonZero:
    xor     a
    inc     l
    or      (hl)
    jr      nz,.foundNonZero
    djnz    .searchForNonZero
.foundNonZero:
    ; output the debug info
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    ld      (OutCurrentAdr),de
    ld      a,h
    call    OutHexaValue
    ld      a,l
    call    OutHexaValue
    ld      a,' '
    call    OutChar
    ld      b,13
.dumpVaulues:
    ld      a,(hl)
    inc     l
    call    OutHexaValue
    djnz    .dumpVaulues
    ret

handleKey_C:            ; caps=DMA_CONTINUE
    rlc     (ix + StateData.caps)
    ret     c
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,DMA_CONTINUE
    jp      SendDmaByte

handleKey_F:            ; caps=DMA_FORCE_READY
    rlc     (ix + StateData.caps)
    ret     c
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,DMA_FORCE_READY
    jp      SendDmaByte

handleKey_S:            ; caps=DMA_REINIT_STATUS_BYTE
    rlc     (ix + StateData.caps)
    ret     c
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,DMA_REINIT_STATUS_BYTE
    jp      SendDmaByte

handleKey_3:            ; caps=set WR3
    rlc     (ix + StateData.caps)
    ret     c
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,$80               ; WR3 = disable interrupts and everything
    jp      SendDmaByte

handleKey_5:            ; caps=set WR5
    rlc     (ix + StateData.caps)
    ret     c
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,%10'0'0'0010      ; WR5 = stop after block, /CE only
    jp      SendDmaByte

ErrTxt_StdToDma:
    DZ      'Err: can''t send "standard" byte'

handleKey_ENTER_Edit:
    xor     a
    ld      (s.isEditMode),a
    call    RedrawValues
    call    SetKeyHandlers_UiMode
    ; force "send byte" after edit when the DMA is awaiting more bytes
    ld      bc,(DmaPortData)    ; reload C with DMA port number
    ld      a,(s.awaitingWriteBytes)
    or      a
    ld      a,(s.customByte)    ; send whatever value in customByte (even "standard == 0")
    jp      nz,SendDmaByte
    ; otherwise "send byte" only with Caps shift
    rlc     (ix + StateData.caps)
    ret     c                   ; no caps, just finish edit mode (both regular and symbol)
    jp      handleKey_ENTER.capsEnter

handleKey_HexaDigit:
    ; DE = key_code
    ld      a,e
    rlc     (ix + StateData.caps)
    jr      nc,.capsWithDigit
.findKeyCodeInA:
    ; ignore symbol shift status
    ld      hl,ConvertKeyCodeToHexaDigit
    ld      b,15
.findCurrentKey:
    cp      (hl)
    jr      z,.keyCodeFound
    inc     hl
    djnz    .findCurrentKey
.keyCodeFound:
    ; B = digit value
    ld      (ix + StateData.isCByteStandard),0  ; no more standard byte
    ; move cursor from first to second position (but stay there)
    ld      a,(s.isEditMode)
    ld      l,a
    inc     a
    and     2
    ld      (s.isEditMode),a    ; 1 -> 2, 2 -> 2
    ld      a,$F0           ; which nibble should be kept of current value (cursor=2)
    dec     l
    jr      nz,.cursorWas2
    ; cursor was 1, edit the top nibble
    ld      a,$0F
    rlc     b
    rlc     b
    rlc     b
    rlc     b
.cursorWas2:
    and     (ix + StateData.customByte)
    or      b
    ld      (s.customByte),a
    jp      RedrawValues
.capsWithDigit:
    cp      KEY_0
    jr      z,.delete
    cp      KEY_5           ; arrow left works as delete too
    ret     nz              ; ignore other keys with caps
.delete:
    ; move cursor one position back
    ld      a,(s.isEditMode)    ; 2 -> 1, 1 -> 1
    sub     2
    adc     a,1
    ld      (s.isEditMode),a
    jp      RedrawValues

ConvertKeyCodeToHexaDigit:
    DB      KEY_F, KEY_E, KEY_D, KEY_C, KEY_B, KEY_A, KEY_9, KEY_8
    DB      KEY_7, KEY_6, KEY_5, KEY_4, KEY_3, KEY_2, KEY_1

SetKeyHandlers_UiMode:
    ld              hl,KeyHandlers_UiMode
    jr              SetKeyHandlers_EditMode.copyHandlersData

SetKeyHandlers_EditMode:
    ld              hl,KeyHandlers_EditMode
.copyHandlersData:
    ld              de,registeredHandlers
    ld              bc,TOTAL_KEYS*2
    ldir
    ret

KeyHandlers_UiMode:
    DW              0           ; KEY_CAPS
    DW              0           ; KEY_Z
    DW              0           ; KEY_X
    DW              handleKey_C ; KEY_C ; caps=DMA_CONTINUE
    DW              0           ; KEY_V
    DW              handleKey_A ; KEY_A ; chg A.adr, shift=A.adjust, caps=DMA_RESET_PORT_A_TIMING
    DW              handleKey_S ; KEY_S ; caps=DMA_REINIT_STATUS_BYTE
    DW              handleKey_D ; KEY_D ; flip direction, caps=DMA_DISABLE
    DW              handleKey_F ; KEY_F ; caps=DMA_FORCE_READY
    DW              0           ; KEY_G
    DW              handleKey_Q ; KEY_Q ; test scenario1, caps=redraw+reinit
    DW              handleKey_W ; KEY_W ; test scenario2
    DW              handleKey_E ; KEY_E ; test scenario3, caps=DMA_ENABLE
    DW              handleKey_R ; KEY_R ; test scenario4, caps=DMA_RESET
    DW              handleKey_T ; KEY_T ; chg A.timing, shift=load custom A.timing
    DW              handleKey_1 ; KEY_1 ; commit WR1, caps=EDIT
    DW              handleKey_2 ; KEY_2 ; commit WR2
    DW              handleKey_3 ; KEY_3 ; caps=set WR3
    DW              handleKey_4 ; KEY_4 ; commit WR4
    DW              handleKey_5 ; KEY_5 ; caps=set WR5
    DW              handleKey_0 ; KEY_0 ; commit WR0
    DW              0           ; KEY_9
    DW              0           ; KEY_8
    DW              0           ; KEY_7
    DW              0           ; KEY_6
    DW              handleKey_P ; KEY_P ; flip pixels/attributes, caps=flip port+restart
    DW              0           ; KEY_O
    DW              0           ; KEY_I
    DW              0           ; KEY_U
    DW              handleKey_Y ; KEY_Y ; chg B.timing, shift=load custom B.timing
    DW              handleKey_ENTER ; KEY_ENTER ; commit WR0124, caps=Send byte to DMA, symbol=edit byte
    DW              handleKey_L ; KEY_L ; chg length, caps=DMA_LOAD
    DW              0           ; KEY_K
    DW              0           ; KEY_J
    DW              handleKey_H ; KEY_H ; show destination hexa bytes (from first non-zero)
    DW              0           ; KEY_SPACE
    DW              0           ; KEY_SYMBOL
    DW              handleKey_M ; KEY_M ; chg mode, caps=DMA_READ_MASK_FOLLOWS
    DW              0           ; KEY_N
    DW              handleKey_B ; KEY_B ; chg B.adr, shift=B.adjust, caps=DMA_RESET_PORT_B_TIMING

KeyHandlers_EditMode:
    DW              0           ; KEY_CAPS
    DW              0           ; KEY_Z
    DW              0           ; KEY_X
    DW              handleKey_HexaDigit     ; KEY_C
    DW              0           ; KEY_V
    DW              handleKey_HexaDigit     ; KEY_A
    DW              0           ; KEY_S
    DW              handleKey_HexaDigit     ; KEY_D
    DW              handleKey_HexaDigit     ; KEY_F
    DW              0           ; KEY_G
    DW              0           ; KEY_Q
    DW              0           ; KEY_W
    DW              handleKey_HexaDigit     ; KEY_E
    DW              0           ; KEY_R
    DW              0           ; KEY_T
    DW              handleKey_HexaDigit     ; KEY_1
    DW              handleKey_HexaDigit     ; KEY_2
    DW              handleKey_HexaDigit     ; KEY_3
    DW              handleKey_HexaDigit     ; KEY_4
    DW              handleKey_HexaDigit     ; KEY_5
    DW              handleKey_HexaDigit     ; KEY_0
    DW              handleKey_HexaDigit     ; KEY_9
    DW              handleKey_HexaDigit     ; KEY_8
    DW              handleKey_HexaDigit     ; KEY_7
    DW              handleKey_HexaDigit     ; KEY_6
    DW              0           ; KEY_P
    DW              0           ; KEY_O
    DW              0           ; KEY_I
    DW              0           ; KEY_U
    DW              0           ; KEY_Y
    DW              handleKey_ENTER_Edit    ; KEY_ENTER
    DW              0           ; KEY_L
    DW              0           ; KEY_K
    DW              0           ; KEY_J
    DW              0           ; KEY_H
    DW              0           ; KEY_SPACE
    DW              0           ; KEY_SYMBOL
    DW              0           ; KEY_M
    DW              0           ; KEY_N
    DW              handleKey_HexaDigit     ; KEY_B

TestScenarioTxt:
    DZ  'Test scenario '

TestScenario1:
    ; try transfer with LOAD done only before final direction flip
    DB  %0'0000'0'01        ; A<-B transfer
    DB  DMA_LOAD
    DB  %0'0000'1'01        ; A->B transfer
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_END_SEQUENCE

TestScenario2:
    ; try change of port adr adjust before continue + enable
    DB  DMA_LOAD            ; expects default state (A++, B++)
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_CONTINUE
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  %0'0'00'0'100       ; WR1 = A memory, --, keep timing
    DB  DMA_CONTINUE
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_END_SEQUENCE

TestScenario3:
    ; try change of port adr adjust between continue + enable
    DB  DMA_LOAD            ; expects default state (A++, B++)
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_CONTINUE
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_CONTINUE
    DB  %0'0'00'0'100       ; WR1 = A memory, --, keep timing
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_END_SEQUENCE

TestScenario4:
    ; try figure out what precisely RESET does
    DB  DMA_LOAD            ; expects default state (A++, B++)
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_RESET
    DB  DMA_CONTINUE
    DB  DMA_FORCE_READY
    DB  DMA_ENABLE
    DB  DMA_END_SEQUENCE

    ALIGN   256
CustomCharsGfx:
    ; zero char
    DG      . . # # # # . .
    DG      . # . . . . # .
    DG      # . # # # . . #
    DG      # . # # . # . #
    DG      # . # . # # . #
    DG      # . . # # # . #
    DG      . # . . . . # .
    DG      . . # # # # . .
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
    DG      . . . . . . . .
    DG      . . . . . . . .
    DG      . . # # . # # #
    DG      . # . . . . # .
    DG      . . # . . . # .
    DG      . . . # . . # .
    DG      . # # . . . # .
    DG      . . . . . . . .
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

    ;       '01234567012345670123456701234567'
LegendTxt_Keyboard:
    DZ      'Controls: X=x, X=CS+x, X=SS+x'
LegendTxt_Keyboard2:
    DZ      ' =edit custom byte  =send to DMA'
LegendTxt_Standard:
    DZ      ' ="standard" byte - specific fn.'
LegendTxt_Uncommited:
    DZ      'Uncommited changes:1234 Q=redraw'
LegendTxt_Port:
    DZ      'DMA Port $   P=alternate+restart'

    ; 78 = bright white (regular key) 70 = bright yellow (symbol), 58 = bright magenta (caps)
    ; offsets are -1 ("inc a" is used to test for 255 terminator value)
LegendTxt_Keyboard_AttrExtras:
    DB      10-1, $78, 15-10-1, $58, 23-15-1, $70, 255
LegendTxt_Keyboard2_AttrExtras: ; use VRAM address - 1, because offset 0 can't be encoded
    DB      1-1, $70, 20-1-1, $58, 255
LegendTxt_Uncommited_AttrExtras:
    DB      19-1, ATTR_UNCOMMITED, 0, ATTR_UNCOMMITED, 0, ATTR_UNCOMMITED
    DB      0, ATTR_UNCOMMITED, 1, $58, 255
LegendTxt_Port_AttrExtras:
    DB      9-1, P_WHITE|RED, 0, P_WHITE|RED, 0, P_WHITE|RED, 1, $58, 255

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
    call    DetectTBBlue
    ret     nc
    ; modify default port to $6B on TBBlue boards
    ld      a,ZXN_DMA_P_6B
    ld      (DmaPortData),a

    ; switch DMA to Zilog mode (and enable all keys: turbo, 50/60Hz, NMI)
    ; use only regular Z80 instructions, so it can survive even on ZX48/ZX128
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    ld      a,PERIPHERAL_2_NR_06
    out     (c),a
    inc     b       ; bc = TBBLUE_REGISTER_ACCESS_P_253B
    in      a,(c)   ; read desired NextReg state
    or      %1110'1000          ; enable F8, F3 and NMI buttons, Zilog DMA mode
    out     (c),a   ; write new value

    ; switch to 28MHz on TBBlue
    dec     b       ; register select
    ld      a,TURBO_CONTROL_NR_07
    out     (c),a
    inc     b
    ld      a,3
    out     (c),a   ; set 28MHz

    ret

Start:
    ;;;;;;;;; !!! global registers - preserve: IX = state, C = DMA port !!! ;;;;;;;;;;
    di
    ; reset SP pointer
    ld      sp,StackSpace
    ; auto-detect TBBlue, will also switch to Zilog mode of DMA, and set 28MHz
    call    AutoDetectTBBlue
    ; install keyboard handlers
    IGNORE_KEY      KEY_CAPS
    IGNORE_KEY      KEY_SYMBOL
StartAfterPortChange:
    ld      sp,StackSpace       ; reset SP also when test is restarted
    call    StartTest
    ; re-install keyboard handlers for UI mode
    call    SetKeyHandlers_UiMode
    ; re-init global state
    ld      hl,stateInitSet
    ld      de,s
    ld      bc,StateData
    ldir
    ld      ix,s
    ; make the "visible" init sequence play from start
    ld      hl,DmaVisibleInitSequence
    ld      (playSequence),hl

    ;; do the full init of DMA chip and helper settings in NextRegs and I/O ports
    BORDER  YELLOW

    ; hidden init of DMA - make the sequence of five RESETs (not needed to show)
    ld      hl,DmaHiddenInit
DmaPortData EQU $+1         ; self-modify storage of port number
    ld      bc,(DmaHiddenInitSz<<8)|Z80_DMA_PORT_MB02
    otir

    ; redraw the main screen with initial info
    call    RedrawScreen

    ; "controls" line
    call    ScrollUpBottomTwoThirdsByRow
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    ld      hl,LegendTxt_Keyboard
    call    OutStringAtDe
    ld      hl,MEM_ZX_ATTRIB_5800+$20*23+0
    ld      de,LegendTxt_Keyboard_AttrExtras
    call    PatchAttrExtra

    ; "controls 2" line
    call    ScrollUpBottomTwoThirdsByRow
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    ld      b,CUSTOM_CHAR_ENTER
    xor     a
    call    OutBCharAtA
    ld      a,19
    call    OutBCharAtA
    ld      (OutCurrentAdr),hl
    ld      hl,LegendTxt_Keyboard2
    call    OutString
    ld      hl,MEM_ZX_ATTRIB_5800+$20*23-1
    ld      de,LegendTxt_Keyboard2_AttrExtras
    call    PatchAttrExtra

    ; "standard byte" line
    call    ScrollUpBottomTwoThirdsByRow
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    ld      b,CUSTOM_CHAR_STD
    xor     a
    call    OutBCharAtA
    ld      (OutCurrentAdr),hl
    ld      hl,LegendTxt_Standard
    call    OutString

    ; "uncommited" line
    call    ScrollUpBottomTwoThirdsByRow
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    ld      hl,LegendTxt_Uncommited
    call    OutStringAtDe
    ld      hl,MEM_ZX_ATTRIB_5800+$20*23+0
    ld      de,LegendTxt_Uncommited_AttrExtras
    call    PatchAttrExtra

    ; "port" line
    call    ScrollUpBottomTwoThirdsByRow
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*7+0
    ld      hl,LegendTxt_Port
    call    OutStringAtDe
    ld      hl,MEM_ZX_ATTRIB_5800+$20*23+0
    ld      de,LegendTxt_Port_AttrExtras
    call    PatchAttrExtra
    ld      hl,MEM_ZX_SCREEN_4000+$1000+$20*7+10
    ld      (OutCurrentAdr),hl
    ld      a,(DmaPortData)
    call    OutHexaValue

    BORDER  BLUE

MainLoop:
    ; check if some sequence is being played -> do the "send byte to DMA" every loop
    ld      hl,(playSequence)
    ld      a,(hl)
    cp      DMA_END_SEQUENCE
    jr      z,.noSequenceIsPlaying
    BORDER  YELLOW
    ld      a,(hl)
    inc     hl
    ld      (playSequence),hl
    call    SendDmaByte
    jr      MainLoop
    ; if no sequence is playing, read the key state and handle key presses
.noSequenceIsPlaying:
    ld      a,(s.awaitingWriteBytes)
    or      a
    jr      z,.noByteIsAwaitedOrInEditMode
    ld      a,(s.isEditMode)
    or      a
    jr      nz,.noByteIsAwaitedOrInEditMode     ; already in edit mode
    ; force edit mode when some byte is being awaited and no pending replay
    push    bc
    call    handleKey_ENTER.enterEditMode
    pop     bc
    jr      MainLoop
.noByteIsAwaitedOrInEditMode:
    ; do BLUE/RED border depending on UI/editByte mode
    ld      a,(s.isEditMode)
    inc     a
    and     2
    or      1
    out     (ULA_P_FE),a
    ; refresh the keyboard state and handle key presses
    push    bc
    call    MyRefreshKeyboardState
    pop     bc
    jr      MainLoop

;; DMA init + transfer sequences used to reset DMA and to init the flashing border blocks

DmaHiddenInit:
    ; 5x DMA_RESET - to get out of any regular state before the visible init sequence
    BLOCK 5, DMA_RESET
DmaHiddenInitSz EQU $ - DmaHiddenInit

DmaEmptySequence:
    DB  DMA_END_SEQUENCE

DmaVisibleInitSequence:
    DB  DMA_RESET           ; (resets also port timings)
    DB  DMA_READ_MASK_FOLLOWS, $7F  ; reset read-mask to $7F (default for this test)
    DB  %0'1111'1'01        ; WR0 = A->B transfer, A.adr=$582D, length=2
    DW  $582D, 2
    DB  %0'0'01'0'100       ; WR1 = A memory, ++, keep standard timing
    DB  %0'0'01'0'000       ; WR2 = B memory, ++, keep standard timing
    DB  $80                 ; WR3 = 0 (reset and switch off interrupts)
    DB  %1'01'0'11'01       ; WR4 = continuous mode, B.adr=$586D
    DW  $586D
    DB  %10'0'0'0010        ; WR5 = stop after block, /CE only
    DB  DMA_LOAD            ; LOAD (to set up RR registers)
    DB  DMA_FORCE_READY     ; FORCE_READY (ready to "enable" first transfer)
    DB  DMA_END_SEQUENCE

DmaResetReadMaskOnly:
    DB  DMA_READ_MASK_FOLLOWS, $7F
    DB  DMA_END_SEQUENCE

    ; set WR0 sequence - this will be dynamically set by code, needs end pointer
    BLOCK   6, DMA_END_SEQUENCE
DmaSetWr0Sequence:
    DB      DMA_END_SEQUENCE, DMA_END_SEQUENCE

    ALIGN   2
    BLOCK   120, $CC
StackSpace:
    DW      0

    IFNDEF BUILD_TAP
        savesna "dmaDebug.sna", Start
    ELSE
        savebin "dma8000.bin", BinStart, $-BinStart
        shellexec "bin2tap -o dmaDebug.tap -a 32768 -b -r 32768 dma8000.bin && rm dma8000.bin"
        org 0
        incbin "ReadMe.txt"
        savetap "dmaDebug.tap", CODE, "ReadMe.txt", 0, $
    ENDIF
