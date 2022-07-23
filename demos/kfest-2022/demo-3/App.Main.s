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

; Dynamic Tile Animations. Add 4 for each offset
;
; Tile IDs = 128,129,130,131
;            160,161,162,163
;            192,193,194,195
;            224,225,226,227
;
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

                lda   #ENGINE_MODE_DYN_TILES  ; Engine in Fast Mode
                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize local variables

                stz   StartX
                stz   StartY
                stz   frameCount

; Initialize the graphics screen playfield

                pea   #320
                pea   #200
                _GTESetScreenMode

; Load a tileset

                pea   #^tiledata
                pea   #tiledata
                _GTELoadTileSet

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
                bra   :do_render
:not_w

:do_render
                jsr   SetDynTiles

                pea   $0000
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

; Pick the correct shift for each of the 16 background tiles over 32 horizontal positions

SetDynTiles
                lda   StartX
                and   #$001F
                asl
                sta   appTmp0
                stz   appTmp1
                stz   appTmp2

                jsr   setDynRow

                lda   appTmp1
                clc
                adc   #4
                sta   appTmp1

                lda   appTmp2
                clc
                adc   #32
                sta   appTmp2

                jsr   setDynRow

                lda   appTmp1
                clc
                adc   #4
                sta   appTmp1

                lda   appTmp2
                clc
                adc   #32
                sta   appTmp2

                jsr   setDynRow

                lda   appTmp1
                clc
                adc   #4
                sta   appTmp1

                lda   appTmp2
                clc
                adc   #32
                sta   appTmp2

                jmp   setDynRow

setDynRow
                ldx   appTmp0
                lda   tile128,x
                clc
                adc   appTmp2
                inc
                pha
                lda   appTmp1
                clc
                adc   #0
                pha
                _GTECopyTileToDynamic

                ldx   appTmp0
                lda   tile129,x
                clc
                adc   appTmp2
                inc
                pha
                lda   appTmp1
                clc
                adc   #1
                pha
                _GTECopyTileToDynamic

                ldx   appTmp0
                lda   tile130,x
                clc
                adc   appTmp2
                inc
                pha
                lda   appTmp1
                clc
                adc   #2
                pha
                _GTECopyTileToDynamic

                ldx   appTmp0
                lda   tile131,x
                clc
                adc   appTmp2
                inc
                pha
                lda   appTmp1
                clc
                adc   #3
                pha
                _GTECopyTileToDynamic

                rts

tile128         dw   128,132,136,140,144,148,152,156
tile131         dw   131,135,139,143,147,151,155,159
tile130         dw   130,134,138,142,146,150,154,158
tile129         dw   129,133,137,141,145,149,153,157
                dw   128,132,136,140,144,148,152,156
                dw   131,135,139,143,147,151,155,159
                dw   130,134,138,142,146,150,154,158

;tile129         dw   129,133,137,141,145,149,153,157
;                dw   128,132,136,140,144,148,152,156
;                dw   131,135,138,143,147,151,155,159
;                dw   130,134,138,142,146,150,154,158



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
