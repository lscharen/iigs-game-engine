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

; Typical init
                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize the graphics screen to a 256x160 playfield

                pea   #320
                pea   #200
                _GTESetScreenMode

; Load a tileset

                pea   #^TSZelda
                pea   #TSZelda
                _GTELoadTileSet

; Set the palette
                ldx   #11*2
:ploop
                lda   palette,x
                stal  $E19E00,x
                dex
                dex
                bpl   :ploop
                bra   sprt

palette dw $0000,$08C1,$0C41,$0F93,$0777,$0FDA,$00A0,$0000,$0D20,$0FFF,$023E
sprt

; Create stamps for the sprites we are going to use
HERO_SPRITE     equ   SPRITE_16X16+1

                pea   HERO_SPRITE                   ; sprint id
                pea   VBUFF_SPRITE_START            ; vbuff address
                _GTECreateSpriteStamp

; Create sprites
                stz   Tmp0
                stz   Tmp1

                ldx   Tmp0
:sloop
                pea   HERO_SPRITE                   ; sprite id
                lda   PlayerX,x
                pha
                lda   PlayerY,x
                pha
                pei   Tmp1
                _GTEAddSprite

                pei   Tmp1                          ; update the sprite in this slot
                pea   $0000                         ; with these flags (h/v flip)
                pea   VBUFF_SPRITE_START            ; and use this stamp
                _GTEUpdateSprite

                inc   Tmp1
                ldx   Tmp0
                inx
                inx
                stx   Tmp0
                cpx   #MAX_SPRITES*2
                bcc   :sloop

; Manually fill in the 41x26 tiles of the TileStore with a test pattern of trees

;               lda   #TILE_DYN_BIT+TILE_PRIORITY_BIT+0                ; fill the screen the the dynamic tile slot 0
                lda   #TILE_DYN_BIT+0                ; fill the screen the the dynamic tile slot 0
                jsr   _fillTileStore
;                brl   :no_trees

                ldx   #0
                ldy   #0
                jsr   _drawTree

                ldx   #3
                ldy   #0
                jsr   _drawTreeH

                ldx   #0
                ldy   #3
                jsr   _drawTreeV

                ldx   #3
                ldy   #3
                jsr   _drawTreeHV

                ldx   #9
                ldy   #0
                jsr   _drawTree

                ldx   #9
                ldy   #3
                jsr   _drawTree

                ldx   #12
                ldy   #0
                jsr   _drawTree

                ldx   #12
                ldy   #3
                jsr   _drawTree

                ldx   #6
                ldy   #0
                jsr   _drawTreeFront

                ldx   #6
                ldy   #3
                jsr   _drawTreeFront

                ldx   #6
                ldy   #6
                jsr   _drawTreeFront

                ldx   #3
                ldy   #6
                jsr   _drawTreeFront

                ldx   #0
                ldy   #6
                jsr   _drawTreeFront
:no_trees
; Set up the dynamic tile
                lda   #65
                sta   DTile

                pei   DTile
                pea   $0000
                _GTECopyTileToDynamic                ; Copy DTile into the first dynamic tile slot

; Initialize the frame counter

                stz   FrameCount

; Set the screen coordinates

                lda   #128
                sta   ScreenX
                lda   #128
                sta   ScreenY

                stz   Selected
                stz   Flips

; Very simple actions
:evt_loop
                pha                           ; space for result, with pattern
                _GTEReadControl
                pla
                and   #$00FF
                cmp   #'q'
                bne   :2
                brl   :exit
:2
;                cmp    KeyState
;                beq    :evt_loop
;                sta    KeyState
;                cmp    #0
;                beq    :evt_loop

;                cmp   #' '
;                bne   :evt_loop              ; only advance one frame at a time
;                brl   :next

:3
                cmp   #'1'
                bcc   :3a
                cmp   #'9'
                bcs   :3a
                sec
                sbc   #'1'
                asl
                sta   Selected
                brl   :next

:3a
                cmp   #'r'
                bne   :3b
                lda    Flips
                clc
                adc    #SPRITE_HFLIP
                and    #SPRITE_VFLIP+SPRITE_HFLIP
                sta    Flips
                
                pei   Selected                      ; update the sprite in this slot
                pei   Flips                         ; with these flags (h/v flip)
                pea   VBUFF_SPRITE_START            ; and use this stamp
                _GTEUpdateSprite

:3b
                cmp   #'x'
                bne   :3d
                ldx   Selected
                lda   PlayerX,x
                clc
                adc   PlayerU,x
                sta   PlayerX,x

                lda   PlayerY,x
                clc
                adc   PlayerV,x
                sta   PlayerY,x
                brl   :next
:3d
                cmp   #'z'
                bne   :3e
                ldx   Selected
                lda   PlayerX,x
                sec
                sbc   PlayerU,x
                sta   PlayerX,x

                lda   PlayerY,x
                sec
                sbc   PlayerV,x
                sta   PlayerY,x
                brl   :next
:3e
                cmp   #'s'
                bne   :4
                ldx   Selected
                inc   PlayerY,x
                brl   :next
:4
                cmp   #'w'
                bne   :5
                ldx   Selected
                dec   PlayerY,x
                brl   :next
:5
                cmp   #'d'
                bne   :6
                ldx   Selected
                inc   PlayerX,x
                brl   :next
:6
                cmp   #'a'
                bne   :7
                ldx   Selected
                dec   PlayerX,x
                brl   :next
:7
                cmp   #$15                    ; left = $08, right = $15, up = $0B, down = $0A
                bne   :8
                inc   ScreenX
                bra   :next

:8              cmp   #$08
                bne   :9
                dec   ScreenX
                brl   :next

:9              cmp   #$0B
                bne   :10
                inc   ScreenY
                brl   :next

:10             cmp   #$0A
                bne   :11
                dec   ScreenY

:11             cmp   #'y'
                bne   :next
                lda   DTile
                inc
                and   #$007F
                sta   DTile
                pha
                pea   $0000
                _GTECopyTileToDynamic

:next
;                inc   ScreenX

                pei   ScreenX
                pei   ScreenY
                _GTESetBG0Origin

;                brl   no_animate

                stz   Tmp0
                stz   Tmp1

                ldx   Tmp0
loopX
                lda   PlayerX,x
                clc
                adc   PlayerU,x
                sta   PlayerX,x
                bpl   is_posx
                cmp   #-15
                bcs   do_y
                lda   PlayerU,x
                eor   #$FFFF
                inc
                sta   PlayerU,x
                bra   do_y
is_posx         cmp   #128
                bcc   do_y
                lda   PlayerU,x
                eor   #$FFFF
                inc
                sta   PlayerU,x

do_y
                lda   PlayerY,x
                clc
                adc   PlayerV,x
                sta   PlayerY,x
                bpl   is_posy
                cmp   #-15
                bcs   do_z
                lda   PlayerV,x
                eor   #$FFFF
                inc
                sta   PlayerV,x
                bra   do_z
is_posy         cmp   #160
                bcc   do_z
                lda   PlayerV,x
                eor   #$FFFF
                inc
                sta   PlayerV,x
do_z
                inc   Tmp1
                ldx   Tmp0
                inx
                inx
                stx   Tmp0
                cpx   #MAX_SPRITES*2
                bcc   loopX

no_animate
                stz   Tmp0
                stz   Tmp1
                ldx   Tmp0
loopY
                pei   Tmp1
                lda   PlayerX,x
                pha
                lda   PlayerY,x
                pha
                _GTEMoveSprite

                inc   Tmp1
                ldx   Tmp0
                inx
                inx
                stx   Tmp0
                cpx   #MAX_SPRITES*2
                bcc   loopY

                _GTERender
                inc   FrameCount

; Debug stuff
                pha
                _GTEGetSeconds
                pla
                cmp   LastSecond
                beq   :no_fps
                sta   LastSecond
                
                lda   FrameCount
                ldx   #0
                ldy   #$FFFF
                jsr   DrawWord

                stz   FrameCount
:no_fps

;                tdc
;                ldx   #160*32
;                jsr   DrawWord

                brl   :evt_loop

; Shut down everything
:exit
                _GTEShutDown
                _QuitGS qtRec
qtRec           adrl       $0000
                da         $00

; Array of sprite positions and velocities
PlayerX  dw  8,14,29,34,45,67,81,83,92,101,39,22,7,74,111,9
PlayerY  dw  72,24,13,56,35,72,23,8,93,123,134,87,143,14,46,65
PlayerU  dw  1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4
PlayerV  dw  1,1,1,1,2,2,2,4,3,3,3,3,4,4,4,4

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
                clc                             ; Give GTE a page of direct page memory
                tdc
                adc   #$0100
                pha
                pea   #ENGINE_MODE_DYN_TILES    ; Enable Dynamic Tiles
                lda   MyUserId                  ; Pass the userId for memory allocation
                pha
                _GTEStartUp
                bcc    :ok3
                brk    $03

:ok3
                rts

_fillTileStore
                sta    Tmp2
                stz    Tmp0
:oloop
                stz    Tmp1
:iloop
                pei    Tmp1
                pei    Tmp0
                pei    Tmp2
                _GTESetTile

                lda    Tmp2
                eor    #TILE_PRIORITY_BIT
                sta    Tmp2

                lda    Tmp1
                inc
                sta    Tmp1
                cmp    #41
                bcc    :iloop

                lda    Tmp0
                inc
                sta    Tmp0
                cmp    #26
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
ToolPath        str   '1/Tool160'
FrameCount      ds    2
LastSecond      dw    0

                PUT        App.Msg.s
                PUT        font.s
