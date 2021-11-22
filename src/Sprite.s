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

; Clear values in the sprite array

           ldx    #{MAX_SPRITES-1}*2
:loop3     stz    _Sprites+TILE_STORE_ADDR_1,x
           dex
           dex
           bpl    :loop3

           rts

; Run through the list of tile store offsets that this sprite was last drawn into and mark
; those tiles as dirty.  The largest number of tiles that a sprite could possibly cover is 20
; (an unaligned 4x3 sprite), covering a 5x4 area of play field tiles.
;
; Y register = sprite record index
_ClearSpriteFromTileStore
            ldx   _Sprites+TILE_STORE_ADDR_1,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x       ; Clear the bit in the bit field.  This seems wasteful, but
            and   _SpriteBitsNot,y                 ; there is no indexed form of TSB/TRB and caching the value in
            sta   TileStore+TS_SPRITE_FLAG,x       ; a direct page location, only saves 1 or 2 cycles per and costs 10.
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_2,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_3,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_4,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_5,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_6,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_7,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_8,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_9,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x
            jmp   _PushDirtyTileX

; This function looks at the sprite list and renders the sprite plane data into the appropriate
; tiles in the code field.  There are a few phases to this routine.  The assumption is that
; any sprite that needs to be re-drawn has been marked as dirty.
;
; In the first phase, we run through the list of dirty sprites and erase them from their
; OLD_VBUFF_ADDR.  This clears the sprite plane buffers.  We also interate through the
; TILE_STORE_ADDR_X array and mark all of the tile store location that this sprite had occupied
; as dirty, as well as removing this sprite from the TS_SPRITE_FLAG bitfield.
;
; A final aspect is that any of the sprites idicated in the TS_SPRITE_FLAG are marked to be
; drawn in the next phase (since a portion of their content may have been erased if they overlap)
; 
; In the second phase, the sprite is re-drawn into the sprite plane buffers and the appropriate
; Tile Store locations are marked as dirty 
;
; 
forceSpriteFlag ds 2
_RenderSprites

; First step is to look at the StartX and StartY values.  If the offsets have changed from the
; last time that the frame was redered, then we need to mark all of the sprites as dirty so that
; the tiles on which they were located at the previous frame will be refreshed

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

; First phase, erase all dirty sprites
            ldy   #0
:loop1      lda   _Sprites+SPRITE_STATUS,y       ; If the status is zero, that's the sentinel value
            beq   :phase2
            bit   #SPRITE_STATUS_DIRTY
            beq   :next1

; Erase the sprite from the Sprite Plane buffers
            jsr   _EraseSpriteY

; Mark all of the tile store indices that thie sprite was drawn at as dirty and clear
; it's bit flag in the TS_SPRITE_FLAG
            jsr   _ClearSpriteFromTileStore

:next1      iny
            iny
            bra   :loop1
:phase2

; Second step is to scan the list of sprites.  A sprite is either clean or dirty.  If it's dirty,
; then its position had changed, so we need to add tiles to the dirty queue to make sure the
; playfield gets update.  If it's clean, we can skip everything.

            ldy   #0
:loop       lda   _Sprites+SPRITE_STATUS,y       ; If the status is zero, that's the sentinel value
            beq   :out
            ora   forceSpriteFlag
            and   #SPRITE_STATUS_DIRTY           ; If the dirty flag is set, do the things....
            bne   :render
:next       iny
            iny
            bra   :loop
:out        rts

; This is the complicated part; we need to draw the sprite into the sprite plane, but then
; calculate the tiles that overlap with the sprite potentially and mark those as dirty _AND_
; store the appropriate sprite plane address from which those tiles need to copy.
:render
            sty   tmp0                                ; stash the Y register

; Draw the sprite into the sprint plane buffer(s)

            lda   _Sprites+SPRITE_ID,y
            bit   #SPRITE_HIDE
            bne   :next

            jsr   _DrawSpriteYA                       ; Use variant that takes the Y-register arg

; Mark the appropriate tiles as dirty and as occupied by a sprite so that the ApplyTiles
; subroutine will get the drawn data from the sprite plane into the code field where it 
; can be drawn to the screen

            ldx   tmp0                                ; Restore the index into the sprite array
            jsr   _MarkDirtySprite                    ; Mark the tiles that this sprite overlaps as dirty

            ldy   tmp0                                ; Restore the index again
            bra   :next

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

; _DrawSprites
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
            jsr   _DrawSprite
            plx
:skip
            inx
            inx
            bra   :loop
:out        rts

; X = _Sprites array offset
_EraseSprite
             txy
_EraseSpriteY
             lda   _Sprites+OLD_VBUFF_ADDR,y
             beq   :noerase
             lda   _Sprites+SPRITE_ID,y
             and   #$1800                        ; use bits 11 and 12 to dispatch (oly care about size)
             lsr
             lsr
             xba
             tax
             jmp   (:erase_sprite,x)
:noerase     rts
:erase_sprite dw   erase_8x8,erase_8x16,erase_16x8,erase_16x16

erase_8x8
            ldx   _Sprites+OLD_VBUFF_ADDR,y
            jmp   _EraseTileSprite                    ; erase from the old position

erase_8x16
            clc
            ldx   _Sprites+OLD_VBUFF_ADDR,y
            jsr   _EraseTileSprite

            txa
            adc   #{8*SPRITE_PLANE_SPAN}
            tax
            jmp   _EraseTileSprite

erase_16x8
            clc
            ldx   _Sprites+OLD_VBUFF_ADDR,y
            jsr   _EraseTileSprite

            txa
            adc   #4
            tax
            jmp   _EraseTileSprite

erase_16x16
            clc
            ldx   _Sprites+OLD_VBUFF_ADDR,y
            jsr   _EraseTileSprite

            txa
            adc   #4
            tax
            jsr   _EraseTileSprite

            txa
            adc   #{8*SPRITE_PLANE_SPAN}-4
            tax
            jsr   _EraseTileSprite

            txa
            adc   #4
            tax
            jmp   _EraseTileSprite

; X = _Sprites array offset
_DrawSprite
             txy
_DrawSpriteY
             lda   _Sprites+SPRITE_ID,y
_DrawSpriteYA
             and   #$1E00                        ; use bits 9, 10, 11 and 12 to dispatch
             xba
             tax
             jmp   (:draw_sprite,x)
:draw_sprite dw    draw_8x8,draw_8x8h,draw_8x8v,draw_8x8hv
             dw    draw_8x16,draw_8x16h,draw_8x16v,draw_8x16hv
             dw    draw_16x8,draw_16x8h,draw_16x8v,draw_16x8hv
             dw    draw_16x16,draw_16x16h,draw_16x16v,draw_16x16hv

draw_8x8
draw_8x8h
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             tay
             jmp   _DrawTile8x8

draw_8x8v
draw_8x8hv
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             tay
             jmp   _DrawTile8x8V

draw_8x16
draw_8x16h
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             tay
             jsr   _DrawTile8x8
             clc
             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             tya
             adc   #{128*32}                      ; 32 tiles to the next verical one, each tile is 128 bytes
             tay
             jmp   _DrawTile8x8

draw_8x16v
draw_8x16hv
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             tay
             jsr   _DrawTile8x8V
             clc
             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             tya
             adc   #{128*32}
             tay
             jmp   _DrawTile8x8V

draw_16x8
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             tay
             jsr   _DrawTile8x8
             clc
             txa
             adc   #4
             tax
             tya
             adc   #128                           ; Next tile is 128 bytes away
             tay
             jmp   _DrawTile8x8

draw_16x8h
             clc
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             pha
             adc   #128
             tay
             jsr   _DrawTile8x8
             txa
             adc   #4
             tax
             ply
             jmp   _DrawTile8x8

draw_16x8v
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             tay
             jsr   _DrawTile8x8V
             clc
             txa
             adc   #4
             tax
             tya
             adc   #128
             tay
             jmp   _DrawTile8x8V

draw_16x8hv
             clc
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             pha
             adc   #128
             tay
             jsr   _DrawTile8x8V
             txa
             adc   #4
             tax
             ply
             jmp   _DrawTile8x8V

draw_16x16
             clc
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             tay
             jsr   _DrawTile8x8
             txa
             adc   #4
             tax
             tya
             adc   #128
             tay
             jsr   _DrawTile8x8
             txa
             adc   #{8*SPRITE_PLANE_SPAN}-4
             tax
             tya
             adc    #{128*{32-1}}
             tay
             jsr   _DrawTile8x8
             txa
             adc   #4
             tax
             tya
             adc   #128
             tay
             jmp   _DrawTile8x8

draw_16x16h
             clc
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             pha
             adc   #128
             tay
             jsr   _DrawTile8x8

             txa
             adc   #4
             tax
             ply
             jsr   _DrawTile8x8

             txa
             adc   #{8*SPRITE_PLANE_SPAN}-4
             tax
             tya
             adc    #{128*32}
             pha
             adc    #128
             tay
             jsr   _DrawTile8x8

             txa
             adc   #4
             tax
             ply
             jmp   _DrawTile8x8

draw_16x16v
             clc
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             pha                                        ; store some copies
             phx
             pha
             adc   #{128*32}
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             ply
             jsr   _DrawTile8x8V

             pla
             adc   #4
             tax
             lda   1,s
             adc   #{128*{32+1}}
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             pla
             adc   #128
             tay
             jmp   _DrawTile8x8V

; TODO
draw_16x16hv
             clc
             ldx   _Sprites+VBUFF_ADDR,y
             lda   _Sprites+TILE_DATA_OFFSET,y
             pha
             adc   #128+{128*32}                        ; Bottom-right source to top-left 
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #4
             tax
             lda   1,s
             adc   #{128*32}
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #{8*SPRITE_PLANE_SPAN}-4
             tax
             lda    1,s
             adc    #128
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #4
             tax
             ply
             jmp   _DrawTile8x8V

DrawTileSprite ENT
            jsr   _DrawTile8x8
            rtl

; X = sprite vbuff address
; Y = tile data pointer
_DrawTile8x8
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

; X = sprite vbuff address
; Y = tile data pointer
;
; Draws the tile vertically flipped
_DrawTile8x8V
            phb
            pea   #^tiledata                     ; Set the bank to the tile data
            plb

]line       equ   0
            lup   8
            lda:  tiledata+32+{{7-]line}*4},y
            andl  spritemask+{]line*256},x
            stal  spritemask+{]line*256},x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            and:  tiledata+32+{{7-]line}*4},y
            ora:  tiledata+{{7-]line}*4},y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN},x

            lda:  tiledata+32+{{7-]line}*4}+2,y
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            and:  tiledata+32+{{7-]line}*4}+2,y
            ora:  tiledata+{{7-]line}*4}+2,y
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
; Bits 11 - 12 : Sprite Size Selector
;   00 - 8x8  (1x1 tile)
;   01 - 8x16 (1x2 tiles)
;   10 - 16x8 (2x1 tiles)
;   11 - 16x16 (2x2 tiles)
; Bit 13       : Reserved. Must be zero.
; Bit 14       : Reserved. Must be zero.
; Bit 15       : Low Sprite priority. Draws behind high priority tiles.
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
            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor
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

; Update the sprite's flags. We do not allow the size fo a sprite to be changed.  That required
; the sprite to be removed and re-added.
;
; A = Sprite ID
; X = Sprite Tile ID and Flags
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

            lda   #SPRITE_STATUS_DIRTY          ; Content is changing, mark as dirty
            sta   _Sprites+SPRITE_STATUS,x

            lda   tmp0                          ; Update the Tile ID
            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor
            jsr   _GetTileAddr                  ; This applies the TILE_ID_MASK
            sta   _Sprites+TILE_DATA_OFFSET,x
            rts

; Move a sprite to a new location.  If the tile ID of the sprite needs to be changed, then
; a full remove/add cycle needs to happen
;
; A = sprite ID
; X = x position
; Y = y position
MoveSprite  ENT
            phb
            phk
            plb
            jsr    _MoveSprite
            plb
            rtl

_MoveSprite
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

MAX_SPRITES  equ 16
SPRITE_REC_SIZE equ 34

SPRITE_STATUS_EMPTY equ 0
SPRITE_STATUS_CLEAN equ 1
SPRITE_STATUS_DIRTY equ 2

SPRITE_STATUS equ {MAX_SPRITES*0}
TILE_DATA_OFFSET equ {MAX_SPRITES*2}
VBUFF_ADDR equ {MAX_SPRITES*4}
SPRITE_ID equ {MAX_SPRITES*6}
SPRITE_X equ {MAX_SPRITES*8}
SPRITE_Y equ {MAX_SPRITES*10}
OLD_VBUFF_ADDR equ {MAX_SPRITES*12}
TILE_STORE_ADDR_1 equ {MAX_SPRITES*14}
TILE_STORE_ADDR_2 equ {MAX_SPRITES*16}
TILE_STORE_ADDR_3 equ {MAX_SPRITES*18}
TILE_STORE_ADDR_4 equ {MAX_SPRITES*20}
TILE_STORE_ADDR_5 equ {MAX_SPRITES*22}
TILE_STORE_ADDR_6 equ {MAX_SPRITES*24}
TILE_STORE_ADDR_7 equ {MAX_SPRITES*26}
TILE_STORE_ADDR_8 equ {MAX_SPRITES*28}
TILE_STORE_ADDR_9 equ {MAX_SPRITES*30}
TILE_STORE_ADDR_10 equ {MAX_SPRITES*32}

_Sprites     ds  SPRITE_REC_SIZE*MAX_SPRITES
