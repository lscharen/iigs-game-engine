                  use       Util.Macs.s
                  use       Load.Macs.s
                  use       Locator.Macs.s
                  use       Mem.Macs.s
                  use       Misc.Macs.s
                  use       Tool222.MACS.s
                  use       Core.MACS.s

                  use       .\Defs.s

; Feature flags
NO_INTERRUPTS     equ       1                   ; turn off for crossrunner debugging
NO_MUSIC          equ       1                   ; turn music + tool loading off

; External data space provided by the main program segment
tiledata          EXT
TileStore         EXT

; Sprite plane data and mask banks are provided as an exteral segment
;
; The sprite data holds a set of pre-rendered sprites that are optimized to support the rendering pipeline.  There
; are four copies of each sprite, along with the cooresponding mask laid out into 4x4 tile regions where the
; empty row and column is shared between adjacent blocks.
;
; Logically, the memory is laid out as 4 columns of sprites and 4 rows.
;
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   |   |   |   |   |   |   |   |   |   |   |   | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 0 | 0 |   | 1 | 1 |   | 2 | 2 |   | 3 | 3 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 0 | 0 |   | 1 | 1 |   | 2 | 2 |   | 3 | 3 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   |   |   |   |   |   |   |   |   |   |   |   | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 4 | 4 |   | 5 | 5 |   | 6 | 6 |   | 7 | 7 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   | 4 | 4 |   | 5 | 5 |   | 6 | 6 |   | 7 | 7 | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
; |   |   |   |   |   |   |   |   |   |   |   |   | ...
; +---+---+---+---+---+---+---+---+---+---+---+---+-...
;
; For each sprite, when it needs to be copied into an on-screen tile, it could exist at any offset compared to its
; natural alignment.  By having a buffer around the sprite data, an address pointer can be set to a different origin
; and a simple 8x8 block copy can cut out the appropriate bit of the sprite.  For example, here is a zoomed-in look
; at a sprite with an offset, O, at (-2,-3).  As shown, by selecting an appropriate origin, just the top corner
; of the sprite data will be copied.
;
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |           ||           |   ||   |   |   |   ||   |   |   |   |
; +---+-- O----------------+ --+---++---+---+---+---++---+---+---+---+..
; |   |   |                |   |   ||   |   |   |   ||   |   |   |   |
; +---+-- |                | --+---++---+---+---+---++---+---+---+---+..
; |   |   |                |   |   ||   |   |   |   ||   |   |   |   |
; +---+-- |                | --+---++---+---+---+---++---+---+---+---+..
; |   |   |                |   |   ||   |   |   |   ||   |   |   |   |
; +===+== |       ++===+== | ==+===++===+===+===+===++===+===+===+===+..
; |   |   |       ||   | S | S | S || S | S | S |   ||   |   |   |   |
; +---+-- +----------------+ --+---++---+---+---+---++---+---+---+---+..
; |   |           || S | S   S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +===+===+===+===++===+===+===+===++===+===+===+===++===+===+===+===+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   || S | S | S | S || S | S | S | S ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; |   |   |   |   ||   | S | S | S || S | S | S |   ||   |   |   |   |
; +---+---+---+---++---+---+---+---++---+---+---+---++---+---+---+---+..
; .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .
;
; Each sprite will take up, effectively 9 tiles of storage space per 
; instance (plus edges) and there are 4 instances for the H/V bits
; and 4 more for the masks.  This results in a need for 43,264 bytes
; for all 16 sprites.

spritedata        EXT
spritemask        EXT

; If there are overlays, they are provided as an external
Overlay           EXT

; Core engine functionality.  The idea is that that source file can be PUT into
; a main source file and all of the functionality will be available.
;
; There are some constancts that must be externally defined that can affect how
; the GTE runtime works
;
; NO_MUSIC      : Set to non-zero to avoid using any source
; NO_INTERRUPTS : Set to non-zero to avoid installing custom interrupt handlers

                  mx        %00

; High-Level StartUp and ShutDown functions
EngineStartUp     ENT
                  phb
                  phk
                  plb

                  jsr       ToolStartUp         ; Start up the toolbox tools we rely on
                  jsr       _CoreStartUp

                  plb
                  rtl

_CoreStartUp
                  jsr       SoundStartUp        ; Start up any sound/music tools
                  jsr       IntStartUp          ; Enable certain iterrupts

                  jsr       InitMemory          ; Allocate and initialize memory for the engine
                  jsr       EngineReset         ; All of the resources are allocated, put the engine in a known state

                  jsr       InitGraphics        ; Initialize all of the graphics-related data
                  nop
                  jsr       InitSprites         ; Initialize the sprite subsystem
                  jsr       InitTiles           ; Initialize the tile subsystem

                  jsr       InitTimers          ; Initialize the timer subsystem
                  rts

EngineShutDown    ENT
                  phb
                  phk
                  plb

                  jsr       _CoreShutDown
                  jsr       ToolShutDown

                  plb
                  rtl

_CoreShutDown
                  jsr       IntShutDown
                  jsr       SoundShutDown
                  rts

ToolStartUp
                  _TLStartUp                    ; normal tool initialization
                  pha
                  _MMStartUp
                  _Err                          ; should never happen
                  pla
                  sta       MasterId            ; our master handle references the memory allocated to us
                  ora       #$0100              ; set auxID = $01  (valid values $01-0f)
                  sta       UserId              ; any memory we request must use our own id 

                  _MTStartUp
                  rts

MasterId          ds        2
UserId            ds        2

; Fatal error handler invoked by the _Err macro
PgmDeath          tax
                  pla
                  inc
                  phx
                  phk
                  pha
                  bra       ContDeath
PgmDeath0         pha
                  pea       $0000
                  pea       $0000
ContDeath         ldx       #$1503
                  jsl       $E10000

ToolShutDown
                  rts

; Use Tool222 (NinjaTrackerPlus) for music playback
SoundStartUp
                  lda       #NO_MUSIC
                  bne       :no_music

                  pea       $00DE
                  pea       $0000
                  _LoadOneTool
                  _Err

                  lda       UserId
                  pha
                  _NTPStartUp
:no_music
                  rts

SoundShutDown
                  lda       #NO_MUSIC
                  bne       :no_music
                  _NTPShutDown
:no_music
                  rts

; Install interrupt handlers.  We use the VBL interrupt to keep animations
; moving at a consistent rate, regarless of the rendered frame rate.  The 
; one-second timer is generally just used for counters and as a handy 
; frames-per-second trigger.
IntStartUp
                  lda       #NO_INTERRUPTS
                  bne       :no_interrupts
                  PushLong  #0
                  pea       $0015               ; Get the existing 1-second interrupt handler and save
                  _GetVector
                  PullLong  OldOneSecVec

                  pea       $0015               ; Set the new handler and enable interrupts
                  PushLong  #OneSecHandler
                  _SetVector

                  pea       $0006
                  _IntSource

                  PushLong  #VBLTASK            ; Also register a Heart Beat Task
                  _SetHeartBeat

:no_interrupts
                  rts

IntShutDown
                  lda       #NO_INTERRUPTS
                  bne       :no_interrupts

                  pea       $0007               ; disable 1-second interrupts
                  _IntSource

                  PushLong  #VBLTASK            ; Remove our heartbeat task
                  _DelHeartBeat

                  pea       $0015
                  PushLong  OldOneSecVec        ; Reset the interrupt vector
                  _SetVector

:no_interrupts
                  rts


; Interrupt handlers. We install a heartbeat (1/60th second and a 1-second timer)
OneSecHandler     mx        %11
                  phb
                  pha
                  phk
                  plb

                  rep       #$20
                  inc       OneSecondCounter
                  sep       #$20

                  ldal      $E0C032
                  and       #%10111111          ;clear IRQ source
                  stal      $E0C032

                  pla
                  plb
                  clc
                  rtl
                  mx        %00

OneSecondCounter  ENT
                  dw        0
OldOneSecVec      ds        4

VBLTASK           hex       00000000
                  dw        0
                  hex       5AA5

; Reset the engine to a known state
; Blitter initialization
EngineReset
                  stz       ScreenHeight
                  stz       ScreenWidth
                  stz       ScreenY0
                  stz       ScreenY1
                  stz       ScreenX0
                  stz       ScreenX1
                  stz       ScreenTileHeight
                  stz       ScreenTileWidth
                  stz       StartX
                  stz       OldStartX
                  stz       StartXMod164

                  stz       StartY
                  stz       OldStartY
                  stz       StartYMod208

                  stz       EngineMode
                  stz       DirtyBits
                  stz       LastRender
                  stz       LastPatchOffset
                  stz       BG1StartX
                  stz       BG1StartXMod164
                  stz       BG1StartY
                  stz       BG1StartYMod208
                  stz       BG1OffsetIndex

                  stz       BG0TileOriginX
                  stz       BG0TileOriginY
                  stz       OldBG0TileOriginX
                  stz       OldBG0TileOriginY

                  stz       BG1TileOriginX
                  stz       BG1TileOriginY
                  stz       OldBG1TileOriginX
                  stz       OldBG1TileOriginY

                  stz       TileMapWidth
                  stz       TileMapHeight
                  stz       TileMapPtr
                  stz       TileMapPtr+2
                  stz       FringeMapPtr
                  stz       FringeMapPtr+2

                  stz       BG1TileMapWidth
                  stz       BG1TileMapHeight
                  stz       BG1TileMapPtr
                  stz       BG1TileMapPtr+2

                  stz       SCBArrayPtr
                  stz       SCBArrayPtr+2

                  stz       SpriteBanks
                  stz       SpriteMap
                  stz       ActiveSpriteCount

                  stz       OneSecondCounter

                  lda       #13
                  sta       tmp15
                  stz       tmp14

:loop
                  ldx       #BlitBuff
                  lda       #^BlitBuff
                  ldy       tmp14
                  jsr       BuildBank

                  lda       tmp14
                  clc
                  adc       #4
                  sta       tmp14

                  dec       tmp15
                  bne       :loop

                  rts

; Allow the user to dynamically select one of the pre-configured screen sizes, or pass
; in a specific width and height.  The screen is automatically centered.  If this is
; not desired, then SetScreenRect should be used directly
;
;  0. Full Screen           : 40 x 25   320 x 200 (32,000 bytes (100.0%)) 
;  1. Sword of Sodan        : 34 x 24   272 x 192 (26,112 bytes ( 81.6%))
;  2. ~NES                  : 32 x 25   256 x 200 (25,600 bytes ( 80.0%))
;  3. Task Force            : 32 x 22   256 x 176 (22,528 bytes ( 70.4%))
;  4. Defender of the World : 35 x 20   280 x 160 (22,400 bytes ( 70.0%))
;  5. Rastan                : 32 x 20   256 x 160 (20,480 bytes ( 64.0%))
;  6. Game Boy Advanced     : 30 x 20   240 x 160 (19,200 bytes ( 60.0%))
;  7. Ancient Land of Y's   : 36 x 16   288 x 128 (18,432 bytes ( 57.6%))
;  8. Game Boy Color        : 20 x 18   160 x 144 (11,520 bytes ( 36.0%))
;  9. Agony (Amiga)         : 36 x 24   288 x 192 (27,648 bytes ( 86.4%))
; 10. Atari Lynx            : 20 x 13   160 x 102 (8,160 bytes  ( 25.5%))
;
;  X = mode number OR width in pixels (must be multiple of 2)
;  Y = height in pixels (if X > 8)

ScreenModeWidth   dw        320,272,256,256,280,256,240,288,160,288,160,320
ScreenModeHeight  dw        200,192,200,176,160,160,160,128,144,192,102,1

SetScreenMode     ENT
                  phb
                  phk
                  plb
                  jsr       _SetScreenMode
                  plb
                  rtl

_SetScreenMode
                  cpx       #11
                  bcs       :direct             ; if x > 10, then assume X and Y are the dimensions

                  txa
                  asl
                  tax

                  ldy       ScreenModeHeight,x
                  lda       ScreenModeWidth,x
                  tax

:direct           cpy       #201
                  bcs       :exit

                  cpx       #321
                  bcs       :exit

                  txa
                  lsr
                  pha                           ; Save X (width / 2) and Y (height)
                  phy

                  lda       #160                ; Center the screen
                  sec
                  sbc       3,s
                  lsr
                  xba
                  pha                           ; Save half the origin coordinate

                  lda       #200
                  sec
                  sbc       3,s                 ; This is now Y because of the PHA above
                  lsr
                  ora       1,s

                  plx                           ; Throw-away to pop the stack
                  ply
                  plx

                  jsr       SetScreenRect
                  jmp       FillScreen          ; tail return
:exit
                  rts


WaitForKey        sep       #$20
                  stal      KBD_STROBE_REG      ; clear the strobe
:WFK              ldal      KBD_REG
                  bpl       :WFK
                  rep       #$20
                  and       #$007F
                  rts

ClearKbdStrobe    sep       #$20
                  stal      KBD_STROBE_REG
                  rep       #$20
                  rts

; Read the keyboard and paddle controls and return in a game-controller-like format
LastKey           db        0
ReadControl       ENT
                  jsr       _ReadControl
                  rtl

_ReadControl      
                  pea       $0000               ; low byte = key code, high byte = %------AB 

                  sep       #$20
                  ldal      OPTION_KEY_REG      ; 'B' button
                  and       #$80
                  beq       :BNotDown

                  lda       #PAD_BUTTON_B
                  ora       2,s
                  sta       2,s

:BNotDown
                  ldal      COMMAND_KEY_REG
                  and       #$80
                  beq       :ANotDown

                  lda       #PAD_BUTTON_A
                  ora       2,s
                  sta       2,s

:ANotDown
                  ldal      KBD_STROBE_REG      ; read the keyboard
                  bit       #$80
                  beq       :KbdNotDwn          ; check the key-down status
                  and       #$7f
                  ora       1,s
                  sta       1,s

                  cmpl      LastKey
                  beq       :KbdDown
                  stal      LastKey

                  lda       #PAD_KEY_DOWN       ; set the keydown flag
                  ora       2,s
                  sta       2,s
                  bra       :KbdDown

:KbdNotDwn
                  lda       #0
                  stal      LastKey
:KbdDown
                  rep       #$20
                  pla
                  rts

                  put       blitter/Template.s

                  put       Memory.s
                  put       Graphics.s
                  put       Sprite.s
                  put       blitter/Tiles.s
                  put       Sprite2.s
                  put       SpriteRender.s
                  put       Render.s
                  put       Timer.s
                  put       Script.s
                  put       blitter/Blitter.s
                  put       blitter/Horz.s
                  put       blitter/PEISlammer.s
                  put       blitter/Tables.s
                  put       blitter/Tiles00000.s      ; normal tiles
                  put       blitter/Tiles00001.s      ; dynamic tiles
                  put       blitter/Tiles00010.s      ; normal masked tiles
                  put       blitter/Tiles00011.s      ; dynamic masked tiles

                  put       blitter/Tiles10000.s      ; normal tiles + sprites
                  put       blitter/Tiles10001.s      ; dynamic tiles + sprites
                  put       blitter/Tiles10010.s      ; normal masked tiles + sprites
                  put       blitter/Tiles10011.s      ; dynamic masked tiles + sprites

                  put       blitter/Tiles11000.s      ; normal high priority tiles + sprites
                  put       blitter/Tiles11001.s      ; dynamic high priority tiles + sprites
                  put       blitter/Tiles11010.s      ; normal high priority masked tiles + sprites
                  put       blitter/Tiles11011.s      ; dynamic high priority masked tiles + sprites

                  put       blitter/TilesBG1.s
                  put       blitter/Vert.s
                  put       blitter/BG0.s
                  put       blitter/BG1.s
                  put       blitter/SCB.s
                  put       TileMap.s
