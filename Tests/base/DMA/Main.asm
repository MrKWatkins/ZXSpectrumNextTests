; WARNING - this is DMA test of "zxnDMA" variant (the ZX Spectrum Next with core
; implemented in FPGA, including the DMA-like mechanics emulating the Zilog DMA)
;
; The zxnDMA is simplified a lot, removing many "gotcha" rules, and doing transfers
; of blocks without the +1/+2 to the set length, to make it less tricky for new
; programmers. The board can be configured to work as Zilog DMA chip doing +1 byte
; transfers (but no search, no interrupts, no single-byte mode) by selecting it in
; NextReg 0x06, to make it compatible with old ZX software using datagear/MB-02 DMA.
;
; The zxnDMA code in this test is thus breaking some Zilog DMA rules:
; - it's not always doing explicit DISABLE command after each block (good idea on Zilog)
; - it's doing WR0 setups on multiple ocassions where the previous point would bug
; - it's not LOAD-ing fixed-address target port by setting it as source port
;   = on Zilog DMA only source port is loaded if fixed-address is used (you must flip
;   the A->B / B->A direction before LOAD and back after, to load the target port
;   as source port, that one is loaded even when fixed-address is used)
; - it's LOAD-ing port addresses only with correct direction of transfer
;   (current core 3.0.5 is sensitive to this and will malfunction when direction is
;   flipped after LOAD)

    device zxspectrum48

    org     $8000

    INCLUDE "../../Constants.asm"
    INCLUDE "../../Macros.asm"
    INCLUDE "../../TestFunctions.asm"
    INCLUDE "../../TestData.asm"
    INCLUDE "../../OutputFunctions.asm"

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
    call    OutHexaValue
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

Start:
    NEXTREG_nn  TURBO_CONTROL_NR_07,3       ; 28MHz
    call    StartTest
    ;; screen init
    BORDER  CYAN
    ; create dots in all DMA squares to make counting easier
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*1+6, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*1+18, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*1+30, 1, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*1+6, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*1+18, 4, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*1+30, 1, 4
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$100+$20*6+13, 4+4+1, 1
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*6+13, 4, 1
    FILL_DMA_CHAR_DOTS MEM_ZX_SCREEN_4000+$900+$20*6+18, 4, 1
    ; display all text in the layout
    ld      de,MEM_ZX_SCREEN_4000+$1000+$20*7+2
    ld      bc,MEM_ZX_SCREEN_4000+$1000+$20*7+16
    call    OutMachineIdAndCore_defLabels
    ld      de,MEM_ZX_SCREEN_4000
    ld      hl,LegendaryText
    call    OutStringAtDe
    ; attributes - odd lines stripes
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20,$20,P_CYAN|BLACK
    ld      hl,MEM_ZX_ATTRIB_5800
    ld      de,MEM_ZX_ATTRIB_5800+$20*2
    ld      bc,32*22
    ldir
    ; extra attributes for "IO is yellow" line
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*5,$20,P_CYAN|WHITE
    ; attributes - "slow burst" area
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*15+0,$20*8,A_BRIGHT|P_WHITE|BLUE
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*16+0,$20*6,P_WHITE|RED
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
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*6+12,11,ATTR_NO_DMA
    FILL_AREA   MEM_ZX_ATTRIB_5800+$20*14+12,11,ATTR_NO_DMA

    ;; do the full init of DMA chip and helper settings in NextRegs and I/O ports
    BORDER  YELLOW

    ; switch DMA to zxnDMA mode (and enable all keys: turbo, 50/60Hz, NMI)
    NEXTREG2A   PERIPHERAL_2_NR_06
    and     ~%0100'0000         ; clear DMA mode (set it as zxnDMA)
    or      %1010'1000          ; enable F8, F3 and NMI buttons
    NEXTREG_A   PERIPHERAL_2_NR_06

    ; init NextReg selector to value which will be used for I/O port tests
    ld      bc,TBBLUE_REGISTER_SELECT_P_243B
    ld      a,ATTR_IO
    out     (c),a

    ; init DMA - full re-init of everything
    ld      hl,DmaFullInit
    ld      bc,(DmaFullInitSz<<8)|ZXN_DMA_P_6B
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
    DEFARRAY SRC_ADR        DmaSrcData4B, DmaSrcData4B+3, DmaSrcData1B, TBBLUE_REGISTER_SELECT_P_243B
    DEFARRAY DST_ADR_BASE   MEM_ZX_ATTRIB_5800+$20*1, MEM_ZX_ATTRIB_5800+$20*2, MEM_ZX_ATTRIB_5800+$20*3, MEM_ZX_ATTRIB_5800+$20*4
    DEFARRAY DATA_SZ        4, 4, 4, 4
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
            ld      a,DMA_LOAD      ; load the internal counters with the settings
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
            ld      a,DMA_LOAD      ; load the internal counters with the settings
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
    ; WR0 B->A, port A adr: MEM_ZX_ATTRIB_5800+$20*12+30 = $599E, length = 4, port A mem+0
    ; port B adr: $243B, port B I/O+0, continuous mode

    ; change current full-init from last B->A test to "-- mode, bottom right 4x1"
    ; Port A adr (*LSB): $59D5, port A mem-- (*), port B adr (*): DmaSrcData4B, port B mem++ (*)
    nop : ; DW $01DD    ; break
    ; WR0 = B->A transfer, LSB start addres port A
    ld      hl,(%0'0001'0'01<<8)|$D5
    out     (c),h           ; in zxnDMA continuous mode WR0 can be first write
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
    ld      a,DMA_ENABLE    ; start the transfer
    out     (c),a
    ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
    out     (c),a

    ; set LSB DST_ADR $59CD, dst mode mem++, load + enable (same SRC data and mode)
    nop : ; DW $01DD    ; break
    ; WR0 = B->A transfer, LSB start addres port A
    ld      hl,(%0'0001'0'01<<8)|$CD
    out     (c),h           ; in zxnDMA continuous mode WR0 can be first write
    out     (c),l           ; start address port A (LSB)
    ; WR2 = port A mode mem++
    ld      a,%0'0'01'0'100
    out     (c),a           ; WR2 = mem++ (port A, dst)
    ld      a,DMA_LOAD      ; load the internal counters with the patched settings
    out     (c),a
    ld      a,DMA_ENABLE    ; start the transfer
    out     (c),a
    ld      a,DMA_DISABLE   ; after block transfer, disable DMA from "inactive" state
    out     (c),a

    ;; short init 4+4+1 block using CONTINUE command

    ; set MSB DST_ADR $58CD, MSB SRC_ADR DmaSrcData9B (has same LSB as DmaSrcData4B), load + enable
    nop : ; DW $01DD    ; break
    ; WR0 = B->A transfer, MSB start addres port A
    ld      hl,(%0'0010'0'01<<8)|$58
    out     (c),h           ; in zxnDMA continuous mode WR0 can be first write
    out     (c),l           ; start address port A (MSB)
    ; WR4 = continuous mode, start address port B (MSB)
    ld      hl,(%1'01'0'10'01<<8)|(high DmaSrcData9B)
    out     (c),h           ; WR4
    out     (c),l           ; SRC_ADR MSB (port B)
    ld      a,DMA_LOAD      ; load the internal counters with the patched settings
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

;    jr      .CSpectDiesSkip

    ; just "continue" (unfortunately this kills the code on #CSpect 2.11.8)
    ; change: actually it does "useless" start address setup of port A/B to verify
    ; they don't get loaded when they should not (with "continue" only)
    nop : ; DW $01DD    ; break
    ; WR0 = start address A
    ld      de,MEM_ZX_ATTRIB_5800+$20*6 ; "error spot" over "short init" text
    ld      a,%0'0011'0'01
    out     (c),a           ; in zxnDMA continuous mode WR0 can be first write
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
    out     (c),h           ; in zxnDMA continuous mode WR0 can be first write
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
    ei
    halt
    ; reset color for first block to the white+red
    ld      a,P_WHITE|RED
    ld      (DmaSrcData1B),a
    ; setup the slow burst DMA with auto-restart
SetupBurstDma:
    ld      hl,DmaSlowBurstInit
    ld      b,DmaSlowBurstInitSz
    otir

    BORDER  BLUE

    jp      EndTest

DmaFullInit:
    BLOCK 6, DMA_RESET      ; 6x DMA_RESET (to get out of any regular state, if 5B data are expected)
    DB  %0'0000'1'01        ; WR0 = A->B transfer (no extra bytes, yet)
    DB  %0'1'01'0'100, %10  ; WR1 = A memory, ++, cycle length=2
    DB  %0'1'01'0'000, %00'1'000'10, 0  ; WR2 = B memory, ++, cycle length=2, prescalar=0
    DB  %1'01'0'00'01       ; WR4 = continuous mode
    DB  %10'0'0'0010        ; WR5 = stop after block, /CE only
DmaFullInitSz EQU $ - DmaFullInit

DmaSlowBurstInit:
    DB  DMA_DISABLE
    DB  %0'1111'1'01        ; WR0 = A->B transfer, port A address, length
    DW  DmaSrcData1B        ; source data address
    DW  $20*6               ; block length (six attr lines)
    DB  %0'0'10'0'100       ; WR1 = A memory, +0
    DB  %0'1'01'0'000, %00'1'000'10, 255  ; WR2 = B memory, ++, cycle length=2, prescalar=255
    DB  %1'10'0'11'01       ; WR4 = burst mode, port B address
    DW  MEM_ZX_ATTRIB_5800+$20*16
    DB  %10'1'0'0010        ; WR5 = auto-restart after block, /CE only
    DB  DMA_LOAD
    DB  DMA_ENABLE
DmaSlowBurstInitSz EQU $ - DmaSlowBurstInit

LegendaryText:
    ;    01234567012345670123456701234567
    DB  "A -> B        m+ = m++, m- = m--"
    DB  "m+m+  \A\A\A\A  m+m-  \A\A\A\A  m+m0  \A "
    DB  "m-m+  \A\A\A\A  m-m-  \A\A\A\A  m-m0  \A "
    DB  "m0m+  \A\A\A\A  m0m-  \A\A\A\A  m0m0  \A "
    DB  "IOm+  \A\A\A\A  IOm-  \A\A\A\A  IOm0  \A "
    DB  "(IO is yellow colour when OK)   "
    DB  "Short init:  \A\A\A\A\A\A\A\A\A  (4+4+1) "
    DB  "                                "
    DB  "B -> A     m0=const, IO=I/O port"
    DB  "m+m+  \A\A\A\A  m+m-  \A\A\A\A  m+m0  \A "
    DB  "m-m+  \A\A\A\A  m-m-  \A\A\A\A  m-m0  \A "
    DB  "m0m+  \A\A\A\A  m0m-  \A\A\A\A  m0m0  \A "
    DB  "IOm+  \A\A\A\A  IOm-  \A\A\A\A  IOm0  \A "
    DB  "                                "
    DB  "Short cont:  \A\A\A\A \A\A\A\A  (4+4)   "
    DB  "-==-==-==-==-==--==-==-==-==-==-"
    DB  "................................"
    DB  "................................"
    DB  "..\"slow\".burst.18FPS.color.chg.."
    DB  "..auto-restart..2s.CPU.Hz.chg..."
    DB  "................................"
    DB  "................................"
    DB  "-= 3.5  7  14  28 Mhz -==-==-==-"
    DB  0

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
    DB      ATTR_DMA_B
    ALIGN   256, ATTR_BAD       ; fill the red+red marker also after the source

    ALIGN   256
IM2_IVT     EQU high $
IM2_HANDLER EQU ((IM2_IVT+1)<<8)|(IM2_IVT+1)
    BLOCK   257, IM2_IVT+1

ClearCpuSpeedMarker:
    ; A = CPU speed, C = attribute byte
.MEM_ATTR_CPU_SPEED  EQU MEM_ZX_ATTRIB_5800+$20*22+2
    ld      h,high .MEM_ATTR_CPU_SPEED
    rlca
    rlca
    add     a,low .MEM_ATTR_CPU_SPEED
    ld      l,a     ; HL = MEM_ATTR_CPU_SPEED + 4*speed
    ld      b,4
.fillLoop:
    ld      (hl),c
    inc     l
    djnz    .fillLoop
    ret
    org     IM2_HANDLER
Im2Handler:
    push    af
    push    bc
    push    hl
    ; chage color
    ld      a,(DmaSrcData1B)
    add     a,P_BLUE|1
    or      P_GREEN
    and     $3F
    ld      (DmaSrcData1B),a
.TimeCnt    EQU $+1
    ld      a,200
    inc     a
    cp      2*50                ; 2s wait
    jr      c,.twoSecDidntPass
    ; change CPU speed
.CpuSpeed   EQU $+1
    ld      a,3
    push    af
    ld      c,A_BRIGHT|P_WHITE|BLUE
    call    ClearCpuSpeedMarker
    pop     af
    inc     a
    and     $03
    ld      (.CpuSpeed),a
    NEXTREG_A TURBO_CONTROL_NR_07
    ld      c,P_CYAN|BLACK
    call    ClearCpuSpeedMarker
    ; reset timer
    xor     a
.twoSecDidntPass:
    ld      (.TimeCnt),a
    pop     hl
    pop     bc
    pop     af
    ei
    ret

    savesna "!dma.sna", Start

/*
Allen info about prescalar:

case turbo_i is
	when "00"   => DMA_timer_s <= DMA_timer_s + "00000000001000";
	when "01"   => DMA_timer_s <= DMA_timer_s + "00000000000100";
	when "10"   => DMA_timer_s <= DMA_timer_s + "00000000000010";
	when others => DMA_timer_s <= DMA_timer_s + "00000000000001";
end case;

The top 9 bits are what are compared with the prescalar value to know when the time has expired.

This timer is zeroed when the dma read cycle starts and a check is made if the prescalar time has been satisfied at the end of the write cycle:

if (R2_portB_preescaler_s > 0) and (('0' & R2_portB_preescaler_s) > DMA_timer_s(13 downto 5)) then

If not satisfied, the dma waits for the time to be satisfied.  If the burst mode is active, the dma gives up the bus as well.
Once satisfied, if continuous mode, the dma can go back to the dma read cycle for the first byte.
But if the bus was given up, it must go to an earlier stage that re-acquires the bus.
This wait occurs before a check is made to see if the transfer is complete.
*/
