; Scratch space to lay out idealized _MakeDirtySprite
;  On input, X register = Sprite Array Index

RowTop      equ   tmp6
AreaIndex   equ   tmp7
SpriteBit   equ   tmp8     ; set the bit of the value that if the current sprite index

; Table of pre-multiplied vbuff strides
vbuff_mul
        dw  0*VBUFF_STRIDE_BYTES
        dw  1*VBUFF_STRIDE_BYTES
        dw  2*VBUFF_STRIDE_BYTES
        dw  3*VBUFF_STRIDE_BYTES
        dw  4*VBUFF_STRIDE_BYTES
        dw  5*VBUFF_STRIDE_BYTES
        dw  6*VBUFF_STRIDE_BYTES
        dw  7*VBUFF_STRIDE_BYTES

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
; For the Y-coordinate, we use "mod 8" instead of "mod 4"
;
; When this subroutine is completed, the following values will be calculated
;
;  _Sprites+TS_COVERAGE_SIZE : The number of horizontal and vertical playfield tiles covered by the sprite
;  _Sprites+TS_LOOKUP_INDEX  : TileStore index of the upper-left corner of the sprite
;  _Sprites+TS_VBUFF_BASE    : Address of the top-left corner of the sprite in the VBUFF sprite stamp memory
;
; The clipped sprite coordinates are used to calculate the tiles that are visible, but the actual 
; sprite coordinates (including handling negative values) are used to calculate the VBUFF offset
; values.
mdsOut2
        lda   #6                                 ; Pick a value for a 0x0 tile sprite
        sta   _Sprites+TS_COVERAGE_SIZE,y         ; zero the list of tile store addresses
        rts

_CalcDirtySprite
        lda   _Sprites+IS_OFF_SCREEN,y           ; Check if the sprite is visible in the playfield
        bne   mdsOut2

; Part 1: Calculate the visible tiles that the sprite covers.  If the sprite is partially
;         off-screen, then the visible tiles may be different than the set of tiles
;         covered by the sprite.  In particular, the upper-left corner tile which defines
;         relative offset values will change.
;
;         So, we do some calculations with the CLIPPED values and some with the actual
;         sprite values.  There is an optimization opportunity here to share calculations
;         when the x or y position of the sprite is positive.

; Add the first visible row of the sprite to the Y-scroll offset to find the first line in the
; code field that needs to be drawn.  The range of values is 0 to 199+207 = [0, 406]. This
; value is dividede by 8, so the range of lookup values is [0, 50], so 51 possible values.

        clc
        lda   _Sprites+SPRITE_CLIP_TOP,y
        adc   StartYMod208                       ; Adjust for the scroll offset
        pha                                      ; Cache
        and   #$FFF8                             ; mask first to ensure LSR will clear the carry
        lsr
        lsr
        tax
        lda   TileStoreLookupYTable,x
        sta   RowTop                             ; Even numbers from [0, 100] (51 elements)

; Get the position of the top edge within the tile and then add it to the sprite's height
; to calculate the number of tiles that are overlapped.  We use the actual width and height
; values here so small sprites (like 4x4 bullets) only force an update to the actual tiles
; that are intersected, rather than assuming an 8x8 sprite always takes up that amount of
; space.

        pla
        and   #$0007
        adc   _Sprites+SPRITE_CLIP_HEIGHT,y       ; Nominal value between 0 and 16+7 = 23 = 10111
        dec
        and   #$0018
        sta   AreaIndex

; Add the horizontal position to the horizontal offset to find the first column in the
; code field that needs to be drawn.  The range of values is 0 to 159+163 = [0, 322]. 
; This value is divided by 4, so 81 possible values

        clc
        lda   _Sprites+SPRITE_CLIP_LEFT,y
        adc   StartXMod164
        pha
        and   #$FFFC
        lsr                                       ; Even numbers from [0, 160] (81 elements)
        adc   RowTop
        sta   _Sprites+TS_LOOKUP_INDEX,y          ; This is the index into the TileStoreLookup table


; Calculate the final amount of visible tiles that need to be refreshed and use that to
; set the coverage size index.

        pla
        and   #$0003
        adc   _Sprites+SPRITE_CLIP_WIDTH,y       ; max width = 8 = 0x08
        dec
        and   #$000C
        lsr                                      ; max value = 4 = 0x04
        ora   AreaIndex                          ; merge into the area index
        sta   _Sprites+TS_COVERAGE_SIZE,y        ; Save this value as a key to the coverage size of the sprite


; Part 2: Redo some calculation with the actual (signed) sprite positions that take into
;         account negative coordinates to set the VBuff offset values.

        clc
        lda   _Sprites+SPRITE_Y,y
        adc   StartYMod208
        bpl   :y_ok
        clc
        adc   #208                               ; Wrap the actual coordinat around
:y_ok   and   #$FFF8                             ; mask first to ensure LSR will clear the carry
        lsr
        lsr
        tax                                      ; Tile store lookup index

        lda   _Sprites+SPRITE_X,y
        adc   StartXMod164
        bpl   :x_ok
        clc
        adc   #164
:x_ok   and   #$FFFC
        lsr                                       ; Even numbers from [0, 160] (81 elements)
        sta   tmp3
        adc   TileStoreLookupYTable,x
        pha                                       ; will be PLX later

        clc                                       ; Carry should still be clear here....
        lda   StartYMod208
        adc   _Sprites+SPRITE_Y,y
        bpl   :pos_y
        clc
        adc   #208
:pos_y
        and   #$0007
        asl                                       ; Multiply by 48.  Would be nice to use a 
        asl                                       ; table lookup, but the values can be negative
        asl                                       ; so do the calculation
        asl
        sta   tmp0
        asl
        clc
        adc   tmp0
        sta   tmp0

; Calculate the final address of the sprite data in the stamp buffer. We have to move earlier 
; in the buffer based on the horizontal offset and move up for each vertical offset.
;
; For a negative value we need to adjust the vbuff by the number of off-screen tiles plus
; the alignment adjustment.

        clc
        lda   StartXMod164
        adc   _Sprites+SPRITE_X,y
        bpl   :pos_x
        clc
        adc   #164
:pos_x
        and   #$0003
        clc
        adc   tmp0                               ; add to the vertical offset

; Subtract this value from the SPRITE_DISP address

        eor   #$FFFF                             ; A = -X - 1
        sec                                      ; C = 1
        adc   _Sprites+SPRITE_DISP,y             ; A = SPRITE_DISP + (-X - 1) + 1 = SPRITE_DISP - X
        sta   _Sprites+TS_VBUFF_BASE,y

; Create an offset value for loading the calculated VBUFF addresses within the core renderer by
; subtracting the actual TileStore offset from the sprite's vbuff address array
;
; The X-register still has the TileStoreLookupYTable index, which we re-use to get a VBuff
; array selector for the vertical location

        lda   VBuffVertTableSelect,x              ; A bunch of 0, 12 or 24 values
        clc
        ldx   tmp3
        adc   VBuffHorzTableSelect,x              ; A bunch of 0, 4 or 8 values
        clc
        adc   #VBuffArray
        plx
;        ldx   _Sprites+TS_LOOKUP_INDEX,y
        sec
        sbc   TileStoreLookup,x
        sta   tmp1                                ; Spill this value to direct page temp space

; Last task. Since we don't need to use the X-register to cache values; load the direct page 2 
; offset for the SPRITE_VBUFF_PTR and save it

tmp_out
        tya
        ora   #$100
        tax
        lda   tmp1
        sta   SPRITE_VBUFF_PTR,x

mdsOut  rts


; NOTE: The VBuffArray table is set up so that each sprite's vbuff address is stored in a
;       parallel structure to the Tile Store.  This allows up to use the same TileStoreLookup
;       offset to index into the array of 16 sprite VBUFF addresses that are bound to a given tile
_MarkDirtySpriteTiles
        lda    _SpriteBits,y
        sta    SpriteBit

        clc
        ldx    _Sprites+TS_COVERAGE_SIZE,y
        jmp    (mdsmark,x)

mdsmark dw    :mark1x1,:mark1x2,:mark1x3,mdsOut
        dw    :mark2x1,:mark2x2,:mark2x3,mdsOut
        dw    :mark3x1,:mark3x2,:mark3x3,mdsOut
        dw    mdsOut,mdsOut,mdsOut,mdsOut

; Pair of macros to make the unrolled loop more concise
;
;   1. Load the tile store address from a fixed offset
;   2. Set the sprite bit from the TS_SPRITE_FLAG location
;   3. Checks if the tile is dirty and marks it
;   4. If the tile was dirty, save the tile store address to be added to the DirtyTiles list later
;   5. Sets the VBUFF address for the current sprite slot
;
; The second macro is the same as the first, but the VBUFF calculation is moved up so that the value
; from the previous step can be reused and save a load every other step.
TSSetSprite mac
        ldy   TileStoreLookup+{]1},x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,y
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

ROW     equ TILE_STORE_WIDTH*2                      ; This many bytes to the next row in TileStore coordinates
COL     equ 2                                       ; This many bytes for each element

:mark1x1
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite   0*{TS_LOOKUP_SPAN*2}
        rts

:mark1x2
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+2
        rts

:mark1x3
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+4
        rts

:mark2x1
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+0
        rts

:mark2x2
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+2
        rts

:mark2x3
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+4
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+4
        rts

:mark3x1
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  2*{TS_LOOKUP_SPAN*2}+0
        rts

:mark3x2
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  2*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  2*{TS_LOOKUP_SPAN*2}+2
        rts

:mark3x3
        ldx   _Sprites+TS_LOOKUP_INDEX,y
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  0*{TS_LOOKUP_SPAN*2}+4
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  1*{TS_LOOKUP_SPAN*2}+4
        TSSetSprite  2*{TS_LOOKUP_SPAN*2}+0
        TSSetSprite  2*{TS_LOOKUP_SPAN*2}+2
        TSSetSprite  2*{TS_LOOKUP_SPAN*2}+4
        rts
