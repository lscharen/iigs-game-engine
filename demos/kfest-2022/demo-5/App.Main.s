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
                use   Tool222.Macs.s

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
PlayerX         equ   30
PlayerY         equ   32
PlayerXVel      equ   34
PlayerYVel      equ   36
PlayerStanding  equ   38
PlayerGlobalX   equ   40
PlayerGlobalY   equ   42
LastHFlip       equ   44
SpriteFrame     equ   46
SpriteToggle    equ   48
SpriteCount     equ   50
PlayerX1        equ   52
PlayerY1        equ   54
PlayerX2        equ   56
PlayerY2        equ   58

                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                tdc
                sta   MyDirectPage            ; Keep a copy for the overlay callback

                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                lda   #ENGINE_MODE_USER_TOOL  ; Engine in Fast Mode
                jsr   GTEStartUp              ; Load and install the GTE User Tool
                
;                jsr   SoundStartUp
;                jsr   StartMusic

; Initialize local variables

                stz   StartX
                stz   StartY
                stz   frameCount
                stz   LastHFlip
                stz   SpriteCount
                stz   SpriteToggle

; Initialize the graphics screen playfield

                pea   #160         ; width in bytes
                pea   #200         ; height in lines
                _GTESetScreenMode

; Load a tileset

                pea   #0
                pea   #511
                pea   #^tiledata
                pea   #tiledata
                _GTELoadTileSet

                pea   $0000
                pea   #^TileSetPalette
                pea   #TileSetPalette
                _GTESetPalette

; Set up our level data

                jsr   BG0SetUp
                jsr   SetLimits

                lda   #193                    ; Tile ID of '0'
                jsr   InitOverlay             ; Initialize the status bar
                pha
                _GTEGetSeconds
                pla
                sta   OldOneSecondCounter
                jsr   UdtOverlay

; Initialize the sprite's global position (this is tracked outside of the tile engine)

                lda   #16
                sta   PlayerGlobalX
                sta   PlayerX
                sta   PlayerX1
                sta   PlayerX2

                lda   MaxGlobalY
                sec
                sbc   #48                     ; 32 for tiles, 16 for sprite
                lda   #48                     ; 32 for tiles, 16 for sprite
                sta   PlayerGlobalY
                sta   PlayerY
                sta   PlayerY1
                sta   PlayerY2

                stz   PlayerXVel
                stz   PlayerYVel

; Set the screen to the bottom-left

                pea   $0000
                lda   MaxBG0Y
                pha
                _GTESetBG0Origin

; Create the sprites

HERO_SIZE       equ   {SPRITE_16X16}
HERO_FLAGS      equ   HERO_SIZE                                 ; no extra H/V bits for now
HERO_FRAME_1    equ   HERO_SIZE+145
HERO_VBUFF_1    equ   VBUFF_SPRITE_START+0*VBUFF_SPRITE_STEP
HERO_FRAME_2    equ   HERO_SIZE+147
HERO_VBUFF_2    equ   VBUFF_SPRITE_START+1*VBUFF_SPRITE_STEP
HERO_FRAME_3    equ   HERO_SIZE+149
HERO_VBUFF_3    equ   VBUFF_SPRITE_START+2*VBUFF_SPRITE_STEP
HERO_FRAME_4    equ   HERO_SIZE+151
HERO_VBUFF_4    equ   VBUFF_SPRITE_START+3*VBUFF_SPRITE_STEP
HERO_SLOT       equ   1

; Create stamps of each sprite

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

; Compile the sprite stamps and hold the compilation token

                pha                                ; Space for result
                pea   HERO_SIZE
                pea   HERO_VBUFF_1
                _GTECompileSpriteStamp
                pla

                pea   HERO_SLOT                    ; Put the player in slot 1
                pea   HERO_FLAGS+SPRITE_COMPILED   ;  mark this as a compiled sprite (can only use in RENDER_WITH_SHADOWING mode)
                pha                                ;  pass in the token of the compiled stamp
                pei   PlayerX
                pei   PlayerY
                _GTEAddSprite

;                brl   Exit

; Repeat for each stamp.  _GTECompileSpriteStamp will return an error if it runs out of memory

                pea   HERO_SLOT+1                   ; Put the player in slot 1
                pea   HERO_FLAGS
                pea   HERO_VBUFF_1                 ; and use this stamp
                pei   PlayerX1
                pei   PlayerY1
                _GTEAddSprite

                pea   HERO_SLOT+2                   ; Put the player in slot 1
                pea   HERO_FLAGS
                pea   HERO_VBUFF_1                 ; and use this stamp
                pei   PlayerX2
                pei   PlayerY2
                _GTEAddSprite

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
                beq   :other_keys
                and   #$007F
                cmp   #'p'
                bne   :not_p
                pea   $0001
                _NTPPlayMusic
                bra   EvtLoop
:not_p          cmp   #'['
                bne   do_render
                _NTPStopMusic
                bra   EvtLoop

:other_keys
                and   #$007F
                cmp   #LEFT_ARROW
                bne   *+5
                jmp   handle_left

                cmp   #RIGHT_ARROW
                bne   *+5
                jmp   handle_right

                cmp   #' '
                bne   do_render
                stz   PlayerXVel

do_render
                jsr   UpdatePlayerPos        ; Apply forces
                jsr   ApplyCollisions        ; Check if we run into things
                jsr   UpdateCameraPos        ; Moves the screen

                pea   HERO_SLOT
                pei   PlayerX
                pei   PlayerY
                _GTEMoveSprite                    ; Move the sprite to this local position

                pea   HERO_SLOT+1
                lda   PlayerX1
                sec
                sbc   StartX
                pha
                lda   PlayerY1
                sec
                sbc   StartY
                pha
                _GTEMoveSprite                    ; Move the sprite to this local position

                pea   HERO_SLOT+2
                lda   PlayerX2
                sec
                sbc   StartX
                pha
                lda   PlayerY2
                sec
                sbc   StartY
                pha
                _GTEMoveSprite                    ; Move the sprite to this local position

;                pea  #RENDER_WITH_SHADOWING
                pea  $0000
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

; Exit code
Exit
;                jsr   SoundShutDown
                _GTEShutDown
Quit
                _QuitGS    qtRec

                bcs   Fatal
Fatal           brk   $00

qtRec           adrl  $0000
                da    $00

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


; Use Tool222 (NinjaTrackerPlus) for music playback
SoundStartUp
                pea       $00DE
                pea       $0000
                _LoadOneTool
                bcc *+4
                brk  $02

                lda       MyUserId
                pha
                _NTPStartUp
                bcc *+4
                brk  $04
:out
                rts

SoundShutDown
                _NTPShutDown
                rts

StartMusic
                pea        #^MusicFile
                pea        #MusicFile
                _NTPLoadOneMusic
                bcc  *+4
                brk  $06
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

; Move coordinates down the list
            lda  PlayerX1
            sta  PlayerX2
            lda  PlayerY1
            sta  PlayerY2

            lda  PlayerGlobalX
            sta  PlayerX1
            lda  PlayerGlobalY
            sta  PlayerY1

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
            adc  #16
            pha
            _GTEGetTileAt
            pla

; Decide if mario's feet are on a "ground" tile (blocks, pipes, etc.)
            and  #TILE_ID_MASK
            cmp  #0
            beq  :not_ground
            cmp  #32
            bcs  :not_ground

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

            ldx  #HERO_VBUFF_1
            lda  PlayerXVel
            beq  :frame

            jsr  _GetVBLTicks
            and  #$0003
            asl
            tax
            lda  HeroFrames,x
            tax
:frame

;            pea   HERO_SLOT
;            pei   LastHFlip
;            phx
;            _GTEUpdateSprite
            
            rts

HeroFrames  dw    HERO_VBUFF_2,HERO_VBUFF_3,HERO_VBUFF_4,HERO_VBUFF_3

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

;            pea        $0000
;            lda        StartY
;            lsr
;            pha
;            _GTESetBG1Origin
            rts

_GetVBLTicks
            PushLong  #0
            _GetTick
            pla
            plx
            rts

frameCount  equ   24

MusicFile   str        '1/overworld.ntp'

            PUT        ../StartUp.s
            PUT        ../../shell/Overlay.s
            PUT        gen/App.TileMapBG0.s
