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
TileSetPalette  EXT

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

                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                tdc
                sta   MyDirectPage            ; Keep a copy for the overlay callback

                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                lda   #ENGINE_MODE_USER_TOOL  ; Engine in Fast Mode as a User Tool
                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize local variables

                stz   StartX
                stz   StartY
                stz   frameCount

; Load a tileset

;                pea   0
;                pea   256
;                pea   #^tiledata
;                pea   #tiledata
;                _GTELoadTileSet

                pea   $0000
                pea   #^TileSetPalette
                pea   #TileSetPalette
                _GTESetPalette

; Set up our level data

                jsr   BG0SetUp
                jsr   SetLimits

                lda   #193                    ; Tile ID of '0'
                jsr   InitOverlay             ; Initialize the status bar
                pha
                _GTEGetSeconds
                pla
                sta   OldOneSecondCounter
                jsr   UdtOverlay

; Set up a very specific test.  First, we draw a sprite into the sprite plane, and then
; leave it alone.  We are just testing the ability to merge sprite plane data into 
; the play field tiles.
EvtLoop
                pha
                _GTEReadControl
                pla

                jsr   HandleKeys                   ; Do the generic key handlers
                bcs   :do_more
                brl   :do_render

:do_more
                cmp        #'d'
                bne        :not_d
                lda        StartX
                cmp        MaxBG0X
                bcc        *+5
                brl        :do_render
                inc        StartX
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                brl        :do_render
:not_d

                cmp        #'a'
                bne        :not_a
                lda        StartX
                bne        *+5
                brl        :do_render
                dec        StartX
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                brl        :do_render
:not_a

                cmp        #'s'
                bne        :not_s
                lda        StartY
                cmp        MaxBG0Y
                bcs        :do_render
                inc        StartY
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                bra        :do_render
:not_s

                cmp        #'w'
                bne        :not_w
                lda        StartY
                beq        :do_render
                dec        StartY
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                bra        :do_render
:not_w

:do_render
                pea  $0000
                _GTERender

; Update the performance counters

                inc   frameCount
                pha
                _GTEGetSeconds
                pla
                cmp   OldOneSecondCounter
                beq   :noudt
                sta   OldOneSecondCounter
                jsr   UdtOverlay
                stz   frameCount
:noudt
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
MyDirectPage    ds    2

SetLimits
                pha                       ; Allocate space for width (in tiles), height (in tiles), pointer
                pha
                pha
                pha
                _GTEGetBG0TileMapInfo
                pla
                sta   TileMapWidth
                pla
                sta   TileMapHeight
                pla
                pla                       ; discard the pointer

                pha                       ; Allocate space for x, y, width, height
                pha
                pha
                pha
                _GTEGetScreenInfo
                pla
                pla                       ; Discard screen corner
                pla
                sta   ScreenWidth
                pla
                sta   ScreenHeight

                lda   TileMapWidth
                asl
                asl
                sta   MaxGlobalX
                sec
                sbc   ScreenWidth
                sta   MaxBG0X

                lda   TileMapHeight
                asl
                asl
                asl
                sta   MaxGlobalY
                sec
                sbc   ScreenHeight
                sta   MaxBG0Y

; Check if the current StartX and StartY are out of bounds
                lda   StartX
                cmp   MaxBG0X
                bcc   :x_ok
                lda   MaxBG0X
:x_ok           pha

                lda   StartY
                cmp   MaxBG0Y
                bcc   :y_ok
                lda   MaxBG0Y
:y_ok           pha
                _GTESetBG0Origin

                rts

frameCount      equ   24

                PUT        ../StartUp.s
                PUT        ../../shell/Overlay.s
                PUT        gen/App.TileMapBG0.s
