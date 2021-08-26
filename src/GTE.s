; Collection of the EXTernal labels exported by GTE.  This is the closest thing
; we have to an API definition.

EngineStartUp      EXT
EngineShutDown     EXT

SetScreenMode      EXT
ReadControl        EXT

SetBG0XPos         EXT
SetBG0YPos         EXT
SetBG1XPos         EXT
SetBG1YPos         EXT
CopyBG0Tile        EXT
CopyBG1Tile        EXT
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

; Allocate a full 64K bank
AllocBank          EXT

; Data references
;
; Super Hires line address lookup table for convenience
ScreenAddr         EXT
OneSecondCounter   EXT
BlitBuff           EXT

