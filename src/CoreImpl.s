; Feature flags
NO_INTERRUPTS     equ       0                   ; turn off for crossrunner debugging
NO_MUSIC          equ       1                   ; turn music + tool loading off

; External data space provided by the main program segment
tiledata          EXT
TileStore         EXT

; Sprite plane data and mask banks are provided as an external segment
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

; Core engine functionality.  The idea is that that source file can be PUT into
; a main source file and all of the functionality will be available.
;
; There are some constancts that must be externally defined that can affect how
; the GTE runtime works
;
; NO_MUSIC      : Set to non-zero to avoid using any source
; NO_INTERRUPTS : Set to non-zero to avoid installing custom interrupt handlers

                  mx        %00

; Assumes the direct page is set and EngineMode and UserId has been initialized
_CoreStartUp
                  jsr       IntStartUp          ; Enable certain interrupts

                  jsr       InitMemory          ; Allocate and initialize memory for the engine
                  jsr       EngineReset         ; All of the resources are allocated, put the engine in a known state

                  jsr       InitGraphics        ; Initialize all of the graphics-related data
                  jsr       InitSprites         ; Initialize the sprite subsystem
                  jsr       InitTiles           ; Initialize the tile subsystem

                  jsr       InitTimers          ; Initialize the timer subsystem
                  rts

_CoreShutDown
                  jsr       IntShutDown
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

                  jsr       _SetDataBank

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

; This is OK, it's referenced by a long address
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

;                  stz       EngineMode
                  stz       DirtyBits
                  stz       LastRender             ; Initialize as is a full render was performed
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
_ReadControl      pea       $0000               ; low byte = key code, high byte = %------AB 

                  sep       #$20
                  ldal      OPTION_KEY_REG      ; 'B' button
                  and       #$80
                  beq       :BNotDown

                  lda       #>PAD_BUTTON_B
                  ora       2,s
                  sta       2,s

:BNotDown
                  ldal      COMMAND_KEY_REG
                  and       #$80
                  beq       :ANotDown

                  lda       #>PAD_BUTTON_A
                  ora       2,s
                  sta       2,s

:ANotDown
                  ldal      KBD_STROBE_REG      ; read the keyboard
                  bit       #$80
                  beq       :KbdNotDwn          ; check the key-down status
                  and       #$7f
                  ora       1,s
                  sta       1,s

                  cmp       LastKey
                  beq       :KbdDown
                  sta       LastKey

                  lda       #>PAD_KEY_DOWN       ; set the keydown flag
                  ora       2,s
                  sta       2,s
                  bra       :KbdDown

:KbdNotDwn
                  stz       LastKey
:KbdDown
                  rep       #$20
                  pla
                  rts


; Helper function to take a local pixel coordinate [0, ScreenWidth-1],[0, ScreenHeight-1] and return the
; row and column in the tile store that is corresponds to.  This takes into consideration the StartX and
; StartY offsets.
;
; This is more specialized than the code in the _MarkDirtySprite routine below since it does not deal with
; negative or off-screen values.
_OriginToTileStore
        lda   StartYMod208
        lsr
        lsr
        and   #$FFFE                             ; Store the pre-multiplied by 2 for indexing
        tay
        lda   StartXMod164
        lsr
        and   #$FFFE                             ; Same pre-multiply by 2 for later
        tax
        rts

; X = local x-coordinate (0, playfield width)
; Y = local y-coordinate (0, playfield height)
_LocalToTileStore
        clc
        tya
        adc   StartYMod208                       ; Adjust for the scroll offset
        cmp   #208                               ; check if we went too far positive
        bcc   *+5
        sbc   #208
        lsr
        lsr
        and   #$FFFE                             ; Store the pre-multiplied by 2 for indexing
        tay

        clc
        txa
        adc   StartXMod164
        cmp   #164
        bcc   *+5
        sbc   #164
        lsr
        and   #$FFFE                             ; Same pre-multiply by 2 for later
        tax
        rts