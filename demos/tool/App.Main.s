                REL
                DSK   MAINSEG

                use   Locator.Macs
                use   Load.Macs
                use   Mem.Macs
                use   Misc.Macs
                use   Util.Macs
                use   EDS.GSOS.Macs
                use   GTE.Macs

                mx         %00

TSZelda         EXT                           ; tileset buffer

ScreenX         equ   0
ScreenY         equ   2

; Typical init
                phk
                plb

                sta   UserId                  ; GS/OS passes the memory manager user ID for the aoplication into the program
                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize the graphics screen to a 256x160 playfield

                pea   #256
                pea   #160
                _GTESetScreenMode

; Load a tileset

                pea   #^TSZelda
                pea   #TSZelda
                _GTELoadTileSet

; Manually fill in the 41x26 tiles of the TileStore with a test pattern.

                ldx   #0
                ldy   #0

:loop
                phx
                phy

                phx
                phy
                pei   0
                _GTESetTile

                lda   0
                inc
                and   #$001F
                sta   0

                ply
                plx
                inx
                cpx   #41
                bcc   :loop

                ldx   #0
                iny
                cpy   #26
                bcc   :loop

; Set the origin of the screen
                stz   ScreenX
                stz   ScreenY

; Very simple actions
:loop
                pha                           ; space for result, with pattern
                _GTEReadControl
                pla
                and   #$00FF
                cmp   #'q'
                beq   :exit

                pei   ScreenX
                pei   ScreenY
                _GTESetBG0Origin

                _GTERender

                inc   ScreenX                 ; Just keep incrementing, it's OK
                bra   :loop

; Shut down everything
:exit
                _GTEShutDown
                _QuitGS qtRec
qtRec           adrl       $0000
                da         $00

; Load the GTE User Tool and install it
GTEStartUp
                pea   $0000
                _LoaderStatus
                pla

                pea   $0000
                pea   $0000
                pea   $0000
                pea   $0000
                pea   $0000                   ; result space

                lda   UserId
                pha

                pea   #^ToolPath
                pea   #ToolPath
                pea   $0001                   ; do not load into special memory
                _InitialLoad
                bcc    :ok1
                brk    $01

:ok1
                ply
                pla                           ; Address of the loaded tool
                plx
                ply
                ply

                pea   $8000                   ; User toolset
                pea   $00A0                   ; Set the tool set number
                phx
                pha                           ; Address of function pointer table
                _SetTSPtr
                bcc    :ok2
                brk    $02

:ok2
                clc                           ; Give GTE a page of direct page memory
                tdc
                adc   #$0100
                pha
                pea   $0000                   ; No extra capabilities
                lda   UserId                  ; Pass the userId for memory allocation
                pha
                _GTEStartUp
                bcc    :ok3
                brk    $03

:ok3
                rts

MasterId        ds    2
UserId          ds    2
ToolPath        str   '1/Tool160'