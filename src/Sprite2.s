; Scratch space to lay out idealized _MakeDirtySprite
;  On input, X register = Sprite Array Index
Left     equ   tmp1
Right    equ   tmp2
Top      equ   tmp3
Bottom   equ   tmp4

TileTop   equ   tmp5
RowTop  equ   tmp6
AreaIndex equ   tmp7

TileLeft   equ   tmp8
ColLeft  equ   tmp9

SpriteBit equ  tmp10     ; set the bit of the value that if the current sprite index
VBuffOrigin equ tmp11

; Marks asprite as dirty.  The work here is mapping from local screen coordinates to the 
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
mdsOut  rts
_MarkDirtySprite

        stz   _Sprites+TILE_STORE_ADDR_1,x       ; Clear the this sprite's dirty tile list in case of an early exit
        lda   _SpriteBits,x
        sta   SpriteBit

; Clip the sprite's extent to the screen so we can assume (mostly) position values from here on out.  Note that
; the sprite width and height are _only_ used in the clip and afterward all calculation use the clip rect
;
; OPTIMIZATION NODE: These values can be calculated in AddSprite/MoveSprite once and stored in the sprite
;                    record since the screen size doesn't change.

        lda   _Sprites+SPRITE_ID,x               ; Get an index into the height/width tables based on the sprite bits
        and   #$1800
        xba
        lsr
        lsr
        tay

        lda   _Sprites+SPRITE_X,x
        bpl   :pos_x
        lda   #0
:pos_x  cmp   ScreenWidth
        bcs   mdsOut                             ; sprite is off-screen, exit early
        sta   Left

        lda   _Sprites+SPRITE_Y,x
        bpl   :pos_y
        lda   #0
:pos_y  cmp   ScreenHeight
        bcs   mdsOut                             ; sprite is off-screen, exit early
        sta   Top

        lda   _Sprites+SPRITE_X,x
        clc
        adc   _SpriteWidthMinus1,y
        bmi   mdsOut                             ; another off-screen test
        cmp   ScreenWidth
        bcc   :ok_x
        lda   ScreenWidth
        dec
:ok_x   sta   Right

        lda   _Sprites+SPRITE_Y,x
        clc
        adc   _SpriteHeightMinus1,y
        bmi   mdsOut                             ; another off-screen test
        cmp   ScreenHeight
        bcc   :ok_y
        lda   ScreenHeight
        dec
:ok_y   sta   Bottom

; At this point we know that we have to update the tiles that overlap the sprite plane rectangle defined
; by (Top, Left), (Bottom, Right).  The general process is to figure out the top-left coordinate in the
; sprite plane that matches up with the code field and then calculate the number of tiles in each direction
; that need to be dirtied to cover the sprite.

        clc
        lda   Top
        adc   StartYMod208                       ; Adjust for the scroll offset (could be a negative number!)
        tay                                      ; Save this value
        and   #$0007                             ; Get (StartY + SpriteY) mod 8
        eor   #$FFFF
        inc
        clc
        adc   Top                                ; subtract from the Y position (possible to go negative here)
        sta   TileTop                            ; This position will line up with the tile that the sprite overlaps with

        tya                                      ; Get back the position of the sprite top in the code field
        cmp   #208                               ; check if we went too far positive
        bcc   *+5
        sbc   #208
        lsr
        lsr
;        lsr                                      ; This is the row in the Tile Store for top-left corner of the sprite
        and   #$FFFE                              ; Store the pre-multiplied by 2 for indexing in the :mark_R_C routines
        sta   RowTop

        lda   Bottom                             ; Figure out how many tiles are needed to cover the sprite's area
        sec
        sbc   TileTop
        and   #$0018                             ; Clear out the lower bits and stash in bits 4 and 5
        sta   AreaIndex

; Repeat to get the same information for the columns

        clc
        lda   Left
        adc   StartXMod164
        tay
        and   #$0003
        eor   #$FFFF
        inc
        clc
        adc   Left
        sta   TileLeft

        tya
        cmp   #164
        bcc   *+5
        sbc   #164
        lsr
;        lsr
        and   #$FFFE                             ; Same pre-multiply by 2 for later
        sta   ColLeft

; Sneak a pre-calculation here. Calculate the upper-left corder of the sprite in the sprite plane.
; We can reuse this in all of the routines below

        clc
        lda   TileTop
        adc   #NUM_BUFF_LINES
        xba
        clc
        adc   TileLeft
        sta   VBuffOrigin                     ; Save once to use later (constant offsets)

; Calculate the number of columns and dispatch

        txy                                   ; Swap the sprite index into the Y register

        lda   Right
        sec
        sbc   TileLeft
        and   #$000C
        lsr                                   ; bit 0 is always zero and width stored in bits 1 and 2
        ora   AreaIndex
        tax
        jmp   (:mark,x)
:mark   dw    :mark1x1,:mark1x2,:mark1x3,mdsOut
        dw    :mark2x1,:mark2x2,:mark2x3,mdsOut
        dw    :mark3x1,:mark3x2,:mark3x3,mdsOut
        dw    mdsOut,mdsOut,mdsOut,mdsOut

; Dispatch to the calculated sizing

; Begin a list of subroutines to cover all of the valid sprite size compinations.  This is all unrolled code,
; maily to be able to do an unrolled fill of the TILE_STORE_ADDR_X values.  Thus, it's important that the clipping
; function does its job properly since it allows up to save a lot of time here.
;
; These functional are a trade off of being composable versus fast.  Having to pay for multiple JSR/RTS invoations
; in the hot sprite path isn't great, but we're at a point of diminishing returns.
;
; There *might* be some speed gained by pushing a list of :mark_R_C addressed onto the stack in the clipping routing
; and dispatching that way, but probably not...
:mark1x1
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_2,y
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
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
        sta   _Sprites+TILE_STORE_ADDR_2,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_3,y
        rts

:mark1x3
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_0_2
        sta   _Sprites+TILE_STORE_ADDR_3,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_4,y
        rts

:mark2x1
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
        sta   _Sprites+TILE_STORE_ADDR_2,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_3,y
        rts

:mark2x2
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_1_0
        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_1_1
        sta   _Sprites+TILE_STORE_ADDR_4,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_5,y
        rts

:mark2x3
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_0_1
        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_0_2
        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_1_0
        sta   _Sprites+TILE_STORE_ADDR_4,y
        jsr   :mark_1_1
        sta   _Sprites+TILE_STORE_ADDR_5,y
        jsr   :mark_1_2
        sta   _Sprites+TILE_STORE_ADDR_6,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_7,y
        rts

:mark3x1
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_2_0
        sta   _Sprites+TILE_STORE_ADDR_3,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_4,y
        rts

:mark3x2
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_2_0
        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_0_1
        sta   _Sprites+TILE_STORE_ADDR_4,y
        jsr   :mark_1_1
        sta   _Sprites+TILE_STORE_ADDR_5,y
        jsr   :mark_2_1
        sta   _Sprites+TILE_STORE_ADDR_6,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_7,y
        rts

:mark3x3
        jsr   :mark_0_0
        sta   _Sprites+TILE_STORE_ADDR_1,y
        jsr   :mark_1_0
        sta   _Sprites+TILE_STORE_ADDR_2,y
        jsr   :mark_2_0
        sta   _Sprites+TILE_STORE_ADDR_3,y
        jsr   :mark_0_1
        sta   _Sprites+TILE_STORE_ADDR_4,y
        jsr   :mark_1_1
        sta   _Sprites+TILE_STORE_ADDR_5,y
        jsr   :mark_2_1
        sta   _Sprites+TILE_STORE_ADDR_6,y
        jsr   :mark_0_2
        sta   _Sprites+TILE_STORE_ADDR_7,y
        jsr   :mark_1_2
        sta   _Sprites+TILE_STORE_ADDR_8,y
        jsr   :mark_2_2
        sta   _Sprites+TILE_STORE_ADDR_9,y
        lda   #0
        sta   _Sprites+TILE_STORE_ADDR_10,y
        rts

; Begin List of subroutines to mark each tile offset

:mark_0_0
        ldx  RowTop
        lda  ColLeft
        clc
        adc  TileStoreYTable,x                 ; Fixed offset to the next row
        tax                                    ; This is the tile store offset

        lda   VBuffOrigin
;        adc   #{0*4}+{0*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX                   ; Needs X = tile store offset; destroys A,X.  Returns X in A

:mark_1_0
        lda  ColLeft
        ldx  RowTop
        clc
        adc  TileStoreYTable+2,x
        tax

        lda   VBuffOrigin
        adc   #{0*4}+{1*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_2_0
        lda  ColLeft
        ldx  RowTop
        clc
        adc  TileStoreYTable+4,x
        tax

        lda   VBuffOrigin
        adc   #{0*4}+{2*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_0_1
        ldx  ColLeft
        lda  NextCol+2,x
        ldx  RowTop
        clc
        adc  TileStoreYTable,x
        tax

        lda   VBuffOrigin
        adc   #{1*4}+{0*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_1_1
        ldx  ColLeft
        lda  NextCol+2,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+2,x
        tax

        lda   VBuffOrigin
        adc   #{1*4}+{1*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_2_1
        ldx  ColLeft
        lda  NextCol+2,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+4,x
        tax

        lda   VBuffOrigin
        adc   #{1*4}+{2*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_0_2
        ldx  ColLeft
        lda  NextCol+4,x
        ldx  RowTop
        clc
        adc  TileStoreYTable,x
        tax

        lda   VBuffOrigin
        adc   #{2*4}+{0*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_1_2
        ldx  ColLeft
        lda  NextCol+4,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+2,x
        tax

        lda   VBuffOrigin
        adc   #{2*4}+{1*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

:mark_2_2
        ldx  ColLeft
        lda  NextCol+4,x
        ldx  RowTop
        clc
        adc  TileStoreYTable+4,x
        tax

        lda   VBuffOrigin
        adc   #{2*4}+{2*8*256}
        sta   TileStore+TS_SPRITE_ADDR,x

        lda   SpriteBit
        ora   TileStore+TS_SPRITE_FLAG,x
        sta   TileStore+TS_SPRITE_FLAG,x

        jmp   _PushDirtyTileX

; End list of subroutines to mark dirty tiles

; Range-check and clamp the vertical part of the sprite.  When this routine returns we will have valid
; values for the tile-top and row-top.  Also, the accumulator will return the number of rows to render,
; a value of zero means that all of the sprite's rows are off-screen.
;
; This subroutine takes are of calculating the extra tile for unaligned accesses, too.
_SpriteHeight       dw 8,8,16,16
_SpriteHeightMinus1 dw 7,7,15,15
_SpriteRows         dw 1,1,2,2
_SpriteWidth        dw 4,8,4,8
_SpriteWidthMinus1  dw 3,7,3,7
_SpriteCols         dw 1,2,1,2

; Convert sprite index to a bit position
_SpriteBits         dw $0001,$0002,$0004,$0008,$0010,$0020,$0040,$0080,$0100,$0200,$0400,$0800,$1000,$2000,$4000,$8000
_SpriteBitsNot      dw $FFFE,$FFFD,$FFFB,$FFF7,$FFEF,$FFDF,$FFBF,$FF7F,$FEFF,$FDFF,$FBFF,$F7FF,$EFFF,$DFFF,$BFFF,$7FFF
