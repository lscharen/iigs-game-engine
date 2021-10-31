; Test driver to exercise graphics routines.

                    REL
                    DSK        MAINSEG

                    use        Locator.Macs.s
                    use        Misc.Macs.s
                    use        EDS.GSOS.MACS.s
                    use        Tool222.Macs.s
                    use        Util.Macs.s
                    use        CORE.MACS.s
                    use        ../../src/GTE.s
                    use        ../../src/Defs.s

                    mx         %00

; Feature flags
NO_INTERRUPTS       equ        0                       ; turn off for crossrunner debugging
NO_MUSIC            equ        1                       ; turn music + tool loading off

; Keycodes
LEFT_ARROW          equ        $08
RIGHT_ARROW         equ        $15
UP_ARROW            equ        $0B
DOWN_ARROW          equ        $0A

; Typical init
                    phk
                    plb

                    jsl        EngineStartUp

                    lda        #^MyPalette               ; Fill Palette #0 with our colors
                    ldx        #MyPalette
                    ldy        #0
                    jsl        SetPalette

                    ldx        #0                        ; Mode 0 is full-screen
                    jsl        SetScreenMode

; Set up our level data
                    jsr        BG0SetUp
;                    jsr        TileAnimInit

; Allocate room to load data
;                    jsr        MovePlayerToOrigin      ; Put the player at the beginning of the map

                    jsr        InitOverlay             ; Initialize the status bar
                    stz        frameCount
                    ldal       OneSecondCounter
                    sta        oldOneSecondCounter

; Add a player sprite
                    lda        #0
                    sta        PlayerX
                    sta        PlayerXOld
                    lda        #14
                    sta        PlayerY
                    sta        PlayerYOld
                    lda        #1
                    sta        PlayerXVel
                    sta        PlayerYVel

                    lda        #DIRTY_BIT_BG0_REFRESH  ; Redraw all of the tiles on the next Render
                    tsb        DirtyBits
                    jsl        Render

; Set up a very specific test.  First, we draw a sprite into the sprite plane, and then
; leave it alone.  We are just testing the ability to merge sprite plane data into 
; the play field tiles.
EvtLoop
                    jsl        ReadControl
                    and        #$007F                  ; Ignore the buttons for now

                    cmp        #'q'
                    bne        :not_q
                    brl        Exit

:not_q
                    cmp        #'x'
                    bne        :not_x
                    lda        #$0001
                    jsr        UpdatePlayerPos
                    bra        :4
:not_x

                    cmp        #'y'
                    bne        :not_y
                    lda        #$0002
                    jsr        UpdatePlayerPos
                    bra        :4
:not_y

                    cmp        #'r'
                    beq        :3

                    cmp        #'n'
                    beq        :2
                    stz        KeyState
                    bra        :4
:2
                    lda        KeyState                ; Wait for key up / key down
                    bne        :4
                    lda        #1
                    sta        KeyState
:3
                    lda        #$0003
                    jsr        UpdatePlayerPos

:4
; Draw the sprite in the sprite plane

                    ldx        PlayerX
                    ldy        PlayerY
                    jsl        GetSpriteVBuffAddr
                    tax                                ; put in X
                    ldy        #3*128                  ; draw the 3rd tile as a sprite
                    stx        PlayerLastPos           ; save for erasure
                    jsl        DrawTileSprite

; Now the sprite has been drawn. Enqueue the dirty tiles.  We blindly add the potential
; dirty tiles and rely on PushDirtyTile to elimate duplicates quickly

                    ldx        PlayerX
                    ldy        PlayerY
                    jsr        MakeDirtySprite8x8

; The dirty tile queue has been written to; apply it to the code field

                    jsl        ApplyTiles

; Let's see what it looks like!

                    jsl        Render

; Update the performance counters

                    inc        frameCount
                    ldal       OneSecondCounter
                    cmp        oldOneSecondCounter
                    beq        :noudt
                    sta        oldOneSecondCounter
                    jsr        UdtOverlay
                    stz        frameCount
:noudt

; Erase the sprites that moved

                    ldx        PlayerLastPos           ; Delete the sprite because it moved
                    jsl        EraseTileSprite

                    ldx        PlayerXOld              ; Remove the sprite flag from the tiles
                    ldy        PlayerYOld              ; at the old position.
                    jsr        ClearSpriteFlag8x8

; Add the tiles that the sprite was previously at as well.

                    ldx        PlayerXOld
                    ldy        PlayerYOld
                    jsr        MakeDirtyTile8x8



;                    tax
;                    ldy        PlayerY
;                    lda        PlayerID
;                    jsl        UpdateSprite

;                    jsl        DoTimers
;                    jsl        Render

                    brl        EvtLoop

; Exit code
Exit
                    jsl        EngineShutDown

                    _QuitGS    qtRec

                    bcs        Fatal
Fatal               brk        $00

MyPalette           dw         $0000,$0777,$0F31,$0E51,$00A0,$02E3,$0BF1,$0FA4,$0FD7,$0EE6,$0F59,$068F,$01CE,$09B9,$0EDA,$0EEE

PlayerID            ds         2
PlayerX             ds         2
PlayerXOld          ds         2
PlayerY             ds         2
PlayerYOld          ds         2
PlayerLastPos       ds         2
PlayerXVel          ds         2
PlayerYVel          ds         2
KeyState            ds         2

oldOneSecondCounter  ds    2
frameCount           ds    2

PLAYER_X_MIN        equ   65536-3
PLAYER_X_MAX        equ   159
PLAYER_Y_MIN        equ   65536-7
PLAYER_Y_MAX        equ   199

; Need to use signed comparisons here
;  @see http://6502.org/tutorials/compare_beyond.html
UpdatePlayerPosX
                    lda        PlayerX                 ; Move the player sprite a bit
                    sta        PlayerXOld
                    clc
                    adc        PlayerXVel
                    sta        PlayerX

; Compate PlayerX with the X_MIN value. BMI if PlayerX < X_MIN, BPL is PlayerX >= X_MIN

                    cmp        #PLAYER_X_MIN
                    beq        :x_flip

                    cmp        #PLAYER_X_MAX
                    bne        :x_ok
:x_flip
                    lda        PlayerXVel
                    eor        #$FFFF
                    inc
                    sta        PlayerXVel
:x_ok
                    rts
    
UpdatePlayerPosY
                    lda        PlayerY
                    sta        PlayerYOld
                    clc
                    adc        PlayerYVel
                    sta        PlayerY

                    cmp        #PLAYER_Y_MIN
                    beq        :y_flip

                    cmp        #PLAYER_Y_MAX
                    bne        :y_ok
:y_flip             
                    lda        PlayerYVel
                    eor        #$FFFF
                    inc
                    sta        PlayerYVel
:y_ok
                    rts

UpdatePlayerPos
                    pha
                    bit        #$0001
                    beq        :skip_x
                    jsr        UpdatePlayerPosX

:skip_x             pla
                    bit        #$0002
                    beq        :skip_y
                    jsr        UpdatePlayerPosY

:skip_y
                    rts

; Takes a signed playfield position (including off-screen coordinates) and a size and marks
; the tiles that are impacted by this shape.  The main job of this subroutine is to ensure
; that all of the tile coordinate s are within the valid bounds [0 - 40], [0 - 25].
;
; X = signed integer
; Y = signed integer
; A = sprite size (0 - 7)
SpriteWidths  dw    4,4,8,8,12,8,12,16
SpriteHeights dw    8,16,8,16,16,24,24,24
 ;   000 - 8x8  (1x1 tile)
;   001 - 8x16 (1x2 tiles)
;   010 - 16x8 (2x1 tiles)
;   011 - 16x16 (2x2 tiles)
;   100 - 24x16 (3x2 tiles)
;   101 - 16x24 (2x3 tiles)
;   110 - 24x24 (3x3 tiles)
;   111 - 32x24 (4x3 tiles)
MarkTilesOut
                ply
                plx
                sec
                rts

MarkTiles
                phx
                phy
                
                and  #$0007
                asl
                tax

; First, do a bound check against the whole sprite.  It it's totally off-screen, do nothing because 
; there are no physical tiles to mark.

                lda  1,s          ; load the Y coordinate
                bpl  :y_pos
                eor  #$FFFF       ; for a negative coordinate, see if it's equal to or larger than the sprite height
                inc
                cmp  SpriteHeights,x
                bcs  MarkTilesOut
                bra  :y_ok
:y_pos          cmp  ScreenHeight
                bcc  :y_ok
                bra  MarkTilesOut
:y_ok
                rts




; X = coordinate
; Y = coordinate
MakeDirtySprite8x8

                    phx
                    phy

                    txa  ; need to do a signed shift...
                    lsr
                    lsr
                    tax
                    tya
                    lsr
                    lsr
                    lsr
                    tay
                    jsr   MakeDirtySpriteTile    ; top-left

                    lda   3,s
                    clc
                    adc   #3
                    lsr
                    lsr
                    tax
                    jsr   MakeDirtySpriteTile    ; top-right

                    lda   1,s
                    clc
                    adc   #7
                    lsr
                    lsr
                    lsr
                    tay
                    jsr   MakeDirtySpriteTile    ; bottom-right

                    lda   3,s
                    lsr
                    lsr
                    tax
                    jsr   MakeDirtySpriteTile    ; bottom-left

                    ply
                    plx
                    rts

; X = coordinate
; Y = coordinate
MakeDirtyTile8x8
                    phx
                    phy

                    txa
                    lsr
                    lsr
                    tax
                    tya
                    lsr
                    lsr
                    lsr
                    tay
                    jsr   MakeDirtyTile    ; top-left

                    lda   3,s
                    clc
                    adc   #3
                    lsr
                    lsr
                    tax
                    jsr   MakeDirtyTile    ; top-right

                    lda   1,s
                    clc
                    adc   #7
                    lsr
                    lsr
                    lsr
                    tay
                    jsr   MakeDirtyTile    ; bottom-right

                    lda   3,s
                    lsr
                    lsr
                    tax
                    jsr   MakeDirtyTile    ; bottom-left

                    ply
                    plx
                    rts

ClearSpriteFlag8x8
                    phx
                    phy

                    txa
                    lsr
                    lsr
                    tax
                    tya
                    lsr
                    lsr
                    lsr
                    tay
                    jsr   ClearSpriteFlag    ; top-left

                    lda   3,s
                    clc
                    adc   #3
                    lsr
                    lsr
                    tax
                    jsr   ClearSpriteFlag    ; top-right

                    lda   1,s
                    clc
                    adc   #7
                    lsr
                    lsr
                    lsr
                    tay
                    jsr   ClearSpriteFlag    ; bottom-right

                    lda   3,s
                    lsr
                    lsr
                    tax
                    jsr   ClearSpriteFlag    ; bottom-left

                    ply
                    plx
                    rts
; x = column
; y = row
ClearSpriteFlag
                    phx
                    phy

                    jsl        GetTileStoreOffset
                    tax
                    lda        #0
                    stal       TileStore+TS_SPRITE_FLAG,x

                    ply
                    plx
                    rts

MakeDirtyTile
                    phx
                    phy

                    jsl        GetTileStoreOffset
                    jsl        PushDirtyTile

                    ply
                    plx
                    rts

MakeDirtySpriteTile
                    phx
                    phy

                    txa
                    asl
                    asl
                    tax
                    tya
                    asl
                    asl
                    asl
                    tay                    
                    jsl        GetSpriteVBuffAddr

                    pha

                    lda        3,s
                    tay
                    lda        5,s
                    tax

                    jsl        GetTileStoreOffset
                    tax
                    lda        #TILE_SPRITE_BIT
                    stal       TileStore+TS_SPRITE_FLAG,x
                    pla
                    stal       TileStore+TS_SPRITE_ADDR,x
                    
                    txa
                    jsl        PushDirtyTile

                    ply
                    plx
                    rts

; Position the screen with the botom-left corner of the tilemap visible
MovePlayerToOrigin
                    lda        #0                      ; Set the player's position
                    jsl        SetBG0XPos

                    lda        TileMapHeight
                    asl
                    asl
                    asl
                    sec
                    sbc        ScreenHeight
                    jsl        SetBG0YPos
                    rts

qtRec               adrl       $0000
                    da         $00

                    PUT        ../shell/Overlay.s
                    PUT        gen/App.TileMapBG0.s
                    PUT        gen/App.TileSetAnim.s

ANGLEBNK            ENT