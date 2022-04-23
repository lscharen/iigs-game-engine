; Scratch space to lay out idealized _MakeDirtySprite
;  On input, X register = Sprite Array Index
;Left     equ   tmp1
;Right    equ   tmp2
;Top      equ   tmp3
;Bottom   equ   tmp4

Origin      equ   tmp4
TileTop     equ   tmp5
RowTop      equ   tmp6
AreaIndex   equ   tmp7

TileLeft    equ   tmp8
ColLeft     equ   tmp9

SpriteBit   equ   tmp10     ; set the bit of the value that if the current sprite index
VBuffOrigin equ   tmp11

; Marks a sprite as dirty.  The work here is mapping from local screen coordinates to the 
; tile store indices.  The first step is to adjust the sprite coordinates based on the current
; code field offsets and then cache variations of this value needed in the rest of the subroutine
;
; The SpriteX is always the MAXIMUM value of the corner coordinates.  We subtract (SpriteX + StartX) mod 4
; to find the coordinate in the sprite cache that matches up with the tile in the play field and 
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
mdsOut2
        lda   #6                                 ; Pick a value for a 0x0 tile sprite
        sta   _Sprites+TS_COVERAGE_SIZE,y         ; zero the list of tile store addresses
        rts

_MarkDirtySprite
        lda   _Sprites+IS_OFF_SCREEN,y           ; Check if the sprite is visible in the playfield
        bne   mdsOut2

; Add the first visible row of the sprite to the Y-scroll offset to find the first line in the
; code field that needs to be drawn.  The range of values is 0 to 199+207 = [0, 406]

        clc
        lda   _Sprites+SPRITE_CLIP_TOP,y
        adc   StartYMod208                       ; Adjust for the scroll offset
        pha                                      ; Cache
        and   #$FFF8                             ; mask first to ensure LSR will clear the carry
        lsr
        lsr
        tax
        lda   TileStoreLookupYTable,x            ; Even numbers from [0, 100] (50 elements)
        sta   RowTop
        pla

; Get the position of the top edge within the tile and then add it to the sprite's height
; to calculate the number of tiles that are overlapped.  We use the actual width and height
; values here so small sprites (like 4x4 bullets) only force an update to the actual tiles
; that are intersected, rather than assuming an 8x8 sprite always takes up that amount of
; space.

        txa
        and   #$0007
        tax                                       ; cache again. This is a bit faster than recalculating

        adc   _Sprites+SPRITE_CLIP_HEIGHT,y       ; Nominal value between 0 and 16+7 = 23 = 10111
        dec
        and   #$0018
        sta   AreaIndex

        txa
        asl
        tax
        lda   :vbuff_mul,x
        sta   tmp0

; Add the horizontal position to the horizontal offset to find the first column in the
; code field that needs to be drawn.  The range of values is 0 to 159+163 = [0, 322]

        clc
        lda   _Sprites+SPRITE_CLIP_LEFT,y
        adc   StartXMod164
        tax
        and   #$FFFC
        lsr
;        sta   ColLeft                            ; Even numbers from [0, 160] (80 elements)
        adc   RowTop
        sta   _Sprites+TS_LOOKUP_INDEX,y          ; This is the index into the TileStoreLookup table


; Calculate the final address of the sprite data in the stamp buffer. We have to move earlier 
; in the buffer based on the horizontal offset and move up for each vertical offset.

        txa
        and   #$0003
        tax

        adc   tmp0                               ; add to the vertical offset

; Subtract this value from the SPRITE_DISP address

        eor   #$FFFF                             ; A = -X - 1
        sec                                      ; C = 1
        adc   _Sprites+SPRITE_DISP,y             ; A = SPRITE_DISP + (-X - 1) + 1 = SPRITE_DISP - X

        sta   VBuffOrigin                        ; this is the final (adjusted) origin for this sprite

; Load the base address of the appropriate TS_VBUFF_? offset for this sprite index and
; store it as an indirect address.

        lda   _Sprites+TS_VBUFF_BASE_ADDR,y
        sta   tmp0

; We know the starting corner of the TileStore.  Now, we need to figure out now many tiles
; the sprite covers.  This is a function of the sprite's width and height and the specific
; location of the upper-left corner of the sprite within the corner tile.

        txa
        adc   _Sprites+SPRITE_CLIP_WIDTH,y       ; max width = 8 = 0x08
        dec
        and   #$000C
        lsr                                      ; max value = 4 = 0x04
        ora   AreaIndex                          ; merge into the area index

; No need to copy the TileStore addresses into the Sprite's TILE_STORE_ADDR values.  Just
; hold a copy of the corner offset into the lookup table and the sprite's size in tiles.
; Then, when we need to erase we can just lookup the values in the TileStoreLookup table.

        sta   _Sprites+TS_COVERAGE_SIZE,y
        tax
;        lda   TileStoreBaseIndex
;        sta   _Sprites+TS_LOOKUP_INDEX,y

; Jump to the appropriate marking routine

        jmp   (:mark,x)

mdsOut  rts
;_MarkDirtySprite
;
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_1,y       ; Clear this sprite's dirty tile list in case of an early exit
;        lda   _SpriteBits,y                      ; Cache its bit flag to mark in the tile slots
;        sta   SpriteBit

;        lda   _Sprites+IS_OFF_SCREEN,y           ; Check if the sprite is visible in the playfield
;        bne   mdsOut

; At this point we know that we have to update the tiles that overlap the sprite's rectangle defined
; by (Top, Left), (Bottom, Right).  First, calculate the row and column in the TileStore that 
; encloses the top-left on-screen corner of the sprite

;        clc
;        lda   _Sprites+SPRITE_CLIP_TOP,y
;        adc   StartYMod208                       ; Adjust for the scroll offset
;        tax                                      ; cache
;        cmp   #208                               ; check if we went too far positive
;        bcc   *+5
;        sbc   #208
;        lsr
;        lsr                                       ; This is the row in the Tile Store for top-left corner of the sprite
;        and   #$FFFE                              ; Store the value pre-multiplied by 2 for indexing in the :mark_R_C routines
;        sta   RowTop

; Next, calculate how many tiles are covered by the sprite.  This uses the table at the top of this function, but
; the idea is that for every increment of StartX or StartY, that can shift the sprite into the next tile, up to
; a maximum of mod 4 / mod 8.  So the effective width of a sprite is (((StartX + Clip_Left) mod 4) + Clip_Width) / 4

;        txa
;        and   #$0007
;        sta   tmp0                                ; save to adjust sprite origin

;        lda   _Sprites+SPRITE_CLIP_HEIGHT,y       ; Nominal value between 0 and 16+7 = 23 = 10111
;        dec
;        clc
;        adc   tmp0
;        and   #$0018
;        sta   AreaIndex

; Repeat to get the same information for the columns

;        clc
;        lda   _Sprites+SPRITE_CLIP_LEFT,y
;        adc   StartXMod164
;        tax
;        cmp   #164
;        bcc   *+5
;        sbc   #164
;        lsr
;        and   #$FFFE                             ; Same pre-multiply by 2 for later
;        sta   ColLeft

;        txa
;        and   #$0003
;        sta   tmp1                               ; save to adjust sprite origin;

;        lda   _Sprites+SPRITE_CLIP_WIDTH,y       ; max width = 8 = 0x08
;        dec
;        clc
;        adc   tmp1
;        lsr                                      ; max value = 4 = 0x04
;        and   #$0006
;        ora   AreaIndex
;        sta   AreaIndex

; Calculate the modified origin address for the sprite.  We need to look at the sprite flip bits
; to determine which of the four sprite stamps is the correct one to use.  Then, offset that origin
; based on the (x, y) and (startx, starty) positions.

;        lda   _Sprites+SPRITE_DISP,y             ; Get the sprite's base display address
;        sec
;        sbc   tmp1                               ; Subtract the horizontal within-tile displacement
;        asl   tmp0
;        ldx   tmp0
;        sec
;        sbc   :vbuff_mul,x
;        sta   VBuffOrigin
;        lda   #^TileStore
;        sta   tmp1

; Dispatch to cover the tiles

;        ldx   AreaIndex
;        jmp   (:mark,x)
:mark   dw    :mark1x1,:mark1x2,:mark1x3,mdsOut
        dw    :mark2x1,:mark2x2,:mark2x3,mdsOut
        dw    :mark3x1,:mark3x2,:mark3x3,mdsOut
        dw    mdsOut,mdsOut,mdsOut,mdsOut

:vbuff_mul  dw  0,52,104,156,208,260,312,364

; Dispatch to the calculated sizing

; Begin a list of subroutines to cover all of the valid sprite size combinations.  This is all unrolled code,
; mainly to be able to do an unrolled fill of the TILE_STORE_ADDR_X values.  Thus, it's important that the clipping
; function does its job properly since it allows us to save a lot of time here.
;
; These functions are a trade off of being composable versus fast.  Having to pay for multiple JSR/RTS invocations
; in the hot sprite path isn't great, but we're at a point of diminishing returns.
;
; There *might* be some speed gained by pushing a list of :mark_R_C addressed onto the stack in the clipping routing
; and dispatching that way, but probably not...

:mark1x1_v2

        tax                                     ; Get the TileStoreBaseIndex

        ldy   TileStoreLookup,x                 ; Get the offset into the TileStore for this tile

        lda   SpriteBit                         ; Mark this tile as having this sprite
        ora   TileStore+TS_SPRITE_FLAG,y
        sta   TileStore+TS_SPRITE_FLAG,y

        lda   VBuffOrigin
        sta   (tmp0),y                          ; Fill in the slot for this sprite on this tile

        lda   TileStore+TS_DIRTY,y              ; If this tile is not yet marked dirty, mark it
        bne   exit1x1

        ldx   DirtyTileCount
        tya
        sta   DirtyTiles,x
        sta   TileStore+TS_DIRTY,y
        inx
        inx
        stx   DirtyTileCount

exit1x1
        rts

:mark2x2_v2

; Put the TileStoreBaseIndex into the X-register

        tax

; Push a sentinel value of the stack that we use to inline all of the dirty tile array updates faster
; and the end of this routine.

        pea   #$0000

; Now, move through each of the TileStore locations and set the necessary fields.  We have to do the
; following
;
; 1. Set the marker bit in the TS_SPRITE_FLAG so the renderer knows which vbuff addresses to load
; 2. Set the address of the sprite stamp graphics that are used.  This can change every frame.
; 3. Mark the tile as dirty and put it on the list if it was marked dirty for the first time.

        ldy   TileStoreLookup,x                 ; Get the offset into the TileStore for this tile

        lda   SpriteBit                         ; Mark this tile as having this sprite
        ora   TileStore+TS_SPRITE_FLAG,y
        sta   TileStore+TS_SPRITE_FLAG,y

        lda   TileStore+TS_DIRTY,y              ; If this tile is not yet marked dirty, queue it up
        bne   *+3
        phy

        lda   VBuffOrigin
        sta   (tmp0),y                          ; Fill in the slot for this sprite on this tile

; Move to the next tile

        ldy   TileStoreLookup+2,x

        adc   #4                                ; Weave in the VBuffOrigin values to save a load every
        sta   (tmp0),y                          ; other iteration

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,y
        sta   TileStore+TS_SPRITE_FLAG,y

        lda   TileStore+TS_DIRTY,y
        bne   *+3
        phy

; Third tile

        ldy   TileStoreLookup+TS_LOOKUP_SPAN,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,y
        sta   TileStore+TS_SPRITE_FLAG,y

        lda   TileStore+TS_DIRTY,y
        bne   *+3
        phy

        lda   VBuffOrigin
        adc   #SPRITE_PLANE_SPAN
        sta   (tmp0),y

; Fourth tile

        ldy   TileStoreLookup+TS_LOOKUP_SPAN+2,x

        adc   #4+SPRITE_PLANE_SPAN
        sta   (tmp0),y

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,y
        sta   TileStore+TS_SPRITE_FLAG,y

; Lift this above the last TS_DIRTY check

        ldx   DirtyTileCount

; Check the TS_DIRTY flag for this tile.  We handle it immediately, if needed

        lda   TileStore+TS_DIRTY,y
        bne   skip

; Now, update the Dirty Tile array

        tya
        sta   DirtyTiles,x
        sta   TileStore+TS_DIRTY,y

skip
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

:mark1x1
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_2,y
        rts

; NOTE: If we rework the _PushDirtyTile to use the Y register instead of the X register, we can
;       optimize all of these :mark routines as
;
; :mark1x1
;        jsr   :mark_0_0
;        sty   _Sprites+TILE_STORE_ADDR_1,x
;        stz   _Sprites+TILE_STORE_ADDR_2,y
;        rts

:mark1x2
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
;        sta   _Sprites+TILE_STORE_ADDR_2,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_3,y
        rts

:mark1x3
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
;        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_0_2
;        sta   _Sprites+TILE_STORE_ADDR_3,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_4,y
        rts

:mark2x1
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
;        sta   _Sprites+TILE_STORE_ADDR_2,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_3,y
        rts

:mark2x2
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
;        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_1_0
;        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_1_1
;        sta   _Sprites+TILE_STORE_ADDR_4,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_5,y
        rts

:mark2x3
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
;        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_0_2
;        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_1_0
;        sta   _Sprites+TILE_STORE_ADDR_4,y
        jsr   :mark_1_1
;        sta   _Sprites+TILE_STORE_ADDR_5,y
        jsr   :mark_1_2
;        sta   _Sprites+TILE_STORE_ADDR_6,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_7,y
        rts

:mark3x1
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
;        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_2_0
;        sta   _Sprites+TILE_STORE_ADDR_3,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_4,y
        rts

:mark3x2
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
;        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_2_0
;        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_0_1
;        sta   _Sprites+TILE_STORE_ADDR_4,y
        jsr   :mark_1_1
;        sta   _Sprites+TILE_STORE_ADDR_5,y
        jsr   :mark_2_1
;        sta   _Sprites+TILE_STORE_ADDR_6,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_7,y
        rts

:mark3x3
        jsr   :mark_0_0
;        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
;        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_2_0
;        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_0_1
;        sta   _Sprites+TILE_STORE_ADDR_4,y
        jsr   :mark_1_1
;        sta   _Sprites+TILE_STORE_ADDR_5,y
        jsr   :mark_2_1
;        sta   _Sprites+TILE_STORE_ADDR_6,y
        jsr   :mark_0_2
;        sta   _Sprites+TILE_STORE_ADDR_7,y
        jsr   :mark_1_2
;        sta   _Sprites+TILE_STORE_ADDR_8,y
        jsr   :mark_2_2
;        sta   _Sprites+TILE_STORE_ADDR_9,y
;        lda   #0
;        sta   _Sprites+TILE_STORE_ADDR_10,y
        rts

; Begin List of subroutines to mark each tile offset
:mark_0_0
        ldx   RowTop
        lda   ColLeft
        clc
        adc   TileStoreYTable,x                 ; Fixed offset to the next row
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        sta   [tmp0],y

;        lda   VBuffOrigin                      ; This is an interesting case.  The mapping between the tile store
;        adc   #{0*4}+{0*256}                  ; and the sprite buffers changes as the StartX, StartY values change
;        stal  TileStore+TS_SPRITE_ADDR,x       ; but don't depend on any sprite information.  However, by setting the
                                               ; value only for the tiles that get added to the dirty tile list, we
                                               ; can avoid recalculating over 1,000 values whenever the screen scrolls
                                               ; (which is common) and just limit it to the number of tiles covered by
                                               ; the sprites.  If the screen is not scrolling and the sprites are not
                                               ; moving and they are being dirtied, then we may do more work, but the
                                               ; odds are in our favor to just take care of it here.

        ; lda   TileStore+TS_SPRITE_FLAG,x
        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX                   ; Needs X = tile store offset; destroys A,X.  Returns X in A

:mark_1_0
        lda  ColLeft
        ldx  RowTop
        clc
        adc  TileStoreYTable+2,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{0*4}+{1*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_2_0
        lda  ColLeft
        ldx  RowTop
        clc
        adc  TileStoreYTable+4,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{0*4}+{2*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_0_1
        ldx  ColLeft
        lda  NextCol+2,x
        ldx  RowTop
        clc
        adc  TileStoreYTable,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{1*4}+{0*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_1_1
        ldx  ColLeft
        lda  NextCol+2,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+2,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{1*4}+{1*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_2_1
        ldx  ColLeft
        lda  NextCol+2,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+4,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{1*4}+{2*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_0_2
        ldx  ColLeft
        lda  NextCol+4,x
        ldx  RowTop
        clc
        adc  TileStoreYTable,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{2*4}+{0*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_1_2
        ldx  ColLeft
        lda  NextCol+4,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+2,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{2*4}+{1*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_2_2
        ldx  ColLeft
        lda  NextCol+4,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+4,x
        tax

        ldal  TileStore+TS_VBUFF_ARRAY_ADDR,x
        sta   tmp0

        lda   VBuffOrigin
        adc   #{2*4}+{2*8*SPRITE_PLANE_SPAN}
        sta   [tmp0],y

        lda   SpriteBit
        oral  TileStore+TS_SPRITE_FLAG,x
        stal  TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

; End list of subroutines to mark dirty tiles

; Range-check and clamp the vertical part of the sprite.  When this routine returns we will have valid
; values for the tile-top and row-top.  Also, the accumulator will return the number of rows to render,
; a value of zero means that all of the sprite's rows are off-screen.
;
; This subroutine takes are of calculating the extra tile for unaligned accesses, too.
;_SpriteHeight       dw 8,8,16,16
;_SpriteHeightMinus1 dw 7,7,15,15
;_SpriteRows         dw 1,1,2,2
;_SpriteWidth        dw 4,8,4,8
;_SpriteWidthMinus1  dw 3,7,3,7
;_SpriteCols         dw 1,2,1,2

; Convert sprite index to a bit position
_SpriteBits         dw $0001,$0002,$0004,$0008,$0010,$0020,$0040,$0080,$0100,$0200,$0400,$0800,$1000,$2000,$4000,$8000
_SpriteBitsNot      dw $FFFE,$FFFD,$FFFB,$FFF7,$FFEF,$FFDF,$FFBF,$FF7F,$FEFF,$FDFF,$FBFF,$F7FF,$EFFF,$DFFF,$BFFF,$7FFF
