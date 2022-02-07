; Functions for sprite handling.  Mostly maintains the sprite list and provides
; utility functions to calculate sprite/tile intersections
;
; The sprite plane actually covers two banks so that more than 32K can be used as a virtual 
; screen buffer.  In order to be able to draw sprites offscreen, the virtual screen must be 
; wider and taller than the physical graphics screen.
;
; NOTE: It may be posible to remove the sprite plane banks in the future and render directly from
;       some small per-sprite graphic buffers.  This would eliminate the need to erase/draw in
;       the sprite planes and all drawing would go directly to the backing tiles.  Need to
;       figure out an efficient way to fall back when sprites are overlapping, though.
;
; All of the erasing must happen in an initial phase, because erasing a sprite could cause
; other sprites to be marked as "DAMAGED" which means they need to be drawn (similar to NEW state)

; What really has to happen in the various cases:
;
;  When a sprite is added, it needs to
;   * draw into the sprite buffer
;   * add itself to the TS_SPRITE_FLAG bitfield on the tiles it occupies
;   * mark the tiles it occupies as dirty
;
;  When a sprite is updated (Tile ID or H/V flip flags), it needs to
;   * erase itself from the sprite buffer
;   * draw into the sprite buffer
;   * mark the tiles it occupies as dirty
;   * mark other sprites it intersects as DAMAGED
;
; When a sprite is moved, it needs to
;   * erase itself from the sprite buffer at the old locations
;   * remove itself from the TS_SPRITE_FLAG bitfields on the tiles it occupied
;   * mark sprites that intersect as DAMAGED
;   * draw into the sprite buffer at the new location
;   * add itself to the TS_SPRITE_FLAG bitfield on the tiles it now occupies
;   * mark the tiles it occupied as dirty
;   * mark other sprites it intersects as DAMAGED
;
; When a sprite is removed, it needs to
;   * erase itself from the sprite buffer at the old locations
;   * remove itself from the TS_SPRITE_FLAG bitfields on the tiles it occupied
;   * mark other sprites it intersects as DAMAGED
;
; The reason that things are broken into phases is that we have to handle all of the erasing first,
; set dirty tiles, identify DAMAGED sprites, and THEN perform the drawing.  It is not possible to
; just do each sprite one at a time.
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

; Precalculate some bank values
           jsr    _CacheSpriteBanks
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
            tsb   DamagedSprites                   ; Mark which other sprites are impacted by this one
            sta   TileStore+TS_SPRITE_FLAG,x       ; a direct page location, only saves 1 or 2 cycles per and costs 10.
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_2,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            tsb   DamagedSprites
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_3,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            tsb   DamagedSprites
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_4,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            tsb   DamagedSprites
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
            tsb   DamagedSprites
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_7,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            tsb   DamagedSprites
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_8,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            tsb   DamagedSprites
            sta   TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_9,y
            bne   *+3
            rts
            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            tsb   DamagedSprites
            sta   TileStore+TS_SPRITE_FLAG,x
            jmp   _PushDirtyTileX

; This function looks at the sprite list and renders the sprite plane data into the appropriate
; tiles in the code field.  There are a few phases to this routine.  The assumption is that
; any sprite that needs to be re-drawn has been marked as DIRTY or DAMAGED.
;
; A DIRTY sprite is one that has moved, so it needs to be erased/redrawn in the sprite
; buffer AND the tiles it covers marked for refresh.  A DAMAGED sprite shared one or more
; tiles with a DIRTY sprite, so it needs to be redraw in the sprite buffer (but not erased!)
; and its tile do NOT need to be marked for refresh.
;
; In the first phase, we run through the list of dirty sprites and erase them from their
; OLD_VBUFF_ADDR.  This clears the sprite plane buffers.  We also iterate through the
; TILE_STORE_ADDR_X array and mark all of the tile store location that this sprite had occupied
; as dirty, as well as removing this sprite from the TS_SPRITE_FLAG bitfield.
;
; A final aspect is that any of the sprites indicated in the TS_SPRITE_FLAG are marked to be
; drawn in the next phase (since a portion of their content may have been erased if they overlap)
; 
; In the second phase, the sprite is re-drawn into the sprite plane buffers and the appropriate
; Tile Store locations are marked as dirty. It is important to recognize that the sprites themselves
; can be marked dirty, and the underlying tiles in the tile store are independently marked dirty.

phase1      dw    :phase1_0
            dw    :phase1_1,:phase1_2,:phase1_3,:phase1_4
            dw    :phase1_5,:phase1_6,:phase1_7,:phase1_8
            dw    :phase1_9,:phase1_10,:phase1_11,:phase1_12
            dw    :phase1_13,:phase1_14,:phase1_15,:phase1_16

:phase1_16
            ldy   activeSpriteList+30
            jsr   _DoPhase1
:phase1_15
            ldy   activeSpriteList+28
            jsr   _DoPhase1
:phase1_14
            ldy   activeSpriteList+26
            jsr   _DoPhase1
:phase1_13
            ldy   activeSpriteList+24
            jsr   _DoPhase1
:phase1_12
            ldy   activeSpriteList+22
            jsr   _DoPhase1
:phase1_11
            ldy   activeSpriteList+20
            jsr   _DoPhase1
:phase1_10
            ldy   activeSpriteList+18
            jsr   _DoPhase1
:phase1_9
            ldy   activeSpriteList+16
            jsr   _DoPhase1
:phase1_8
            ldy   activeSpriteList+14
            jsr   _DoPhase1
:phase1_7
            ldy   activeSpriteList+12
            jsr   _DoPhase1
:phase1_6
            ldy   activeSpriteList+10
            jsr   _DoPhase1
:phase1_5
            ldy   activeSpriteList+8
            jsr   _DoPhase1
:phase1_4
            ldy   activeSpriteList+6
            jsr   _DoPhase1
:phase1_3
            ldy   activeSpriteList+4
            jsr   _DoPhase1
:phase1_2
            ldy   activeSpriteList+2
            jsr   _DoPhase1
:phase1_1
            ldy   activeSpriteList
            jsr   _DoPhase1
:phase1_0
            jmp   phase1_rtn

; If this sprite has been MOVED or REMOVED, then clear its bit from the TS_SPRITE_FLAG in
; all of the tile store locations that it occupied on the previous frame and add those
; tile store locations to the dirty tile list.
_DoPhase1

            lda   _Sprites+SPRITE_STATUS,y
            ora   forceSpriteFlag
            bit   #SPRITE_STATUS_MOVED+SPRITE_STATUS_REMOVED
            beq   :no_clear
            jsr   _ClearSpriteFromTileStore
:no_clear

; If this sprite has been MOVED, UPDATED or REMOVED, then it needs to be erased from the
; sprite plane buffer

            lda   _Sprites+SPRITE_STATUS,y
            bit   #SPRITE_STATUS_MOVED+SPRITE_STATUS_UPDATED+SPRITE_STATUS_REMOVED
            beq   :no_erase
            jsr   _EraseSpriteY
:no_erase

; Check to see if sprite was REMOVED  If so, then this is where we return its Sprite ID to the
; list of open slots

            lda   _Sprites+SPRITE_STATUS,y
            bit   #SPRITE_STATUS_REMOVED
            beq   :out

            lda   #SPRITE_STATUS_EMPTY            ; Mark as empty
            sta   _Sprites+SPRITE_STATUS,y

            lda   _SpriteBits,y                   ; Clear from the sprite bitmap
            trb   SpriteMap

            ldx   _OpenListHead
            dex
            dex
            stx   _OpenListHead
            tya
            sta   _OpenList,x
            sty   _NextOpenSlot
:out
            rts

; Second phase takes care of drawing the sprites and marking the tiles that will need to be merged
; with pixel data from the sprite plane
phase2      dw    :phase2_0
            dw    :phase2_1,:phase2_2,:phase2_3,:phase2_4
            dw    :phase2_5,:phase2_6,:phase2_7,:phase2_8
            dw    :phase2_9,:phase2_10,:phase2_11,:phase2_12
            dw    :phase2_13,:phase2_14,:phase2_15,:phase2_16

:phase2_16
            ldy   activeSpriteList+30
            jsr   _DoPhase2
:phase2_15
            ldy   activeSpriteList+28
            jsr   _DoPhase2
:phase2_14
            ldy   activeSpriteList+26
            jsr   _DoPhase2
:phase2_13
            ldy   activeSpriteList+24
            jsr   _DoPhase2
:phase2_12
            ldy   activeSpriteList+22
            jsr   _DoPhase2
:phase2_11
            ldy   activeSpriteList+20
            jsr   _DoPhase2
:phase2_10
            ldy   activeSpriteList+18
            jsr   _DoPhase2
:phase2_9
            ldy   activeSpriteList+16
            jsr   _DoPhase2
:phase2_8
            ldy   activeSpriteList+14
            jsr   _DoPhase2
:phase2_7
            ldy   activeSpriteList+12
            jsr   _DoPhase2
:phase2_6
            ldy   activeSpriteList+10
            jsr   _DoPhase2
:phase2_5
            ldy   activeSpriteList+8
            jsr   _DoPhase2
:phase2_4
            ldy   activeSpriteList+6
            jsr   _DoPhase2
:phase2_3
            ldy   activeSpriteList+4
            jsr   _DoPhase2
:phase2_2
            ldy   activeSpriteList+2
            jsr   _DoPhase2
:phase2_1
            ldy   activeSpriteList
            jsr   _DoPhase2
:phase2_0
            jmp   phase2_rtn

_DoPhase2
            lda   _Sprites+SPRITE_STATUS,y
            ora   forceSpriteFlag
            and   #SPRITE_STATUS_ADDED+SPRITE_STATUS_MOVED+SPRITE_STATUS_UPDATED
            beq   :out

; This is the complicated part; we need to draw the sprite into the sprite plane, but then
; calculate the tiles that overlap with the sprite potentially and mark those as dirty _AND_
; store the appropriate sprite plane address from which those tiles need to copy.
;
; Mark the appropriate tiles as dirty and as occupied by a sprite so that the ApplyTiles
; subroutine will get the drawn data from the sprite plane into the code field where it 
; can be drawn to the screen

            jsr   _MarkDirtySprite

; Draw the sprite into the sprite plane buffer(s)

            lda   _Sprites+SPRITE_DISP2,y       ; use bits 9, 10, 11, 12, and 13 to dispatch
            jmp   (draw_sprite,x)
:out
            rts

; Optimization: Could use 8-bit registers to save 
RebuildSpriteArray
            ldx   #0                            ; Number of non-empty sprite locations
            lda   SpriteMap                     ; Get the bit field
            tay                                 ; Cache to restore

            bit   #$0001                        ; For each bit position, test and store a value
            beq   :chk1
            stz   activeSpriteList              ; Shortcut for the first one
            ldx   #2

; A super-optimization here would be to put the activeSpriteList on the direct page (32 bytes) and then
; use PEA instructions to push the slot values.  Calculate the count at the end based on the final stack
; address.  Only 160 cycles to build the list.
:chk1
]flag       equ   $0002
]slot       equ   $0002
            lup   15
            bit   #]flag
            beq   :chk2
            lda   #]slot
            sta   activeSpriteList,x
            tya
            inx
            inx
:chk2
]flag       equ   ]flag*2
]slot       equ   ]slot+2
            --^

            stx   activeSpriteCount
            rts

forceSpriteFlag ds 2
_RenderSprites

            stz   DamagedSprites                   ; clear the potential set of damaged sprites

; Check to see if any sprites have been added or removed.  If so, then we regenerate the active
; sprite list.  Since adding and removing sprites is rare, this is a worthwhile tradeoff, because
; there are several places where we want to interative over the all of the sprites, and having a list
; and not have to contantly load and test the SPRITE_STATUS just to skip unused slots can help streamline
; the code.

            lda   #DIRTY_BIT_SPRITE_ARRAY
            trb   DirtyBits                        ; clears the flag, if it was set
            beq   :no_rebuild
            jsr   RebuildSpriteArray

:no_rebuild

; First step is to look at the StartX and StartY values.  If the screen has scrolled, then it has
; the same effect as moving all of the sprites.
;
; OPTIMIZATION NOTE: Should check that the sprite actually changes position.  If the screen scrolls
;                    by +X, but the sprite moves by -X (so it's relative position is unchanged), then
;                    it does NOT need to be marked as dirty.

            stz   forceSpriteFlag
            lda   StartX
            cmp   OldStartX
            bne   :force_update

            lda   StartY
            cmp   OldStartY
            beq   :no_change

:force_update
            lda   #SPRITE_STATUS_MOVED
            sta   forceSpriteFlag
:no_change

; Dispatch to the first phase of rendering the sprites. By pre-building the list, we know exactly
; how many sprite to process and they are in a contiguous array.  So we on't have to keep track
; of an iterating variable

            ldx   activeSpriteCount
            jmp   (phase1,x)
phase1_rtn

; Dispatch to the second phase of rendering the sprites.
            ldx   activeSpriteCount
            jmp   (phase2,x)
phase2_rtn

; Speite rendering complete
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

; Y = _Sprites array offset
_EraseSpriteY
             lda   _Sprites+OLD_VBUFF_ADDR,y
             beq   :noerase
             ldx   _Sprites+SPRITE_DISP,y              ; get the dispatch index for this sprite
             jmp   (:do_erase,x)
:noerase     rts
:do_erase    dw    _EraseTileSprite8x8,_EraseTileSprite8x16
             dw    _EraseTileSprite16x8,_EraseTileSprite16x16


; X = _Sprites array offset
_DrawSpriteYA
             lda   _Sprites+SPRITE_DISP2,y       ; use bits 9, 10, 11 and 12,13 to dispatch
             jmp   (draw_sprite,x)

draw_sprite  dw    draw_8x8,draw_8x8h,draw_8x8v,draw_8x8hv
             dw    draw_8x16,draw_8x16h,draw_8x16v,draw_8x16hv
             dw    draw_16x8,draw_16x8h,draw_16x8v,draw_16x8hv
             dw    draw_16x16,draw_16x16h,draw_16x16v,draw_16x16hv

             dw    :rtn,:rtn,:rtn,:rtn           ; hidden bit is set
             dw    :rtn,:rtn,:rtn,:rtn
             dw    :rtn,:rtn,:rtn,:rtn
             dw    :rtn,:rtn,:rtn,:rtn
:rtn         rts

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
             adc   #{128*32}                      ; 32 tiles to the next vertical one, each tile is 128 bytes
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
             jmp   _DrawTile16x16

;             jsr   _DrawTile8x8
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

; Hypothetical compiled tile routine
;
; Need 1MB of memory to have 1:1 space for 512 tiles
; for 16 sprites we have 8 variants: Vert, Horz, Shift.  The shift sprites need an extra column
;
; 16x16 sprite = 4x16 words x 4 = 256, 5x16 words x 4 = 320 = 576 words * 21 bytes/word = 12K per sprite

;            pei   SpriteBanks
;            plb

;            lda   spritedata+0,x                 ; skipped if mask = $ffff
;            and   #tilemask
;            ora   #tiledata
;            sta   spritedata+0,x                 ; 12 bytes / word = 12 * 16 = 216 < 256 in the worst case

;            lda   spritedata+2,x                 ; if mask != 0 and data = 0
;            and   #tilemask
;            sta   spritedata+0,x

;            lda   #tiledata                      ; if mask = 0 and data != 0
;            sta   spritedata+0,x

;            stz   spritedata+0,x                 ; if mask = 0 and data = 0
;            ...

;            plb
;            lda   #tilemask
;            and   spritemask+0,x
;            sta   spritemask+0,x                 ; 9 * 16 = 144 i the worst case
;
;           stz   spritemask+2,x                 ; if mask is zero (often the case)

_DrawTileTemplate
; X = sprite vbuff address
; Y = tile data pointer
_DrawTile8x8
            phb
            pea   #^tiledata                     ; Set the bank to the tile data
            plb

]line       equ   0
            lup   8
            lda:  tiledata+32+{]line*4},y
            andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN},x
            
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
_DrawTile16x16
            phb
            pea   #^tiledata                     ; Set the bank to the tile data
            plb

]line       equ   0
            lup   8
            lda:  tiledata+32+{]line*4},y
            andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN},x
            
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

            lda:  tiledata+32+128+{]line*4},y
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+4,x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN}+4,x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+4,x
            and:  tiledata+32+128+{]line*4},y
            ora:  tiledata+128+{]line*4},y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN}+4,x

            lda:  tiledata+32+128+{]line*4}+2,y
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+6,x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN}+6,x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+6,x
            and:  tiledata+32+128+{]line*4}+2,y
            ora:  tiledata+128+{]line*4}+2,y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN}+6,x

]line       equ   ]line+1
            --^

TILE_ROW_STRIDE equ 32*128
SPRITE_ROW_STRIDE equ 8*SPRITE_PLANE_SPAN

]line       equ   0
            lup   8
            lda:  tiledata+TILE_ROW_STRIDE+32+{]line*4},y
            andl  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN},x
            stal  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN},x
            
            ldal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN},x
            and:  tiledata+TILE_ROW_STRIDE+32+{]line*4},y
            ora:  tiledata+TILE_ROW_STRIDE+{]line*4},y
            stal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN},x

            lda:  tiledata+TILE_ROW_STRIDE+32+{]line*4}+2,y
            andl  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+2,x
            stal  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+2,x
            
            ldal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+2,x
            and:  tiledata+TILE_ROW_STRIDE+32+{]line*4}+2,y
            ora:  tiledata+TILE_ROW_STRIDE+{]line*4}+2,y
            stal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+2,x

            lda:  tiledata+TILE_ROW_STRIDE+32+128+{]line*4},y
            andl  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+4,x
            stal  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+4,x
            
            ldal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+4,x
            and:  tiledata+TILE_ROW_STRIDE+32+128+{]line*4},y
            ora:  tiledata+TILE_ROW_STRIDE+128+{]line*4},y
            stal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+4,x

            lda:  tiledata+TILE_ROW_STRIDE+32+128+{]line*4}+2,y
            andl  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+6,x
            stal  spritemask+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+6,x
            
            ldal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+6,x
            and:  tiledata+TILE_ROW_STRIDE+128+32+{]line*4}+2,y
            ora:  tiledata+TILE_ROW_STRIDE+128+{]line*4}+2,y
            stal  spritedata+SPRITE_ROW_STRIDE+{]line*SPRITE_PLANE_SPAN}+6,x

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
            andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN},x
            
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
_CacheSpriteBanks
            lda    #>spritemask
            and    #$FF00
            ora    #^spritedata
            sta    SpriteBanks
            rts

SPRITE_PLANE_SPAN equ 256

; A = bank address
_EraseTileSprite8x8
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    8
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)
            lda    #$FFFF
]line       equ    0
            lup    8
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb
            rts

_EraseTileSprite8x16
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    16
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)
            lda    #$FFFF
]line       equ    0
            lup    16
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb
            rts

_EraseTileSprite16x8
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    8
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
            stz:   {]line*SPRITE_PLANE_SPAN}+4,x
            stz:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)
            lda    #$FFFF
]line       equ    0
            lup    8
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
            sta:   {]line*SPRITE_PLANE_SPAN}+4,x
            sta:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb
            rts

_EraseTileSprite16x16
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    16
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
            stz:   {]line*SPRITE_PLANE_SPAN}+4,x
            stz:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)

            lda    #$FFFF
]line       equ    0
            lup    16
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
            sta:   {]line*SPRITE_PLANE_SPAN}+4,x
            sta:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb
            rts

; A = x coordinate
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

; Version that uses temporary space (tmp15)
_GetSpriteVBuffAddrTmp
            sta   tmp15
            tya
            clc
            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
            clc
            adc   tmp15
            rts

; Add a new sprite to the rendering pipeline
;
; The tile id in the range 0 - 511.  The top 7 bits are used as sprite control bits
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
            phx                                  ; Save the horizontal position
            ldx   _NextOpenSlot                  ; Get the next free sprite slot index
            bpl   :open                          ; A negative number means we are full

            plx                                  ; Early out
            sec                                  ; Signal that no sprite slot was available
            rts

:open            
            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor
            jsr   _GetTileAddr                  ; This applies the TILE_ID_MASK
            sta   _Sprites+TILE_DATA_OFFSET,x

            lda   #SPRITE_STATUS_OCCUPIED+SPRITE_STATUS_ADDED
            sta   _Sprites+SPRITE_STATUS,x

            tya
            sta   _Sprites+SPRITE_Y,x           ; Y coordinate
            pla                                 ; X coordinate
            sta   _Sprites+SPRITE_X,x

            jsr   _GetSpriteVBuffAddrTmp        ; Preserves X-register
            sta   _Sprites+VBUFF_ADDR,x

            jsr   _PrecalcAllSpriteInfo         ; Cache stuff

; Mark the dirty bit to indicate that the active sprite list needs to be rebuild in the next
; render call

            lda   #DIRTY_BIT_SPRITE_ARRAY
            tsb   DirtyBits

            lda   _SpriteBits,x                 ; Get the bit flag for this sprite slot
            tsb   SpriteMap                     ; Mark it in the sprite map bit field

            txa                                 ; And return the sprite ID
            clc                                 ; Mark that the sprite was successfully added

; We can only get to this point if there was an open slot, so we know we're not at the
; end of the list yet.

            ldx   _OpenListHead
            inx
            inx
            stx   _OpenListHead
            ldy   _OpenList,x                   ; If this is the end, then the sentinel value will
            sty   _NextOpenSlot                 ; get stored into _NextOpenSlot

            rts

; Precalculate some cached values for a sprite.  These are *only* to make other part of code,
; specifically the draw/erase routines more efficient.
;
; There are variations of thi routine based on whether we are adding a new sprite, updating
; it's tile information, or changing its position.
;
; X = sprite index
_PrecalcAllSpriteInfo
            lda   _Sprites+SPRITE_ID,x 
            and   #$2E00
            xba
            sta   _Sprites+SPRITE_DISP2,x        ; use bits 9 through 13 for full dispatch

            lda   _Sprites+SPRITE_ID,x 
            and   #$1800                        ; use bits 11 and 12 to dispatch (only care about size)
            lsr
            lsr
            xba
            sta   _Sprites+SPRITE_DISP,x

; Clip the sprite's bounding box to the play field size and also set a flag if the sprite
; is fully offs-screen or not
            tay                                  ; use the index we just calculated
            lda   _Sprites+SPRITE_X,x
            bpl   :pos_x
            lda   #0
:pos_x      cmp   ScreenWidth
            bcs   :offscreen                     ; sprite is off-screen, exit early
            sta   _Sprites+SPRITE_CLIP_LEFT,x

            lda   _Sprites+SPRITE_Y,x
            bpl   :pos_y
            lda   #0
:pos_y      cmp   ScreenHeight
            bcs   :offscreen                     ; sprite is off-screen, exit early
            sta   _Sprites+SPRITE_CLIP_TOP,x

            lda   _Sprites+SPRITE_X,x
            clc
            adc   _SpriteWidthMinus1,y
            bmi   :offscreen
            cmp   ScreenWidth
            bcc   :ok_x
            lda   ScreenWidth
            dec
:ok_x       sta   _Sprites+SPRITE_CLIP_RIGHT,x

            lda   _Sprites+SPRITE_Y,x
            clc
            adc   _SpriteHeightMinus1,y
            bmi   :offscreen
            cmp   ScreenHeight
            bcc   :ok_y
            lda   ScreenHeight
            dec
:ok_y       sta   _Sprites+SPRITE_CLIP_BOTTOM,x

            stz   _Sprites+IS_OFF_SCREEN,x       ; passed all of the off-screen test
            rts

:offscreen
            lda   #1
            sta   _Sprites+IS_OFF_SCREEN,x
            rts

; Remove a sprite from the list. Just mark its STATUS as FREE and it will be
; picked up in the next AddSprite.
;
; A = Sprite ID
RemoveSprite ENT
            phb
            phk
            plb
            jsr    _RemoveSprite
            plb
            rtl

_RemoveSprite
            tax

_RemoveSpriteX
            lda   _Sprites+SPRITE_STATUS,x
            ora   #SPRITE_STATUS_REMOVED
            sta   _Sprites+SPRITE_STATUS,x
            rts

; Update the sprite's flags. We do not allow the size of a sprite to be changed.  That requires
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
            phx                                 ; swap X/A to be more efficient
            tax
            pla

_UpdateSpriteX
            cpx   #MAX_SPRITES*2                ; Make sure we're in bounds
            bcc   :ok
            rts

:ok
_UpdateSpriteXnc
            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor
            jsr   _GetTileAddr                  ; This applies the TILE_ID_MASK
            sta   _Sprites+TILE_DATA_OFFSET,x

            jsr   _PrecalcAllSpriteInfo         ; Cache stuff

            lda   _Sprites+SPRITE_STATUS,x
            ora   #SPRITE_STATUS_UPDATED
            sta   _Sprites+SPRITE_STATUS,x

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
            phx                                 ; swap X/A to be more efficient
            tax
            pla

_MoveSpriteX
            cpx   #MAX_SPRITES*2                ; Make sure we're in bounds
            bcc   :ok
            rts

:ok
_MoveSpriteXnc
            sta   _Sprites+SPRITE_X,x           ; Update the X coordinate
            pha
            tya
            sta   _Sprites+SPRITE_Y,x           ; Update the Y coordinate
            pla

            jsr   _GetSpriteVBuffAddrTmp        ; A = x-coord, Y = y-coord
            ldy   _Sprites+VBUFF_ADDR,x         ; Save the previous draw location for erasing
            sta   _Sprites+VBUFF_ADDR,x         ; Overwrite with the new location
            tya
            sta   _Sprites+OLD_VBUFF_ADDR,x

            lda   _Sprites+SPRITE_STATUS,x
            ora   #SPRITE_STATUS_MOVED
            sta   _Sprites+SPRITE_STATUS,x

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
SPRITE_REC_SIZE equ 48

; Mark each sprite as ADDED, UPDATED, MOVED, REMOVED depending on the actions applied to it
; on this frame.  Quick note, the same Sprite ID cannot be removed and added in the same frame.
; A REMOVED sprite if removed from the sprite list during the Render call, so it's ID is not
; available to the AddSprite function until the next frame.

SPRITE_STATUS_EMPTY    equ $0000         ; If the status value is zero, this sprite slot is available
SPRITE_STATUS_OCCUPIED equ $8000         ; Set the MSB to flag it as occupied
SPRITE_STATUS_ADDED    equ $0001         ; Sprite was just added (new sprite)
SPRITE_STATUS_MOVED    equ $0002         ; Sprite's position was changed
SPRITE_STATUS_UPDATED  equ $0004         ; Sprite's non-position attributes were changed
SPRITE_STATUS_REMOVED  equ $0008         ; Sprite has been removed.

; Each subroutine just sets the relevant bits, so it's possible to call AddSprite / UpdateSprite / MoveSprite
; and RemoveSprite in a single frame.  These bits have priorities, so in this case, the sprite is immediately
; removed and never displayed.

SPRITE_STATUS      equ {MAX_SPRITES*0}
TILE_DATA_OFFSET   equ {MAX_SPRITES*2}
VBUFF_ADDR         equ {MAX_SPRITES*4}
SPRITE_ID          equ {MAX_SPRITES*6}
SPRITE_X           equ {MAX_SPRITES*8}
SPRITE_Y           equ {MAX_SPRITES*10}
OLD_VBUFF_ADDR     equ {MAX_SPRITES*12}
TILE_STORE_ADDR_1  equ {MAX_SPRITES*14}
TILE_STORE_ADDR_2  equ {MAX_SPRITES*16}
TILE_STORE_ADDR_3  equ {MAX_SPRITES*18}
TILE_STORE_ADDR_4  equ {MAX_SPRITES*20}
TILE_STORE_ADDR_5  equ {MAX_SPRITES*22}
TILE_STORE_ADDR_6  equ {MAX_SPRITES*24}
TILE_STORE_ADDR_7  equ {MAX_SPRITES*26}
TILE_STORE_ADDR_8  equ {MAX_SPRITES*28}
TILE_STORE_ADDR_9  equ {MAX_SPRITES*30}
TILE_STORE_ADDR_10 equ {MAX_SPRITES*32}
SPRITE_DISP        equ {MAX_SPRITES*34}  ; pre-calculated index for jmp (abs,x) based on sprite size
SPRITE_CLIP_LEFT   equ {MAX_SPRITES*36}
SPRITE_CLIP_RIGHT  equ {MAX_SPRITES*38}
SPRITE_CLIP_TOP    equ {MAX_SPRITES*40}
SPRITE_CLIP_BOTTOM equ {MAX_SPRITES*42}
IS_OFF_SCREEN      equ {MAX_SPRITES*44}
SPRITE_DISP2       equ {MAX_SPRITES*46}

; Maintain the index of the next open sprite slot.  This allows us to have amortized
; constant sprite add performance.  A negative value means no slots are available.
_NextOpenSlot  dw  0
_OpenListHead  dw  0
_OpenList      dw  0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,$FFFF  ; List with sentinel at the end

_Sprites     ds  SPRITE_REC_SIZE*MAX_SPRITES

; On-demand cached list of active sprite slots
activeSpriteCount ds 2
activeSpriteList  ds 2*MAX_SPRITES

