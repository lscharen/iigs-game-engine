; Test driver to exercise graphics routines.

                REL
                DSK        MAINSEG

                use   Locator.Macs
                use   Load.Macs
                use   Mem.Macs
                use   Misc.Macs
                use   Tool222.Macs.s
                use   Util.Macs
                use   EDS.GSOS.Macs
                use   GTE.Macs

;                use   ../../src/Defs.s

                mx         %00

TSet            EXT                           ; tileset buffer

; Keycodes
LEFT_ARROW      equ        $08
RIGHT_ARROW     equ        $15
UP_ARROW        equ        $0B
DOWN_ARROW      equ        $0A

; Direct page space
appTmp0         equ        0
BankLoad        equ        2
StartX          equ        4
StartY          equ        6
TileMapWidth    equ        8
TileMapHeight   equ        10
ScreenWidth     equ        12
ScreenHeight    equ        14

                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize local variables

                stz   appTmp0
                stz   BankLoad
                stz   StartX
                stz   StartY

; Initialize the graphics screen to a 256x160 playfield

                pea   #320
                pea   #200
                _GTESetScreenMode

; Load a tileset

                pea   #^TSet
                pea   #TSet
                _GTELoadTileSet

                pea   $0000
                pea   #^MyPalette
                pea   #MyPalette
                _GTESetPalette

; Set up our level data
                jsr        BG0SetUp
;                jsr        TileAnimInit
                jsr        SetLimits

;                jsr        InitOverlay             ; Initialize the status bar
                stz        frameCount
                pha
                _GTEGetSeconds
                pla
                sta        oldOneSecondCounter
;                jsr        UdtOverlay

; Allocate a buffer for loading files
                jsl        AllocBank               ; Alloc 64KB for Load/Unpack
                sta        BankLoad                ; Store "Bank Pointer"

; Load in the 256 color background into BG1 buffer
                brl        :nobackground
DoLoadBG1
                lda        BankLoad
                ldx        #BG1DataFile
                jsr        LoadFile

                lda        BankLoad
                pha
                pea        $0000
                _GTECopyPicToBG1

; Copy the palettes into place

                stz        appTmp0
:ploop
                lda        appTmp0
                pha                        ; Palette number
                ldy        BankLoad
                phy                        ; High word pointer to palette

                asl
                asl
                asl
                asl
                asl
                clc
                adc        #$7E00
                pha                        ; Low word pointer to palette
                _GTESetPalette

                inc        appTmp0
                lda        appTmp0
                cmp        #16
                bcc        :ploop

; Bind the SCBs

                lda        BankLoad
                ora        #$8000                     ; set high bit to bind to BG1 Y-position
                pha
                pea        $7D00
                _GTEBindSCBArray
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

; Create the sprites
HERO_ID         equ        {SPRITE_16X16+145}
HERO_VBUFF      equ        VBUFF_SPRITE_START+0*VBUFF_SPRITE_STEP
HERO_SLOT       equ        1
MUSHROOM_ID     equ        {SPRITE_16X16+255}
MUSHROOM_VBUFF  equ        VBUFF_SPRITE_START+1*VBUFF_SPRITE_STEP

                pea   HERO_ID                     ; sprint id
                pea   HERO_VBUFF                  ; vbuff address
                _GTECreateSpriteStamp

                pea   MUSHROOM_ID                 ; sprint id
                pea   MUSHROOM_VBUFF              ; vbuff address
                _GTECreateSpriteStamp
                
                pea   MUSHROOM_ID                 ; Put the mushroom in Slot 0
                pea   #80                         ; at x=80, y=152
                pea   #152
                pea   $0000
                _GTEAddSprite

                pea   $0000
                pea   $0000                       ; with these flags (h/v flip)
                pea   MUSHROOM_VBUFF             ; and use this stamp
                _GTEUpdateSprite

                jsr        UpdatePlayerLocal

                pea   HERO_ID
                lda   PlayerX
                pha
                lda   PlayerY
                pha
                pea   HERO_SLOT                    ; Put the player in slot 1
                _GTEAddSprite

                pea   HERO_SLOT
                pea   $0000
                pea   HERO_VBUFF                   ; and use this stamp
                _GTEUpdateSprite

; Set up a very specific test.  First, we draw a sprite into the sprite plane, and then
; leave it alone.  We are just testing the ability to merge sprite plane data into 
; the play field tiles.
EvtLoop
                pha
                _GTEReadControl

; Check the buttons first
                lda   1,s

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
                cmp        #'f'
                bne        :not_f
                lda        SpriteToggle
                eor        #SPRITE_HIDE
                sta        SpriteToggle
                bne        :not_f
                stz        SpriteCount

:not_f
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
                bcc        *+5
                brl        :do_render
                inc        StartX
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                brl        :do_render
:not_d

                cmp        #'a'
                bne        :not_a
                lda        StartX
                bne        *+5
                brl        :do_render
                dec        StartX
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                brl        :do_render
:not_a

                cmp        #'s'
                bne        :not_s
                lda        StartY
                cmp        MaxBG0Y
                bcs        :do_render
                inc        StartY
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                bra        :do_render
:not_s

                cmp        #'w'
                bne        :not_w
                lda        StartY
                beq        :do_render
                dec        StartY
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                bra        :do_render
:not_w

; Do j,l to move the character left/right
                cmp        #'j'
                bne        :not_j
                lda        PlayerXVel
                bpl        :pos_xvel
                cmp        #$FFFA
                bcc        :not_j
:pos_xvel       dec
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
:neg_xvel       inc
                inc
                sta        PlayerXVel
                bra        :do_render
:not_l

; Update the camera position
:do_render
                jsr        UpdatePlayerPos        ; Moves in global cordinates
                jsr        UpdateCameraPos        ; Moves the screen
                jsr        UpdatePlayerLocal      ; Gets local sprite coordinates

                pea        HERO_SLOT
                lda        PlayerX
                pha
                lda        PlayerY
                pha
                _GTEMoveSprite                    ; Move the sprite to this local position

; Update the timers
;                jsl        DoTimers

; Let's see what it looks like!

;                    lda        vsync
;                    beq        :no_vsync
;:vsyncloop          jsl        GetVerticalCounter     ; 8-bit value
;                    cmp        ScreenY0
;                    bcc        :vsyncloop
;                    sec
;                    sbc        ScreenY0
;                    cmp        #8
;                    bcs        :vsyncloop
;                    lda        #1
;                    jsl        SetBorderColor
;:no_vsync
                    _GTERender
    
;                    lda        vsync
;                    beq        :no_vsync2
;                    lda        #0
;                    jsl        SetBorderColor
;:no_vsync2

; Update the performance counters

                    inc        frameCount
                    pha
                    _GTEGetSeconds
                    pla
                    cmp        oldOneSecondCounter
                    beq        :noudt
                    sta        oldOneSecondCounter
;                    jsr        UdtOverlay
                    stz        frameCount
:noudt
                    brl        EvtLoop

; Exit code
Exit
                    _GTEShutDown
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
MyUserId             ds    2

PLAYER_X_MIN        equ   0
PLAYER_X_MAX        equ   160-4
PLAYER_Y_MIN        equ   0
PLAYER_Y_MAX        equ   200-8

EMPTY_TILE          equ   33              ; the tile that makes up the background

SetLimits
                    pha                       ; Allocate space for width (in tiles), height (in tiles), pointer
                    pha
                    pha
                    pha
                    _GTEGetBG0TileMapInfo
                    pla
                    sta        TileMapWidth
                    pla
                    sta        TileMapHeight
                    pla
                    pla                       ; discard the pointer

                    pha                       ; Allocate space for x, y, width, height
                    pha
                    pha
                    pha
                    _GTEGetScreenInfo
                    pla
                    pla                       ; Discard screen corner
                    pla
                    sta        ScreenWidth
                    pla
                    sta        ScreenHeight



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

; Set the scroll position based on the global coordinates of the player
; Try to center the player on the screen
UpdateCameraPos
                    lda        ScreenWidth
                    lsr
                    sta        appTmp0
                    lda        PlayerGlobalX
                    sec
                    sbc        appTmp0
                    bpl        :x_pos
                    lda        #0
:x_pos              cmp        MaxBG0X
                    bcc        :x_ok
                    lda        MaxBG0X
:x_ok               pha                                ; Push the x-position

                    lda        ScreenHeight
                    lsr
                    sta        appTmp0
                    lda        PlayerGlobalY
                    sec
                    sbc        appTmp0
                    bpl        :y_pos
                    lda        #0
:y_pos              cmp        MaxBG0Y
                    bcc        :y_ok
                    lda        MaxBG0Y
:y_ok               pha                                ; Push the y-position
                    _GTESetBG0Origin

                    pea        $0000
                    lda        StartY
                    lsr
                    pha
                    _GTESetBG1Origin
                    rts

; Convert the global coordinates to adjusted local coordinated (compensating for wrap-around)
UpdatePlayerLocal
            lda  PlayerGlobalX
            sec
            sbc  StartX
            sta  PlayerX

            lda  PlayerGlobalY
            sec
            sbc  StartY
            sta  PlayerY
            rts

; Simple updates with gravity and collisions.  It's important that eveything in this
; subroutine be done against 
UpdatePlayerPos
            stz  PlayerStanding
            lda  PlayerYVel
            bmi  :no_ground_check

; Check if the player is standing on the ground at their current local position

            lda  PlayerX
            pha
            lda  PlayerY
            clc
            adc  #16
            pha
            _GTEGetTileAt
            pla
            and  #TILE_ID_MASK
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
            ora  #HERO_ID
            sta  SpriteFrame

            lda  SpriteCount
            eor  SpriteToggle
            sta  SpriteCount

; If the player is standing and XVel != 0, pick a frame
            lda  PlayerStanding
            beq  :frame
            lda  PlayerXVel
            beq  :frame

            jsr  _GetVBLTicks
            and  #$0003
            inc
            and  #$0003
            asl
            adc  SpriteFrame
            sta  SpriteFrame
:frame
            lda  SpriteFrame
            ora  SpriteCount
            tax

            lda  PlayerID
;            jsl  UpdateSprite                          ; Change the tile ID and / or flags

;            pea   HERO_SLOT
;            pei   Flips                         ; with these flags (h/v flip)
;            pea   VBUFF_SPRITE_START            ; and use this stamp
;            _GTEUpdateSprite
            
            rts

ToolPath        str   '1/Tool160'
LastHFlip       dw   0
SpriteFrame     ds   2
SpriteCount     dw   0
SpriteToggle    dw   0


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
                pea   #ENGINE_MODE_DYN_TILES+ENGINE_MODE_TWO_LAYER   ; Enable Dynamic Tiles and Two Layer
                lda   MyUserId                  ; Pass the userId for memory allocation
                pha
                _GTEStartUp
                bcc    :ok3
                brk    $03

:ok3
                rts

_Deref          MAC
                phb                   ; save caller's data bank register
                pha                   ; push high word of handle on stack
                plb                   ; sets B to the bank byte of the pointer
                lda   |$0002,x        ; load the high word of the master pointer
                pha                   ; and save it on the stack
                lda   |$0000,x        ; load the low word of the master pointer
                tax                   ; and return it in X
                pla                   ; restore the high word in A
                plb                   ; pull the handle's high word high byte off the
                                      ; stack
                plb                   ; restore the caller's data bank register    
                <<<

AllocBank      PushLong  #0
               PushLong  #$10000
               PushWord  MyUserId
               PushWord  #%11000000_00011100
               PushLong  #0
               _NewHandle
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               _Deref
               rts

_GetVBLTicks
                PushLong  #0
                _GetTick
                pla
                plx
                rts

;                    PUT        ../shell/Overlay.s
                    PUT        gen/App.TileMapBG0.s
;                    PUT        gen/App.TileSetAnim.s
