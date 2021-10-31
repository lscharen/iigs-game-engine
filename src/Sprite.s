; Functions for sprie handling.  Mostly maintains the sprite list and provides
; utility functions to calculate sprite/tile intersections
;
; The sprite plane actually covers two banks so that more than 32K can be used as a virtual 
; screen buffer.  In order to be able to draw sprites offscreen, the virtual screen must be 
; wider and taller than the physical graphics screen.
;
; Initialize the sprite plane data and mask banks (all data = $0000, all masks = $FFFF)
InitSprites
           ldx    #$FFFE
           lda    #0
:loop1     stal   spritedata,x
           dex
           dex
           cpx    #$FFFE
           bne    :loop1

           ldx    #$FFFE
           lda    #$FFFF
:loop2     stal   spritemask,x
           dex
           dex
           cpx    #$FFFE
           bne    :loop2

           rts


; This function looks at the sprite list and renders the sprite plane data into the appropriate
; tiles in the code field
forceSpriteFlag ds 2
_RenderSprites

; First step is to look at the StartX and StartY values.  If the offsets have changed from the
; last time that the frame was rederer, then we need to mark all of the sprites as dirty so that
; the tiles that they were located at on the previous frame will be refreshed

            stz   forceSpriteFlag
            lda   StartX
            cmp   OldStartX
            beq   :no_chng_x
            lda   #SPRITE_STATUS_DIRTY
            sta   forceSpriteFlag
:no_chng_x 
            lda   StartY
            cmp   OldStartY
            beq   :no_chng_y
            lda   #SPRITE_STATUS_DIRTY
            sta   forceSpriteFlag
:no_chng_y

; Second step is to scan the list of spries.  A sprite is either clean or dirty.  If it's dirty,
; then its position had changed, so we need to add tiles to the dirty queue to make sure the
; playfield gets update.  If it's clean, we can skip eerything.

            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x       ; If the sttus is zero, that's the sentinel value
            beq   :out
            ora   forceSpriteFlag
            bit   #SPRITE_STATUS_DIRTY           ; If the dirty flag is set, do the things....
            bne   :render
:next       inx
            inx
            bra   :loop
:out        rts

; This is the complicated part; we need to draw the sprite into the sprite plane, but then
; calculate the code field tiles that this sprite potentially overlaps with and mark those
; tiles as dirty and store the appropriate sprite plane address that those tiles need to copy
; from.
:render
            stx   tmp0                                ; stash the X register
            txy                                       ; switch to the Y register

;            ldx   _Sprites+OLD_VBUFF_ADDR,y   
;            jsr   _EraseTileSprite                    ; erase from the old position

; Draw the sprite into the sprint plane buffer(s)

            ldx   _Sprites+VBUFF_ADDR,y               ; Get the address in the sprite plane to draw at
            lda   _Sprites+TILE_DATA_OFFSET,y         ; and the tile address of the tile
            tay
            jsr   _DrawTileSprite                     ; draw the sprite into the sprite plane

; Mark the appropriate tiles as dirty and as occupied by a sprite so that the ApplyTiles
; subroutine will get the drawn data from the sprite plane into the code field where it 
; can be drawn to the screen

            ldx   tmp0                                ; Restore the index into the sprite array
            jsr   _MarkDirtySprite8x8                 ; Eventually will have routines for all sprite sizes
            bra   :next

; Marks a 8x8 square as dirty.  The work here is mapping from local screen coordinates to the 
; tile store indices.  The first step is to adjust the sprite coordinates based on the current
; code field offsets and then cache variations of this value needed in the rest of the subroutine
;
; The SpritX is always the MAXIMUM value of the corner coordinates.  We subtract (SpriteX + StartX) mod 4
; to find the coordinate in the sprite plane that match up with the tile in the play field and 
; then use that to calculate the VBUFF address to copy sprite data from.
;
; StartX   SpriteX   z = * mod 4   (SprietX - z)
; ----------------------------------------------
; 0        8         0             8
; 1        8         1             7
; 2        8         2             6
; 3        8         3             5
; 4        9         1             8
; 5        9         2             7
; 6        9         3             6
; 7        9         0             9
; 8        10        2             8
; ...
;
; For the Y-coordinate, we just use "mod 8" instead of "mod 4"

_MarkDirtySprite8x8

; First, bounds check the X and Y coodinates of the sprite and, if they pass, pre-calculate some
; values that we can use later

            lda   _Sprites+SPRITE_Y,x                ; This is a signed value
            bpl   :y_is_pos
            cmp   #$FFF9                             ; If a tile is <= -8 do nothing, it's off-screen
            bcs   :y_is_ok
            rts
:y_is_pos   cmp   ScreenHeight                       ; Is a tile is > ScreenHeight, it's off-screen
            bcc   :y_is_ok
            rts
:y_is_ok

; The sprite's Y coordinate is in a range that it will impact the visible tiles that make up the play
; field.  Figure out what tile(s) they are and what part fo the sprite plane data/mask need to be
; accessed to overlay with the tile pixels

            clc
            adc   StartYMod208                       ; Adjust for the scroll offset (could be a negative number!)
            tay                                      ; Save this value
            and   #$0007                             ; Get (StartY + SpriteY) mod 8.  For negative, this is ok because 65536 mod 8 = 0.
            sta   tmp6

            eor   #$FFFF
            inc
            clc
            adc   _Sprites+SPRITE_Y,x                ; subtract from the SpriteY position
            sta   tmp1                               ; This position will line up with the tile that the sprite overlaps with

            tya                                      ; Get back the position of the sprite in the code field
            bpl   :ty_is_pos
            clc
            adc   #208                               ; wrap around if we are slightly off-screen
            bra   :ty_is_ok
:ty_is_pos  cmp   #208                               ; check if we went too far positive
            bcc   :ty_is_ok
            sbc   #208
:ty_is_ok
            lsr
            lsr
            lsr                                      ; This is the row in the Tile Store for top-left corner of the sprite
            sta   tmp2

; Same code, except for the X coordiante

            lda   _Sprites+SPRITE_X,x
            bpl   :x_is_pos
            cmp   #$FFFD                             ; If a tile is <= -4 do nothing, it's off-screen
            bcs   :x_is_ok
            rts
:x_is_pos   cmp   ScreenWidth                        ; Is a tile is > ScreeWidth, it's off-screen
            bcc   :x_is_ok
            rts
:x_is_ok
            clc
            adc   StartXMod164
            tay
            and   #$0003
            sta   tmp5                               ; save the mod value to test for alignment later

            eor   #$FFFF
            inc
            clc
            adc   _Sprites+SPRITE_X,x
            sta   tmp3

            tya
            bpl   :tx_is_pos
            clc
            adc   #164
            bra   :tx_is_ok
:tx_is_pos  cmp   #164
            bcc   :tx_is_ok
            sbc   #164
:tx_is_ok
            lsr
            lsr
            sta   tmp4

; At this point we have the top-left corner in the sprite plane (tmp1, tmp3) and the corresponding
; column and row in the tile store (tmp2, tmp4).  The next step is to add these tile locations to
; the dirty queue and set the sprite flag along with the VBUFF location.  We try to incrementally
; calculate new values to avoid re-doing work.

            _SpriteVBuffAddr tmp3;tmp1
            pha
            _TileStoreOffset tmp4;tmp2
            tax
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            pla
            sta   TileStore+TS_SPRITE_ADDR,x
            txa
            jsr   _PushDirtyTile

; Now see if we need to extend to other tiles.  If the mod values are not equal to zero, then
; the width of the sprite will extend into the adjacent code field tiles.

            lda   tmp5
            beq   :no_x_oflow

            lda   tmp3
            clc
            adc   #4
            sta   tmp7
            lda   tmp4
            inc
            cmp   #41
            bcc   *+5
            lda   #0
            sta   tmp8

            _SpriteVBuffAddr tmp7;tmp1
            pha
            _TileStoreOffset tmp8;tmp2
            tax
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            pla
            sta   TileStore+TS_SPRITE_ADDR,x
            txa
            jsr   _PushDirtyTile

:no_x_oflow
            lda   tmp6
            beq   :no_y_oflow

            lda   tmp1
            clc
            adc   #8
            sta   tmp1
            lda   tmp2
            inc
            cmp   #26
            bcc   *+5
            lda   #0
            sta   tmp2

            _SpriteVBuffAddr tmp3;tmp1
            pha
            _TileStoreOffset tmp4;tmp2
            tax
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            pla
            sta   TileStore+TS_SPRITE_ADDR,x
            txa
            jsr   _PushDirtyTile

            lda   tmp5
            beq   :no_y_oflow

            _SpriteVBuffAddr tmp7;tmp1
            pha
            _TileStoreOffset tmp8;tmp2
            tax
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            pla
            sta   TileStore+TS_SPRITE_ADDR,x
            txa
            jsr   _PushDirtyTile

:no_y_oflow
            ldx   tmp0                                ; Restore X register
            rts

; _GetTileAt
;
; Given a relative playfield coordinate [0, ScreenWidth), [0, ScreenHeight) return the
;  X = horizontal point [0, ScreenTileWidth]
;  Y = vertical point [0, ScreenTileHeight]
;
; Return 
;  C = 1, out of range
;  C = 0, X = column, Y = row
_GetTileAt
            cpx   ScreenWidth
            bcc   *+3
            rts

            cpy   ScreenHeight
            bcc   *+3
            rts

            tya                           ; carry is clear here
            adc   StartYMod208            ; This is the code field line that is at the top of the screen
            cmp   #208
            bcc   *+5
            sbc   #208

            lsr
            lsr
            lsr
            tay                           ; This is the code field row for this point

            clc
            txa
            adc   StartXMod164
            cmp   #164
            bcc   *+5
            sbc   #164

            lsr
            lsr
            tax                           ; Could call _CopyBG0Tile with these arguments

            clc
            rts

; _DrawSprite
;
; Draw the sprites on the _Sprite list into the Sprite Plane data and mask buffers. This is using the 
; tile data right now, but could be replaced with compiled sprite routines.
_DrawSprites
            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x
            beq   :out                          ; The first open slot is the end of the list
            cmp   #SPRITE_STATUS_DIRTY
            bne   :skip

            phx

            lda   _Sprites+VBUFF_ADDR,x          ; Load the address in the sprite plane
            ldy   _Sprites+TILE_DATA_OFFSET,x    ; Load the address in the tile data bank
            tax
            jsr   _DrawTileSprite
            plx
:skip
            inx
            inx
            bra   :loop
:out        rts

DrawTileSprite ENT
            jsr   _DrawTileSprite
            rtl

_DrawTileSprite 
            phb
            pea   #^tiledata                     ; Set the bank to the tile data
            plb

]line       equ   0
            lup   8
            lda:  tiledata+32+{]line*4},y
            andl  spritemask+{]line*256},x
            stal  spritemask+{]line*256},x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            and:  tiledata+32+{]line*4},y
            ora:  tiledata+{]line*4},y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN},x

            lda:  tiledata+32+{]line*4}+2,y
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            and:  tiledata+32+{]line*4}+2,y
            ora:  tiledata+{]line*4}+2,y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb                                  ; pop extra byte
            plb
            rts

; Erase is easy -- set an 8x8 area of the data region to all $0000 and the corresponding mask
; resgion to all $FFFF
; 
; X = address is sprite plane -- erases an 8x8 region
SPRITE_PLANE_SPAN equ 256

EraseTileSprite ENT
            jsr    _EraseTileSprite
            rtl

_EraseTileSprite
            phb                                   ; Save the bank to switch to the sprite plane

            pea    #^spritedata
            plb

            lda    #0
            sta:   {0*SPRITE_PLANE_SPAN}+0,x
            sta:   {0*SPRITE_PLANE_SPAN}+2,x
            sta:   {1*SPRITE_PLANE_SPAN}+0,x
            sta:   {1*SPRITE_PLANE_SPAN}+2,x
            sta:   {2*SPRITE_PLANE_SPAN}+0,x
            sta:   {2*SPRITE_PLANE_SPAN}+2,x
            sta:   {3*SPRITE_PLANE_SPAN}+0,x
            sta:   {3*SPRITE_PLANE_SPAN}+2,x
            sta:   {4*SPRITE_PLANE_SPAN}+0,x
            sta:   {4*SPRITE_PLANE_SPAN}+2,x
            sta:   {5*SPRITE_PLANE_SPAN}+0,x
            sta:   {5*SPRITE_PLANE_SPAN}+2,x
            sta:   {6*SPRITE_PLANE_SPAN}+0,x
            sta:   {6*SPRITE_PLANE_SPAN}+2,x
            sta:   {7*SPRITE_PLANE_SPAN}+0,x
            sta:   {7*SPRITE_PLANE_SPAN}+2,x

            pea    #^spritemask
            plb

            lda    #$FFFF
            sta:   {0*SPRITE_PLANE_SPAN}+0,x
            sta:   {0*SPRITE_PLANE_SPAN}+2,x
            sta:   {1*SPRITE_PLANE_SPAN}+0,x
            sta:   {1*SPRITE_PLANE_SPAN}+2,x
            sta:   {2*SPRITE_PLANE_SPAN}+0,x
            sta:   {2*SPRITE_PLANE_SPAN}+2,x
            sta:   {3*SPRITE_PLANE_SPAN}+0,x
            sta:   {3*SPRITE_PLANE_SPAN}+2,x
            sta:   {4*SPRITE_PLANE_SPAN}+0,x
            sta:   {4*SPRITE_PLANE_SPAN}+2,x
            sta:   {5*SPRITE_PLANE_SPAN}+0,x
            sta:   {5*SPRITE_PLANE_SPAN}+2,x
            sta:   {6*SPRITE_PLANE_SPAN}+0,x
            sta:   {6*SPRITE_PLANE_SPAN}+2,x
            sta:   {7*SPRITE_PLANE_SPAN}+0,x
            sta:   {7*SPRITE_PLANE_SPAN}+2,x

            pla
            plb
            rts

; Add a new sprite to the rendering pipeline
;
; The tile id ithe range 0 - 511.  The top 7 bits are used as sprite control bits
;
; Bit 9        : Horizontal flip.
; Bit 10       : Vertical flip.
; Bits 11 - 13 : Sprite Size Selector
;   000 - 8x8  (1x1 tile)
;   001 - 8x16 (1x2 tiles)
;   010 - 16x8 (2x1 tiles)
;   011 - 16x16 (2x2 tiles)
;   100 - 24x16 (3x2 tiles)
;   101 - 16x24 (2x3 tiles)
;   110 - 24x24 (3x3 tiles)
;   111 - 32x24 (4x3 tiles)
; Bit 14       : Low Sprite priority. Draws behind high priority tiles.
; Bit 15       : Reserved. Must be zero.
;
; When a sprite has a size > 8x8, the horizontal tiles are taken from the next tile index and
; the vertical tiles are taken from tileId + 32.  This is why tile sheets should be saved
; with a width of 256 pixels.
;
; Single sprite are limited to 24 lines high because there are 28 lines of padding above and below the
; sprite plane buffers, so a sprite that is 32 lines high could overflow the drawing area.
;
; A = tileId + flags
; X = x position
; Y = y position
AddSprite   ENT
            phb
            phk
            plb
            jsr    _AddSprite
            plb
            rtl

_AddSprite
            phx                                  ; Save the horizontal position and tile ID
            pha

            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x       ; Look for an open slot
            beq   :open
            inx
            inx
            cpx   #MAX_SPRITES*2
            bcc   :loop

            pla                    ; Early out
            pla
            sec                    ; Signal that no sprite slot was available
            rts

:open       lda   #SPRITE_STATUS_DIRTY
            sta   _Sprites+SPRITE_STATUS,x      ; Mark this sprite slot as occupied and that it needs to be drawn
            pla
            jsr   _GetTileAddr                  ; This applies the TILE_ID_MASK
            sta   _Sprites+TILE_DATA_OFFSET,x

            tya                                 ; Y coordinate
            sta   _Sprites+SPRITE_Y,x

            pla                                 ; X coordinate
            sta   _Sprites+SPRITE_X,x

            jsr   _GetSpriteVBuffAddr           ; Preserves X-register
            sta   _Sprites+VBUFF_ADDR,x

            clc                                 ; Mark that the sprite was successfully added
            txa                                 ; And return the sprite ID
            rts

; X = x coordinate
; Y = y coordinate
GetSpriteVBuffAddr ENT
            jsr   _GetSpriteVBuffAddr
            rtl

; A = x coordinate
; Y = y coordinate
_GetSpriteVBuffAddr
            pha
            tya
            clc
            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
            clc
            adc   1,s
            sta   1,s
            pla
            rts

; Move a sprite to a new location.  If the tile ID of the sprite needs to be changed, then
; a full remove/add cycle needs to happen
;
; A = sprite ID
; X = x position
; Y = y position
UpdateSprite ENT
            phb
            phk
            plb
            jsr    _UpdateSprite
            plb
            rtl

_UpdateSprite
            cmp   #MAX_SPRITES*2                ; Make sure we're in bounds
            bcc   :ok
            rts

:ok
            stx   tmp0                          ; Save the horizontal position
            and   #$FFFE                        ; Defensive
            tax                                 ; Get the sprite index

            lda   #SPRITE_STATUS_DIRTY          ; Position is changing, mark as dirty
            sta   _Sprites+SPRITE_STATUS,x      ; Mark this sprite slot as occupied and that it needs to be drawn

            lda   _Sprites+VBUFF_ADDR,x         ; Save the previous draw location for erasing
            sta   _Sprites+OLD_VBUFF_ADDR,x

            lda   tmp0                          ; Update the X coordinate
            sta   _Sprites+SPRITE_X,x

            tya                                 ; Update the Y coordinate
            sta   _Sprites+SPRITE_Y,x

            lda   tmp0
            jsr   _GetSpriteVBuffAddr
            sta   _Sprites+VBUFF_ADDR,x

            rts

; Sprite data structures.  We cache quite a few pieces of information about the sprite
; to make calculations faster, so this is hidden from the caller.
;
; Each sprite record contains the following properties:
;
; +0: Sprite status word (0 = unoccupied)
; +2: Tile data address
; +4: Screen offset address (used for data and masks)

; Number of "off-screen" lines above logical (0,0)
NUM_BUFF_LINES equ 24

MAX_SPRITES  equ 64
SPRITE_REC_SIZE equ 12

SPRITE_STATUS_EMPTY equ 0
SPRITE_STATUS_CLEAN equ 1
SPRITE_STATUS_DIRTY equ 2

SPRITE_STATUS equ 0
TILE_DATA_OFFSET equ {MAX_SPRITES*2}
VBUFF_ADDR equ {MAX_SPRITES*4}
SPRITE_X equ {MAX_SPRITES*6}
SPRITE_Y equ {MAX_SPRITES*8}
OLD_VBUFF_ADDR equ {MAX_SPRITES*10}

_Sprites     ds  SPRITE_REC_SIZE*MAX_SPRITES
