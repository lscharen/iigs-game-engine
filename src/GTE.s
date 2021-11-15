; Collection of the EXTernal labels exported by GTE.  This is the closest thing
; we have to an API definition.

EngineStartUp      EXT
EngineShutDown     EXT

SetScreenMode      EXT
ReadControl        EXT

; Low-Level Functions
SetPalette         EXT
GetVBLTicks        EXT
GetVerticalCounter EXT
SetBorderColor     EXT

; Tilemap functions
SetBG0XPos         EXT
SetBG0YPos         EXT
SetBG1XPos         EXT
SetBG1YPos         EXT
CopyBG0Tile        EXT
CopyBG1Tile        EXT
CopyTileToDyn      EXT
Render             EXT

; SCB/Palette binding (high bit of array point indicates whether to bind to BG0 Y position (0)
; or BG1 Y position (1).
SetSCBArray        EXT
BltSCB             EXT

; Rotation
ApplyBG1XPosAngle  EXT
ApplyBG1YPosAngle  EXT

CopyPicToField     EXT
CopyBinToField     EXT
CopyPicToBG1       EXT
CopyBinToBG1       EXT

AddTimer           EXT
RemoveTimer        EXT
DoTimers           EXT

StartScript        EXT
StopScript         EXT

; Sprite functions
AddSprite          EXT
UpdateSprite       EXT

; Direct access to internals
DoScriptSeq        EXT
GetTileAddr        EXT

PushDirtyTile      EXT    ; A = address from GetTileStoreOffset, marks as dirty (will not mark the same tile more than once)
PopDirtyTile       EXT    ; No args, returns Y with tile store offset of the dirty tile
ApplyTiles         EXT    ; Drain the dirty tile queue and call RenderTile on each
RenderTile         EXT    ; Y = address from GetTileStoreOffset
GetTileStoreOffset EXT    ; X = column, Y = row
TileStore          EXT    ; Tile store internal data structure

DrawTileSprite     EXT    ; X = target address in sprite plane, Y = address in tile bank
EraseTileSprite    EXT    ; X = target address is sprite plane
GetSpriteVBuffAddr EXT    ; X = x-coordinate (0 - 159), Y = y-coordinate (0 - 199). Return in Acc.

; Allocate a full 64K bank
AllocBank          EXT

; Data references
;
; Super Hires line address lookup table for convenience
ScreenAddr         EXT
OneSecondCounter   EXT
BlitBuff           EXT
