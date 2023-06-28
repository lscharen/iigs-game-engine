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
Tmp0            equ   4
Tmp1            equ   6
KeyState        equ   8
Selected        equ   10
Flips           equ   12
DTile           equ   14
Tmp2            equ   16
ScreenWidth     equ   18
ScreenHeight    equ   20
SpriteFlags     equ   22
frameCount      equ   24
OldOneSecondCounter equ 26
SpriteAddr      equ   28
RenderMode      equ   30

; Control modes
DefaultMode     equ   RENDER_WITH_SHADOWING
SlowSprites     equ   0

; Typical init
                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                tdc
                sta   MyDirectPage            ; Keep a copy for the overlay callback

                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                lda   #ENGINE_MODE_USER_TOOL
                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Init local variables

                stz   frameCount

; Initialize the graphics screen to a 256x160 playfield

                pea   #160
                pea   #200
                _GTESetScreenMode

; Load a tileset

                pea   0
                pea   360
                pea   #^TSZelda
                pea   #TSZelda
                _GTELoadTileSet

; Set the palette
                pea   $0000
                pea   #^palette
                pea   #palette
                _GTESetPalette

                jsr   SetLimits

                pha
                _GTEGetSeconds
                pla
                sta   OldOneSecondCounter

; Manually fill in the 41x26 tiles of the TileStore with a test pattern of trees

                jsr   _fillTileStore

                pha
                pha
                pea   liteBlitter
                _GTEGetAddress
                pla
                plx

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
                bra   :evt_loop
:do_more
                bit   #PAD_KEY_DOWN
                beq   :evt_loop

                and   #$007F
                cmp   #'a'
                bne   :not_a
                dec   ScreenX
:not_a          cmp   #'s'
                bne   :not_s
                inc   ScreenX
:not_s
 
:do_render      jsr   :next_frame
                brl   :evt_loop

:next_frame
                pei   ScreenX
                pei   ScreenY
                _GTESetBG0Origin

                pea    $FFFE
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
                rts

; Shut down everything
Exit
                _GTEShutDown
                _QuitGS qtRec
qtRec           adrl       $0000
                da         $00

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
                clc
                adc    #2
                sta    Tmp1
                cmp    #40
                bcc    :iloop

                lda    Tmp0
                clc
                adc    #2
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

MyDirectPage    ds    2
MyUserId        ds    2
palette         dw    $0000,$08C1,$0C41,$0F93,$0777,$0FDA,$00A0,$0000,$0D20,$0FFF,$0FD7,$0F59,$0000,$01CE,$0EDA,$0EEE

                PUT        ../kfest-2022/StartUp.s
                PUT        ../shell/Overlay.s

;                PUT        App.Msg.s
;                PUT        font.s
