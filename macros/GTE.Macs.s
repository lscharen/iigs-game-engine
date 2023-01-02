* Generic Tile Engine Macros
*   by Lucas Scharenbroich

GTEToolNum           equ   $A0

_GTEBootInit         MAC
                     UserTool  $0100+GTEToolNum
                     <<<
_GTEStartUp          MAC
                     UserTool  $0200+GTEToolNum
                     <<<
_GTEShutDown         MAC
                     UserTool  $0300+GTEToolNum
                     <<<
_GTEVersion          MAC
                     UserTool  $0400+GTEToolNum
                     <<<
_GTEReset            MAC
                     UserTool  $0500+GTEToolNum
                     <<<
_GTEStatus           MAC
                     UserTool  $0600+GTEToolNum
                     <<<
_GTEReadControl      MAC
                     UserTool  $0900+GTEToolNum
                     <<<
_GTESetScreenMode    MAC
                     UserTool  $0A00+GTEToolNum
                     <<<
_GTESetTile          MAC
                     UserTool  $0B00+GTEToolNum
                     <<<
_GTESetBG0Origin     MAC
                     UserTool  $0C00+GTEToolNum
                     <<<
_GTERender           MAC
                     UserTool  $0D00+GTEToolNum
                     <<<
_GTELoadTileSet      MAC
                     UserTool  $0E00+GTEToolNum
                     <<<
_GTECreateSpriteStamp MAC
                     UserTool  $0F00+GTEToolNum
                     <<<
_GTEAddSprite        MAC
                     UserTool  $1000+GTEToolNum
                     <<<
_GTEMoveSprite       MAC
                     UserTool  $1100+GTEToolNum
                     <<<
_GTEUpdateSprite     MAC
                     UserTool  $1200+GTEToolNum
                     <<<
_GTERemoveSprite     MAC
                     UserTool  $1300+GTEToolNum
                     <<<
_GTEGetSeconds       MAC
                     UserTool  $1400+GTEToolNum
                     <<<
_GTECopyTileToDynamic MAC
                      UserTool  $1500+GTEToolNum
                      <<<
_GTESetPalette       MAC
                     UserTool  $1600+GTEToolNum
                     <<<
_GTECopyPicToBG1     MAC
                     UserTool  $1700+GTEToolNum
                     <<<
_GTEBindSCBArray     MAC
                     UserTool  $1800+GTEToolNum
                     <<<
_GTEGetBG0TileMapInfo MAC
                     UserTool  $1900+GTEToolNum
                     <<<
_GTEGetScreenInfo    MAC
                     UserTool  $1A00+GTEToolNum
                     <<<
_GTESetBG1Origin     MAC
                     UserTool  $1B00+GTEToolNum
                     <<<
_GTEGetTileAt        MAC
                     UserTool  $1C00+GTEToolNum
                     <<<                     
_GTESetBG0TileMapInfo MAC
                     UserTool  $1D00+GTEToolNum
                     <<<
_GTESetBG1TileMapInfo MAC
                     UserTool  $1E00+GTEToolNum
                     <<<
_GTEAddTimer         MAC
                     UserTool  $1F00+GTEToolNum
                     <<<
_GTERemoveTimer      MAC
                     UserTool  $2000+GTEToolNum
                     <<<
_GTEStartScript      MAC
                     UserTool  $2100+GTEToolNum
                     <<<
_GTESetOverlay       MAC
                     UserTool  $2200+GTEToolNum
                     <<<
_GTEClearOverlay     MAC
                     UserTool  $2300+GTEToolNum
                     <<<
_GTEGetTileDataAddr  MAC
                     UserTool  $2400+GTEToolNum
                     <<<
_GTEFillTileStore    MAC
                     UserTool  $2500+GTEToolNum
                     <<<
_GTERefresh          MAC
                     UserTool  $2600+GTEToolNum
                     <<<
_GTERenderDirty      MAC
                     UserTool  $2700+GTEToolNum
                     <<<
_GTESetBG1Displacement MAC
                     UserTool  $2800+GTEToolNum
                     <<<
_GTESetBG1Rotation   MAC
                     UserTool  $2900+GTEToolNum
                     <<<
_GTEClearBG1Buffer   MAC
                     UserTool  $2A00+GTEToolNum
                     <<<
_GTESetBG1Scale      MAC
                     UserTool  $2B00+GTEToolNum
                     <<<
_GTEGetAddress       MAC
                     UserTool  $2C00+GTEToolNum
                     <<<

; EngineMode definitions
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

; Overlay flags
OVERLAY_MASKED         equ   $0000      ; Overlay has a mask, so the background must be draw first
OVERLAY_SOLID          equ   $8000      ; Overlay covers the scan line and is fully opaque
OVERLAY_ABOVE          equ   $0000      ; Overlay is drawn above scanline sprites
OVERLAY_BELOW          equ   $4000      ; Overlay is drawn below scanline sprites

; GetAddress table IDs
scanlineHorzOffset     equ   $0001

; Tile constants
; TILE_RESERVED_BIT      equ   $8000
TILE_PRIORITY_BIT      equ   $4000                  ; Put tile on top of sprite
TILE_FRINGE_BIT        equ   $2000                  ; Unused
TILE_SOLID_BIT         equ   $1000                  ; Hint bit used in TWO_LAYER_MODE to optimize rendering
TILE_DYN_BIT           equ   $0800                  ; Is this a Dynamic Tile?
TILE_VFLIP_BIT         equ   $0400
TILE_HFLIP_BIT         equ   $0200
TILE_ID_MASK           equ   $01FF
TILE_CTRL_MASK         equ   $FE00


; Sprite constants
SPRITE_HIDE            equ   $2000
SPRITE_16X16           equ   $1800
SPRITE_16X8            equ   $1000
SPRITE_8X16            equ   $0800
SPRITE_8X8             equ   $0000
SPRITE_VFLIP           equ   $0400
SPRITE_HFLIP           equ   $0200

; Stamp storage parameters
VBUFF_STRIDE_BYTES     equ {12*4}                        ; Each line has 4 slots of 16 pixels + 8 buffer pixels
VBUFF_TILE_ROW_BYTES   equ {8*VBUFF_STRIDE_BYTES}        ; Each row is comprised of 8 lines
VBUFF_TILE_COL_BYTES   equ 4
VBUFF_SPRITE_STEP      equ {VBUFF_TILE_ROW_BYTES*3}      ; Allocate space for 16 rows + 8 rows of buffer
VBUFF_SPRITE_START     equ {VBUFF_TILE_ROW_BYTES+4}      ; Start at an offset so $0000 can be used as an empty value
VBUFF_SLOT_COUNT       equ 48                            ; Have space for this many stamps
