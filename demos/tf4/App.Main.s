; Test driver to exercise graphics routines.

                REL
                DSK   MAINSEG

                use   Locator.Macs
                use   Load.Macs
                use   Mem.Macs
                use   Misc.Macs
                use   Util.Macs
                use   EDS.GSOS.Macs
                use   GTE.Macs

                mx    %00

tiledata        EXT                           ; tileset buffer
;TileSetPalette  EXT

; Keycodes
LEFT_ARROW      equ   $08
RIGHT_ARROW     equ   $15
UP_ARROW        equ   $0B
DOWN_ARROW      equ   $0A

; Direct page space
MyUserId        equ   0
BankLoad        equ   2
StartX          equ   4
StartY          equ   6
TileMapWidth    equ   8
TileMapHeight   equ   10
ScreenWidth     equ   12
ScreenHeight    equ   14
MaxGlobalX      equ   16
MaxGlobalY      equ   18
MaxBG0X         equ   20
MaxBG0Y         equ   22
OldOneSecondCounter equ 26
appTmp0         equ   28
appTmp1         equ   30
appTmp2         equ   32

                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                tdc
                sta   MyDirectPage            ; Keep a copy for the overlay callback

                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                lda   #ENGINE_MODE_USER_TOOL+ENGINE_MODE_TWO_LAYER
                jsr   GTEStartUp              ; Load and install the GTE User Tool

                pea   $0000                   ; Set the first two tiles
                pea   $0002
                pea   #^TileData
                pea   #TileData
                _GTELoadTileSet

                pea   $0000
                pea   #^TileSetPalette
                pea   #TileSetPalette
                _GTESetPalette

; Fill in the field with a checkboard pattern

                stz   appTmp1

:tloop0         stz   appTmp0
:tloop1         lda   appTmp0     ; X
                pha
                pei   appTmp1     ; Y
                eor   appTmp1
                and   #$0001
                pha               ; tile ID
                _GTESetTile

                inc   appTmp0
                lda   #40
                cmp   appTmp0
                bcs   :tloop1

                inc   appTmp1
                lda   #25
                cmp   appTmp1
                bcs   :tloop0

; Set up a very specific test.  First, we draw a sprite into the sprite plane, and then
; leave it alone.  We are just testing the ability to merge sprite plane data into 
; the play field tiles.
EvtLoop
                pha
                _GTEReadControl
                pla

                jsr   HandleKeys                   ; Do the generic key handlers

                pea  #RENDER_PER_SCANLINE          ; Scanline rendering
;                pea  $0000
                _GTERender

                brl   EvtLoop

; Exit code
Exit
                _GTEShutDown
Quit
                _QuitGS    qtRec

                bcs   Fatal
Fatal           brk   $00

qtRec           adrl  $0000
                da    $00

; Color palette
TileSetPalette  dw    $0000,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF,$0FFF

MyDirectPage    ds    2

; Stub
SetLimits       rts

                PUT        ../kfest-2022/StartUp.s
                PUT        Tiles.s
