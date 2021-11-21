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

                    ldx        #5                        ; Mode 0 is full-screen, mode 5 is 256x160
                    ldx        #320
                    ldy        #200
                    jsl        SetScreenMode

; Set up our level data
                    jsr        BG0SetUp
                    jsr        TileAnimInit
                    jsr        SetLimits

                    jsr        InitOverlay             ; Initialize the status bar
                    stz        frameCount
                    ldal       OneSecondCounter
                    sta        oldOneSecondCounter
                    jsr        UdtOverlay

; Allocate a buffer for loading files
                    jsl        AllocBank               ; Alloc 64KB for Load/Unpack
                    sta        BankLoad                ; Store "Bank Pointer"

; Load in the 256 color background into BG1 buffer
                    brl        :nobackground
DoLoadBG1
                    lda        BankLoad
                    ldx        #BG1DataFile
                    jsr        LoadFile

                    ldx        BankLoad
                    lda        #0
                    ldy        BG1DataBank
                    jsl        CopyPicToBG1

; Copy the palettes into place

                    stz        tmp0
:ploop
                    lda        tmp0
                    tay
                    asl
                    asl
                    asl
                    asl
                    asl
                    clc
                    adc        #$7E00
                    tax

                    lda        BankLoad
                    jsl        SetPalette

                    inc        tmp0
                    lda        tmp0
                    cmp        #16
                    bcc        :ploop

; Bind the SCBs

                    lda        BankLoad
                    ora        #$8000                     ; set high bit to bind to BG1 Y-position
                    ldx        #$7D00
                    jsl        SetSCBArray
:nobackground

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
SPRITE_ID           equ        {SPRITE_16X16+145}
MUSHROOM_ID         equ        {SPRITE_16X16+255}

                    lda        #MUSHROOM_ID              ; 16x16 sprite, tile ID = 145
                    ldx        #80
                    ldy        #152
                    jsl        AddSprite

                    jsr        UpdatePlayerLocal
                    lda        #SPRITE_ID              ; 16x16 sprite, tile ID = 145
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


; Enable/disable v-sync
                    lda        1,s
                    bit        #$0400
                    beq        :no_key_down
                    and        #$007F
                    cmp        #'v'
                    bne        :not_v
                    lda        #$0001
                    eor        vsync
                    sta        vsync
:not_v
:no_key_down


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
                    jsl        MoveSprite             ; Move the sprite to this local position

; Update the timers
                    jsl        DoTimers

; Let's see what it looks like!

                    lda        vsync
                    beq        :no_vsync
:vsyncloop          jsl        GetVerticalCounter     ; 8-bit value
                    cmp        ScreenY0
                    bcc        :vsyncloop
                    sec
                    sbc        ScreenY0
                    cmp        #8
                    bcs        :vsyncloop
                    lda        #1
                    jsl        SetBorderColor
:no_vsync
                    jsl        Render
    
                    lda        vsync
                    beq        :no_vsync2
                    lda        #0
                    jsl        SetBorderColor
:no_vsync2

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

BG1DataFile         strl       '1/sunset.c1'

; Color palette
MyPalette           dw         $068F,$0EDA,$0000,$0000,$0BF1,$00A0,$0EEE,$0456,$0FA4,$0F59,$0E30,$01CE,$02E3,$0870,$0F93,$0FD7
; B&W Palette
;MyPalette           dw         $0000,$0EDA,$0000,$0E51,$0BF1,$00A0,$0EEE,$0456,$0FA4,$0F59,$0E30,$01CE,$02E3,$0870,$0F93,$0FFF
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

EMPTY_TILE          equ   33              ; the tile that makes up the background

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

                    lda        StartY
                    lsr
                    jsl        SetBG1YPos
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
            adc  #16
            tay
            jsr  GetTileAt
            and  #$1FF
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

            ldx  LastHFlip
            lda  PlayerXVel
            beq  :no_dxv
            bpl  :pos_dxv
            ldx  #SPRITE_HFLIP
            inc
            bra  :no_dxv
:pos_dxv
            ldx  #0
            dec
:no_dxv
            sta  PlayerXVel
            stx  LastHFlip

            ldx  #0
            lda  PlayerStanding
            bne  :too_fast

            lda  PlayerYVel
            inc
            bmi  :is_neg
            cmp  #4
            bcs  :too_fast
:is_neg
            ldx  #SPRITE_VFLIP
            sta  PlayerYVel
:too_fast

            txa
            ora  LastHFlip
            ora  #SPRITE_ID
            sta  SpriteFrame

; If the player is standing and XVel != 0, pick a frame
            lda  PlayerStanding
            beq  :frame
            lda  PlayerXVel
            beq  :frame

            jsl  GetVBLTicks
            and  #$0003
            inc
            and  #$0003
            asl
            adc  SpriteFrame
            sta  SpriteFrame
:frame
            ldx  SpriteFrame

            lda  PlayerID
            jsl  UpdateSprite                          ; Change the tile ID and / or flags

            rts

LastHFlip       dw   0
SpriteFrame     ds   2

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

openRec             dw         2                       ; pCount
                    ds         2                       ; refNum
                    adrl       BG1DataFile             ; pathname

eofRec              dw         2                       ; pCount
                    ds         2                       ; refNum
                    ds         4                       ; eof

readRec             dw         4                       ; pCount
                    ds         2                       ; refNum
                    ds         4                       ; dataBuffer
                    ds         4                       ; requestCount
                    ds         4                       ; transferCount

closeRec            dw         1                       ; pCount
                    ds         2                       ; refNum

qtRec               adrl       $0000
                    da         $00

vsync               dw         $0000


LoadFile
                    stx        openRec+4               ; X=File, A=Bank (high word) assumed zero for low
                    stz        readRec+4
                    sta        readRec+6

:openFile           _OpenGS    openRec
                    bcs        :openReadErr
                    lda        openRec+2
                    sta        eofRec+2
                    sta        readRec+2

                    _GetEOFGS  eofRec
                    lda        eofRec+4
                    sta        readRec+8
                    lda        eofRec+6
                    sta        readRec+10

                    _ReadGS    readRec
                    bcs        :openReadErr

:closeFile          _CloseGS   closeRec
                    clc
                    lda        eofRec+4                ; File Size
                    rts

:openReadErr        jsr        :closeFile
                    nop
                    nop

                    PushWord   #0
                    PushLong   #msgLine1
                    PushLong   #msgLine2
                    PushLong   #msgLine3
                    PushLong   #msgLine4
                    _TLTextMountVolume
                    pla
                    cmp        #1
                    bne        :loadFileErr
                    brl        :openFile
:loadFileErr        sec
                    rts

msgLine1            str        'Unable to load File'
msgLine2            str        'Press a key :'
msgLine3            str        ' -> Return to Try Again'
msgLine4            str        ' -> Esc to Quit'

                    PUT        ../shell/Overlay.s
                    PUT        gen/App.TileMapBG0.s
                    PUT        gen/App.TileSetAnim.s

ANGLEBNK            ENT