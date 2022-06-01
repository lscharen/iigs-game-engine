                REL
                DSK   MAINSEG

                use   Locator.Macs
                use   Load.Macs
                use   Mem.Macs
                use   Misc.Macs
                use   Util.Macs
                use   EDS.GSOS.Macs
                use   GTE.Macs

                use   ../../src/Defs.s

                mx         %00

TSZelda         EXT                           ; tileset buffer

ScreenX         equ   0
ScreenY         equ   2

; Typical init
                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the aoplication into the program
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

; Create stamps for the sprites we are going to use
HERO_SPRITE_1   equ   SPRITE_16X16+1
HERO_SLOT       equ   0

                pea   HERO_SPRITE_1                 ; sprint id
                pea   VBUFF_SPRITE_START            ; vbuff address
                _GTECreateSpriteStamp

; Create sprites
                pea   HERO_SPRITE_1                 ; sprite id
                pea   #0                            ; screen x-position (<256)
                pea   #0                            ; screen y-position (<256)
                pea   HERO_SLOT                     ; sprite slot (0 - 15)
                _GTEAddSprite

                pea   HERO_SLOT                     ; update the sprite in this slot
                pea   $0000                         ; with these flags (h/v flip)
                pea   VBUFF_SPRITE_START            ; and use this stamp
                _GTEUpdateSprite

; Manually fill in the 41x26 tiles of the TileStore with a test pattern.

                ldx   #0
                ldy   #0

:loop
                phx
                phy

                phx
                phy
                lda   0
                clc
                adc   #64
                pha
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
:skip

                stz   ScreenX
                stz   ScreenY

; Very simple actions
:evt_loop
                pha                           ; space for result, with pattern
                _GTEReadControl
                pla
                and   #$00FF
                cmp   #'q'
                beq   :exit

                cmp   #$15                    ; left = $08, right = $15, up = $0B, down = $0A
                bne   :8
                inc   ScreenX
                bra   :next

:8              cmp   #$08
                bne   :9
                dec   ScreenX
                bra   :next

:9              cmp   #$0B
                bne   :10
                inc   ScreenY
                bra   :next

:10             cmp   #$0A
                bne   :next
                dec   ScreenY

:next
                pei   ScreenX
                pei   ScreenY
                _GTESetBG0Origin

; Update the sprite each frame for testing
;                pea   HERO_SLOT
;                pea   $0000
;                pea   VBUFF_SPRITE_START
;                _GTEUpdateSprite

                _GTERender

; Debug stuff
                ldx   #$100
                lda   StartX,x
                ldx   #0
                jsr   DrawWord

                ldx   #$100
                lda   StartY,x
                ldx   #160*8
                jsr   DrawWord

                lda   ScreenX
                ldx   #160*16
                jsr   DrawWord

                lda   ScreenY
                ldx   #160*24
                jsr   DrawWord

                tdc
                ldx   #160*32
                jsr   DrawWord

                brl   :evt_loop

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

                lda   MyUserId
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
                lda   MyUserId                  ; Pass the userId for memory allocation
                pha
                _GTEStartUp
                bcc    :ok3
                brk    $03

:ok3
                rts

MyUserId        ds    2
ToolPath        str   '1/Tool160'

                PUT        App.Msg.s
                PUT        font.s
