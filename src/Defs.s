; Global addresses and engine values
SHADOW_REG             equ   $E0C035
STATE_REG              equ   $E0C068
NEW_VIDEO_REG          equ   $E0C029
BORDER_REG             equ   $E0C034     ; 0-3 = border, 4-7 Text color
VBL_VERT_REG           equ   $E0C02E
VBL_HORZ_REG           equ   $E0C02F

KBD_REG                equ   $E0C000
KBD_STROBE_REG         equ   $E0C010
VBL_STATE_REG          equ   $E0C019
MOD_REG                equ   $E0C025
COMMAND_KEY_REG        equ   $E0C061
OPTION_KEY_REG         equ   $E0C062

SHADOW_SCREEN          equ   $012000
SHADOW_SCREEN_SCB      equ   $019D00
SHADOW_SCREEN_PALETTES equ   $019E00
SHR_SCREEN             equ   $E12000
SHR_SCB                equ   $E19D00
SHR_PALETTES           equ   $E19E00

; Direct page locations used by the engine
ScreenHeight           equ   0           ; Height of the playfield in scan lines
ScreenWidth            equ   2           ; Width of the playfield in bytes
ScreenY0               equ   4           ; First vertical line on the physical screen of the playfield
ScreenY1               equ   6           ; End of playfield on the physical screen. If the height is 20 and Y0 is
ScreenX0               equ   8           ; 100, then ScreenY1 = 120.
ScreenX1               equ   10
ScreenTileHeight       equ   12          ; Height of the playfield in 8x8 blocks
ScreenTileWidth        equ   14          ; Width of the playfield in 8x8 blocks

StartX                 equ   16          ; Which code buffer byte is the left edge of the screen. Range = 0 to 167
StartY                 equ   18          ; Which code buffer line is the top of the screen. Range = 0 to 207
EngineMode             equ   20          ; Defined the mode/capabilities that are enabled
                                         ;  bit 0: 0 = Single Background, 1 = Parallax
DirtyBits              equ   22          ; Identify values that have changed between frames

BG1DataBank            equ   24          ; Data bank that holds BG1 layer data
BG1AltBank             equ   26          ; Alternate BG1 bank

BlitterDP              equ   28          ; Direct page address the holder blitter data

OldStartX              equ   30
OldStartY              equ   32

LastPatchOffset        equ   34          ; Offset into code field that was patched with BRA instructions
StartXMod164           equ   36
StartYMod208           equ   38

BG1StartX              equ   40          ; Logical offset of the second background
BG1StartXMod164        equ   42

BG1StartY              equ   44
BG1StartYMod208        equ   46

OldBG1StartX           equ   48
OldBG1StartY           equ   50

BG1OffsetIndex         equ   52

BG0TileOriginX         equ   54          ; Coordinate in the tile map that corresponds to the top-left corner
BG0TileOriginY         equ   56
OldBG0TileOriginX      equ   58
OldBG0TileOriginY      equ   60

BG1TileOriginX         equ   62          ; Coordinate in the tile map that corresponds to the top-left corner
BG1TileOriginY         equ   64
OldBG1TileOriginX      equ   66
OldBG1TileOriginY      equ   68

TileMapWidth           equ   70
TileMapHeight          equ   72
TileMapPtr             equ   74
FringeMapPtr           equ   78

BG1TileMapWidth        equ   82
BG1TileMapHeight       equ   84
BG1TileMapPtr          equ   86

SCBArrayPtr            equ   90          ; USed for palette binding
Next                   equ   94

BankLoad               equ   128

AppSpace               equ   160         ; 16 bytes of space reserved for application use

tiletmp                equ   178         ; 16 bytes of temp storage for the tile renderers
blttmp                 equ   192         ; 32 bytes of local cache/scratch space for blitter

tmp8                   equ   224         ; another 16 bytes of temporary space to be used as scratch 
tmp9                   equ   226
tmp10                  equ   228
tmp11                  equ   230
tmp12                  equ   232
tmp13                  equ   234
tmp14                  equ   236
tmp15                  equ   238

tmp0                   equ   240         ; 16 bytes of temporary space to be used as scratch 
tmp1                   equ   242
tmp2                   equ   244
tmp3                   equ   246
tmp4                   equ   248
tmp5                   equ   250
tmp6                   equ   252
tmp7                   equ   254

DIRTY_BIT_BG0_X        equ   $0001
DIRTY_BIT_BG0_Y        equ   $0002
DIRTY_BIT_BG1_X        equ   $0004
DIRTY_BIT_BG1_Y        equ   $0008
DIRTY_BIT_BG0_REFRESH  equ   $0010
DIRTY_BIT_BG1_REFRESH  equ   $0020

; Script definition
YIELD                  equ   $8000
JUMP                   equ   $4000

SET_PALETTE_ENTRY      equ   $0002
SWAP_PALETTE_ENTRY     equ   $0004
SET_DYN_TILE           equ   $0006
CALLBACK               equ   $0010

; ReadControl return value bits
PAD_BUTTON_B           equ   $01
PAD_BUTTON_A           equ   $02
PAD_KEY_DOWN           equ   $04

; Tile constants
TILE_ID_MASK           equ   $01FF
TILE_SPRITE_BIT        equ   $8000                  ; Set if this tile intersects an active sprite
TILE_PRIORITY_BIT      equ   $4000                  ; Put tile on top of sprite
TILE_FRINGE_BIT        equ   $2000
TILE_MASK_BIT          equ   $1000
TILE_DYN_BIT           equ   $0800
TILE_VFLIP_BIT         equ   $0400
TILE_HFLIP_BIT         equ   $0200

; Tile Store Offsets (internals)
MAX_TILES             equ  {26*41}            ; Number of tiles in the code field (41 columns * 26 rows)
TILE_STORE_SIZE       equ  {MAX_TILES*2}      ; The tile store contains a tile descriptor in each slot

TS_TILE_ID            equ  TILE_STORE_SIZE*0
TS_DIRTY              equ  TILE_STORE_SIZE*1
TS_SPRITE_FLAG        equ  TILE_STORE_SIZE*2
TS_TILE_ADDR          equ  TILE_STORE_SIZE*3      ; const value
TS_CODE_ADDR_LOW      equ  TILE_STORE_SIZE*4      ; const value
TS_CODE_ADDR_HIGH     equ  TILE_STORE_SIZE*5      ; const value
TS_WORD_OFFSET        equ  TILE_STORE_SIZE*6
TS_BASE_ADDR          equ  TILE_STORE_SIZE*7
TS_SPRITE_ADDR        equ  TILE_STORE_SIZE*8
