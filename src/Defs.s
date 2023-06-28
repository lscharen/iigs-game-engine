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
SHR_LINE_WIDTH         equ   160
SHR_SCREEN_HEIGHT      equ   200

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
                                         ;  bit 1: 0 = No Dynamic Tiles, 1 = Allocate Bank 00 space for dynamic tiles
                                         ;  bit 2: 0 = No static buffer, 1 = Allocation Bank 00 space for a static screen buffer
DirtyBits              equ   22          ; Identify values that have changed between frames

CompileBank0           equ   24          ; Always zero to allow [CompileBank0],y addressing
CompileBank            equ   26          ; Data bank that holds compiled sprite code

BlitterDP              equ   28          ; Direct page address that holds blitter data

OldStartX              equ   30          ; Used to track deltas between frames
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

BG1OffsetIndex         equ   52          ; Utility index for scanline effect in BG1

BG0TileOriginX         equ   54          ; Coordinate in the tile map that corresponds to the top-left corner
BG0TileOriginY         equ   56
OldBG0TileOriginX      equ   58
OldBG0TileOriginY      equ   60

BG1TileOriginX         equ   62          ; Coordinate in the tile map that corresponds to the top-left corner
BG1TileOriginY         equ   64
OldBG1TileOriginX      equ   66
OldBG1TileOriginY      equ   68

TileMapWidth           equ   70          ; Pointer to memory holding the tile map for the primary background
TileMapHeight          equ   72
TileMapPtr             equ   74
; FringeMapPtr           equ   78
GTEControlBits         equ   78          ; Enable / disable things

BG1TileMapWidth        equ   82
BG1TileMapHeight       equ   84
BG1TileMapPtr          equ   86          ; Pointer to memory holding the tile map for the secondary background

SCBArrayPtr            equ   90          ; Used for palette binding
SpriteBanks            equ   94          ; Bank bytes for the sprite data and sprite mask
LastRender             equ   96          ; Record which render function was last executed
CompileBankTop         equ   98          ; First free byte i nthe compile bank.  Grows upward in memeory.
SpriteMap              equ   100         ; Bitmap of open sprite slots.
ActiveSpriteCount      equ   102
BG1DataBank            equ   104          ; Data bank that holds BG1 layer data
TileStoreBankAndBank01 equ   106
TileStoreBankAndTileDataBank equ 108
TileStoreBankDoubled   equ   110
UserId                 equ   112         ; Memory manager user Id to use
ToolNum                equ   114         ; Tool number assigned to us
LastKey                equ   116
LastTick               equ   118
ForceSpriteFlag        equ   120
SpriteRemovedFlag      equ   122         ; Indicate if any sprites were removed this frame
RenderFlags            equ   124         ; Flags passed to the Render() function
BG1Scaling             equ   126

activeSpriteList       equ   128         ; 32 bytes for the active sprite list (can persist across frames)

; Free space from 160 to 192
STATE_REG_OFF          equ   160
STATE_REG_BLIT         equ   161
STK_SAVE               equ   162         ; Only used by the lite renderer

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

; Defines for the second direct page (used in the tile blitters)

sprite_ptr0            equ   0           ; Each tile can render up to 4 sprite blocks.  The sprite
sprite_ptr1            equ   4           ; data and mask values live in different banks, but have a
sprite_ptr2            equ   8           ; parallel structure.  The high word of each point is set to
sprite_ptr3            equ   12          ; the mask bank.  With the Bank register set, both data and mask
;                                        ; can be accessed through the same pointer, e.g. lda (sprite_ptr0)
;                                        ; and [sprite_ptr0]

tmp_sprite_data        equ   16          ; 32 byte temporary buffer to build up sprite data values
tmp_sprite_mask        equ   48          ; 32 byte temporary buffer to build up sprite mask values
tmp_tile_data          equ   80          ; 32 byte temporary buffer to build up tile data values
tmp_tile_mask          equ   112         ; 32 byte temporary buffer to build up tile mask values

; Temporary direct page locations used by some of the complex tile renderers
_X_REG                 equ   144
_Y_REG                 equ   146
_T_PTR                 equ   148         ; Copy of the tile address pointer
_OP_CACHE2             equ   148         ; CAche of second opcode
_BASE_ADDR             equ   150         ; Copy of BTableLow for this tile
_SPR_X_REG             equ   152         ; Cache address of sprite plane source for a tile
_JTBL_CACHE            equ   154         ; Cache the offset to the exception handler for a column
_OP_CACHE              equ   156         ; Cache of a relevant operand / oeprator
_TILE_ID               equ   158         ; Copy of the tile descriptor

; Define free space the the application to use
; FREE_SPACE_DP2         equ   160
DP2_DIRTY_TILE_COUNT    equ  160         ; Local copy of dirty tile count to avoid banking
DP2_DIRTY_TILE_CALLBACK equ  162

; Some pre-defined bank values
DP2_TILEDATA_AND_TILESTORE_BANKS   equ 164
DP2_SPRITEDATA_AND_TILESTORE_BANKS equ 166
DP2_TILEDATA_AND_SPRITEDATA_BANKS  equ 168
DP2_BANK01_AND_TILESTORE_BANKS     equ 170
DP2_TILEDATA_AND_BANK01_BANKS      equ 172

; Tile record passed to user-defined tile callback
USER_TILE_RECORD        equ  178
USER_TILE_ID            equ  178         ; copy of the tile id in the tile store
USER_TILE_CODE_PTR      equ  180         ; pointer to the code bank in which to patch
USER_TILE_ADDR          equ  184         ; address in the tile data bank
USER_FREE_SPACE         equ  186         ; a few bytes of scratch space

SPRITE_VBUFF_PTR        equ  224         ; 32 bytes of adjusted pointers to VBuffArray addresses
; End direct page values

; EngineMode definitions
ENGINE_MODE_TWO_LAYER  equ   $0001
ENGINE_MODE_DYN_TILES  equ   $0002
ENGINE_MODE_BNK0_BUFF  equ   $0004
ENGINE_MODE_USER_TOOL  equ   $8000       ; Communicate if GTE is loaded as a system tool, or a user tool

; Render flags
RENDER_ALT_BG1         equ   $0001
RENDER_BG1_HORZ_OFFSET equ   $0002
RENDER_BG1_VERT_OFFSET equ   $0004
RENDER_BG1_ROTATION    equ   $0008
RENDER_PER_SCANLINE    equ   $0010
RENDER_WITH_SHADOWING  equ   $0020
RENDER_SPRITES_SORTED  equ   $0040      ; Draw the sprites in y-sorted order.  Otherwise, use the index.

; DirtyBits definitions
DIRTY_BIT_BG0_X        equ   $0001
DIRTY_BIT_BG0_Y        equ   $0002
DIRTY_BIT_BG1_X        equ   $0004
DIRTY_BIT_BG1_Y        equ   $0008
DIRTY_BIT_BG0_REFRESH  equ   $0010
DIRTY_BIT_BG1_REFRESH  equ   $0020
DIRTY_BIT_SPRITE_ARRAY equ   $0040

; GetAddress table IDs
scanlineHorzOffset     equ   $0001        ; Table of 416 words, a double-array of scanline offset values. Values must be in range [0, 163]
scanlineHorzOffset2    equ   $0002        ; Table of 416 words, a double-array of scanline offset values. Values must be in range [0, 163]
tileStore              equ   $0003
vblCallback            equ   $0004        ; User routine to be called by VBL interrupt.  Set to $000000 to disconnect
extSpriteRenderer      equ   $0005
rawDrawTile            equ   $0006
extBG0TileUpdate       equ   $0007
userTileCallback       equ   $0008
liteBlitter            equ   $0009

; CopyPicToBG1 flags
COPY_PIC_NORMAL        equ   $0000        ; Copy into BG1 buffer in "normal mode" treating the buffer as a 164x208 pixmap with stride of 256
COPY_PIC_SCANLINE      equ   $0001        ; Copy in a way to support BG1 + RENDER_PER_SCANLINE.  Pixmap is double-width, 327x200 with stride of 327

; Script definition
YIELD                  equ   $8000
JUMP                   equ   $4000

SET_PALETTE_ENTRY      equ   $0002
SWAP_PALETTE_ENTRY     equ   $0004
SET_DYN_TILE           equ   $0006
CALLBACK               equ   $0010

; ReadControl return value bits
PAD_BUTTON_B           equ   $0100
PAD_BUTTON_A           equ   $0200
PAD_KEY_DOWN           equ   $0400

; GTE Control Bits
CTRL_SPRITE_DISABLE    equ   $0001
CTRL_BKGND_DISABLE     equ   $0002

; Tile constants
TILE_DAMAGED_BIT       equ   $8000                  ; Mark a tile as damaged (internal only)
TILE_PRIORITY_BIT      equ   $4000                  ; Put tile on top of sprite (unimplemented)
TILE_USER_BIT          equ   $2000                  ; User-defined tile.  Execute registered callback.
TILE_SOLID_BIT         equ   $1000                  ; Hint bit used in TWO_LAYER_MODE to optimize rendering
TILE_DYN_BIT           equ   $0800                  ; Is this a Dynamic Tile?
TILE_VFLIP_BIT         equ   $0400
TILE_HFLIP_BIT         equ   $0200
TILE_ID_MASK           equ   $01FF
TILE_CTRL_MASK         equ   $7E00
; TILE_PROC_MASK         equ   $7800                  ; Select tile proc for rendering

; Sprite constants
SPRITE_OVERLAY         equ   $8000                    ; This is an overlay record.  Stored as a sprite for render ordering purposes
SPRITE_COMPILED        equ   $4000                    ; This is a compiled sprite (SPRITE_DISP points to a routine in the compiled cache bank)
SPRITE_HIDE            equ   $2000                    ; Do not render the sprite
SPRITE_16X16           equ   $1800                    ; 16 pixels wide x 16 pixels tall
SPRITE_16X8            equ   $1000                    ; 16 pixels wide x 8 pixels tall
SPRITE_8X16            equ   $0800                    ; 8 pixels wide x 16 pixels tall
SPRITE_8X8             equ   $0000                    ; 8 pixels wide x 8 pixels tall
SPRITE_VFLIP           equ   $0400                    ; Flip the sprite vertically
SPRITE_HFLIP           equ   $0200                    ; Flip the sprite horizontally

; Overlay bits (aliases of SPRITE_ID bits)
OVERLAY_MASKED         equ   $0000      ; Overlay has a mask, so the background must be draw first
OVERLAY_SOLID          equ   $4000      ; Overlay covers the scan line and is fully opaque
OVERLAY_ABOVE          equ   $0000      ; Overlay is drawn above scanline sprites
OVERLAY_BELOW          equ   $2000      ; Overlay is drawn below scanline sprites

; Stamp storage parameters
VBUFF_STRIDE_BYTES     equ {12*4}                        ; Each line has 4 slots of 16 pixels + 8 buffer pixels
VBUFF_TILE_ROW_BYTES   equ {8*VBUFF_STRIDE_BYTES}        ; Each row is comprised of 8 lines
VBUFF_TILE_COL_BYTES   equ 4
VBUFF_SPRITE_STEP      equ {VBUFF_TILE_ROW_BYTES*3}      ; Allocate space for 16 rows + 8 rows of buffer
VBUFF_SPRITE_START     equ {VBUFF_TILE_ROW_BYTES+4}      ; Start at an offset so $0000 can be used as an empty value
VBUFF_SLOT_COUNT       equ 48                            ; Have space for this many stamps

; This is 13 blocks wide
SPRITE_PLANE_SPAN      equ VBUFF_STRIDE_BYTES

; External references to data bank
TileStore         EXT
DirtyTileCount    EXT
DirtyTiles        EXT
_Sprites          EXT
TileStore         EXT
TileStoreLookupYTable EXT
TileStoreLookup   EXT
Col2CodeOffset    EXT
JTableOffset      EXT
CodeFieldEvenBRA  EXT
CodeFieldOddBRA   EXT
ScreenAddr        EXT
TileStoreYTable   EXT
NextCol           EXT
RTable            EXT
BlitBuff          EXT
BTableHigh        EXT
BTableLow         EXT
BRowTableHigh     EXT
BRowTableLow      EXT
BG1YTable         EXT
BG1YOffsetTable   EXT
OldOneSecVec      EXT
OneSecondCounter  EXT
Timers            EXT
DefaultPalette    EXT
ScreenModeWidth   EXT
ScreenModeHeight  EXT
_SpriteBits       EXT
_SpriteBitsNot    EXT
VBuffArray        EXT
_stamp_step       EXT
VBuffVertTableSelect EXT
VBuffHorzTableSelect EXT
; Overlays          EXT
BG1YCache         EXT
ScalingTables     EXT

;StartXMod164Arr    EXT
;LastPatchOffsetArr EXT

_SortedHead EXT
_ShadowListCount  EXT
_ShadowListTop    EXT
_ShadowListBottom EXT
_DirectListCount  EXT
_DirectListTop    EXT
_DirectListBottom EXT
ObjectListCount   EXT
ObjectListHead    EXT
ObjectList        EXT
StartXMod164Tbl   EXT
LastOffsetTbl     EXT
BG1StartXMod164Tbl EXT
ExtSpriteRenderer EXT
ExtUpdateBG0Tiles  EXT

; Tool error codes
NO_TIMERS_AVAILABLE  equ  10

; Offsets for the Lite blitter
_ENTRY_1   equ 0
_ENTRY_JMP equ 4
_ENTRY_ODD equ 11
_ENTRY_INT equ 14
_LOOP      equ 38
_EXIT_ODD  equ 290
_EXIT_EVEN equ 293
_LOW_SAVE  equ 296

_LINE_BASE equ 4                        ; header size
_LINE_SIZE equ 298                      ; number of bytes for each blitter line
