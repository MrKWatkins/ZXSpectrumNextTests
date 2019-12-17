; WARNING - this is DMA test of "zxnDMA" variant (the ZX Spectrum Next with core
; implemented in FPGA, including the DMA-like mechanics emulating the Zilog DMA)
;
; But in Zilog compatibility mode. The zxnDMA emulates only limited sub-set of
; Zilog DMA chip, so this test is using only the available sub-parts.
;
; This test should work also on regular ZX128 with some DMA chip at port $0B or $6B,
; all the ZX Next related actions are using only regular Z80 machine code and I/O
; ports $243B and $253B.
;
; From the initial tests it seems zxnDMA is accurate rendition of UA858D DMA chip
; (timing, transfer behaviour) except it will trigger transfer also on WR3.enable,
; just like Zilog DMA, and the LOAD must be done after correct direction is set.
; Values read back from zxnDMA are different too.
;
; Details (UA858D):
; * the "continue" command in 4+4+2 transfer will transfer 10B -> 10B
; * the variable timing per port is preserved even when WR1/2.D6=0 (test with real UA858D)
;   (to reset custom timing one has to do probably reset command - not tested)
; * length of transfer is "length + 1" (as Zilog docs document)
; * values read after transfer [A.adrS (++) -> B.adrS (++), length=N] are:
;   counter=N, A.adrS+N+1, B.adrS+N (N+1 bytes are transferred in total)
;   = this *IS* in sync with Zilog docs ... notice that dest. address is only +N, but
;   doing CONTINUE+ENABLE will do the missing increment of B address ahead of first
;   byte transfer, so larger transfer split into sub-parts and done by CONTINUE will
;   produce identical results as one single big transfer.
; ! the LOAD command will reset "START_READ_SEQUENCE" state and the reads done after
;   LOAD will simply return zero. This is *NOT* in sync with Zilog documentation.
;
; Details Next core 3.0.5, in ZilogDMA compatibility mode:
; * the "continue" command 4+4+2 will transfer 10B -> 10B
; ! any unexpected read of DMA will read status byte, even when it was not requested
; * variable timing is preserved (even when WR1/2.D6=0 set later)
; * length of transfer is "length + 1"
; ! values read after transfer are: counter=0, A.adrS+N+1, B.adrS+N+1
; ! status byte has always bit0 as "0" (does not report 1+ byte transferred)
; ! the final LOAD must be done with correct transfer direction set, flipping direction
;   after LOAD will result in wrong addresses used for source/destination of transfer.
; * the "START_READ_SEQUENCE" will be preserved also across LOAD, in sync with Zilog docs.
;
; TODO: still in need of genuine Zilog DMA test results to compare for differences

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

AutoDetectDmaPort:
    ld      a,(DmaPortData)
    ld      c,a
    ld      b,250
    ld      l,0
.listenToPort:
    in      a,(c)
    inc     a
    jr      nz,.notFF
    inc     l
.notFF:
    djnz    .listenToPort
    ld      a,l
    cp      20      ; less than 20 $FF values read => port alive => CF=1
    ret

Start:
    ; auto-detect DMA port heuristic
    di
    call    AutoDetectDmaPort
    jr      c,StartAfterPortChange      ; port $0B detected
    ld      a,Z80_DMA_PORT_MB02 ^ Z80_DMA_PORT_DATAGEAR
    xor     c
    ld      (DmaPortData),a
    call    AutoDetectDmaPort
    jr      c,StartAfterPortChange      ; port $6B detected
    call    StartTest
    ld      de,MEM_ZX_SCREEN_4000
    ld      hl,.DmaPortNotFoundTxt
    call    OutStringAtDe
    jp      EndTest
.DmaPortNotFoundTxt:
    DB      'no DMA chip at port $0B or $6B',0

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

    ; switch DMA to zxnDMA mode (and enable all keys: turbo, 50/60Hz, NMI)
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

;    jr      .CSpectDiesSkip

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

    BORDER  BLACK       ; wait cca 1+7 scanlines
    ld      b,16
    djnz    $
    BORDER  GREEN
    ld      b,121
    djnz    $

    ; setup the transfers to BORDER port with 2T timings of ports (mem -> IO (border))
    BORDER  RED
    ld      hl,DmaBorderTimingPerformance_ST
    ld      b,DmaBorderTimingPerformance_STSz
    otir

    BORDER  BLACK
    ld      b,16
    djnz    $
    BORDER  BLUE
    ; check for press of "P" to restart the whole test with the other port
    ld      a,%11011111
    in      a,(ULA_P_FE)
    rra
    jr      c,BorderPerformanceTest
    ; flip the port to the other one (between $6B and $0B)
    di
    ld      a,(DmaPortData)
    xor     Z80_DMA_PORT_DATAGEAR^Z80_DMA_PORT_MB02
    ld      (DmaPortData),a
    ; restart the test completely
    jp      StartAfterPortChange

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
    DW  2918                ; block length (cca. 14590T => 64 scanlines if 228T per line)
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

BorderTextGfx:
       ;0               8               16              24              32              40     |44      48              56 = 57B total
    DB  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,2,0,0,1,1,1,0,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,0,0,1,1,1,1,1,0,0,2,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,5,5,5,0,0,0,5,0,0,0,5,0,0,0,5,5,5,0,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,2,0,0,1,1,1,1,0,0,0,1,1,0,1,1,0,0,0,1,1,1,0,0,0,1,1,1,1,1,0,0,2,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,5,5,5,0,0,0,5,5,0,5,5,0,0,0,5,5,5,0,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,5,5,5,5,0,0,5,5,5,5,5,0,0,5,5,5,5,5,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,7,7,7,7,0,0,7,7,7,7,7,0,0,7,7,7,7,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,0,0,5,5,0,0,5,5,5,5,5,0,0,5,5,0,5,5,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,7,7,0,0,7,7,7,7,7,0,0,7,7,0,7,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,0,7,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,0,7,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,0,0,7,7,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,0,0,5,5,0,0,5,0,0,0,5,0,0,5,0,0,0,5,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,6,0,0,7,7,7,7,7,0,0,7,0,0,0,7,0,0,7,0,0,0,7,0,0,7,7,7,7,7,0,0,6,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,5,5,5,5,0,0,5,0,0,0,5,0,0,5,0,0,0,5,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,5,5,5,0,0,0,5,0,0,0,5,0,0,5,0,0,0,5,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,2,0,0,1,1,1,1,0,0,0,1,0,0,0,1,0,0,1,0,0,0,1,0,0,1,1,1,1,1,0,0,2,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,3,0,0,5,5,5,5,0,0,0,5,0,0,0,5,0,0,5,0,0,0,5,0,0,5,5,5,5,5,0,0,3,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,2,0,0,1,1,1,0,0,0,0,1,0,0,0,1,0,0,1,0,0,0,1,0,0,1,1,1,1,1,0,0,2,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
BorderTextGfxSz EQU     $ - BorderTextGfx
    DB  2   ; do red border afterward the block

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
    ret     c       ; 5T
    nop             ; 4T
    ld      b,249
    djnz    $       ; 13/8T

    ; do the border effect with DMA transfer
    ld      hl,DmaBorderText
    ld      b,DmaBorderTextSz
    otir
    ; return from interrupt
    pop     hl
    pop     bc
    pop     af
    ei
    ret

    IFNDEF BUILD_TAP
        savesna "zilogDMA.sna", Start
    ELSE
        savebin "dma8000.bin", BinStart, $-BinStart
        shellexec "bin2tap -o zilogdma.tap -a 32768 -b -r 32768 dma8000.bin && rm dma8000.bin"
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
