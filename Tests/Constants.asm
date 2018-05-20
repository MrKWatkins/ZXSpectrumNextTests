; Gratuitously nicked from the Scroll Nutter demo.

SPRITE_INFO_PORT = $5b

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

;	-- port 0x123B = 4667
;	-- bit 7 and 6 = new vram page selection ("00", "01" or "10") 0, 64, 128
;	-- bit 5 and 4 = layers order	"00" - new vram over vram (100% magenta is transparent)
;	--								"01" - vram over new vram (black with bright is transparent) ; out 9275,20:out 9531,colour
;	-- bit 3 = not used
;	-- bit 2 = 	"0" page selected is write only, ZX ROM visible at 0000-3FFF
;	--			"1" page selected is read and write, ZX ROM is disabled
;	-- bit 1 = 	"0" new vram not visible
;	-- bit 0 = 	"0" new vram read and write disabled
LAYER2_ACCESS_PORT			equ $123B
TBBLUE_REGISTER_SELECT			equ $243B
TBBLUE_REGISTER_ACCESS			equ $253B
SPRITE_STATUS_SLOT_SELECT		equ $303B	; what should this be called?
MEMORY_PAGING_CONTROL			equ $7FFD
SOUND_CHIP_REGISTER_WRITE		equ $BFFD
NEXT_MEMORY_BANK_SELECT			equ $DFFD
NXT_ULA_PLUS				equ $FF3B	;?
TURBO_SOUND_CONTROL			equ $FFFD
Z80_DMA_PORT_DATAGEAR			equ $6b
Z80_DMA_PORT_MB02			equ $0b
;----------------------------------------------
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
;----------------------------------------------
; Registers
MACHINE_ID_REGISTER			equ $00
NEXT_VERSION_REGISTER			equ $01
NEXT_RESET_REGISTER			equ $02
MACHINE_TYPE_REGISTER			equ $03
ROM_MAPPING_REGISTER			equ $04		;In config mode, allows RAM to be mapped to ROM area.
PERIPHERAL_1_REGISTER			equ $05		;Sets joystick mode, video frequency, Scanlines and Scandoubler.
PERIPHERAL_2_REGISTER			equ $06		;Enables Acceleration, Lightpen, DivMMC, Multiface, Mouse and AY audio.
TURBO_CONTROL_REGISTER			equ $07
PERIPHERAL_3_REGISTER			equ $08		;Enables Stereo, Internal Speaker, SpecDrum, Timex Video Modes, Turbo Sound Next and NTSC/PAL selection.
CORE_VERSION_REGISTER			equ $0E
ANTI_BRICK_REGISTER			equ $10
LAYER2_RAM_PAGE_REGISTER		equ $12		;Sets the bank number where Layer 2 video memory begins.
LAYER2_RAM_PAGE_SHADOW_REGISTER		equ $13		;Sets the bank number where the Layer 2 shadow screen begins.
GLOBAL_TRANSPARENCY_REGISTER		equ $14		;Sets the color treated as transparent when drawing layer 2.
SPRITE_CONTROL_REGISTER			equ $15		;Enables/disables Sprites and Lores Layer, and chooses priority of sprites and Layer 2.
LAYER2_XOFFSET_REGISTER 		equ $16
LAYER2_YOFFSET_REGISTER			equ $17
CLIP_WINDOW_REGISTER			equ $18
CLIP_SPRITE_REGISTER			equ $19
CLIP_LORES_REGISTER			equ $1a
CLIP_WINDOW_CONTROL_REGISTER		equ $1C		;set to 7 to reset all clipping
RASTER_LINE_MSB_REGISTER		equ $1E
RASTER_LINE_LSB_REGISTER		equ $1F
RASTER_INTERUPT_CONTROL_REGISTER	equ $22		;Controls the timing of raster interrupts and the ULA frame interrupt.
RASTER_INTERUPT_VALUE_REGISTER		equ $23
HIGH_ADRESS_KEYMAP_REGISTER		equ $28
LOW_ADRESS_KEYMAP_REGISTER		equ $29
HIGH_DATA_TO_KEYMAP_REGISTER		equ $2A
LOW_DATA_TO_KEYMAP_REGISTER		equ $2B
SOUNDDRIVE_MIRROR_REGISTER		equ $2D		;this port cand be used to send data to the SoundDrive using the Copper co-processor
LORES_XOFFSET_REGISTER			equ $32
LORES_YOFFSET_REGISTER			equ $33
PALETTE_INDEX_REGISTER			equ $40		;Chooses a ULANext palette number to configure.
PALETTE_VALUE_REGISTER			equ $41		;Used to upload 8-bit colors to the ULANext palette.
PALETTE_FORMAT_REGISTER			equ $42
PALETTE_CONTROL_REGISTER		equ $43		;Enables or disables ULANext interpretation of attribute values and toggles active palette.
PALETTE_VALUE_BIT9_REGISTER		equ $44		;Holds the additional blue color bit for RGB333 color selection.
MMU_REGISTER_0				equ $50		;Set a Spectrum RAM page at position 0x0000 to 0x1fff
MMU_REGISTER_1				equ $51		;Set a Spectrum RAM page at position 0x2000 to 0x3fff
MMU_REGISTER_2				equ $52		;Set a Spectrum RAM page at position 0x4000 to 0x5fff
MMU_REGISTER_3				equ $53		;Set a Spectrum RAM page at position 0x6000 to 0x7fff
MMU_REGISTER_4				equ $54		;Set a Spectrum RAM page at position 0x8000 to 0x9fff
MMU_REGISTER_5				equ $55		;Set a Spectrum RAM page at position 0xa000 to 0xbfff
MMU_REGISTER_6				equ $56		;Set a Spectrum RAM page at position 0xC000 to 0xDFFF
MMU_REGISTER_7				equ $57		;Set a Spectrum RAM page at position 0xE000 to 0xFFFF
;----------------------------------------------
COPPER_DATA				equ $60
COPPER_CONTROL_LO_BYTE_REGISTER		equ $61
COPPER_CONTROL_HI_BYTE_REGISTER		equ $62
COPPER_WAIT				= %10000000
;----------------------------------------------
DEBUG_LED_CONTROL_REGISTER		equ $FF 	;Turns debug LEDs on and off on TBBlue implementations that have them.
;----------------------------------------------
ZX_SCREEN				= $4000
ZX_ATTRIB				= $5800
LORES_MEM_1				= $4000
LORES_MEM_2				= $6000
