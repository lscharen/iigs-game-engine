; Test driver to exercise graphics routines.

                REL
                DSK   MAINSEG

                use   Locator.Macs
                use   Load.Macs
                use   Mem.Macs
                use   Misc.Macs
                use   Util.Macs
                use   EDS.GSOS.Macs
                use   GTE.Macs

                mx    %00

tiledata        EXT                           ; tileset buffer
TileSetPalette  EXT

; Keycodes
LEFT_ARROW      equ   $08
RIGHT_ARROW     equ   $15
UP_ARROW        equ   $0B
DOWN_ARROW      equ   $0A

; Direct page space
MyUserId        equ   0
BankLoad        equ   2
StartX          equ   4
StartY          equ   6
TileMapWidth    equ   8
TileMapHeight   equ   10
ScreenWidth     equ   12
ScreenHeight    equ   14
MaxGlobalX      equ   16
MaxGlobalY      equ   18
MaxBG0X         equ   20
MaxBG0Y         equ   22
OldOneSecondCounter equ 26
appTmp0         equ   28
appTmp1         equ   30
appTmp2         equ   32
PlayerX         equ   34
PlayerY         equ   36
PlayerXVel      equ   38
PlayerYVel      equ   40
PlayerStanding  equ   42
PlayerGlobalX   equ   44
PlayerGlobalY   equ   46
LastHFlip       equ   48
SpriteFrame     equ   50
SpriteToggle    equ   52
SpriteCount     equ   54
Scale           equ   56

                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                tdc
                sta   MyDirectPage            ; Keep a copy for the overlay callback

                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                lda   #ENGINE_MODE_USER_TOOL+ENGINE_MODE_TWO_LAYER+ENGINE_MODE_DYN_TILES
                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize local variables

                stz   StartX
                stz   StartY
                stz   frameCount
                stz   bg1rotation
                stz   LastHFlip
                stz   SpriteCount
                stz   SpriteToggle

                lda   #4
                sta   Scale
                pei   Scale
                _GTESetBG1Scale

; Initialize the graphics screen playfield

                pea   #320
                pea   #200
                _GTESetScreenMode

; Load a tileset

                pea   #^tiledata
                pea   #tiledata
                _GTELoadTileSet

                pea   $0000
                pea   #^TileSetPalette
                pea   #TileSetPalette
                _GTESetPalette

; Reset the BG1 buffer

                pea   $DDDD
                _GTEClearBG1Buffer

; Set up our level data

                jsr   BG0SetUp
                jsr   SetLimits

                jsr   AllocBank               ; Alloc 64KB for Load/Unpack
                sta   BankLoad                ; Store "Bank Pointer"
                ldx   #BG1DataFile            ; Load the background file into the bank
                jsr   LoadFile

                lda   #193                    ; Tile ID of '0'
                jsr   InitOverlay             ; Initialize the status bar
                pha
                _GTEGetSeconds
                pla
                sta   OldOneSecondCounter
                jsr   UdtOverlay

                pha                         ; space for result
                pea   #6
                pea   ^UpdateBG1Rotation
                pea   UpdateBG1Rotation
                pea   $0000
                _GTEAddTimer
                pla

; Initialize the sprite's global position (this is tracked outside of the tile engine)

                lda   #16
                sta   PlayerGlobalX
                sta   PlayerX
                lda   MaxGlobalY
                sec
                sbc   #64                     ; 32 for tiles, 16 for sprite
                sta   PlayerGlobalY
                sta   PlayerY

                stz   PlayerXVel
                stz   PlayerYVel

; Create the sprites

HERO_FRAME_1    equ   {SPRITE_16X16+1}
HERO_VBUFF_1    equ   VBUFF_SPRITE_START+0*VBUFF_SPRITE_STEP
HERO_FRAME_2    equ   {SPRITE_16X16+7}
HERO_VBUFF_2    equ   VBUFF_SPRITE_START+1*VBUFF_SPRITE_STEP
HERO_FRAME_3    equ   {SPRITE_16X8+65}
HERO_VBUFF_3    equ   VBUFF_SPRITE_START+2*VBUFF_SPRITE_STEP
HERO_FRAME_4    equ   {SPRITE_16X8+71}
HERO_VBUFF_4    equ   VBUFF_SPRITE_START+3*VBUFF_SPRITE_STEP
HERO_SLOT_1     equ   1
HERO_SLOT_2     equ   2

                pea   HERO_FRAME_1
                pea   HERO_VBUFF_1
                _GTECreateSpriteStamp

                pea   HERO_FRAME_2
                pea   HERO_VBUFF_2
                _GTECreateSpriteStamp

                pea   HERO_FRAME_3
                pea   HERO_VBUFF_3
                _GTECreateSpriteStamp

                pea   HERO_FRAME_4
                pea   HERO_VBUFF_4
                _GTECreateSpriteStamp

                pea   HERO_FRAME_1
                pei   PlayerX
                pei   PlayerY
                pea   HERO_SLOT_1                   ; Put the player in slot 1
                _GTEAddSprite

                pea   HERO_SLOT_1
                pea   $0000
                pea   HERO_VBUFF_1                 ; and use this stamp
                _GTEUpdateSprite

                pea   HERO_FRAME_2
                pei   PlayerX
                lda   PlayerY
                clc
                adc   #16
                pha
                pea   HERO_SLOT_2                   ; Put the player in slot 1
                _GTEAddSprite

                pea   HERO_SLOT_2
                pea   $0000
                pea   HERO_VBUFF_3                 ; and use this stamp
                _GTEUpdateSprite

EvtLoop
                pha
                _GTEReadControl
                pla

                jsr   HandleKeys                   ; Do the generic key handlers
                bcs   :do_more
                brl   do_render

:do_more
                bit   #PAD_BUTTON_A
                beq   :no_a
                pha
                jsr   handle_a
                pla
:no_a
                bit   #PAD_KEY_DOWN
                beq   :reg_key
                and   #$007F
                cmp   #'s'
                bne   :not_s
                inc   Scale
                pei   Scale
                _GTESetBG1Scale
                jmp   do_render

:not_s
                cmp   #'x'
                bne   :reg_key
                dec   Scale
                pei   Scale
                _GTESetBG1Scale
                jmp   do_render

:reg_key
                and   #$007F
                cmp   #LEFT_ARROW
                bne   *+5
                jmp   handle_left

                cmp   #RIGHT_ARROW
                bne   *+5
                jmp   handle_right

                cmp   #' '
                bne   :not_stop
                stz   PlayerXVel
                bra   do_render

:not_stop
                cmp   #'b'     ; show background
                bne   :not_b
                jsr   ShowBG1
:not_b

do_render
                jsr   UpdatePlayerPos        ; Apply forces
                jsr   ApplyCollisions        ; Check if we run into things
                jsr   UpdateCameraPos        ; Moves the screen

                pea   HERO_SLOT_1
                pei   PlayerX
                pei   PlayerY
                _GTEMoveSprite                    ; Move the sprite to this local position

                pea   HERO_SLOT_2
                pei   PlayerX
                lda   PlayerY
                clc
                adc   #16
                pha
                _GTEMoveSprite

                pea    #RENDER_BG1_ROTATION
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
                brl   EvtLoop


handle_a
                lda   PlayerStanding
                beq   :no_jump
                lda   #-9
                sta   PlayerYVel
:no_jump        rts

handle_left
                lda   PlayerXVel
                bpl   :ok
                cmp   #-4
                bcc   :out
:ok
                dec   PlayerXVel
:out
                jmp   do_render

handle_right    lda   PlayerXVel
                bmi   :ok
                cmp   #6
                bcs   :out
:ok
                inc   PlayerXVel
:out
                jmp   do_render

ShowBG1
                pea   #164                    ; Fill everything
                pea   #200
                pea   #256
                lda   BankLoad
                pha
                pea   $0000
                pea   $0000                   ; default flags
                _GTECopyPicToBG1
                rts

; Simple updates with gravity and collisions.  It's important that eveything in this
; subroutine be done against the VBL tick count
UpdatePlayerPos
            lda  PlayerGlobalY
            clc
            adc  PlayerYVel
            bpl  :not_neg_y
            lda  #0

:not_neg_y
            cmp  MaxGlobalY
            bcc  *+4
            lda  MaxGlobalY
            sta  PlayerGlobalY

            lda  PlayerGlobalX
            clc
            adc  PlayerXVel
            bpl  :not_neg
            lda  #0

:not_neg
            cmp  MaxGlobalX
            bcc  *+4
            lda  MaxGlobalX
            sta  PlayerGlobalX
            rts

ApplyCollisions

; Convert global to local coordinates

            lda  PlayerGlobalX
            sec
            sbc  StartX
            sta  PlayerX

            lda  PlayerGlobalY
            sec
            sbc  StartY
            sta  PlayerY

; Collision testing

            inc  PlayerYVel
            stz  PlayerStanding

; Check if the player is standing on the ground at their current local position

            pha                         ; space for result
            pei  PlayerX
            lda  PlayerY
            clc
            adc  #24
            pha
            _GTEGetTileAt
            pla

; Decide if mario's feet are on a "ground" tile (blocks, pipes, etc.)
            and  #TILE_ID_MASK
            cmp  #64
            bcc  :not_ground

            lda  PlayerYVel
            bmi  :not_ground

            lda  PlayerGlobalY
            and  #$fff8
            sta  PlayerGlobalY
            stz  PlayerYVel                     ; Stop falling when we hit the ground
            lda  #1
            sta  PlayerStanding
            bra  :y_ok

:not_ground
            lda  PlayerYVel
            bmi  :y_ok
            cmp  #8
            bcc  :y_ok
            lda  #7
            sta  PlayerYVel
:y_ok

            ldx  LastHFlip                     ; Update sprite frame based on actions
            lda  PlayerXVel
            beq  :no_dxv
            bpl  :pos_dxv
            ldx  #SPRITE_HFLIP
            bra  :no_dxv
:pos_dxv
            ldx  #0
:no_dxv
            sta  PlayerXVel
            stx  LastHFlip

            lda  SpriteCount
            eor  SpriteToggle
            sta  SpriteCount

; If the player is standing and XVel != 0, pick a frame

            ldx  #2
            lda  PlayerXVel
            beq  :frame

            jsr  _GetVBLTicks
            and  #$0006
            tax
:frame
            pea   HERO_SLOT_1
            pei   LastHFlip
            lda   HeroFrames1,x
            pha

            pea   HERO_SLOT_2
            pei   LastHFlip
            lda   HeroFrames2,x
            pha

            _GTEUpdateSprite
            _GTEUpdateSprite
            
            rts

HeroFrames1  dw    HERO_VBUFF_2,HERO_VBUFF_1,HERO_VBUFF_2,HERO_VBUFF_1
HeroFrames2  dw    HERO_VBUFF_4,HERO_VBUFF_3,HERO_VBUFF_4,HERO_VBUFF_3

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
:x_pos      cmp        MaxBG0X
            bcc        :x_ok
            lda        MaxBG0X
:x_ok       sta        StartX

            lda        ScreenHeight
            lsr
            sta        appTmp0
            lda        PlayerGlobalY
            sec
            sbc        appTmp0
            bpl        :y_pos
            lda        #0
:y_pos      cmp        MaxBG0Y
            bcc        :y_ok
            lda        MaxBG0Y
:y_ok       sta        StartY

            pei        StartX
            pei        StartY
            _GTESetBG0Origin

            rts

; Timer callback to animate the background
UpdateBG1Rotation
            ldal  bg1rotation
            inc
            cmp   #64
            bcc   *+5
            sbc   #64
            stal  bg1rotation
            pha
            _GTESetBG1Rotation
            rtl
bg1rotation     ds   2

; Exit code
Exit
                _GTEShutDown
Quit
                _QuitGS    qtRec

                bcs   Fatal
Fatal           brk   $00

qtRec           adrl  $0000
                da    $00

; Color palette
MyDirectPage    ds    2

SetLimits
                pha                       ; Allocate space for width (in tiles), height (in tiles), pointer
                pha
                pha
                pha
                _GTEGetBG0TileMapInfo
                pla
                sta   TileMapWidth
                pla
                sta   TileMapHeight
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
                sta   ScreenWidth
                pla
                sta   ScreenHeight

                lda   TileMapWidth
                asl
                asl
                sta   MaxGlobalX
                sec
                sbc   ScreenWidth
                sta   MaxBG0X

                lda   TileMapHeight
                asl
                asl
                asl
                sta   MaxGlobalY
                sec
                sbc   ScreenHeight
                sta   MaxBG0Y

; Check if the current StartX and StartY are out of bounds
                lda   StartX
                cmp   MaxBG0X
                bcc   :x_ok
                lda   MaxBG0X
:x_ok           pha

                lda   StartY
                cmp   MaxBG0Y
                bcc   :y_ok
                lda   MaxBG0Y
:y_ok           pha
                _GTESetBG0Origin

                rts

; Load a binary file in the BG1 buffer
DoLoadBG1
                lda   BankLoad
                ldx   #BG1DataFile
                jsr   LoadFile

;                ldx   BankLoad
;                lda   #0
;                ldy   BG1DataBank
;                jsl   CopyBinToBG1

                pea   #256                      ; fill the whole buffer
                pea   #208
                pei   BankLoad
                pea   $0008                     ; skip header
                _GTECopyPicToBG1
                rts

_GetVBLTicks
            PushLong  #0
            _GetTick
            pla
            plx
            rts

BG1DataFile     strl  '1/bg1.bin'

frameCount      equ   24

                PUT        ../StartUp.s
                PUT        ../../shell/Overlay.s
                PUT        gen/App.TileMapBG0.s
