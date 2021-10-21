; Collection of the EXTernal labels exported by GTE.  This is the closest thing
; we have to an API definition.

EngineStartUp      EXT
EngineShutDown     EXT

SetScreenMode      EXT
ReadControl        EXT

; Low-Level Functions
SetPalette         EXT
GetVBLTicks        EXT

; Tilemap functions
SetBG0XPos         EXT
SetBG0YPos         EXT
SetBG1XPos         EXT
SetBG1YPos         EXT
CopyBG0Tile        EXT
CopyBG1Tile        EXT
CopyTileToDyn      EXT
Render             EXT

; Rotation
ApplyBG1XPosAngle  EXT
ApplyBG1YPosAngle  EXT

CopyPicToField     EXT
CopyBinToField     EXT
CopyBinToBG1       EXT

AddTimer           EXT
RemoveTimer        EXT
DoTimers           EXT

StartScript        EXT
StopScript         EXT

; Sprite functions
AddSprite          EXT

; Direct access to internals
DoScriptSeq        EXT
GetTileAddr        EXT

; Allocate a full 64K bank
AllocBank          EXT

; Data references
;
; Super Hires line address lookup table for convenience
ScreenAddr         EXT
OneSecondCounter   EXT
BlitBuff           EXT
