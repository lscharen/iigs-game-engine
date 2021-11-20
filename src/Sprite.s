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


; This function looks at the sprite list and renders the sprite plane data into the appropriate
; tiles in the code field
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

; Second step is to scan the list of sprites.  A sprite is either clean or dirty.  If it's dirty,
; then its position had changed, so we need to add tiles to the dirty queue to make sure the
; playfield gets update.  If it's clean, we can skip everything.

            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x       ; If the status is zero, that's the sentinel value
            beq   :out
            ora   forceSpriteFlag
            ora   #SPRITE_STATUS_DIRTY           ; If the dirty flag is set, do the things....
            bne   :render
:next       inx
            inx
            bra   :loop
:out        rts

; This is the complicated part; we need to draw the sprite into the sprite plane, but then
; calculate the tiles that overlap with the sprite potentially and mark those as dirty _AND_
; store the appropriate sprite plane address from which those tiles need to copy.
:render
            stx   tmp0                                ; stash the X register
            txy                                       ; switch to the Y register

; Run through the list of tile store offsets that this sprite was last drawn into and mark
; those tiles as dirty.  The largest number of tiles that a sprite could possibly cover is 20
; (an unaligned 4x3 sprite), covering a 5x4 area of play field tiles.
;
; For now, we limit ourselves to 4 tiles until things are working....
;
; There is only one sprite, so clear the TS_SPRITE_FLAG field, too

            ldx   _Sprites+TILE_STORE_ADDR_1,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_2,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_3,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_4,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_5,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_6,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_7,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_8,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
            ldx   _Sprites+TILE_STORE_ADDR_9,y
            beq   :erase_done
            stz   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX
:erase_done

; Really, we should only be erasing and redrawing a sprite if its local coordinates change.  Look into this
; as a future optimization.  Ideally, all of the sprites will be rendered into the sprite plane in a separate
; pass from this function, which is primarily concerned with flagging dirty tiles in the Tile Store.

            jsr   _EraseSpriteY

; Draw the sprite into the sprint plane buffer(s)

            jsr   _DrawSpriteY                        ; Use variant that takes the Y-register arg

; Mark the appropriate tiles as dirty and as occupied by a sprite so that the ApplyTiles
; subroutine will get the drawn data from the sprite plane into the code field where it 
; can be drawn to the screen

            ldx   tmp0                                ; Restore the index into the sprite array
            jsr   _MarkDirtySprite                    ; Mark the tiles that this sprite overlaps as dirty

            ldx   tmp0                                ; Restore the index again
            brl   :next

; Marks an 8x8 square as dirty.  The work here is mapping from local screen coordinates to the 
; tile store indices.  The first step is to adjust the sprite coordinates based on the current
; code field offsets and then cache variations of this value needed in the rest of the subroutine
;
; The SpriteX is always the MAXIMUM value of the corner coordinates.  We subtract (SpriteX + StartX) mod 4
; to find the coordinate in the sprite plane that matches up with the tile in the play field and 
; then use that to calculate the VBUFF address from which to copy sprite data.
;
; StartX   SpriteX   z = * mod 4   (SpriteX - z)
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
;
; On input, X register = Sprite Array Index
_MarkDirtySprite8x8

            stz   _Sprites+TILE_STORE_ADDR_1,x       ; Clear the Dirty Tile list in case of an early exit

; First, bounds check the X and Y coodinates of the sprite and, if they pass, pre-calculate some
; values that we can use later.

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
; field.  Figure out what tile(s) they are and what part of the sprite plane data/mask need to be
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

; tmp5 = X mod 4
; tmp6 = Y mod 8
;
; Look at these values to determine, up front, exactly which bounding tiles will need to be put into the
; dirty tile queue.  
;
; tmp5   tmp6
; ------------+
;    0      0 | top-left only (1 tile)
;   !0      0 | top row (2 tiles)
;    0     !0 | left column (2 tiles)
;   !0     !0 | square (4 tiles)

            txy

            ldx  #0
            lda  tmp6
            beq  :hop_y
            ldx  #4
:hop_y
            lda  tmp5
            beq  :hop_x
            inx
            inx
:hop_x      
            lda  #0                            ; shared value
            jmp  (:mark,x)                     ; pick the appropriate marking routine
:mark       dw   :mark1x1,:mark1x2,:mark2x1,:mark2x2

; At this point we have the top-left corner in the sprite plane (tmp1, tmp3) and the corresponding
; column and row in the tile store (tmp2, tmp4).  The next step is to add these tile locations to
; the dirty queue and set the sprite flag along with the VBUFF location.  We try to incrementally
; calculate new values to avoid re-doing work.
;
; The sprite plane address calculation is x + 256 * y and there are no wrap-around considerations,
; so we can take the calculated VBUFF address and just add a single, pre-calculate constant for each
; tile
;
; The tile store addresses are more involved, because we could wrap around in the X or Y direction
; at any step, so they need to be tracked separately.  However, they can be decomposed so that we
; can update each independently.  If the values are pre-multiplied by 2, then calculating the
; Tile Store for X and Y is just
;
;     txa
;     adc  TileStoreYTable,y
;
; One other consideration is that the visibility tests for the sprite coverage vs the tile store
; coverage are different.  We get into the main loop is *any* part of the sprite is potentially
; visible in the play field.  However, for multi-tile sprites, some of the sub-tiles that 
; comprise the sprite could be totally off-screen.
;
; To handle this, we pre-filter the tile list while calculating the sprite plane and tile store
; addresses to remove any tiles that are off-screen.  This provides a natural break in the subroutine
; where the actually updating values in the TileStore and _Sprites tables and marking tiles as
; dirty involves walking a single list.
;
; A final note.  Although this seems like a lot of code, rendering each tile requires, at a minimum,
; 16 LDA/STA pairs plus the overhead of the dirty tile list (~50 cycles), and possible much more.
; It's safe to assume that each tile no drawn saves around 500 cycles per frame.
;
; The worst-case for sprites is 16 sprites, all the maximum size of 4x3 and all unaligned, so
; 16 * 5 * 4 = 320 tiles total.  There are, at most, 1066 tiles visible on a full-screen.  This
; would effectively halve the framerate.
:mark1x1
            sta   _Sprites+TILE_STORE_ADDR_2,y     ; Terminate the list after one item

            jsr   :top_left
            sta   _Sprites+TILE_STORE_ADDR_1,y     ; Returns the tile store offset
            jmp   _PushDirtyTile

:mark1x2
            sta   _Sprites+TILE_STORE_ADDR_3,y     ; Terminate the list after two items
;            jsr   :calc_col1                       ; Calculate the values for the next column

            jsr   :top_left
            sta   _Sprites+TILE_STORE_ADDR_1,y 
            jsr   _PushDirtyTile

            jsr   :top_right
            sta   _Sprites+TILE_STORE_ADDR_2,y 
            jmp   _PushDirtyTile

:mark2x1
            sta   _Sprites+TILE_STORE_ADDR_3,y     ; Terminate the list after two items
;            jsr   :calc_row1                       ; Calculate the values for the next row

            jsr   :top_left
            sta   _Sprites+TILE_STORE_ADDR_1,y
            jsr   _PushDirtyTile

            jsr   :bottom_left
            sta   _Sprites+TILE_STORE_ADDR_2,y
            jmp   _PushDirtyTile

:mark2x2
            sta   _Sprites+TILE_STORE_ADDR_3,y     ; Terminate the list after four items

;            jsr   :calc_col1                       ; Calculate the next row and column values
;            jsr   :calc_row1

            jsr   :top_left
            sta   _Sprites+TILE_STORE_ADDR_1,y
            jsr   _PushDirtyTile

            jsr   :bottom_left
            sta   _Sprites+TILE_STORE_ADDR_2,y
            jsr   _PushDirtyTile

            jsr   :top_right
            sta   _Sprites+TILE_STORE_ADDR_3,y
            jsr   _PushDirtyTile

            jsr   :bottom_right
            sta   _Sprites+TILE_STORE_ADDR_4,y
            jmp   _PushDirtyTile

:top_left
            _TileStoreOffsetX tmp4;tmp2            ; Overwrites X
            tax
            _SpriteVBuffAddr tmp3;tmp1             ; Does not affect X, Y
            sta   TileStore+TS_SPRITE_ADDR,x
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            txa
            rts

:top_right
            _TileStoreOffsetX tmp8;tmp2
            tax
            _SpriteVBuffAddr tmp7;tmp1
            sta   TileStore+TS_SPRITE_ADDR,x
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            txa
            rts

:bottom_left
            _TileStoreOffsetX tmp4;tmp10
            tax
            _SpriteVBuffAddr tmp3;tmp9
            sta   TileStore+TS_SPRITE_ADDR,x
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            txa
            rts

:bottom_right
            _TileStoreOffsetX tmp8;tmp10
            tax
            _SpriteVBuffAddr tmp7;tmp9
            sta   TileStore+TS_SPRITE_ADDR,x
            lda   #TILE_SPRITE_BIT
            sta   TileStore+TS_SPRITE_FLAG,x
            txa
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
