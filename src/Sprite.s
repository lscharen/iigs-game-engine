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

; Clear values in the sprite array

;           ldx    #{MAX_SPRITES-1}*2
;:loop3     stz    _Sprites+TILE_STORE_ADDR_1,x
;           dex
;           dex
;           bpl    :loop3

; Initialize the VBUFF address offsets in the data and mask banks for each sprite
;
; The internal grid 12 tiles wide where each sprite has a 2x2 interior square with a
; tile-size buffer all around. We pre-render each sprite with all four vert/horz flips
;
; Eventually we should be able to have a separate rendering path for vertically flipped
; sprites and will be able to double the capacity of the stamp buffer

           ldx    #0
           lda    #VBUFF_SPRITE_START
           clc
:loop4     sta    VBuffAddrTable,x
           adc    #VBUFF_SPRITE_STEP
           inx
           inx
           cpx    #VBUFF_SLOT_COUNT*2
           bcc    :loop4

; Precalculate some bank values
           jsr    _CacheSpriteBanks
           rts

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
; Currently, we support a maximum of 48 stamps.
;
; Input:
;   A = sprite descriptor
;   X = stamp slot
; Return:
;   A = vbuff address to be assigned to Sprite[VBUFF_ADDR]
CreateSpriteStamp   ENT
            phb
            phk
            plb
            jsr    _CreateSpriteStamp
            plb
            rtl

_CreateSpriteStamp
           pha                                       ; Save the descriptor
           jsr   _GetBaseTileAddr                    ; Get the address of the tile data
           pha

           txa
           asl
           tax
           ldy   VBuffAddrTable,x                    ; Load the address of the stamp slot

           plx                                       ; Pop the tile address
           pla                                       ; Pop the sprite ID
           phy                                       ; VBUFF_ADDR value
           jsr   _DrawSpriteStamp                    ; Render the sprite data and create a stamp

           pla                                       ; Pop the VBUFF_ADDR and return
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
; A = tileId + flags
; Y = High Byte = x-pos, Low Byte = y-pos
; X = Sprite Slot (0 - 15)
AddSprite   ENT
            phb
            phk
            plb
            jsr    _AddSprite
            plb
            rtl

_AddSprite
            pha
            txa
            and   #$000F
            asl
            tax
            pla

            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor

            lda   #SPRITE_STATUS_OCCUPIED+SPRITE_STATUS_ADDED
            sta   _Sprites+SPRITE_STATUS,x

            stz   _Sprites+VBUFF_ADDR,x         ; Clear the VBUFF address, just to initialize it
 
            phy
            tya
            and   #$00FF
            sta   _Sprites+SPRITE_Y,x           ; Y coordinate
            pla
            xba
            and   #$00FF
            sta   _Sprites+SPRITE_X,x           ; X coordinate

            jsr   _PrecalcAllSpriteInfo         ; Cache sprite property values (simple stuff)
;            jsr   _DrawSpriteSheet              ; Render the sprite into internal space

; Mark the dirty bit to indicate that the active sprite list needs to be rebuilt in the next
; render call

            lda   #DIRTY_BIT_SPRITE_ARRAY
            tsb   DirtyBits

            lda   _SpriteBits,x                 ; Get the bit flag for this sprite slot
            tsb   SpriteMap                     ; Mark it in the sprite map bit field

;            txa                                 ; And return the sprite ID
;            clc                                 ; Mark that the sprite was successfully added

            rts

; Alternate implementation that uses the TS_COVERAGE_SIZE and TS_LOOKUP_INDEX properties to
; load the old values directly from the TileStoreLookup table, rather than caching them.
; This is more efficient, because the work in MarkDirtySprite is independent of the
; sprite size and, by inlining the _PushDirtyTile logic, we can save a fair amount of overhead
_ClearSpriteFromTileStore2
            ldx   _Sprites+TS_COVERAGE_SIZE,y
            jmp   (csfts_tbl,x)
csfts_tbl   dw    csfts_1x1,csfts_1x2,csfts_1x3,csfts_out
            dw    csfts_2x1,csfts_2x2,csfts_2x3,csfts_out
            dw    csfts_3x1,csfts_3x2,csfts_3x3,csfts_out
            dw    csfts_out,csfts_out,csfts_out,csfts_out

; Just a single value to clear and add to the dirty tile list
csfts_1x1   ldx   _Sprites+TS_LOOKUP_INDEX,y
            lda   TileStoreLookup,x
            tax

            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBitsNot,y
            sta   TileStore+TS_SPRITE_FLAG,x

            lda   TileStore+TS_DIRTY,x
            bne   csfts_1x1_out

            inc                                  ; any non-zero value will work
            sta   TileStore+TS_DIRTY,x            ; and is 1 cycle faster than loading a constant value

            txa
            ldx   DirtyTileCount
            sta   DirtyTiles,x
            inx
            inx
            stx   DirtyTileCount
csfts_1x2
csfts_1x3
csfts_2x1
csfts_2x3
csfts_3x1
csfts_3x2
csfts_3x3
csfts_1x1_out
            rts

; This is a more interesting case where the ability to batch things up starts to produce some
; efficiency gains
csfts_2x2   ldx   _Sprites+TS_LOOKUP_INDEX,y     ; Get the address of the old top-left corner
            tay
            ldx   TileStoreLookup,y

            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBits
            sta   TileStore+TS_SPRITE_FLAG,x

            lda   TileStore+TS_DIRTY,x
            beq   *+3
            phx


            ldx   TileStoreLookup+2,y

            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBits
            sta   TileStore+TS_SPRITE_FLAG,x

            lda   TileStore+TS_DIRTY,x
            beq   *+3
            phx


            ldx   TileStoreLookup+TS_LOOKUP_SPAN,y

            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBits
            sta   TileStore+TS_SPRITE_FLAG,x

            lda   TileStore+TS_DIRTY,x
            beq   *+3
            phx


            ldx   TileStoreLookup+TS_LOOKUP_SPAN+2,y

            lda   TileStore+TS_SPRITE_FLAG,x
            and   _SpriteBits
            sta   TileStore+TS_SPRITE_FLAG,x

            ldy   DirtyTileCount

            lda   TileStore+TS_DIRTY,x
            beq   skip_2x2

            txa
            sta   DirtyTiles,y
            sta   TileStore+TS_DIRTY,x

skip_2x2
            pla
            beq   :done1
            sta   DirtyTiles+2,x
            tay
            sta   TileStore+TS_DIRTY,y

            pla
            beq   :done2
            sta   DirtyTiles+4,x
            tay
            sta   TileStore+TS_DIRTY,y

            pla
            beq   :done3
            sta   DirtyTiles+6,x
            tay
            sta   TileStore+TS_DIRTY,y

; Maximum number of dirty tiles reached. Just fall through.

            pla
            txa
            adc  #8
            sta  DirtyTileCount
            rts
:done3
            txa
            adc  #6
            sta  DirtyTileCount
            rts
:done2
            txa
            adc  #4
            sta  DirtyTileCount
            rts
:done1
            inx
            inx
            stx  DirtyTileCount

            rts



            lda   _SpriteBitsNot,y               ; Cache the bit value for this sprite

            ldy   TileStoreLookup,x              ; Get the tile store offset


            and   TileStore+TS_SPRITE_FLAG,y
            sta   TileStore+TS_SPRITE_FLAG,y

csfts_out   rts

; Run through the list of tile store offsets that this sprite was last drawn into and mark
; those tiles as dirty.  The largest number of tiles that a sprite could possibly cover is 20
; (an unaligned 4x3 sprite), covering a 5x4 area of play field tiles.
;
; Y register = sprite record index
_CSFTS_Out  rts
_ClearSpriteFromTileStore
;            ldx   _Sprites+TILE_STORE_ADDR_1,y
;            beq   _CSFTS_Out
;            ldal  TileStore+TS_SPRITE_FLAG,x       ; Clear the bit in the bit field.  This seems wasteful, but
;            and   _SpriteBitsNot,y                 ; there is no indexed form of TSB/TRB and caching the value in
;            stal  TileStore+TS_SPRITE_FLAG,x       ; a direct page location, only saves 1 or 2 cycles per and costs 10.
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_2,y
;            beq   _CSFTS_Out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_3,y
;            beq   _CSFTS_Out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_4,y
;            beq   _CSFTS_Out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_5,y
;            beq   :out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_6,y
;            beq   :out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_7,y
;            beq   :out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_8,y
;            beq   :out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jsr   _PushDirtyTileX

;            ldx   _Sprites+TILE_STORE_ADDR_9,y
;            beq   :out
;            ldal  TileStore+TS_SPRITE_FLAG,x
;            and   _SpriteBitsNot,y
;            stal  TileStore+TS_SPRITE_FLAG,x
;            jmp   _PushDirtyTileX

:out        rts

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

; Check to see if sprite was REMOVED  If so, clear the sprite slot status

            lda   _Sprites+SPRITE_STATUS,y
            bit   #SPRITE_STATUS_REMOVED
            beq   :out

            lda   #SPRITE_STATUS_EMPTY            ; Mark as empty (zero value)
            sta   _Sprites+SPRITE_STATUS,y

            lda   _SpriteBits,y                   ; Clear from the sprite bitmap
            trb   SpriteMap

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
            beq   :out                          ; If phase 1 marked us as empty, do nothing
            ora   forceSpriteFlag
            and   #SPRITE_STATUS_ADDED+SPRITE_STATUS_MOVED+SPRITE_STATUS_UPDATED
            beq   :out

; Last thing to do, so go ahead and clear the flags

            lda   #SPRITE_STATUS_OCCUPIED
            sta   _Sprites+SPRITE_STATUS,y

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
;
; OPTIMIZATION NOTE: At this point, a decent chunk of per-tile time is spent cupdating the sprite flgas
;                    for a given TileStore entry.  When a sprite needs to be redrawn (such as when the
;                    screen scrolls), the code marks every tile the sprite was on as no longer occupied
;                    and then marks the occupied tiles.  While simple, this is very redundent when the
;                    screen in scrolling slowly since it is very likely that the same sprite covers the
;                    exact same tiles.  Each pair of markings requires 35 cycles, so a basic 16x16 sprite
;                    could save >300 cycles per frame.  With 4 or 5 sprites on screen, the saving passes
;                    our 1% threshold for useful optimizations.
;
;                    Since we cache the tile location and effective sprite coverage, we need a fast
;                    way to compare the old and new positions and get a list of the new tiles the sprite
;                    occupies and old locations that it no longer covers.  It's possible that just testing
;                    for equality would be the easiest win to know when we can skip everything.

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

            lda    #>TileStore
            and    #$FF00
            ora    #^TileStore
            sta    TileStoreBankDoubled
            
            rts

; This is 13 blocks wide
SPRITE_PLANE_SPAN equ VBUFF_STRIDE_BYTES

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

; Precalculate some cached values for a sprite.  These are *only* to make other part of code,
; specifically the draw/erase routines more efficient.
;
; There are variations of this routine based on whether we are adding a new sprite, updating
; it's tile information, or changing its position.
;
; X = sprite index
_stamp_step dw  0,12,24,36
_PrecalcAllSpriteInfo
            lda   _Sprites+SPRITE_ID,x 
;            and   #$3E00
            xba
            and   #$0006
            tay
            lda   _Sprites+VBUFF_ADDR,x
            clc
            adc   _stamp_step,y
            sta   _Sprites+SPRITE_DISP,x

; Set the 

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
            bit   #$0800                        ; width select
            beq   :height_8
            lda   #16
            sta   _Sprites+SPRITE_HEIGHT,x
:height_8

; Clip the sprite's bounding box to the play field size and also set a flag if the sprite
; is fully off-screen or not

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
RemoveSprite ENT
            phb
            phk
            plb
            jsr    _RemoveSprite
            plb
            rtl

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

            rts

; Update the sprite's flags. We do not allow the size of a sprite to be changed.  That requires
; the sprite to be removed and re-added.
;
; A = Sprite ID
; X = New Sprite Flags
; Y = New Sprite Stamp Address
UpdateSprite ENT
            phb
            phk
            plb
            jsr    _UpdateSprite
            plb
            rtl

_UpdateSprite
            cmp   #MAX_SPRITES
            bcc   :ok
            rts

:ok
            phx                                 ; Save X to swap into A
            asl
            tax
            pla

            cmp   _Sprites+SPRITE_ID,x          ; If the flags changed, need to redraw the sprite
            bne   :sprite_flag_change           ; on the next frame
            tya
            cmp   _Sprites+VBUFF_ADDR,x          ; Did the stamp change?
            bne   :sprite_stamp_change
            rts                                 ; Nothing changed, so just return

:sprite_flag_change
            sta   _Sprites+SPRITE_ID,x          ; Keep a copy of the full descriptor
            tya
:sprite_stamp_change
            sta   _Sprites+VBUFF_ADDR,x          ; Just save this to stay in sync

            lda   _Sprites+SPRITE_STATUS,x      ; Mark this sprite as updated
            ora   #SPRITE_STATUS_UPDATED
            sta   _Sprites+SPRITE_STATUS,x

            jmp   _PrecalcAllSpriteInfo         ; Cache stuff and return

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
            sta   _Sprites+SPRITE_X,x           ; Update the X coordinate
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

            jmp   _PrecalcAllSpriteInfo         ; Can be specialized to only update (x,y) values

; Sprite data structures.  We cache quite a few pieces of information about the sprite
; to make calculations faster, so this is hidden from the caller.
;
;
; Number of "off-screen" lines above logical (0,0)
; NUM_BUFF_LINES  equ 24

MAX_SPRITES     equ 16
SPRITE_REC_SIZE equ 52

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
; TILE_DATA_OFFSET   equ {MAX_SPRITES*2}
VBUFF_ADDR         equ {MAX_SPRITES*4}   ; Base address of the sprite's stamp in the data/mask banks
SPRITE_ID          equ {MAX_SPRITES*6}
SPRITE_X           equ {MAX_SPRITES*8}
SPRITE_Y           equ {MAX_SPRITES*10}
; TILE_STORE_ADDR_1  equ {MAX_SPRITES*12}
TS_LOOKUP_INDEX     equ {MAX_SPRITES*12}       ; The index into the TileStoreLookup table corresponding to the top-left corner of the sprite
; TILE_STORE_ADDR_2  equ {MAX_SPRITES*14}
TS_COVERAGE_SIZE    equ {MAX_SPRITES*14}       ; Index into the lookup table of how many TileStore tiles are covered by this sprite
;TILE_STORE_ADDR_3  equ {MAX_SPRITES*16}
TS_VBUFF_BASE_ADDR  equ {MAX_SPRITES*16}       ; Fixed address of the TS_VBUFF_X memory locations
;TILE_STORE_ADDR_4  equ {MAX_SPRITES*18}
;TILE_STORE_ADDR_5  equ {MAX_SPRITES*20}
;TILE_STORE_ADDR_6  equ {MAX_SPRITES*22}
;TILE_STORE_ADDR_7  equ {MAX_SPRITES*24}
;TILE_STORE_ADDR_8  equ {MAX_SPRITES*26}
;TILE_STORE_ADDR_9  equ {MAX_SPRITES*28}
;TILE_STORE_ADDR_10 equ {MAX_SPRITES*30}
SPRITE_DISP        equ {MAX_SPRITES*32}  ; cached address of the specific stamp based on flags
SPRITE_CLIP_LEFT   equ {MAX_SPRITES*34}
SPRITE_CLIP_RIGHT  equ {MAX_SPRITES*36}
SPRITE_CLIP_TOP    equ {MAX_SPRITES*38}
SPRITE_CLIP_BOTTOM equ {MAX_SPRITES*40}
IS_OFF_SCREEN      equ {MAX_SPRITES*42}
SPRITE_WIDTH       equ {MAX_SPRITES*44}
SPRITE_HEIGHT      equ {MAX_SPRITES*46}
SPRITE_CLIP_WIDTH  equ {MAX_SPRITES*48}
SPRITE_CLIP_HEIGHT equ {MAX_SPRITES*50}

_Sprites       ds  SPRITE_REC_SIZE*MAX_SPRITES
