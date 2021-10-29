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

; Add a player sprite
                    lda        #80
                    sta        PlayerX
                    sta        PlayerXOld
                    lda        #100
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
                    jsr        UpdatePlayerPos

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

; Add the tiles that the sprite was previously at as well.

                    ldx        PlayerXOld
                    ldy        PlayerYOld
                    jsr        MakeDirtyTile8x8

; The dirty tile queue has been written to; apply it to the code field

                    jsl        ApplyTiles

; Let's see what it looks like!

                    jsl        Render

                    ldx        PlayerLastPos           ; Delete the sprite because it moved
                    jsl        EraseTileSprite

;                    tax
;                    ldy        PlayerY
;                    lda        PlayerID
;                    jsl        UpdateSprite

;                    jsl        DoTimers
;                    jsl        Render

                    jsl        ReadControl
                    and        #$007F                  ; Ignore the buttons for now

                    cmp        #'q'
                    bne        :7
                    brl        Exit

:7                  cmp        #LEFT_ARROW
                    bne        :8
                    brl        EvtLoop

:8                  cmp        #RIGHT_ARROW
                    bne        :9
                    brl        EvtLoop

:9
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

UpdatePlayerPos
                    lda        PlayerX                 ; Move the player sprite a bit
                    sta        PlayerXOld
                    clc
                    adc        PlayerXVel
                    sta        PlayerX

                    cmp        #160-4
                    bcc        :x_ok_1
                    lda        #$FFFF
                    sta        PlayerXVel
:x_ok_1             cmp        #0
                    bne        :x_ok_2
                    lda        #$0001
                    sta        PlayerXVel
:x_ok_2

                    lda        PlayerY                 
                    sta        PlayerYOld
                    clc
                    adc        PlayerYVel
                    sta        PlayerY

                    cmp        #200-8
                    bcc        :y_ok_1
                    lda        #$FFFF
                    sta        PlayerYVel
:y_ok_1             cmp        #0
                    bne        :y_ok_2
                    lda        #$0001
                    sta        PlayerYVel
:y_ok_2
                    rts
; X = coordinate
; Y = coordinate
MakeDirtySprite8x8
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

; x = column
; y = row
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

                    PUT        gen/App.TileMapBG0.s
                    PUT        gen/App.TileSetAnim.s

Overlay             ENT
                    rtl

ANGLEBNK            ENT