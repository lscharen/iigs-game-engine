; Test driver to exercise graphics routines.

                    REL
                    DSK        MAINSEG

                    use        Load.Macs.s
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

                    ldx        #256                      ; 32 x 22 playfield (704 tiles, $580 tiles)
                    ldy        #176
                    jsl        SetScreenMode

; Set up our level data
                    jsr        BG0SetUp

; Initialize the sprite's global position (this is tracked outside of the tile engine)
                    lda        #64
                    sta        PlayerX
                    sta        PlayerY
                    stz        MapScreenX
                    stz        MapScreenY

; Add a sprite to the engine and save its sprite
SPRITE_ID           equ        {SPRITE_16X16+1}
OKTOROK             equ        {SPRITE_16X16+79}

                    lda        PlayerX
                    xba
                    ora        PlayerY
                    tay                                ; (x, y) position
                    ldx        #0
                    lda        #SPRITE_ID              ; 16x16 sprite
                    jsl        AddSprite
                    sta        PlayerID

; Add 4 octoroks 
                    lda        #OKTOROK
                    ldx        #1
                    ldy        #{32*256}+48
                    jsl        AddSprite

                    lda        #OKTOROK
                    ldx        #2
                    ldy        #{32*256}+96
                    jsl        AddSprite

                    lda        #OKTOROK
                    ldx        #3
                    ldy        #{96*256}+56
                    jsl        AddSprite

                    lda        #OKTOROK
                    ldx        #4
                    ldy        #{96*256}+72
                    jsl        AddSprite

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
                    beq        :no_sword
:no_sword

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
                    inc        PlayerX
                    lda        PlayerX
                    cmp        #128-8
                    bcc        *+5
                    jsr        TransitionRight

                    lda        PlayerID
                    ldx        #SPRITE_16X16+5
                    jsl        UpdateSprite

                    bra        :do_render
:not_d

                    cmp        #'a'
                    bne        :not_a
                    dec        PlayerX
                    bpl        *+5
                    jsr        TransitionLeft

                    lda        PlayerID
                    ldx        #SPRITE_16X16+SPRITE_HFLIP+5
                    jsl        UpdateSprite
                    
                    bra        :do_render
:not_a

                    cmp        #'s'
                    bne        :not_s
                    inc        PlayerY
                    lda        PlayerID
                    ldx        #SPRITE_16X16+1
                    jsl        UpdateSprite
                    bra        :do_render
:not_s

                    cmp        #'w'
                    bne        :not_w
                    dec        PlayerY
                    lda        PlayerID
                    ldx        #SPRITE_16X16+9
                    jsl        UpdateSprite
                    bra        :do_render
:not_w

:do_render
                    lda        PlayerID
                    ldx        PlayerX
                    ldy        PlayerY
                    jsl        MoveSprite             ; Move the sprite to the current position

; Based on the frame count, move an oktorok
                    jsl        GetVBLTicks
                    pha
                    and        #$0003
                    asl
                    tax

                    pla
                    and        #$007C
                    lsr
                    tay

                    lda        OktorokX,x
                    clc
                    adc        OktorokDelta,y

                    phx

                    ldy        OktorokY,x
                    tax
                    pla
                    inc
                    inc
                    jsl        MoveSprite


; Let's see what it looks like!

                    lda        vsync
                    beq        :no_vsync
:vsyncloop          jsl        GetVerticalCounter     ; 8-bit value
                    cmp        ScreenY0
                    bcc        :vsyncloop
                    sec
                    sbc        ScreenY0
                    cmp        #4
                    bcs        :vsyncloop             ; Wait until we're within the top 8 scanlines
                    lda        #1
                    jsl        SetBorderColor
:no_vsync
                    jsl        RenderDirty
    
                    lda        vsync
                    beq        :no_vsync2
                    lda        #0
                    jsl        SetBorderColor
:no_vsync2
                    brl        EvtLoop

; Exit code
Exit
                    jsl        EngineShutDown

                    _QuitGS    qtRec

                    bcs        Fatal
Fatal               brk        $00

TransitionRight
                    lda        MapScreenX           ; Only two screens
                    cmp        #1
                    bcs        :done

                    lda        StartX               ; Scroll 128 bytes to the right
                    clc
                    adc        #128
                    sta        TransitionX

:loop               lda        StartX
                    cmp        TransitionX
                    bcs        :out
                    clc
                    adc        #4
                    jsl        SetBG0XPos

                    lda        PlayerX
                    sec
                    sbc        #4
                    bmi        :nosprite
                    sta        PlayerX

                    lda        PlayerID
                    ldx        PlayerX
                    ldy        PlayerY
                    jsl        MoveSprite
:nosprite

                    jsl        Render               ; Do full renders since the playfield is scrolling
                    bra        :loop
:out

                    lda        #0                   ; Move the player back to the left edge
                    sta        PlayerX
                    inc        MapScreenX           ; Move the index to the next screen
:done
                    rts


TransitionLeft
                    lda        MapScreenX
                    cmp        #0
                    beq        :done

                    lda        StartX               ; Scroll 128 bytes to the left
                    sec
                    sbc        #128
                    sta        TransitionX

:loop               lda        StartX
                    cmp        TransitionX
                    beq        :out
                    sec
                    sbc        #4
                    jsl        SetBG0XPos

                    lda        PlayerX
                    clc
                    adc        #4
                    cmp        #128-8+1
                    bcs        :nosprite
                    sta        PlayerX

                    lda        PlayerID
                    ldx        PlayerX
                    ldy        PlayerY
                    jsl        MoveSprite
:nosprite

                    jsl        Render
                    bra        :loop
:out
;                    lda        #128-8                   ; Move the player back to the right edge
;                    sta        PlayerX
                    dec        MapScreenX           ; Move the index to the next screen
:done
                    rts
; Color palette
;MyPalette           dw         $068F,$0EDA,$0000,$0000,$0BF1,$00A0,$0EEE,$0456,$0FA4,$0F59,$0E30,$01CE,$02E3,$0870,$0F93,$0FD7
MyPalette           dw         $0FDA,$08C1,$0C41,$0F93,$0777,$0FDA,$00A0,$0000,$0D20,$0FFF,$023E,$01CE,$02E3,$0870,$0F93,$0FD7

MapScreenX          ds         2
MapScreenY          ds         2

PlayerID            ds         2
PlayerX             ds         2
PlayerY             ds         2

OktorokX            dw         32,32,96,96
OktorokY            dw         48,96,56,72
OktorokDelta        dw         0,1,2,3,4,5,6,7,6,5,4,3,2,1,0,-1,-2,-3,-4,-5,-6,-7,-8,-7,-6,-5,-4,-3,-2,-1,0,0,0
TransitionX         ds         2
TransitionY         ds         2

oldOneSecondCounter  ds    2
frameCount           ds    2

qtRec               adrl       $0000
                    da         $00

vsync               dw         $8000

                    PUT        gen/App.TileMapBG0.s

ANGLEBNK            ENT