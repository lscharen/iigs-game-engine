/* ********************************************************************
 
 GTE is copyright Lucas Scharenbroich and licensed under the Apache-2.0
 License.

 The following GTE function definitions are taken from the GTE Toolbox
 documentation:
 https://lscharen.github.io/iigs-game-engine/toolboxref.html
 
 And from the GTE Macros:
 https://github.com/lscharen/iigs-game-engine/blob/d7be9f1be44748b0180c930b1f90b144cda661ea/macros/GTE.Macs.s
 
 The contents of this file are a derivite work from GTE intended to
 ease the process of calling GTE / Tool 160 from ORCA/C and are believed
 to be permitted under the terms of the Apache-2.0 License.

 ********************************************************************* */

#ifndef _GTE_HEADER_INCLUDE_
#define _GTE_HEADER_INCLUDE_

#include <types.h>

/*
 GTE_IS_SYSTEM_TOOLS_INSTALL is a boolean toggle for controlling what the application assumes about the location of the GTE tool.

 If GTE is installed in System:Tools, GTE_IS_SYSTEM_TOOLS_INSTALL must be defined.
 Otherwise, GTE_IS_SYSTEM_TOOLS_INSTALL must be undefined.

 This will control which header file is used as well as the calls used to load the tool during application startup.
*/
// #define GTE_IS_SYSTEM_TOOLS_INSTALL 1

#ifdef GTE_IS_SYSTEM_TOOLS_INSTALL
#define tool_dispatcher dispatcher
#else
#define tool_dispatcher 0xE10008L
#endif // GTE_IS_SYSTEM_TOOLS_INSTALL

typedef struct TileMapInfo {
    Word width;
    Word height;
    Pointer tileMapPtr;
} TileMapInfo;

typedef struct ScreenInfo {
    Word x;
    Word y;
    Word width;
    Word height;
} ScreenInfo;

/* GTE Housekeeping Routines */
extern pascal void GTEBootInit(void) inline(0x01A0, tool_dispatcher);
extern pascal void GTEStartUp(Word dPageAddr, Word capFlags, Word userID) inline(0x02A0, tool_dispatcher);
extern pascal void GTEShutDown(void) inline(0x03A0, tool_dispatcher);
extern pascal Word GTEVersion(void) inline(0x04A0, tool_dispatcher);
extern pascal void GTEReset(void) inline(0x05A0, tool_dispatcher);
extern pascal Word GTEStatus(void) inline(0x06A0, tool_dispatcher);


/* GTE Sprite Routines */
extern pascal void GTECreateSpriteStamp(Word spriteDescriptor, Word vBuffAddr) inline(0x0FA0, tool_dispatcher);
extern pascal Word GTECompileSpriteStamp(Word spriteDescriptor, Word vBuffAddr) inline(0x2DA0, tool_dispatcher);
extern pascal void GTEAddSprite(Word spriteSlot, Word spriteFlags, Word vBuffAddr, Word x, Word y) inline(0x10A0, tool_dispatcher);
extern pascal void GTEMoveSprite(Word spriteSlot, Word x, Word y) inline(0x11A0, tool_dispatcher);
extern pascal void GTEUpdateSprite(Word spriteSlot, Word spriteFlags, Word vBuffAddr) inline(0x12A0, tool_dispatcher);
extern pascal void GTERemoveSprite(Word spriteSlot) inline(0x13A0, tool_dispatcher);


/* GTE Tile Routines */
extern pascal void GTELoadTileSet(Word start, Word finish, Pointer tileSetPtr) inline(0x0EA0, tool_dispatcher);
extern pascal void GTEFillTileStore(Word tileID) inline(0x25A0, tool_dispatcher);
extern pascal void GTESetTile(Word xTile, Word yTile, Word tileID) inline(0x0BA0, tool_dispatcher);
extern pascal void GTECopyTileToDynamic(Word tileID, Word dynID) inline(0x15A0, tool_dispatcher);
extern pascal Word GTEGetTileAt(Word x, Word y) inline(0x1CA0, tool_dispatcher);
extern pascal Pointer GTEGetTileDataAddr() inline(0x24A0, tool_dispatcher);


/* GTE Primary Background Routines */
extern pascal void GTESetBG0Origin(Word x, Word y) inline(0x0CA0, tool_dispatcher);
extern pascal void GTERender(Word flags) inline(0x0DA0, tool_dispatcher);
extern pascal void GTERefresh() inline(0x26A0, tool_dispatcher);
extern pascal struct TileMapInfo GTEGetBG0TileMapInfo() inline(0x19A0, tool_dispatcher);
extern pascal void GTESetBG0TileMapInfo(Word width, Word height, Pointer tileMapPtr) inline(0x1DA0, tool_dispatcher);


/* GTE Secondary Background Routines */
extern pascal void GTESetBG1Origin(Word x, Word y) inline(0x1BA0, tool_dispatcher);
extern pascal void GTECopyPicToBG1(Word width, Word height, Word stride, Pointer picPtr) inline(0x17A0, tool_dispatcher);
extern pascal void GTESetBG1TileMapInfo(Word width, Word height, Pointer tileMapPtr) inline(0x1EA0, tool_dispatcher);


/* GTE Global State Functions */
extern pascal void GTESetScreenMode(Word width, Word height) inline(0x0AA0, tool_dispatcher);
extern pascal void GTESetPalette(Word palNum, Pointer palettePtr) inline(0x16A0, tool_dispatcher);
extern pascal void GTEBindSCBArray(Pointer scbPtr) inline(0x18A0, tool_dispatcher);
extern pascal struct ScreenInfo GTEGetScreenInfo() inline(0x1AA0, tool_dispatcher);
extern pascal void GTESetBG1Displacement(Word offset) inline(0x27A0, tool_dispatcher);
extern pascal void GTESetBG1Rotation(Word rotIndex) inline(0x28A0, tool_dispatcher);
extern pascal void GTEClearBG1Buffer(Word value) inline(0x29A0, tool_dispatcher);


/* GTE Misc. Functions */
extern pascal Word GTEReadControl(void) inline(0x09A0, tool_dispatcher);
extern pascal Word GTEGetSeconds(void) inline(0x14A0, tool_dispatcher);
extern pascal Pointer GTEGetAddress(Word tableId) inline(0x2CA0, tool_dispatcher);
extern pascal void GTESetAddress(Word tableId, Pointer pointer) inline(0x2EA0, tool_dispatcher);


/* GTE Timer Functions */
extern pascal Word GTEAddTimer(Word numTicks, Pointer callback, Word flags) inline(0x1FA0, tool_dispatcher);
extern pascal Word GTERemoveTimer(Word timerID) inline(0x20A0, tool_dispatcher);
extern pascal Word GTEStartScript(Word numTicks, Pointer scriptAddr) inline(0x21A0, tool_dispatcher);


/* GTE Overlay Functions */
extern pascal Word GTESetOverlay(Word top, Word bottom, Pointer procPtr) inline(0x22A0, tool_dispatcher);
extern pascal Word GTEClearOverlay() inline(0x23A0, tool_dispatcher);


/* ReadControl return value bits */
#define PAD_BUTTON_B               0x0100
#define PAD_BUTTON_A               0x0200
#define PAD_KEY_DOWN               0x0400

/* GTE EngineMode definitions */
#define ENGINE_MODE_TWO_LAYER      0x0001
#define ENGINE_MODE_DYN_TILES      0x0002
#define ENGINE_MODE_BNK0_BUFF      0x0004
#define ENGINE_MODE_USER_TOOL      0x8000       /* Communicate if GTE is loaded as a system tool, or a user tool */

/* GTE Render Flags */
#define RENDER_ALT_BG1             0x0001
#define RENDER_BG1_HORZ_OFFSET     0x0002
#define RENDER_BG1_VERT_OFFSET     0x0004
#define RENDER_BG1_ROTATION        0x0008

/* GTE Tile Constants */
#define TILE_PRIORITY_BIT          0x4000                  /* Put tile on top of sprite */
#define TILE_FRINGE_BIT            0x2000                  /* Unused */
#define TILE_SOLID_BIT             0x1000                  /* Hint bit used in TWO_LAYER_MODE to optimize rendering */
#define TILE_DYN_BIT               0x0800                  /* Is this a Dynamic Tile? */
#define TILE_VFLIP_BIT             0x0400
#define TILE_HFLIP_BIT             0x0200
#define TILE_ID_MASK               0x01FF
#define TILE_CTRL_MASK             0xFE00

/* GTE Sprite Constants */
#define GTE_SPRITE_HIDE            0x2000
#define GTE_SPRITE_16X16           0x1800
#define GTE_SPRITE_16X8            0x1000
#define GTE_SPRITE_8X16            0x0800
#define GTE_SPRITE_8X8             0x0000
#define GTE_SPRITE_VFLIP           0x0400
#define GTE_SPRITE_HFLIP           0x0200


/* GTE Sprint Stamp Storage Parameters */
#define GTE_VBUFF_STRIDE_BYTES     (12 * 4)                            /* Each line has 4 slots of 16 pixels + 8 buffer pixels */
#define GTE_VBUFF_TILE_ROW_BYTES   (8 * GTE_VBUFF_STRIDE_BYTES)        /* Each row is comprised of 8 lines */
#define GTE_VBUFF_TILE_COL_BYTES   (4)
#define GTE_VBUFF_SPRITE_STEP      (GTE_VBUFF_TILE_ROW_BYTES*3)        /* Allocate space for 16 rows + 8 rows of buffer */
#define GTE_VBUFF_SPRITE_START     (GTE_VBUFF_TILE_ROW_BYTES+4)        /* Start at an offset so $0000 can be used as an empty value */
#define GTE_VBUFF_SLOT_COUNT       (48)                                /* Have space for this many stamps */


#endif /* _GTE_HEADER_INCLUDE_ */