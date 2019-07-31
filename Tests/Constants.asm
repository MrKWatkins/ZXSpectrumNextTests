
; ----- Colour palette (ULA)
BLACK 			equ 0
BLUE 			equ 1
RED 			equ 2
MAGENTA 		equ 3
GREEN 			equ 4
CYAN 			equ 5
YELLOW	 		equ 6
WHITE	 		equ 7
P_BLACK			equ 0
P_BLUE			equ 1<<3
P_RED			equ 2<<3
P_MAGENTA		equ 3<<3
P_GREEN			equ 4<<3
P_CYAN			equ 5<<3
P_YELLOW		equ 6<<3
P_WHITE			equ 7<<3
; ----- Attribs
A_FLASH			equ 128
A_BRIGHT 		equ 64
;----------------------------------------------
BIT_UP			equ 4	; 16
BIT_DOWN		equ 5	; 32
BIT_LEFT		equ 6	; 64
BIT_RIGHT		equ 7	; 128

DIR_NONE		equ %00000000
DIR_UP			equ %00010000
DIR_DOWN		equ %00100000
DIR_LEFT		equ %01000000
DIR_RIGHT		equ %10000000

DIR_UP_I		equ %11101111
DIR_DOWN_I		equ %11011111
DIR_LEFT_I		equ %10111111
DIR_RIGHT_I		equ %01111111

;-----------------------------------------------------------------------------
;-- I/O ports - ZX Spectrum classic (48, 128, Timex, Pentagon, ...) ports

ULA_P_FE                        equ $FE     ; BORDER + MIC + BEEP + read Keyboard
TIMEX_P_FF                      equ $FF     ; Timex video control port

ZX128_MEMORY_P_7FFD             equ $7FFD   ; ZX Spectrum 128 ports
ZX128_MEMORY_P_DFFD             equ $DFFD
ZX128P3_MEMORY_P_1FFD           equ $1FFD

AY_REG_P_FFFD                   equ $FFFD
AY_DATA_P_BFFD                  equ $BFFD

Z80_DMA_PORT_DATAGEAR           equ $6B     ; on ZXN the zxnDMA handles this
Z80_DMA_PORT_MB02               equ $0B     ; on ZXN the zxnDMA handles this

DIVMMC_CONTROL_P_E3             equ $E3
SPI_CS_P_E7                     equ $E7
SPI_DATA_P_EB                   equ $EB

KEMPSTON_MOUSE_X_P_FBDF         equ $FBDF
KEMPSTON_MOUSE_Y_P_FFDF         equ $FFDF
KEMPSTON_MOUSE_B_P_FADF         equ $FADF   ; kempston mouse wheel+buttons

KEMPSTON_JOY1_P_1F              equ $1F
KEMPSTON_JOY2_P_37              equ $37

;-----------------------------------------------------------------------------
;-- I/O ports - ZX Spectrum NEXT specific ports

TBBLUE_REGISTER_SELECT_P_243B   equ $243B
    ; -- port $243B = 9275  Read+Write (detection bitmask: %0010_0100_0011_1011)
    ;   -- selects NextREG mapped at port TBBLUE_REGISTER_ACCESS_P_253B

TBBLUE_REGISTER_ACCESS_P_253B   equ $253B
    ; -- port $253B = 9531  Read?+Write? (detection bitmask: %0010_0101_0011_1011)
    ;   -- data for selected NextREG (read/write depends on the register selected)

I2C_SCL_P_103B                  equ $103B   ; i2c bus port (clock) (write only?)
I2C_SDA_P_113B                  equ $113B   ; i2c bus port (data) (read+write)
UART_TX_P_133B                  equ $133B   ; UART tx port (read+write)
UART_RX_P_143B                  equ $143B   ; UART rx port (read+write)

ZXN_DMA_P_6B                    equ $6B
    ; -- port $6B = 107 Read+Write (detection bitmask: %xxxx_xxxx_0110_1011)
    ;   - The zxnDMA is mostly compatible with Zilog DMA chip (Z8410) (at least
    ;     as far as old ZX apps are concerned), but has many modifications.

LAYER2_ACCESS_P_123B            equ $123B
    ; -- port $123B = 4667 Read+Write (detection bitmask: %0001_0010_0011_1011)
    ;   -- bit 7-6 = write-Layer2-over-ROM bank selection (00, 01 or 10)
    ;   -- bit 3 = shadow banks over ROM (nextreg $13 banks instead of $12 banks)
    ;   -- bit 1 = Layer2 visibility (1 = visible, 0 = disabled)
    ;   -- bit 0 = write-Layer2-over-ROM (1 = write at $0000..$3FFF writes into Layer2)
LAYER2_ACCESS_WRITE_OVER_ROM    equ $01     ; map Layer2 bank into ROM area (0000..3FFF) for WRITE-only (reads as ROM)
LAYER2_ACCESS_L2_ENABLED        equ $02     ; enable Layer2
LAYER2_ACCESS_SHADOW_OVER_ROM   equ $08     ; bank selected by bits 6-7 is from "shadow Layer 2" banks range (nextreg $13)
LAYER2_ACCESS_OVER_ROM_BANK_M   equ $C0     ; (mask of) value 0..2 selecting bank mapped for write (Nextreg $12 or $13)
LAYER2_ACCESS_OVER_ROM_BANK_0   equ $00     ; screen lines 0..63
LAYER2_ACCESS_OVER_ROM_BANK_1   equ $40     ; screen lines 64..127
LAYER2_ACCESS_OVER_ROM_BANK_2   equ $80     ; screen lines 128..191

SPRITE_STATUS_SLOT_SELECT_P_303B    equ $303B
    ; -- port $303B = 12347  Read+Write (detection bitmask: %0011_0000_0011_1011)
    ;   -- write:
    ;     - sets both "sprite slot" (0..63) and "pattern slot" (0..63 +128)
    ;     - once the sprite/pattern slots are set, they act independently and
    ;     each port ($xx57 and $xx5B) will auto-increment its own slot index
    ;     (to resync one can write to this port again).
    ;     - the +128 flag will make the pattern upload start at byte 128 of pattern
    ;     slot (second half of slot)
    ;     - The sprite-slot (sprite-attributes) may be optionally interlinked with
    ;     NextReg $34 (feature controlled by NextReg $34)
    ;     - auto-increments of slot position from value 63 are officially
    ;     "undefined behaviour", wrap to 0 is not guaranteed. (only setting slots
    ;     explicitly back to valid 0..63 will make your code future-proof)
    ;   -- read (will also reset both collision and max-sprites flags):
    ;     - bit 1 = maximum sprites per line hit (set when sprite renderer ran
    ;               out of time when preparing next scanline)
    ;     - bit 0 = collision flag (set when any sprites draw non-transparent
    ;               pixel at the same location)
    ;     Both flags contain values for current scanline already at the beginning
    ;     of scanline (sprite engine renders one line ahead into buffer and updates
    ;     flags progressively as it renders the sprites)
SPRITE_STATUS_MAXIMUM_SPRITES   equ $02
SPRITE_STATUS_COLLISION         equ $01
SPRITE_SLOT_SELECT_PATTERN_HALF equ 128     ; add it to 0..63 index to make pattern upload start at second half of pattern

SPRITE_ATTRIBUTE_P_57           equ $57
    ; -- port $xx57 = 87 write-only (detection bitmask: %xxxx_xxxx_0101_0111)
    ;  - writing 4 or 5 bytes long structures to control particular sprite
    ;  - after 4/5 bytes block the sprite slot index is auto-incremented
    ;  - for detailed documentation check official docs or wiki (too long)

SPRITE_PATTERN_P_5B             equ $5B
    ; -- port $xx5B = 91 write-only (detection bitmask: %xxxx_xxxx_0101_1011)
    ;  - each pattern slot is 256 bytes long = one 16x16 pattern of 8-bit pixels
    ;    or two 16x16 patterns of 4-bit pixels.
    ;  - Patterns are uploaded in "English" order (left to right, top to bottom),
    ;    one byte encodes single pixel in 8 bit mode and two pixels in 4 bit
    ;    mode (bits 7-4 are "left" pixel, 3-0 are "right" pixel)
    ;  - pixels are offset (index) into active sprite palette

TURBO_SOUND_CONTROL_P_FFFD      equ $FFFD   ; write with bit 7 = 1 (port shared with AY)

;-----------------------------------------------------------------------------
;-- NEXT HW Registers (NextReg)
MACHINE_ID_NR_00                equ $00
NEXT_VERSION_NR_01              equ $01
NEXT_RESET_NR_02                equ $02
MACHINE_TYPE_NR_03              equ $03
ROM_MAPPING_NR_04               equ $04     ;In config mode, allows RAM to be mapped to ROM area.
PERIPHERAL_1_NR_05              equ $05     ;Sets joystick mode, video frequency and Scandoubler.
PERIPHERAL_2_NR_06              equ $06     ;Enables Acceleration, Lightpen, DivMMC, Multiface, Mouse and AY audio.
TURBO_CONTROL_NR_07             equ $07
PERIPHERAL_3_NR_08              equ $08     ;Enables Stereo, Internal Speaker, SpecDrum, Timex Video Modes, Turbo Sound Next and NTSC/PAL selection.
PERIPHERAL_4_NR_09              equ $09     ;Sets scanlines, AY mono output, disables Kempston and divMMC ports.
NEXT_VERSION_MINOR_NR_0E        equ $0E
ANTI_BRICK_NR_10                equ $10
VIDEO_TIMING_NR_11              equ $11
LAYER2_RAM_BANK_NR_12           equ $12     ;bank number where Layer 2 video memory begins.
LAYER2_RAM_SHADOW_BANK_NR_13    equ $13     ;bank number for Layer2 "shadow" write-over-rom
GLOBAL_TRANSPARENCY_NR_14       equ $14     ;Sets the color treated as transparent for ULA/Layer2/LoRes
SPRITE_CONTROL_NR_15            equ $15     ;LoRes mode, Sprites configuration, layers priority
    ; bit 7: enable LoRes mode, bits 6-5: reserved, write 0
    ; 4-2: layers priority: 000=SLU, 001=LSU, 010=SUL, 011=LUS, 100=USL, 101=ULS, 110=S,mix(U+L), 111=S,mix(U+L-5)
    ; bit 1: enable sprites over border, bit 0: show sprites
LAYER2_XOFFSET_NR_16            equ $16
LAYER2_YOFFSET_NR_17            equ $17
CLIP_LAYER2_NR_18               equ $18
CLIP_SPRITE_NR_19               equ $19
CLIP_ULA_LORES_NR_1A            equ $1A
CLIP_TILEMAP_NR_1B              equ $1B
CLIP_WINDOW_CONTROL_NR_1C       equ $1C     ;set to 7 to reset all clip-window indices to 0
RASTER_LINE_MSB_NR_1E           equ $1E
RASTER_LINE_LSB_NR_1F           equ $1F
RASTER_INTERUPT_CONTROL_NR_22   equ $22     ;Controls the timing of raster interrupts and the ULA frame interrupt.
RASTER_INTERUPT_VALUE_NR_23     equ $23
HIGH_ADRESS_KEYMAP_NR_28        equ $28
LOW_ADRESS_KEYMAP_NR_29         equ $29
HIGH_DATA_TO_KEYMAP_NR_2A       equ $2A
LOW_DATA_TO_KEYMAP_NR_2B        equ $2B
SOUNDDRIVE_DF_MIRROR_NR_2D      equ $2D     ;Nextreg port-mirror of port 0xDF
TILEMAP_XOFFSET_MSB_NR_2F       equ $2F
TILEMAP_XOFFSET_LSB_NR_30       equ $30
TILEMAP_YOFFSET_NR_31           equ $31
LORES_XOFFSET_NR_32             equ $32     ;Also ULA scroll register (since core 2.00.26)
LORES_YOFFSET_NR_33             equ $33     ;Also ULA scroll register (since core 2.00.26)
SPRITE_ATTR_SLOT_SEL_NR_34      equ $34     ;Sprite-attribute slot index for $35-$39/$75-$79 port $57 mirrors
SPRITE_ATTR0_NR_35              equ $35     ;port $57 mirror in nextreg space (accessible to copper)
SPRITE_ATTR1_NR_36              equ $36
SPRITE_ATTR2_NR_37              equ $37
SPRITE_ATTR3_NR_38              equ $38
SPRITE_ATTR4_NR_39              equ $39
PALETTE_INDEX_NR_40             equ $40     ;Chooses a ULANext palette number to configure.
PALETTE_VALUE_NR_41             equ $41     ;Used to upload 8-bit colors to the ULANext palette.
PALETTE_FORMAT_NR_42            equ $42     ;ink-mask for ULANext modes
PALETTE_CONTROL_NR_43           equ $43     ;Enables or disables ULANext interpretation of attribute values and toggles active palette.
PALETTE_VALUE_9BIT_NR_44        equ $44     ;Holds the additional blue color bit for RGB333 color selection.
TRANSPARENCY_FALLBACK_COL_NR_4A equ $4A     ;8-bit colour to be drawn when all layers are transparent
SPRITE_TRANSPARENCY_I_NR_4B     equ $4B     ;index of transparent colour in sprite palette (only bottom 4 bits for 4-bit patterns)
TILEMAP_TRANSPARENCY_I_NR_4C    equ $4C     ;index of transparent colour in tilemap graphics (only bottom 4 bits)
MMU0_0000_NR_50                 equ $50     ;Set a Spectrum RAM page at position 0x0000 to 0x1fff
MMU1_2000_NR_51                 equ $51     ;Set a Spectrum RAM page at position 0x2000 to 0x3fff
MMU2_4000_NR_52                 equ $52     ;Set a Spectrum RAM page at position 0x4000 to 0x5fff
MMU3_6000_NR_53                 equ $53     ;Set a Spectrum RAM page at position 0x6000 to 0x7fff
MMU4_8000_NR_54                 equ $54     ;Set a Spectrum RAM page at position 0x8000 to 0x9fff
MMU5_A000_NR_55                 equ $55     ;Set a Spectrum RAM page at position 0xa000 to 0xbfff
MMU6_C000_NR_56                 equ $56     ;Set a Spectrum RAM page at position 0xC000 to 0xDFFF
MMU7_E000_NR_57                 equ $57     ;Set a Spectrum RAM page at position 0xE000 to 0xFFFF
COPPER_DATA_NR_60               equ $60
COPPER_CONTROL_LO_NR_61         equ $61
COPPER_CONTROL_HI_NR_62         equ $62
ULA_CONTROL_NR_68               equ $68
TILEMAP_CONTROL_NR_6B           equ $6B
TILEMAP_DEFAULT_ATTR_NR_6C      equ $6C
TILEMAP_BASE_ADR_NR_6E          equ $6E     ;Tilemap base address of map
TILEMAP_GFX_ADR_NR_6F           equ $6F     ;Tilemap definitions (graphics of tiles)
SPRITE_ATTR0_INC_NR_75          equ $75     ;port $57 mirror in nextreg space (accessible to copper) (slot index++)
SPRITE_ATTR1_INC_NR_76          equ $76
SPRITE_ATTR2_INC_NR_77          equ $77
SPRITE_ATTR3_INC_NR_78          equ $78
SPRITE_ATTR4_INC_NR_79          equ $79
DEBUG_LED_CONTROL_NR_FF         equ $FF     ;Turns debug LEDs on and off on TBBlue implementations that have them.

;-----------------------------------------------------------------------------
;-- common memory addresses
MEM_ROM_CHARS_3C00              equ $3C00   ; actual chars start at $3D00 with space
MEM_ZX_SCREEN_4000              equ $4000
MEM_ZX_ATTRIB_5800              equ $5800
MEM_LORES0_4000                 equ $4000
MEM_LORES1_6000                 equ $6000
MEM_TIMEX_SCR0_4000             equ $4000
MEM_TIMEX_SCR1_6000             equ $6000

;-----------------------------------------------------------------------------
;-- Copper commands
COPPER_NOOP                     equ %00000000
COPPER_WAIT                     equ %10000000
COPPER_HALT                     equ %11111111   ; wait for (511,63) = infinite wait

;-----------------------------------------------------------------------------
; DMA (Register 6)
DMA_RESET				equ $c3
DMA_RESET_PORT_A_TIMING			equ $c7
DMA_RESET_PORT_B_TIMING			equ $cb
DMA_LOAD				equ $cf
DMA_CONTINUE				equ $d3
DMA_DISABLE_INTERUPTS			equ $af
DMA_ENABLE_INTERUPTS			equ $ab
DMA_RESET_DISABLE_INTERUPTS		equ $a3
DMA_ENABLE_AFTER_RETI			equ $b7
DMA_READ_STATUS_BYTE			equ $bf
DMA_REINIT_STATUS_BYTE			equ $8b
DMA_START_READ_SEQUENCE			equ $a7
DMA_FORCE_READY				equ $b3
DMA_DISABLE				equ $83
DMA_ENABLE				equ $87
DMA_WRITE_REGISTER_COMMAND		equ $bb

; About UART<->ESP baund rate from AA:
;
; It's very easy to compute the prescalar.
; 1. Read nextreg 0x11 to find out the video timing the system is using 0-7
; 2. Take the associated actual system clock from this table:define(__CLK_28_0', 28000000)
; define(CLK_28_1', 28571429)
; define(`CLK_28_2', 29464286)
; define(__CLK_28_3', 30000000)
; define(CLK_28_4', 31000000)
; define(`CLK_28_5', 32000000)
; define(__CLK_28_6', 33000000)
; define(__CLK_28_7', 27000000)
; 3. Divide the clock by the baud rate you want to find the 14-bit prescalar value.
; That's it.
