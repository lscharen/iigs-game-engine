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

MAX_SPRITES     equ   16

ScreenX         equ   0
ScreenY         equ   2
Tmp0            equ   4
Tmp1            equ   6
KeyState        equ   8
Selected        equ   10
Flips           equ   12
DTile           equ   14
Tmp2            equ   16
ScreenWidth     equ   18
ScreenHeight    equ   20

; Typical init
                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                lda   #ENGINE_MODE_USER_TOOL+ENGINE_MODE_TWO_LAYER
                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize the graphics screen to a 256x160 playfield

                pea   #160
                pea   #200
                _GTESetScreenMode

; Load a tileset

                pea   0
                pea   120
                pea   #^TSZelda
                pea   #TSZelda
                _GTELoadTileSet

; Set the palette
                pea   $0000
                pea   #^palette
                pea   #palette
                _GTESetPalette

                jsr   SetLimits

; Create stamps for the sprites we are going to use
HERO_SPRITE     equ   SPRITE_16X16+1

                pea   HERO_SPRITE                   ; sprint id
                pea   VBUFF_SPRITE_START            ; vbuff address
                _GTECreateSpriteStamp

; Create sprites
                stz   Tmp0
                stz   Tmp1                          ; Slot number

                ldx   Tmp0
:sloop
                pei   Tmp1                          ; Put the sprite in this slot
                pea   SPRITE_16X16                  ; with these flags (h/v flip)
                pea   VBUFF_SPRITE_START
                lda   PlayerX,x
                pha
                lda   PlayerY,x
                pha
                _GTEAddSprite

                inc   Tmp1
                ldx   Tmp0
                inx
                inx
                stx   Tmp0
                cpx   #MAX_SPRITES*2
                bcc   :sloop

; Manually fill in the 41x26 tiles of the TileStore with a test pattern of trees

                jsr   _fillTileStore

; Initialize the frame counter

                stz   FrameCount

; Set the screen coordinates

                lda   #0
                sta   ScreenX
                lda   #0
                sta   ScreenY

                stz   Selected
                stz   Flips

; Very simple actions
:evt_loop
                pha                           ; space for result, with pattern
                _GTEReadControl
                pla

                jsr   HandleKeys                   ; Do the generic key handlers
                bcs   :do_more
                brl   :do_render
:do_more
                and   #$007F
                cmp   #'a'
                bne   :skip_a
                inc   ScreenX
                pei   ScreenX
                pei   ScreenY
                _GTESetBG0Origin
                brl   :do_render
:skip_a
                cmp   #'z'
                bne   :skip_z
                inc   PlayerX
                pea   0
                lda   PlayerX
                pha
                lda   PlayerY
                pha
                _GTEMoveSprite 
:skip_z
 
:do_render
                jsr  _moveSprites

                pea  #RENDER_WITH_SHADOWING
                _GTERender

; Update the performance counters

                inc   FrameCount
                pha
                _GTEGetSeconds
                pla
                cmp   LastSecond
                beq   :no_fps
                sta   LastSecond

;                lda   FrameCount
;                ldx   #0
;                ldy   #$FFFF
;                jsr   DrawWord

                stz   FrameCount
:no_fps
                brl   :evt_loop

; Shut down everything
Exit
                _GTEShutDown
                _QuitGS qtRec
qtRec           adrl       $0000
                da         $00

; Array of sprite positions and velocities
PlayerX  dw  8,14,29,34,45,67,81,83,92,101,39,22,7,74,111,9
PlayerY  dw  72,24,13,56,35,72,23,8,93,123,134,87,143,14,46,65
PlayerU  dw  1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4
PlayerV  dw  1,1,1,1,2,2,2,4,3,3,3,3,4,4,4,4

_moveSprites
                stz   Tmp0
:loop
                ldx   Tmp0

                lda   PlayerX,x
                clc
                adc   PlayerU,x
                sta   PlayerX,x

                bpl   :chk_xpos
                eor   #$FFFF
                inc
                sta   PlayerX,x
                bra   :rev_x
:chk_xpos
                cmp   ScreenWidth
                bcc   :ok_x
                sbc   ScreenWidth
                eor   #$FFFF
                inc
                clc
                adc   ScreenWidth
                sta   PlayerX,x

:rev_x
                lda   PlayerU,x                ; reverse the velocity
                eor   #$FFFF
                inc
                sta   PlayerU,x
:ok_x

                lda   PlayerY,x
                clc
                adc   PlayerV,x
                sta   PlayerY,x
                bpl   :chk_ypos
                eor   #$FFFF
                inc
                sta   PlayerY,x
                bra   :rev_y
:chk_ypos
                cmp   ScreenHeight
                bcc   :ok_y
                sbc   ScreenHeight
                eor   #$FFFF
                inc
                clc
                adc   ScreenHeight
                sta   PlayerY,x

:rev_y
                lda   PlayerV,x                ; reverse the velocity
                eor   #$FFFF
                inc
                sta   PlayerV,x

:ok_y
                txa
                lsr
                pha
                lda   PlayerX,x
                pha
                lda   PlayerY,x
                pha
                _GTEMoveSprite

                lda   Tmp0
                inc
                inc
                sta   Tmp0
                cmp   #2*MAX_SPRITES
                bcc   :loop
                rts

; Called by StartUp function callbacks when the screen size changes
SetLimits
                pha                       ; Allocate space for x, y, width, height
                pha
                pha
                pha
                _GTEGetScreenInfo
                pla
                pla                       ; Discard screen corner
                pla
                sec
                sbc   #8
                sta   ScreenWidth         ; Pre-adjust to keep sprites on the visible playfield (for compiled sprites)
                pla
                sec
                sbc   #16
                sta   ScreenHeight
                rts

_fillTileStore
                sta    Tmp2
                stz    Tmp0
:oloop
                stz    Tmp1
:iloop
                ldx    Tmp1
                ldy    Tmp0
                jsr    _drawTree

                lda    Tmp1
                inc
                inc
                sta    Tmp1
                cmp    #40
                bcc    :iloop

                lda    Tmp0
                inc
                inc
                sta    Tmp0
                cmp    #25
                bcc    :oloop
                rts

;   Tile 65 Tile 66
;   Tile 97 Tile 98

_drawTreeFront
                phx
                phy
                pea   #65+TILE_PRIORITY_BIT
                
                inx
                phx
                phy
                pea   #66+TILE_PRIORITY_BIT

                iny
                phx
                phy
                pea   #98+TILE_PRIORITY_BIT

                dex
                phx
                phy
                pea   #97+TILE_PRIORITY_BIT

                _GTESetTile
                _GTESetTile
                _GTESetTile
                _GTESetTile
                rts

_drawTree
                phx
                phy
                pea   #65
                
                inx
                phx
                phy
                pea   #66

                iny
                phx
                phy
                pea   #98

                dex
                phx
                phy
                pea   #97

                _GTESetTile
                _GTESetTile
                _GTESetTile
                _GTESetTile
                rts

_drawTreeH
                phx
                phy
                pea   #66+TILE_HFLIP_BIT

                inx
                phx
                phy
                pea   #65+TILE_HFLIP_BIT

                iny
                phx
                phy
                pea   #97+TILE_HFLIP_BIT

                dex
                phx
                phy
                pea   #98+TILE_HFLIP_BIT

                _GTESetTile
                _GTESetTile
                _GTESetTile
                _GTESetTile
                rts

_drawTreeV
                phx
                phy
                pea   #97+TILE_VFLIP_BIT
                
                inx
                phx
                phy
                pea   #98+TILE_VFLIP_BIT

                iny
                phx
                phy
                pea   #66+TILE_VFLIP_BIT

                dex
                phx
                phy
                pea   #65+TILE_VFLIP_BIT

                _GTESetTile
                _GTESetTile
                _GTESetTile
                _GTESetTile
                rts

_drawTreeHV
                phx
                phy
                pea   #98+TILE_VFLIP_BIT+TILE_HFLIP_BIT
                
                inx
                phx
                phy
                pea   #97+TILE_VFLIP_BIT+TILE_HFLIP_BIT

                iny
                phx
                phy
                pea   #65+TILE_VFLIP_BIT+TILE_HFLIP_BIT

                dex
                phx
                phy
                pea   #66+TILE_VFLIP_BIT+TILE_HFLIP_BIT

                _GTESetTile
                _GTESetTile
                _GTESetTile
                _GTESetTile
                rts

MyUserId        ds    2
FrameCount      ds    2
LastSecond      dw    0
palette         dw $0000,$08C1,$0C41,$0F93,$0777,$0FDA,$00A0,$0000,$0D20,$0FFF,$023E,$0,$0,$0,$0,$0

                PUT        ../kfest-2022/StartUp.s
                PUT        App.Msg.s
                PUT        font.s
