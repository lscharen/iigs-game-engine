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
                    jsr        SetLimits

                    jsr        InitOverlay             ; Initialize the status bar
                    stz        frameCount
                    ldal       OneSecondCounter
                    sta        oldOneSecondCounter
                    jsr        UdtOverlay

; Initialize the sprite's global position (this is tracked outside of the tile engine)
                    lda        #16
                    sta        PlayerGlobalX
                    lda        MaxGlobalY
                    sec
                    lda        #40                     ; 32 for tiles, 8 for sprite
                    sta        PlayerGlobalY

                    stz        PlayerXVel
                    stz        PlayerYVel

; Add a sprite to the engine and save it's sprite ID

                    jsr        UpdatePlayerLocal
                    lda        #64                      ; 8x8 sprite, tile ID = 64
                    ldx        PlayerX
                    ldy        PlayerY
                    jsl        AddSprite
                    bcc        :sprite_ok
                    brl        Exit                    ; If we could not allocate a sprite, exit

:sprite_ok
                    sta        PlayerID

; Draw the initial screen

                    lda        #DIRTY_BIT_BG0_REFRESH  ; Redraw all of the tiles on the next Render
                    tsb        DirtyBits
                    jsl        Render

; Set up a very specific test.  First, we draw a sprite into the sprite plane, and then
; leave it alone.  We are just testing the ability to merge sprite plane data into 
; the play field tiles.
EvtLoop
                    jsl        ReadControl

; Check the buttons first
                    pha

                    bit        #$0100
                    beq        :no_jump
                    lda        PlayerStanding
                    beq        :no_jump
                    lda        #$FFF8
                    sta        PlayerYVel
:no_jump
                    pla
                    and        #$007F                  ; Ignore the buttons for now

                    cmp        #'q'
                    bne        :not_q
                    brl        Exit
:not_q

                    cmp        #'d'
                    bne        :not_d
                    lda        StartX
                    cmp        MaxBG0X
                    bcs        :do_render
                    inc
                    jsl        SetBG0XPos
                    bra        :do_render
:not_d

                    cmp        #'a'
                    bne        :not_a
                    lda        StartX
                    beq        :do_render
                    dec
                    jsl        SetBG0XPos
                    bra        :do_render
:not_a

                    cmp        #'s'
                    bne        :not_s
                    lda        StartY
                    cmp        MaxBG0Y
                    bcs        :do_render
                    inc
                    jsl        SetBG0YPos
                    bra        :do_render
:not_s

                    cmp        #'w'
                    bne        :not_w
                    lda        StartY
                    beq        :do_render
                    dec
                    jsl        SetBG0YPos
                    bra        :do_render
:not_w

; Do j,l to move the character left/right
                    cmp        #'j'
                    bne        :not_j
                    lda        PlayerXVel
                    bpl        :pos_xvel
                    cmp        #$FFFA
                    bcc        :not_j
:pos_xvel           dec
                    dec
                    sta        PlayerXVel
                    bra        :do_render
:not_j

                    cmp        #'l'
                    bne        :not_l
                    lda        PlayerXVel
                    bmi        :neg_xvel
                    cmp        #6
                    bcs        :not_l
:neg_xvel           inc
                    inc
                    sta        PlayerXVel
                    bra        :do_render
:not_l

; Update the camera position

:do_render
                    jsr        UpdatePlayerPos        ; Moves in global cordinates
                    jsr        UpdateCameraPos        ; Moves the screen
                    jsr        UpdatePlayerLocal      ; Gets local sprite coordinates

                    lda        PlayerID
                    ldx        PlayerX
                    ldy        PlayerY
                    jsl        UpdateSprite           ; Move the sprite to this local position

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
                    brl        EvtLoop

; Exit code
Exit
                    jsl        EngineShutDown

                    _QuitGS    qtRec

                    bcs        Fatal
Fatal               brk        $00

MyPalette           dw         $068F,$0EDA,$0000,$068F,$0BF1,$00A0,$0EEE,$0777,$01CE,$0FA4,$0F59,$0D40,$02E3,$09B9,$0F93,$0FD7

PlayerGlobalX       ds         2
PlayerGlobalY       ds         2

PlayerID            ds         2
PlayerX             ds         2
PlayerXOld          ds         2
PlayerY             ds         2
PlayerYOld          ds         2
PlayerLastPos       ds         2
PlayerXVel          ds         2
PlayerYVel          ds         2
KeyState            ds         2
PlayerStanding      ds         2
MaxGlobalX          ds         2
MaxGlobalY          ds         2
MaxBG0X             ds         2
MaxBG0Y             ds         2

oldOneSecondCounter  ds    2
frameCount           ds    2

PLAYER_X_MIN        equ   0
PLAYER_X_MAX        equ   160-4
PLAYER_Y_MIN        equ   0
PLAYER_Y_MAX        equ   200-8

EMPTY_TILE          equ   $0029              ; the tile that makes up the background

AdjustLocalX
                    clc
                    adc        StartXMod164
                    cmp        #164
                    bcc        *+5
                    sbc        #164
                    rts
AdjustLocalY
                    clc
                    adc        StartYMod208
                    cmp        #208
                    bcc        *+5
                    sbc        #208
                    rts

SetLimits
                    lda        TileMapWidth
                    asl
                    asl
                    sta        MaxGlobalX
                    sec
                    sbc        ScreenWidth
                    sta        MaxBG0X

                    lda        TileMapHeight
                    asl
                    asl
                    asl
                    sta        MaxGlobalY
                    sec
                    sbc        ScreenHeight
                    sta        MaxBG0Y
                    rts

; Set the scroll position based on the global cooridinate of the player
; Try to center the player on the screen
UpdateCameraPos
                    lda        ScreenWidth
                    lsr
                    sta        tmp0
                    lda        PlayerGlobalX
                    sec
                    sbc        tmp0
                    bpl        :x_pos
                    lda        #0
:x_pos              cmp        MaxBG0X
                    bcc        :x_ok
                    lda        MaxBG0X
:x_ok               jsl        SetBG0XPos

                    lda        ScreenHeight
                    lsr
                    sta        tmp0
                    lda        PlayerGlobalY
                    sec
                    sbc        tmp0
                    bpl        :y_pos
                    lda        #0
:y_pos              cmp        MaxBG0Y
                    bcc        :y_ok
                    lda        MaxBG0Y
:y_ok               jsl        SetBG0YPos
                    rts

; Convert the global coordinates to adjusted local coordinated (compensating for wrap-around)
UpdatePlayerLocal
            lda  PlayerGlobalX
            sec
            sbc  StartX
;            jsr  AdjustLocalX
            sta  PlayerX

            lda  PlayerGlobalY
            sec
            sbc  StartY
;            jsr  AdjustLocalY
            sta  PlayerY
            rts

; Simple updates with gravity and collisions.  It's important that eveything in this
; subroutine be done against 
UpdatePlayerPos
            stz  PlayerStanding
            lda  PlayerYVel
            bmi  :no_ground_check

; Check if the player is standing on the ground at their current local position

            ldx  PlayerX
            lda  PlayerY
            clc
            adc  #8
            tay
            jsr  GetTileAt
            cmp  #EMPTY_TILE
            beq  :no_ground_check

            lda  PlayerGlobalY
            and  #$fff8
            sta  PlayerGlobalY
            stz  PlayerYVel
            lda  #1
            sta  PlayerStanding

:no_ground_check
            lda  PlayerGlobalY
            clc
            adc  PlayerYVel
            bpl  *+5
            lda  #0

            cmp  MaxGlobalY
            bcc  *+5
            lda  MaxGlobalY
            sta  PlayerGlobalY

            lda  PlayerGlobalX
            clc
            adc  PlayerXVel
            bpl  *+5
            lda  #0

            cmp  MaxGlobalX
            bcc  *+5
            lda  MaxGlobalX
            sta  PlayerGlobalX

            lda  PlayerXVel
            beq  :no_dxv
            bpl  :pos_dxv
            inc
            bra  :no_dxv
:pos_dxv
            dec
:no_dxv
            sta  PlayerXVel

            lda  PlayerStanding
            bne  :too_fast

            lda  PlayerYVel
            inc
            bmi  :is_neg
            cmp  #4
            bcs  :too_fast
:is_neg
            sta  PlayerYVel
:too_fast
            rts

; X = coordinate
; Y = coordinate
GetTileAt
                txa
                bmi  :out
                clc
                adc  StartXMod164
                cmp  #164
                bcc  *+5
                sbc  #164
                
                lsr
                lsr
                tax

                tya
                bmi  :out
                clc
                adc  StartYMod208
                cmp  #208
                bcc  *+5
                sbc  #208

                lsr
                lsr
                lsr
                tay

                jsl   GetTileStoreOffset
                tax
                ldal  TileStore+TS_TILE_ID,x
                rts

:out
                lda  #EMPTY_TILE
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