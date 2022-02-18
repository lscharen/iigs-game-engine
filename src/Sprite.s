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
; Initialize the sprite data and mask banks (all data = $0000, all masks = $FFFF)
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

; Initialize the VBUFF address offsets in the data and mask banks for each sprite
;
; The internal grid 13 tiles wide where each sprite has a 2x2 interior square with a
; tile-size buffer all around. We pre-render each sprite with all four vert/horz flips
VBUFF_STRIDE_BYTES   equ 13*4
VBUFF_TILE_ROW_BYTES equ 8*VBUFF_STRIDE_BYTES
VBUFF_SPRITE_STEP    equ VBUFF_TILE_ROW_BYTES*3
VBUFF_SPRITE_START   equ {8*VBUFF_TILE_ROW_BYTES}+4

           ldx    #{MAX_SPRITES-1}*2
           lda    #VBUFF_SPRITE_START
           clc
:loop4     sta    _Sprites+VBUFF_ADDR,x
           adc    #VBUFF_SPRITE_STEP
           dex
           dex
           bpl    :loop4

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
            ldal  TileStore+TS_SPRITE_FLAG,x       ; Clear the bit in the bit field.  This seems wasteful, but
            and   _SpriteBitsNot,y                 ; there is no indexed form of TSB/TRB and caching the value in
            stal  TileStore+TS_SPRITE_FLAG,x       ; a direct page location, only saves 1 or 2 cycles per and costs 10.
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_2,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_3,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_4,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_5,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_6,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_7,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_8,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
            jsr   _PushDirtyTileX

            ldx   _Sprites+TILE_STORE_ADDR_9,y
            bne   *+3
            rts
            ldal  TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            stal  TileStore+TS_SPRITE_FLAG,x
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

activeSpriteList equ blttmp

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

; Mark the appropriate tiles as dirty and as occupied by a sprite so that the ApplyTiles
; subroutine will combine the sprite data with the tile data into the code field where it 
; can be drawn to the screen.  This routine is also responsible for setting the specific
; VBUFF address for each sprite's tile sheet position

            jmp   _MarkDirtySprite
:out
            rts

; Use the blttmp space to build the active sprite list.  Since the sprite tiles are not drawn until later,
; it's OK to use that scratch space here.  And it's just the right size, 32 bytes
RebuildSpriteArray
            lda   SpriteMap                     ; Get the bit field

; Unrolled loop to get the sprite index values that coorespond to the set bit positions

            pea   $FFFF                         ; end-of-list marker
]step       equ   0
            lup   4
            ror
            bcc   :skip_1
            pea   ]step
:skip_1     ror
            bcc   :skip_2
            pea   ]step+2
:skip_2     ror
            bcc   :skip_3
            pea   ]step+4
:skip_3     ror
            bcc   :skip_4
            pea   ]step+6
:skip_4     beq   :end_1
]step       equ   ]step+8
            --^
:end_1

; Now pop the values off of the stack until reaching the sentinel value.  This could be unrolled, but
; it is only done once per frame.

            ldx   #0
:loop
            pla
            bmi   :out
            sta   blttmp,x
            inx
            inx
            bra   :loop
:out
            stx   ActiveSpriteCount
            rts

forceSpriteFlag ds 2
_RenderSprites

; Check to see if any sprites have been added or removed.  If so, then we regenerate the active
; sprite list.  Since adding and removing sprites is rare, this is a worthwhile tradeoff, because
; there are several places where we want to iterate over the all of the sprites, and having a list
; and not have to constantly load and test the SPRITE_STATUS just to skip unused slots can help
; streamline the code.

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

            ldx   ActiveSpriteCount
            jmp   (phase1,x)
phase1_rtn

; Dispatch to the second phase of rendering the sprites.
            ldx   ActiveSpriteCount
            jmp   (phase2,x)
phase2_rtn

; Sprite rendering complete
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

; Small initialization routine to cache the banks for the sprite data and mask
_CacheSpriteBanks
            lda    #>spritemask
            and    #$FF00
            ora    #^spritedata
            sta    SpriteBanks
            rts

; This is 13 blocks wide
SPRITE_PLANE_SPAN equ 52        ; 256

; A = x coordinate
; Y = y coordinate
;GetSpriteVBuffAddr ENT
;            jsr   _GetSpriteVBuffAddr
;            rtl

; A = x coordinate
; Y = y coordinate
;_GetSpriteVBuffAddr
;            pha
;            tya
;            clc
;            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
;            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
;            clc
;            adc   1,s
;            sta   1,s
;            pla
;            rts

; Version that uses temporary space (tmp15)
;_GetSpriteVBuffAddrTmp
;            sta   tmp15
;            tya
;            clc
;            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
;            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
;            clc
;            adc   tmp15
;            rts

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

;            jsr   _GetSpriteVBuffAddrTmp      
;            sta   _Sprites+VBUFF_ADDR,x        ; This is now pre-calculated since each sprite slot gets a fixed location

            jsr   _PrecalcAllSpriteInfo         ; Cache sprite property values (simple stuff)
            jsr   _DrawSpriteSheet              ; Render the sprite into internal space

; Mark the dirty bit to indicate that the active sprite list needs to be rebuilt in the next
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
; There are variations of this routine based on whether we are adding a new sprite, updating
; it's tile information, or changing its position.
;
; X = sprite index
_PrecalcAllSpriteInfo
            lda   _Sprites+SPRITE_ID,x 
            and   #$2E00
            xba
            sta   _Sprites+SPRITE_DISP,x        ; use bits 9 through 13 for full dispatch

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

;            pla
;            jsr   _GetSpriteVBuffAddrTmp        ; A = x-coord, Y = y-coord
;            ldy   _Sprites+VBUFF_ADDR,x         ; Save the previous draw location for erasing
;            sta   _Sprites+VBUFF_ADDR,x         ; Overwrite with the new location
;            tya
;            sta   _Sprites+OLD_VBUFF_ADDR,x

            jsr   _PrecalcAllSpriteInfo          ; Can be specialized to only update (x,y) values

            lda   _Sprites+SPRITE_STATUS,x
            ora   #SPRITE_STATUS_MOVED
            sta   _Sprites+SPRITE_STATUS,x

            rts

; Sprite data structures.  We cache quite a few pieces of information about the sprite
; to make calculations faster, so this is hidden from the caller.
;
;
; Number of "off-screen" lines above logical (0,0)
; NUM_BUFF_LINES  equ 24

MAX_SPRITES     equ 16
SPRITE_REC_SIZE equ 46

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

SPRITE_STATUS      equ {MAX_SPRITES*0}
TILE_DATA_OFFSET   equ {MAX_SPRITES*2}
VBUFF_ADDR         equ {MAX_SPRITES*4}  ; Fixed address in sprite/mask banks
SPRITE_ID          equ {MAX_SPRITES*6}
SPRITE_X           equ {MAX_SPRITES*8}
SPRITE_Y           equ {MAX_SPRITES*10}
; OLD_VBUFF_ADDR     equ {MAX_SPRITES*12}
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

; Maintain the index of the next open sprite slot.  This allows us to have amortized
; constant sprite add performance.  A negative value means no slots are available.
_NextOpenSlot  dw  0
_OpenListHead  dw  0
_OpenList      dw  0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,$FFFF  ; List with sentinel at the end

_Sprites       ds  SPRITE_REC_SIZE*MAX_SPRITES
