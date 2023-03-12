; Functions for sprite handling.  Mostly maintains the sprite list and provides
; utility functions to calculate sprite/tile intersections
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

; Initialize the VBuff offset values for the different cases. These are locations in
; the TileStoreLookup table, which has different dimensions than the underlying TileStore
; array

LAST_ROW          equ {2*TS_LOOKUP_SPAN*{TILE_STORE_HEIGHT-1}}
NEXT_TO_LAST_ROW  equ {2*TS_LOOKUP_SPAN*{TILE_STORE_HEIGHT-2}}
LAST_COL          equ {{TILE_STORE_WIDTH-1}*2}
NEXT_TO_LAST_COL  equ {{TILE_STORE_WIDTH-2}*2}

           lda    #0                          ; Normal row, Normal column
           ldx    #0
           jsr    _SetVBuffValues

           lda    #8
           ldx    #LAST_COL                   ; Normal row, Last column
           jsr    _SetVBuffValues

           lda    #16
           ldx    #NEXT_TO_LAST_COL           ; Normal row, Next-to-Last column
           jsr    _SetVBuffValues

           lda    #24                         ; Last row, normal column
           ldx    #LAST_ROW
           jsr    _SetVBuffValues

           lda    #32
           ldx    #LAST_ROW+LAST_COL          ; Last row, Last column
           jsr    _SetVBuffValues

           lda    #40
           ldx    #LAST_ROW+NEXT_TO_LAST_COL  ; Last row, Next-to-Last column
           jsr    _SetVBuffValues

           lda    #48                         ; Next-to-Last row, normal column
           ldx    #NEXT_TO_LAST_ROW
           jsr    _SetVBuffValues

           lda    #56
           ldx    #NEXT_TO_LAST_ROW+LAST_COL          ; Next-to-Last row, Last column
           jsr    _SetVBuffValues

           lda    #64
           ldx    #NEXT_TO_LAST_ROW+NEXT_TO_LAST_COL  ; Next-to-Last row, Next-to-Last column
           jsr    _SetVBuffValues

; Initialize the Page 2 pointers
            ldx    #$100
            lda    #^spritemask
            sta    sprite_ptr0+2,x
            sta    sprite_ptr1+2,x
            sta    sprite_ptr2+2,x
            sta    sprite_ptr3+2,x

; Precalculate some bank values
            jsr    _CacheSpriteBanks
            rts

; Call with X-register set to TileStore tile and A set to the VBuff slot offset
_SetVBuffValues
COL_BYTES  equ 4                                   ; VBUFF_TILE_COL_BYTES
ROW_BYTES  equ 384                                 ; VBUFF_TILE_ROW_BYTES

           clc
           adc   #VBuffArray
           sec
           sbc   TileStoreLookup,x
           sta   tmp0

           ldy   TileStoreLookup,x
           lda   #{0*COL_BYTES}+{0*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+2,x
           lda   #{1*COL_BYTES}+{0*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+4,x
           lda   #{2*COL_BYTES}+{0*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+{1*{TS_LOOKUP_SPAN*2}},x
           lda   #{0*COL_BYTES}+{1*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+{1*{TS_LOOKUP_SPAN*2}}+2,x
           lda   #{1*COL_BYTES}+{1*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+{1*{TS_LOOKUP_SPAN*2}}+4,x
           lda   #{2*COL_BYTES}+{1*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+{2*{TS_LOOKUP_SPAN*2}},x
           lda   #{0*COL_BYTES}+{2*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+{2*{TS_LOOKUP_SPAN*2}}+2,x
           lda   #{1*COL_BYTES}+{2*ROW_BYTES}
           sta   (tmp0),y

           ldy   TileStoreLookup+{2*{TS_LOOKUP_SPAN*2}}+4,x
           lda   #{2*COL_BYTES}+{2*ROW_BYTES}
           sta   (tmp0),y
            rts
; _RenderSprites
;
; The function is responsible for updating all of the rendering information based on any changes
; that occured to the sprites on this frame. Sprite handling is one of the most expensive and 
; complicated pieces of the rendering pipeline, so these functions are aggressively simplified and
; optimized.
;
; The sprite rendering pipeline is:
;
; 0. Check if any new sprites have been added by testing the DIRTY_BIT_SPRITE_ARRAY. If so, then
;    the activeSpriteList (a 32-byte array on the direct page) is rebuilt from the SpriteBits bitmap
;    word.
;
; Next, the activeSpriteList is scanned for changes to specific sprites. If the screen has been
; scrolled, then every sprite is considered to have the SPRITE_STATUS_MOVED flag set.
;
; 1. If a sprite is marked as (SPRITE_STATUS_MOVED or SPRITE_STATUS_UPDATED or SPRITE_STATUS_ADDED) and not SPRITE_STATUS_REMOVED
;    A. Calculate the TS_COVERAGE_SIZE, TS_LOOKUP_INDEX, and TS_VBUFF_BASE for the sprite
;    B. For each tile the sprite overlaps with:
;       i.   Set its bit in the TileStore's TS_SPRITE_FLAG
;       ii.  Add the tile to the DirtyTile list
;       iii. Set the VBUFF address for the sprite block
;    C. If the sprite is not marked as SPRITE_STATUS_ADDED
;       i.  For each old tile the sprite overlaps with
;          a. If it is not marked in the DirtyTile list
;             * Clear its bit from the TileStore's TS_SPRITE_FLAG
;             * Add the tile to the DirtyTile list
;
; 2. If a sprite is marked as SPRITE_STATUS_REMOVED, then
;    A. Clear its bit from the SpriteBits bitmap
;    B. For each tile the sprite overlaps with:
;       i.  Clear its bit from the TileStore's TS_SPRITE_FLAG
;       ii. Add the tile to the DirtyTile list
;    C. Clear the SPRITE_STATUS flags (work complete)
;
; 3. For each tile on the Dirty Tile list
;    A. Place the sprite VBUFF addresses in TS_VBUFF_ADDR_0 through TS_VBUFF_ADDR_3 and set TS_VBUFF_ADDR_COUNT
;
; It is important that this work is done *prior* to any tile map updates so that we can interate over the
; DirtyTile list and *know* that it only contains tiles that are impacted by sprite changes.
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

            stz   ForceSpriteFlag
            lda   StartX
            cmp   OldStartX
            bne   :force_update

            lda   StartY
            cmp   OldStartY
            beq   :no_change

:force_update
            lda   #SPRITE_STATUS_MOVED
            sta   ForceSpriteFlag
:no_change

; Dispatch to the update process for sprites. By pre-building the list, we know exactly
; how many sprite to process and they are in a contiguous array.  So we don't have to keep
; track of an iteration variable

            ldx   ActiveSpriteCount
            jmp   (phase1,x)

; Implement the logic for updating sprite and tile rendering information. Each iteration of the 
; ActiveSpriteCount will call this routine with the Y-register set to the sprite index
_DoPhase1
            lda   _Sprites+SPRITE_STATUS,y
            ora   ForceSpriteFlag

; First step, if a sprite is being removed, then we just have to clear its old tile information
; and mark the tiles it overlapped as dirty.

            bit   #SPRITE_STATUS_REMOVED
            beq   :no_clear

            lda   _SpriteBits,y                   ; Clear from the sprite bitmap
            sta   SpriteRemovedFlag               ; Stick a non-zero value here
            trb   SpriteMap
            lda   #SPRITE_STATUS_EMPTY            ; Mark as empty so no error if we try to Add a sprite here again
            sta   _Sprites+SPRITE_STATUS,y
            tyx
            jsr   _DeleteSprite                   ; Remove sprite from linked list
            txy                                   ; Restore y-register
:hidden
            jmp   _ClearSpriteFromTileStore       ; Clear the tile flags, add to the dirty tile list and done

:no_clear

; If the sprite is hidden, then treat it like it's offscreen and clear it from the tile store.  Because
; the hidden flag must be changed via the UpdateSprite function, if it's toggled, the SPRITE_STATUS_UPDATED
; flag will be set, too.

            bit   #SPRITE_STATUS_HIDDEN
            bne   :hidden

; If the sprite is marked as ADDED, then it does not need to have its old tile locations cleared

            bit   #SPRITE_STATUS_ADDED
            bne   :added

; If the sprite was not ADDED and also not MOVED, then there is no reason to erase the old tiles
; because they will be overwritten anyway.

            bit   #SPRITE_STATUS_MOVED
            bne   :moved

; Finally, see if it was updated.  If not, return early

            bit   #SPRITE_STATUS_UPDATED
            bne   :updated
            rts

:moved
            phy
            jsr   _ClearSpriteFromTileStore
            ply

; Anything else (MOVED, UPDATED, ADDED) will need to have the VBUFF information updated and the 
; current tiles marked for update
:added
:updated
            jsr   _CalcDirtySprite                     ; This function preserves Y

            lda   #$FFFF!{SPRITE_STATUS_ADDED.SPRITE_STATUS_UPDATED.SPRITE_STATUS_MOVED}
            and   _Sprites+SPRITE_STATUS,y
            sta   _Sprites+SPRITE_STATUS,y             ; Clear the dirty bits (ADDED, UPDATED, MOVED)

            jmp   _MarkDirtySpriteTiles

; Dispatch table.  It's unintersting, so it's tucked out of the way
phase1      dw    :phase1_0
            dw    :phase1_1,:phase1_2,:phase1_3,:phase1_4
            dw    :phase1_5,:phase1_6,:phase1_7,:phase1_8
            dw    :phase1_9,:phase1_10,:phase1_11,:phase1_12
            dw    :phase1_13,:phase1_14,:phase1_15,:phase1_16
:phase1_16  ldy   activeSpriteList+30
            jsr   _DoPhase1
:phase1_15  ldy   activeSpriteList+28
            jsr   _DoPhase1
:phase1_14  ldy   activeSpriteList+26
            jsr   _DoPhase1
:phase1_13  ldy   activeSpriteList+24
            jsr   _DoPhase1
:phase1_12  ldy   activeSpriteList+22
            jsr   _DoPhase1
:phase1_11  ldy   activeSpriteList+20
            jsr   _DoPhase1
:phase1_10  ldy   activeSpriteList+18
            jsr   _DoPhase1
:phase1_9   ldy   activeSpriteList+16
            jsr   _DoPhase1
:phase1_8   ldy   activeSpriteList+14
            jsr   _DoPhase1
:phase1_7   ldy   activeSpriteList+12
            jsr   _DoPhase1
:phase1_6   ldy   activeSpriteList+10
            jsr   _DoPhase1
:phase1_5   ldy   activeSpriteList+8
            jsr   _DoPhase1
:phase1_4   ldy   activeSpriteList+6
            jsr   _DoPhase1
:phase1_3   ldy   activeSpriteList+4
            jsr   _DoPhase1
:phase1_2   ldy   activeSpriteList+2
            jsr   _DoPhase1
:phase1_1   ldy   activeSpriteList
            jmp   _DoPhase1
:phase1_0   rts

; Utility function to calculate the difference in tile positions between a sprite's current
; position and it's previous position.  This gets interesting because the number of tiles
; that a sprite covers can change based on the relative alignemen of the sprite with the
; background.
;
; Ideally, we would be able to quickly calculate exactly which new background tiles a sprite
; intersects with and which ones it has left to minimize the number of TileStore entries
; that need to be updated.
;
; In the short-term, we just do an equality test which lets us know if the sprite is
; covering the exact same tiles.


; Render a sprite stamp into the sprite buffer.  Stamps exist independent of the sprites
; and sprite reference a specific stamp.  This is necessary because it's common for a
; sprite to change its graphic as its animating, but it is too costly to have to set up
; the stamp every time.  So this allows users to create stamps in advance and then
; assign them to the sprites as needed.
;
; Note that the user has full freedom to create a stamp at any VBUFF address, however,
; without leaving a buffer around each stamp, graphical corruption will occur.  It is
; recommended that the defines for VBUFF_SPRITE_START, VBUFF_TILE_ROW_BYTES and
; VBUFF_TILE_COL_BYTES to calculate tile-aligned corner locations to lay out the 
; sprite stamps in VBUFF memory.
;
; Input:
;   A = sprite descriptor
;   Y = vbuff address
;
; The Sprite[VBUFF_ADDR] property must be set to the vbuff address passed into this function
; to bind the sprite stamp to the sprite record.
_CreateSpriteStamp
           pha                                       ; Save the descriptor
           jsr   _GetBaseTileAddr                    ; Get the address of the tile data

           tax                                       ; Tile data address
           pla                                       ; Pop the sprite ID
           jmp   _DrawSpriteStamp                    ; Render the sprite data and create a stamp

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
; Bit 13       : Show/Hide sprite during rendering
; Bit 14       : Mark sprite as a compile sprite.  SPRITE_DISP is treated as a compilation token.
; Bit 15       : Reserved. Must be zero.
; TBD: Bit 15       : Low Sprite priority. Draws behind high priority tiles.
;
; When a sprite has a size > 8x8, the horizontal tiles are taken from the next tile index and
; the vertical tiles are taken from tileId + 32.  This is why tile sheets should be saved
; with a width of 256 pixels.
;
; A = Sprite ID / Flags
; Y = High Byte = x-pos, Low Byte = y-pos
; X = Sprite Slot (0 - 15)
_AddSprite
            pha
            txa
            and   #$000F
            asl
            tax
            pla

            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor

            lda   #SPRITE_STATUS_ADDED          ; Used to initialize the SPRITE_STATUS
            sta   _Sprites+SPRITE_STATUS,x

            lda   #$FFFF
            sta   _Sprites+VBUFF_ADDR,x         ; Clear the VBUFF address, just to initialize it
 
            phy
            tya
            and   #$00FF
            sta   _Sprites+SPRITE_Y,x           ; Y coordinate
            pla
            xba
            and   #$00FF
            sta   _Sprites+SPRITE_X,x           ; X coordinate

; Mark the dirty bit to indicate that the active sprite list needs to be rebuilt in the next
; render call

            lda   #DIRTY_BIT_SPRITE_ARRAY
            tsb   DirtyBits

            lda   _SpriteBits,x                 ; Get the bit flag for this sprite slot
            tsb   SpriteMap                     ; Mark it in the sprite map bit field

            jsr   _PrecalcSpriteSize            ; Cache sprite property values
            jsr   _PrecalcSpriteBounds

            jsr   _InsertSprite                 ; Insert it into the sorted list
            jmp   _Validate

; _SortSprite
;
; Given a sprite's index, i, update the sprite permutation array such that p[j] = i where
; the sprite is the j.th sprite ordered by the SPRITE_CLIP_TOP value.  It is important to
; note that the sorted sprite order does not impact rendering order (that is determined by
; the sprite index position), but is only used to calculate region of the screen to update
; and, in the future, may be useful for isometric perspectives where sorting order *is*
; determined by y-position
;
; X = current sprite index
;
; The sorting strategy is to
;
; a) check if the current slot's y-pos is greater than the next item. If yes, then search forward
; b) check if the current slot's y-pos is less than the prev item.  If yes, then search in reverse
; c) sprite is in the correct location
;
; The heuristic in play here is that, usually sprites will only move one position in the sorted order
; between frames, if at all.
_SortSprite
           lda   _Sprites+SPRITE_CLIP_TOP,x

           ldy   _Sprites+SORTED_PREV,x
           bmi   :chk_fwd
           cmp   _Sprites+SPRITE_CLIP_TOP,y
           bcc   :scan_bkwd                     ; The current node needs to move to an lower position

:chk_fwd
           ldy   _Sprites+SORTED_NEXT,x        ; If there is nothing ahead of the current node, we're done
           bmi   :early_out
           cmp   _Sprites+SPRITE_CLIP_TOP,y    ; If the current node is <= the next node, we're done
           bcc   :early_out
           bne   :scan_fwd

:early_out
           rts

; Look to move the sprite into a later position
:scan_fwd
           lda   _Sprites+SORTED_NEXT,y        ; Need to step forward; if we're at the end, then insert here
           bmi   :insert_end
           tay
           lda   _Sprites+SPRITE_CLIP_TOP,y    ; Check against the next node. If it's less that current, keep going
           cmp   _Sprites+SPRITE_CLIP_TOP,x
           bcc   :scan_fwd

; Put X before Y
;
; Change
;  a <=> x <=> b
;  c <=> y <=> d
;
; Into
;  a <=> b and c <=> x <=> y <=> d
:insert_before
           jsr  _ReleaseNode

           tya
           sta  _Sprites+SORTED_NEXT,x        ; Link X to Y

           lda  _Sprites+SORTED_PREV,y
           sta  _Sprites+SORTED_PREV,x        ; Link X to C

           txa                                ; Link Y to X
           sta  _Sprites+SORTED_PREV,y

           ldy  _Sprites+SORTED_PREV,x        ; Link C to X
           sta  _Sprites+SORTED_NEXT,y
           rts

; Move X to the end of the list. Y point to the last element
;
; ; Change
;  a <=> x <=> b
;  y -> nil
;
; Into
;  a <=> b and y <=> x -> nil
:insert_end
           jsr  _ReleaseNode

           lda  #$FFFF
           sta  _Sprites+SORTED_NEXT,x
           tya
           sta  _Sprites+SORTED_PREV,x
           txa
           sta  _Sprites+SORTED_NEXT,y
           rts

; Look to move the sprite into an earlier position
:scan_bkwd
           lda   _Sprites+SORTED_PREV,y        ; Need to step backward; if we're at the beginning, then insert here
           bmi   :insert_front
           tay
           lda   _Sprites+SPRITE_CLIP_TOP,x    ; Check against the next node. If it's less that current, keep going
           cmp   _Sprites+SPRITE_CLIP_TOP,y
           bcc   :scan_bkwd

; Put X after Y
;
; Change
;  a <=> x <=> b
;  c <=> y <=> d
;
; Into
;  a <=> b and c <=> y <=> x <=> d
:insert_after
           jsr  _ReleaseNode

           tya
           sta  _Sprites+SORTED_PREV,x    ; c <=> y <-- x --- d

           lda  _Sprites+SORTED_NEXT,y    ; c <=> y <-- x --> d
           sta  _Sprites+SORTED_NEXT,x

           txa
           ldx  _Sprites+SORTED_NEXT,y
           sta  _Sprites+SORTED_NEXT,y    ; c <=> y <=> x --> d

           sta  _Sprites+SORTED_PREV,x    ; c <=> y <=> x <=> d
           rts

; Move X to the front of the list. Y points to the first element
;
; ; Change
;  a <=> x <=> b
;  head -> y
;
; Into
;  a <=> b and head -> x <=> y
:insert_front
           jsr  _ReleaseNode

           stx  _SortedHead
           txa
           sta  _Sprites+SORTED_PREV,y
           lda  #$FFFF
           sta  _Sprites+SORTED_PREV,x
           tya
           sta  _Sprites+SORTED_NEXT,x

:done
           rts

; Take the node pointed at X and remove it from the doubly-linked list.
_ReleaseNode
           phy
           jsr  _DeleteSprite
           ply
           rts

; Add a new sprite into the sorted double-linked list
_InsertSprite
           lda   _SortedHead                   ; If the list is empty, just insert the sprite index
           bmi   :empty

           tay                                 ; Check the first item
           lda   _Sprites+SPRITE_CLIP_TOP,x
           cmp   _Sprites+SPRITE_CLIP_TOP,y
           bcc   :insert_head

:next
           lda   _Sprites+SORTED_NEXT,y
           bmi   :insert_tail

           tay
           lda   _Sprites+SPRITE_CLIP_TOP,x
           cmp   _Sprites+SPRITE_CLIP_TOP,y
           bcs   :next

           lda   _Sprites+SORTED_PREV,y
           sta   _Sprites+SORTED_PREV,x       ;  [p] <-- [c]     [n]

           tya
           sta   _Sprites+SORTED_NEXT,x       ;  [p] <-- [c] --> [n]

           txa
           ldx   _Sprites+SORTED_PREV,y       ; get ref to the [p]revious node
           sta   _Sprites+SORTED_PREV,y       ;  [p] <-- [c] <=> [n]

           sta   _Sprites+SORTED_NEXT,x       ;  [p] <=> [c] <=> [n]

           rts

:insert_head
           stx   _SortedHead
           lda   #$FFFF
           sta   _Sprites+SORTED_PREV,x
           tya
           sta   _Sprites+SORTED_NEXT,x
           txa
           sta   _Sprites+SORTED_PREV,y
           rts

:insert_tail
           txa
           sta   _Sprites+SORTED_NEXT,y
           tya
           sta   _Sprites+SORTED_PREV,x
           lda   #$FFFF
           sta   _Sprites+SORTED_NEXT,x
           rts

:empty
           sta  _Sprites+SORTED_NEXT,x
           sta  _Sprites+SORTED_PREV,x
           stx  _SortedHead
           rts

; Remove a sprite from the double-linked list
_DeleteSprite
           ldy  _Sprites+SORTED_NEXT,x
           bmi  :remove_tail

           cpx  _SortedHead
           beq  :remove_head

           lda  _Sprites+SORTED_PREV,x
           sta  _Sprites+SORTED_PREV,y

           tay
           lda  _Sprites+SORTED_NEXT,x
           sta  _Sprites+SORTED_NEXT,y
           rts

:remove_head
           sty  _SortedHead
           lda  #$FFFF
           sta  _Sprites+SORTED_PREV,y
           rts

:remove_tail
           ldy  _Sprites+SORTED_PREV,x
           bmi  :make_empty

           lda  #$FFFF
           sta  _Sprites+SORTED_NEXT,y
           rts

:make_empty
           lda  #$FFFF
           sta  _SortedHead
           rts

; Validate the integrity of the linked list
_Validate
:prev      equ  tmp0
:curr      equ  tmp1

           ldy  #$FFFF
           ldx  _SortedHead
           bmi  :done
:loop
           sty  :prev
           stx  :curr

           lda  _Sprites+SORTED_PREV,x
           cmp  :prev
           beq  *+4
           brk  $08

           cpy  #$FFFF
           beq  :skip
           lda  _Sprites+SORTED_NEXT,y
           cmp  :curr
           beq  *+4
           brk  $06

           lda  _Sprites+SPRITE_CLIP_TOP,x
           cmp  _Sprites+SPRITE_CLIP_TOP,y
           bcs  *+4
           brk  $0A
:skip
           txy
           lda  _Sprites+SORTED_NEXT,x
           tax
           bpl  :loop

:done
           rts
; Macro to make the unrolled loop more concise
;
;   1. Load the tile store address from a fixed offset
;   2. Clears the sprite bit from the TS_SPRITE_FLAG location
;   3. Checks if the tile is dirty and marks it
;   4. If the tile was dirty, save the tile store address to be added to the DirtyTiles list later
TSClearSprite mac
            ldy   TileStoreLookup+{]1},x

            lda   TileStore+TS_SPRITE_FLAG,y
            and   tmp0
            sta   TileStore+TS_SPRITE_FLAG,y

            lda   TileStore+TS_DIRTY,y
            bne   next
            inc
            sta   TileStore+TS_DIRTY,y
            
            tya
            ldy   DirtyTileCount
            sta   DirtyTiles,y
            iny
            iny
            sty   DirtyTileCount
next
            <<<

; Alternate implementation that uses the TS_COVERAGE_SIZE and TS_LOOKUP_INDEX properties to
; load the old values directly from the TileStoreLookup table, rather than caching them.
; This is more efficient, because the work in MarkDirtySprite is independent of the
; sprite size and, by inlining the _PushDirtyTile logic, we can save a fair amount of overhead
_ClearSpriteFromTileStore
            lda   _SpriteBitsNot,y                          ; Cache this value in a direct page location
            sta   tmp0
            ldx   _Sprites+TS_COVERAGE_SIZE,y
            jmp   (csfts_tbl,x)
csfts_tbl   dw    csfts_1x1,csfts_1x2,csfts_1x3,csfts_out
            dw    csfts_2x1,csfts_2x2,csfts_2x3,csfts_out
            dw    csfts_3x1,csfts_3x2,csfts_3x3,csfts_out
            dw    csfts_out,csfts_out,csfts_out,csfts_out

csfts_out   rts

csfts_3x3   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 2
            TSClearSprite 4
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+0
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+2
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+4
            TSClearSprite 2*{TS_LOOKUP_SPAN*2}+0
            TSClearSprite 2*{TS_LOOKUP_SPAN*2}+2
            TSClearSprite 2*{TS_LOOKUP_SPAN*2}+4
            rts

csfts_3x2   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 2
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+0
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+2
            TSClearSprite 2*{TS_LOOKUP_SPAN*2}+0
            TSClearSprite 2*{TS_LOOKUP_SPAN*2}+2
            rts

csfts_3x1   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+0
            TSClearSprite 2*{TS_LOOKUP_SPAN*2}+0
            rts

csfts_2x3   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 2
            TSClearSprite 4
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+0
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+2
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+4
            rts

csfts_2x2   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 2
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+0
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+2
            rts

csfts_2x1   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 1*{TS_LOOKUP_SPAN*2}+0
            rts

csfts_1x3   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 2
            TSClearSprite 4
            rts

csfts_1x2   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            TSClearSprite 2
            rts

csfts_1x1   ldx   _Sprites+TS_LOOKUP_INDEX,y
            TSClearSprite 0
            rts

; Use the blttmp space to build the active sprite list.  Since the sprite tiles are not drawn until later,
; it's OK to use that scratch space here.  And it's just the right size, 32 bytes
RebuildSpriteArray
            lda   SpriteMap                     ; Get the bit field

; Unrolled loop to get the sprite index values that correspond to the set bit positions

            pea   $FFFF                         ; end-of-list marker
]step       equ   0
            lup   4
            lsr
            bcc   :skip_1
            pea   ]step
:skip_1     lsr
            bcc   :skip_2
            pea   ]step+2
:skip_2     lsr
            bcc   :skip_3
            pea   ]step+4
:skip_3     lsr
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
            sta   activeSpriteList,x
            inx
            inx
            bra   :loop
:out
            stx   ActiveSpriteCount
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

; Small initialization routine to cache the banks for the sprite data and mask and tile/sprite stuff
_CacheSpriteBanks
            lda    #>spritemask
            and    #$FF00
            ora    #^spritedata
            sta    SpriteBanks

            lda    #$0100
            ora    #^TileStore
            sta    TileStoreBankAndBank01

            lda    #>tiledata
            and    #$FF00
            ora    #^TileStore
            sta    TileStoreBankAndTileDataBank

            xba
            ldx    #$100
            sta    DP2_TILEDATA_AND_TILESTORE_BANKS,x     ; put a reversed copy in the second direct page
            and    #$FF00
            ora    #$0001
            sta    DP2_BANK01_AND_TILESTORE_BANKS,x       ; put a value with bank 01 and the tile store

            lda    #>spritedata
            and    #$FF00
            ora    #^tiledata
            sta    DP2_TILEDATA_AND_SPRITEDATA_BANKS,x

            lda    #>spritedata
            and    #$FF00
            ora    #^TileStore
            xba
            ldx    #$100
            sta    DP2_SPRITEDATA_AND_TILESTORE_BANKS,x     ; put a reversed copy in the second direct page

            lda    #>TileStore
            and    #$FF00
            ora    #^TileStore
            sta    TileStoreBankDoubled
            
            rts

; Precalculate some cached values for a sprite.  These are *only* to make other parts of code,
; specifically the draw/erase routines more efficient.
;
; X = sprite index
_PrecalcSpriteVBuff
            lda   _Sprites+SPRITE_ID,x               ; Compiled sprites use the SPRITE_DISP as a fixed address to compiled code
            bit   #SPRITE_COMPILED
            bne   :compiled

            xba
            and   #$0006
            tay
            lda   _Sprites+VBUFF_ADDR,x
            clc
            adc   _stamp_step,y
            sta   _Sprites+SPRITE_DISP,x            ; Interpreted as an address in the VBUFF bank
            rts

:compiled
            xba
            and   #$0006                            ; Pick the address from the table of 4 values.  Can use this value directly
            clc                                     ; as an index
            adc   _Sprites+VBUFF_ADDR,x
            tay
            lda   [CompileBank0],y
            sta   _Sprites+SPRITE_DISP,x            ; Interpreted as an address in the CompileBank
            rts

; Compile the four stamps and keep a reference to the addresses.  We take the current CompileBankTop address and allocate 8 bytes
; of memory.  Then compile each stamp and save the compilation address in the header area.  Finally, the DISP_ADDR is set
; to that value and the SPRITE_COMPILED bit is set in the SPRITE_ID word.
;
; A = sprite Id
; X = vbuff base address
_CompileStampSet
:height     equ   tmp8
:width      equ   tmp9
:base       equ   tmp10
:output     equ   tmp11
:addrs      equ   tmp12            ; 4 words (tmp12, tmp13, tmp14 and tmp15)

; Save the base address
            stx   :base

; Initialize the height and width based on the sprite flags

            ldy   #8
            sty   :height
            ldx   #4
            stx   :width

            bit   #$1000                              ; wide flag
            beq   :skinny
            ldx   #8
            stx   :width
:skinny

            bit   #$0800                              ; tall flag
            beq   :short
            ldy   #16
            sty   :height
:short

            lda   CompileBankTop
            sta   :output                         ; Save the current address as the return value

            clc
            adc   #8
            sta   CompileBankTop                ; Allocate space for the 4 addresses return by _CompileStamp

;            ldy   :height                      ; X and Y are already set for the first call
;            ldx   :width
            lda   :base
            jsr   _CompileStamp                 ; Compile into the bank
            sta   :addrs                        ; Save the address temporarily

            ldy   :height
            ldx   :width
            clc
            lda   :base
            adc   _stamp_step+2
            jsr   _CompileStamp
            sta   :addrs+2

            ldy   :height
            ldx   :width
            clc
            lda   :base
            adc   _stamp_step+4
            jsr   _CompileStamp
            sta   :addrs+4

            ldy   :height
            ldx   :width
            clc
            lda   :base
            adc   _stamp_step+6
            jsr   _CompileStamp
            sta   :addrs+6

; Now the sprite stamps are all compiled.  Set the bank to the compilation bank and fill in the header

            phb

            ldy   :output
            pei   CompileBank
            plb

            lda   :addrs
            sta:  0,y
            lda   :addrs+2
            sta:  2,y
            lda   :addrs+4
            sta:  4,y
            lda   :addrs+6
            sta:  6,y

            plb
            plb

            tya                             ; Put the output value into the accumulator
            clc                             ; No error
            rts

_PrecalcSpriteSize
; Set the sprite's width and height
            lda   #4
            sta   _Sprites+SPRITE_WIDTH,x
            lda   #8
            sta   _Sprites+SPRITE_HEIGHT,x

            lda   _Sprites+SPRITE_ID,x
            bit   #$1000                        ; width select
            beq   :width_4
            lda   #8
            sta   _Sprites+SPRITE_WIDTH,x
:width_4

            lda   _Sprites+SPRITE_ID,x
            bit   #$0800                        ; height select
            beq   :height_8
            lda   #16
            sta   _Sprites+SPRITE_HEIGHT,x
:height_8
            rts

; Clip the sprite's bounding box to the play field size and also set a flag if the sprite
; is fully off-screen or not
_PrecalcSpriteBounds
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
            adc   _Sprites+SPRITE_WIDTH,x
            dec
            bmi   :offscreen
            cmp   ScreenWidth
            bcc   :ok_x
            lda   ScreenWidth
            dec
:ok_x       sta   _Sprites+SPRITE_CLIP_RIGHT,x

            lda   _Sprites+SPRITE_Y,x
            clc
            adc   _Sprites+SPRITE_HEIGHT,x
            dec
            bmi   :offscreen
            cmp   ScreenHeight
            bcc   :ok_y
            lda   ScreenHeight
            dec
:ok_y       sta   _Sprites+SPRITE_CLIP_BOTTOM,x

            stz   _Sprites+IS_OFF_SCREEN,x       ; passed all of the off-screen tests

; Calculate the clipped width and height
            lda   _Sprites+SPRITE_CLIP_RIGHT,x
            sec
            sbc   _Sprites+SPRITE_CLIP_LEFT,x
            inc
            sta   _Sprites+SPRITE_CLIP_WIDTH,x

            lda   _Sprites+SPRITE_CLIP_BOTTOM,x
            sec
            sbc   _Sprites+SPRITE_CLIP_TOP,x
            inc
            sta   _Sprites+SPRITE_CLIP_HEIGHT,x

            rts

:offscreen
            lda   #1
            sta   _Sprites+IS_OFF_SCREEN,x
            rts

; Remove a sprite from the list. Just mark its STATUS as FREE and it will be
; picked up in the next AddSprite.
;
; A = Sprite ID
_RemoveSprite
            cmp   #MAX_SPRITES
            bcc   :ok
            rts

:ok
            asl
            tax

            lda   _Sprites+SPRITE_STATUS,x
            ora   #SPRITE_STATUS_REMOVED
            sta   _Sprites+SPRITE_STATUS,x

            rts                                   ; The _DeleteSprite call is made in _DoPhase1 during the next render

; Update the sprite's flags. We do not allow the size of a sprite to be changed.  That requires
; the sprite to be removed and re-added.
;
; A = Sprite slot
; X = New Sprite Flags
; Y = New Sprite Stamp Address | New Compiled Sprite Token
_UpdateSprite
            cmp   #MAX_SPRITES
            bcc   :ok
            rts

:ok
            phx                                 ; Save X to swap into A
            asl
            tax
            pla

; Do some work to see if only the H or V bits have changed.  If so, merge them into the
; SPRITE_ID
            eor   _Sprites+SPRITE_ID,x          ; If either bit has changed, this will be non-zero
            and   #SPRITE_VFLIP+SPRITE_HFLIP+SPRITE_HIDE
            bne   :sprite_flag_change

            tya
            cmp   _Sprites+VBUFF_ADDR,x         ; Did the stamp change?
            bne   :sprite_stamp_change
            rts                                 ; Nothing changed, so just return

:sprite_flag_change
            eor   _Sprites+SPRITE_ID,x          ; put the new bits into the value. ---HV--- ^ SPRITE_ID & 00011000 ^ SPRITE_ID = SSSHVSSS
            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor

            bit   #SPRITE_HIDE                  ; Sync the SPRITE_HIDE bit into the SPRITE_STATUS_HIDDEN flag
            beq   :not_hidden
            lda   #SPRITE_STATUS_HIDDEN
            ora   _Sprites+SPRITE_STATUS,x
            sta   _Sprites+SPRITE_STATUS,x
            bra   :sync_complete
:not_hidden lda   #$FFFF!SPRITE_STATUS_HIDDEN
            and   _Sprites+SPRITE_STATUS,x
            sta   _Sprites+SPRITE_STATUS,x
:sync_complete

            tya
:sprite_stamp_change
            sta   _Sprites+VBUFF_ADDR,x         ; Just save this to stay in sync

            lda   _Sprites+SPRITE_STATUS,x      ; Mark this sprite as updated
            ora   #SPRITE_STATUS_UPDATED
            sta   _Sprites+SPRITE_STATUS,x

            jmp   _PrecalcSpriteVBuff           ; Cache stuff and return

; Move a sprite to a new location.  If the tile ID of the sprite needs to be changed, then
; a full remove/add cycle needs to happen
;
; A = sprite slot
; X = x position
; Y = y position
_MoveSprite
            cmp   #MAX_SPRITES
            bcc   :ok
            rts

:ok
            phx                                 ; Save X to swap into A
            asl
            tax
            pla

            cmp   _Sprites+SPRITE_X,x
            bne   :changed1
            tya
            cmp   _Sprites+SPRITE_Y,x
            bne   :changed2
            rts

:changed1
            sta   _Sprites+SPRITE_X,x           ; Update the X coordinate
            tya
:changed2
            sta   _Sprites+SPRITE_Y,x           ; Update the Y coordinate

            lda   _Sprites+SPRITE_STATUS,x
            ora   #SPRITE_STATUS_MOVED
            sta   _Sprites+SPRITE_STATUS,x

            jsr   _PrecalcSpriteBounds          ; Can be specialized to only update (x,y) values
            jsr   _SortSprite                   ; Update the sprite's sorted position
            jmp   _Validate
