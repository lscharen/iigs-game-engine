; Routines for handling tilemaps
;
; This module contains higher-level functions than the low-level tile rendering routines.  The
; goal here is to take a rectangular tilemap data structure and efficiently render it into
; code buffer.  Especially important is to only draw new tiles as they come into view.
;
; Also, we maintain a tilemap cache to track the current state of the tiles rendered into
; the code field so if, by chance, a tile that comes into view is the same as a tile that
; has already been drawn, then there is no reason to update it.  This happen quite often
; in actual games since the primary background is often large empty areas, or runs
; of repeating tiles.

; The ranges are [:Left, :Right] and [:Top, :Bottom], so :Right can be, at most, 40
; if we are drawing all 41 tiles (Index 0 through 40).  The :Bottom value can be
; at most 25.
MAX_TILE_X         equ   40
MAX_TILE_Y         equ   25

; _UpdateBG0TileMap
;
; Fill in dirty tiles into the BG0 buffer.
;
; A = $FFFF re-render the entire playfield.  Otherwise only render difference from the old
;     coordinates.
_UpdateBG0TileMap
:Left              equ   tmp0
:Right             equ   tmp1
:Top               equ   tmp2
:Bottom            equ   tmp3

:Width             equ   tmp4                    ; Used in DrawRectBG0
:Height            equ   tmp5

:MulA              equ   tmp6                    ; Scratch space for multiplication
:MulB              equ   tmp7

:Offset            equ   tmp8                    ; Address offset into the tilemap
:Span              equ   tmp9

:GlobalTileIdxX    equ   tmp10
:GlobalTileIdxY    equ   tmp11

:BlkX              equ   tmp12
:BlkY              equ   tmp13

                   lda   TileMapPtr              ; Do nothing if no data is set
                   ora   TileMapPtr+2
                   bne   :valid
                   rts

:valid
                   lda   StartY                  ; calculate the tile index of the current location
                   lsr
                   lsr
                   lsr
                   sta   BG0TileOriginY

                   lda   OldStartY
                   lsr
                   lsr
                   lsr
                   sta   OldBG0TileOriginY

                   lda   StartX
                   lsr
                   lsr
                   sta   BG0TileOriginX

                   lda   OldStartX
                   lsr
                   lsr
                   sta   OldBG0TileOriginX

; Figure out the two rectangular regions that need to be updated. We check for changes in Y-direction
; first because it's a bit more efficient to redraw tiles in long horizontal strips, because we do not
; have to skip to different banks.
;
; +---------------------------+----------+ <-- Top
; |                           |          |
; |                           |   New    |
; |                           |          |
; |       Old Area            | (drawn)  |
; |                           | (second) |
; |                           |          |
; +---------------------------+==========|
; |                                      |
; |   New Area (drawn first)             |
; |                                      |
; +--------------------------------------+ <-- Bottom
; ^                                      ^
; |                                      |
; +--- Left                      Right --+

                   stz   :Left                   ; prepare to do the entire screen
                   lda   ScreenTileWidth         ; and then whack off the parts
                   sta   :Right                  ; that are not needed

                   stz   :Top                    ; since the ranges are inclusive, we are 
                   lda   ScreenTileHeight        ; always going to be drawing width+1 tiles
                   sta   :Bottom                 ; which takes care of edge tiles.

; If we are supposed to refresh the whole field, just do that and return

                   lda   #DIRTY_BIT_BG0_REFRESH
                   bit   DirtyBits
                   beq   :NoRefresh
                   trb   DirtyBits               ; Clear the dirty bit
:FullScreen        jmp   :DrawRectBG0            ; Let the DrawRectBG0 RTS take care of the return for us

:NoRefresh
                   lda   BG0TileOriginY
                   cmp   OldBG0TileOriginY
                   beq   :NoYUpdate              ; if equal, don't change Y

                   sec
                   sbc   OldBG0TileOriginY       ; find the difference; D = Y_new - Y_old
                   bpl   :DoBottom               ; if we scrolled up, fill in the bottom row(s)

                   eor   #$FFFF                  ; if we scrolled down, Y_new < Y_old and we need
                   cmp   :Bottom                 ; to fill in the top row(s) from 0 to Y_new - Y_old - 1
                   bcs   :FullScreen             ; If the displacement was very large, just fill in the whole screen

                   sta   :Bottom
                   bra   :DoYUpdate

:DoBottom
                   eor   #$FFFF                  ; same explanation as above, except we are filling in from
                   inc                           ; Bottom - (Y_new - Y_old) to Bottom
                   clc
                   adc   ScreenTileHeight
                   bmi   :FullScreen
                   sta   :Top

:DoYUpdate
                   jsr   :DrawRectBG0            ; Fill in the rectangle.

; We performed an update in the Y-direction, so now change the bounds so
; an update in the X-direction will not draw too many rows
;
; +---------------------------+----------+
; |                           |          |
; |                           |   New    |
; |                           |          |
; |       Old Area            | (drawn)  |
; |                           | (second) |
; |                           |          |
; +---------------------------+==========| <-- Top
; |//////////////////////////////////////|
; |// New Area (drawn first) ////////////|
; |//////////////////////////////////////|
; +--------------------------------------+ <-- Bottom
; ^                                      ^
; |                                      |
; +--- Left                      Right --+

                   lda   :Top
                   beq   :drewTop
                   dec                           ; already did Y to HEIGHT, so only need to draw from 
                   sta   :Bottom                 ; 0 to (Y-1) for any horizontal updates
                   stz   :Top
                   bra   :NoYUpdate

:drewTop
                   lda   :Bottom                 ; opposite, did 0 to Y
                   inc                           ; so do Y+1 to HEIGHT
                   sta   :Top
                   lda   ScreenTileHeight
                   sta   :Bottom

; +---------------------------+----------+ <-- Top
; |                           |          |
; |                           |   New    |
; |                           |          |
; |       Old Area            | (drawn)  |
; |                           | (second) |
; |                           |          | <-- Bottom
; +---------------------------+==========| 
; |//////////////////////////////////////|
; |// New Area (drawn first) ////////////|
; |//////////////////////////////////////|
; +--------------------------------------+
; ^                                      ^
; |                                      |
; +--- Left                      Right --+

; The Top an Bottom are set the the correct values to draw in whatever potential range of tiles
; need to be draws if there was any horizontal displacement
:NoYUpdate
                   lda   BG0TileOriginX          ; Did the first column of the tile map change from before?
                   cmp   OldBG0TileOriginX       ; Did it change from before?
                   beq   :NoXUpdate              ; no, so we can ignore this

                   sec
                   sbc   OldBG0TileOriginX       ; find the difference
                   bpl   :DoRightSide            ; did we move in a pos or neg?

; Handle the two sides in an analagous way as the vertical code

                   eor   #$FFFF
                   cmp   :Right
                   bcs   :FullScreen
                   sta   :Right
                   bra   :DoXUpdate

:DoRightSide
                   eor   #$FFFF
                   inc
                   clc
                   adc   ScreenTileWidth
                   bmi   :FullScreen
                   sta   :Left

:DoXUpdate
                   jsr   :DrawRectBG0            ; Fill in the rectangle.

:NoXUpdate
                   rts

; This is a private subroutine that draws in tiles into the code fields using the
; data from the tilemap and the local :Top, :Left, :Bottom and :Right parameters.
:DrawRectBG0
                   lda   :Bottom
                   sec
                   sbc   :Top
                   inc
                   sta   :Height                 ; Maximum value of 26 (top = 0, bottom = 25)

                   lda   :Right
                   sec
                   sbc   :Left
                   inc
                   sta   :Width                  ; Maximum value of 41 (left = 0, right = 40)

; Compute the offset into the tile array of the top-left corner

                   lda   :Left
                   clc
                   adc   BG0TileOriginX
                   sta   :GlobalTileIdxX

                   lda   :Top
                   clc
                   adc   BG0TileOriginY          ; This is the global verical index
                   sta   :GlobalTileIdxY

                   ldx   TileMapWidth
                   jsr   :MulAX
                   clc
                   adc   :GlobalTileIdxX
                   asl                           ; Double for word sizes
                   sta   :Offset                 ; Stash the pointer offset in Y

; Draw the tiles
                   lda   TileMapWidth
                   sec
                   sbc   :Width
                   asl                           ; This is the number of bytes to move the Offset to advance from the end of
                   sta   :Span                   ; one line to the beginning of the next

; Now we need to figure out the code field tile coordinate of corner of
; play field.  That is, becuase the screen is scrolling, the location of 
; tile (0, 0) could be anywhere within the code field

                   lda   StartYMod208            ; This is the code field line that is at the top of the screen
                   and   #$FFF8                  ; Clamp to the nearest block
                   lsr
                   lsr
                   lsr                           ; Could optimize because the Tile code shifts back....
                   clc
                   adc   :Top
                   cmp   #MAX_TILE_Y+1           ; Top can be less than or equal to 25
                   bcc   *+5
                   sbc   #MAX_TILE_Y+1
                   sta   :BlkY                   ; This is the Y-block we start drawing from

                   lda   StartXMod164            ; Do the same thing for X, except only need to clamp by 4
                   and   #$FFFC
                   lsr
                   lsr
                   clc
                   adc   :Left
                   cmp   #MAX_TILE_X+1           ; Left can be less than or equal to 40
                   bcc   *+5
                   sbc   #MAX_TILE_X+1
                   sta   :BlkX

; Call the copy tile routine to blit the tile data into the playfield
;
; A = Tile ID (0 - 1023)
; X = Tile column (0 - 40)
; Y = Tile row (0 - 25)

                   pha                           ; cache the starting X-block index to restore later
                   pei   :Width                  ; cache the Width value to restore later
:yloop
:xloop
                   ldy   :Offset                 ; Set up the arguments and call the tile blitter
                   lda   [TileMapPtr],y

; Handle fringe tiles -- if the fringe bit is set, then we need to get the fringe tile index
; and merge the tiles before rendering

;                   bit   #TILE_FRINGE_BIT
;                   beq   :no_fringe
;                   jsr   _GetTileAddr
;                   tax
;                   lda   FringeMapPtr
;                   ora   FringeMapPtr+2
;                   beq   :no_fringe
;                   lda   [FringeMapPtr],y
;                   jsr   _GetTileAddr
;                   tay
;                   jsr   _MergeTiles
;
;:no_fringe
                   inc   :Offset                 ; pre-increment the address.
                   inc   :Offset

                   ldx   :BlkX
                   ldy   :BlkY
                   jsr    _SetTile               ; set the value in the tile store

                   lda   :BlkX
                   inc
                   cmp   #MAX_TILE_X+1           ; If we go past the maximum block index, wrap around
                   bcc   *+5
                   lda   #0
                   sta   :BlkX

                   dec   :Width                  ; Decrement out count
                   bne   :xloop

                   lda   :Offset                 ; Move to the next line of the Tile Map
                   clc
                   adc   :Span
                   sta   :Offset

                   lda   3,s                     ; Reset the BlkX
                   sta   :BlkX

                   lda   1,s                     ; Reset the width
                   sta   :Width

                   lda   :BlkY                   ; The y lookup has a double-length array, may not need the bounds check
                   inc
                   cmp   #MAX_TILE_Y+1
                   bcc   *+5
                   lda   #0
                   sta   :BlkY

                   dec   :Height                 ; Have we done all of the rows?
                   bne   :yloop

                   pla                           ; Pop off cached values
                   pla

                   rts

; Quick multiplication of the accumulator and x-register
; A = A * X
:MulAX
                   stx   :MulA
                   cmp   :MulA                   ; Put the smaller value in MulA (less shifts on average)
                   bcc   :swap
                   sta   :MulB
                   bra   :entry
:swap              stx   :MulB
                   sta   :MulA

:entry
                   lda   #0

; Start shifting and adding.  We actually do an extra
; shift if MulA is zero, but a zero value does not
; change the result and it allows us to eliminate a 
; branch on the inner loop

:loop
                   lsr   :MulA                   ; shift out the LSB
                   bcc   :skip                   ; zero is no multiply
                   clc
                   adc   :MulB

:skip
                   asl   :MulB                   ; double the multplicand
                   ldx   :MulA
                   bne   :loop

                   rts

; Exact same logic as _UpdateBG0TileMap, except for the other background
_UpdateBG1TileMap
:Left              equ   tmp0
:Right             equ   tmp1
:Top               equ   tmp2
:Bottom            equ   tmp3

                   lda   BG1TileMapPtr           ; Do nothing if no data is set
                   ora   BG1TileMapPtr+2
                   bne   :valid
                   rts

:valid
                   lda   BG1StartY               ; calculate the tile index of the current location
                   lsr
                   lsr
                   lsr
                   sta   BG1TileOriginY

                   lda   OldBG1StartY
                   lsr
                   lsr
                   lsr
                   sta   OldBG1TileOriginY

                   lda   BG1StartX
                   lsr
                   lsr
                   sta   BG1TileOriginX

                   lda   OldBG1StartX
                   lsr
                   lsr
                   sta   OldBG1TileOriginX

; Figure out the two rectangular regions that need to be updated. 

                   stz   :Left                   ; prepare to do the entire screen
                   lda   ScreenTileWidth         ; and then whack off the parts
                   sta   :Right                  ; that are not needed

                   stz   :Top                    ; since the ranges are inclusive, we are 
                   lda   ScreenTileHeight        ; always going to be drawing width+1 tiles
                   sta   :Bottom                 ; which takes care of edge tiles.

; If we are supposed to refresh the whole field, just do that and return

                   lda   #DIRTY_BIT_BG1_REFRESH
                   bit   DirtyBits
                   beq   :NoRefresh
                   trb   DirtyBits               ; Clear the dirty bit
:FullScreen        jmp   _DrawRectBG1            ; Let the DrawRectBG1 RTS take care of the return for us

:NoRefresh
                   lda   BG1TileOriginY
                   cmp   OldBG1TileOriginY
                   beq   :NoYUpdate              ; if equal, don't change Y

                   sec
                   sbc   OldBG1TileOriginY       ; find the difference; D = Y_new - Y_old
                   bpl   :DoBottom               ; if we scrolled up, fill in the bottom row(s)

                   eor   #$FFFF                  ; if we scrolled down, Y_new < Y_old and we need
                   cmp   :Bottom                 ; to fill in the top row(s) from 0 to Y_new - Y_old - 1
                   bcs   :FullScreen             ; If the displacement was very large, just fill in the whole screen

                   sta   :Bottom
                   bra   :DoYUpdate

:DoBottom
                   eor   #$FFFF                  ; same explanation as above, except we are filling in from
                   inc                           ; Bottom - (Y_new - Y_old) to Bottom
                   clc
                   adc   ScreenTileHeight
                   bmi   :FullScreen
                   sta   :Top

:DoYUpdate
                   jsr   _DrawRectBG1            ; Fill in the rectangle.

; We performed an update in the Y-direction, so now change the bounds so
; an update in the X-direction will not draw too many rows

                   lda   :Top
                   beq   :drewTop
                   dec                           ; already did Y to HEIGHT, so only need to draw from 
                   sta   :Bottom                 ; 0 to (Y-1) for any horizontal updates
                   stz   :Top
                   bra   :NoYUpdate

:drewTop
                   lda   :Bottom                 ; opposite, did 0 to Y
                   inc                           ; so do Y+1 to HEIGHT
                   sta   :Top
                   lda   ScreenTileHeight
                   sta   :Bottom

; The Top and Bottom are set the the correct values to draw in whatever potential range of tiles
; need to be draws if there was any horizontal displacement
:NoYUpdate
                   lda   BG1TileOriginX          ; Did the first column of the tile map change from before?
                   cmp   OldBG1TileOriginX       ; Did it change from before?
                   beq   :NoXUpdate              ; no, so we can ignore this

                   sec
                   sbc   OldBG1TileOriginX       ; find the difference
                   bpl   :DoRightSide            ; did we move in a pos or neg?

; Handle the two sides in an analagous way as the vertical code

                   eor   #$FFFF
                   cmp   :Right
                   bcs   :FullScreen
                   sta   :Right
                   bra   :DoXUpdate

:DoRightSide
                   eor   #$FFFF
                   inc
                   clc
                   adc   ScreenTileWidth
                   bmi   :FullScreen
                   sta   :Left

:DoXUpdate
                   jmp   _DrawRectBG1            ; Fill in the rectangle.

:NoXUpdate
                   rts

; This is a private subroutine that draws in tiles into the code fields using the
; data from the tilemap and the local :Top, :Left, :Bottom and :Right parameters.
_DrawRectBG1
:Left              equ   tmp0
:Right             equ   tmp1
:Top               equ   tmp2
:Bottom            equ   tmp3

:Width             equ   tmp4
:Height            equ   tmp5

:MulA              equ   tmp6                    ; Scratch space for multiplication
:MulB              equ   tmp7

:Offset            equ   tmp8                    ; Address offset into the tilemap
:Span              equ   tmp9

:GlobalTileIdxX    equ   tmp10
:GlobalTileIdxY    equ   tmp11

:BlkX              equ   tmp12
:BlkY              equ   tmp13

                   lda   :Bottom
                   sec
                   sbc   :Top
                   inc
                   sta   :Height                 ; Maximum value of 26 (top = 0, bottom = 25)

                   lda   :Right
                   sec
                   sbc   :Left
                   inc
                   sta   :Width                  ; Maximum value of 41 (left = 0, right = 40)

; Compute the offset into the tile array of the top-left corner

                   lda   :Left
                   clc
                   adc   BG1TileOriginX
                   sta   :GlobalTileIdxX

                   lda   :Top
                   clc
                   adc   BG1TileOriginY          ; This is the global verical index
                   sta   :GlobalTileIdxY

                   ldx   BG1TileMapWidth
                   jsr   :MulAX
                   clc
                   adc   :GlobalTileIdxX
                   asl                           ; Double for word sizes
                   sta   :Offset                 ; Stash the pointer offset in Y

; Draw the tiles
                   lda   BG1TileMapWidth
                   sec
                   sbc   :Width
                   asl                           ; This is the number of bytes to move the Offset to advance from the end of
                   sta   :Span                   ; one line to the beginning of the next

; Now we need to figure out the tile coordinate of corner of play field.

                   lda   BG1StartYMod208         ; This is the line that is at the top of the screen
                   and   #$FFF8                  ; Clamp to the nearest block
                   lsr
                   lsr
                   lsr                           ; Could optimize because the Tile code shifts back....
                   clc
                   adc   :Top
                   cmp   #MAX_TILE_Y+1           ; Top can be less than or equal to 25
                   bcc   *+5
                   sbc   #MAX_TILE_Y+1
                   sta   :BlkY                   ; This is the Y-block we start drawing from

                   lda   BG1StartXMod164         ; Do the same thing for X, except only need to clamp by 4
                   and   #$FFFC
                   lsr
                   lsr
                   clc
                   adc   :Left
                   cmp   #MAX_TILE_X+1           ; Left can be less than or equal to 40
                   bcc   *+5
                   sbc   #MAX_TILE_X+1
                   sta   :BlkX

; Call the copy tile routine to blit the tile data into the playfield
;
; A = Tile ID (0 - 1023)
; X = Tile column (0 - 40)
; Y = Tile row (0 - 25)

                   pei   :BlkX                   ; cache the starting X-block index to restore later
                   pei   :Width                  ; cache the Width value to restore later
:yloop
:xloop
                   ldy   :Offset                 ; Set up the arguments and call the tile blitter
                   lda   [BG1TileMapPtr],y
                   iny                           ; pre-increment the address. A bit faster than two "INC DP" instructions
                   iny
                   sty   :Offset

                   ldx   :BlkX
                   ldy   :BlkY
;                   jsr   _CopyBG1Tile

                   lda   :BlkX
                   inc
                   cmp   #MAX_TILE_X+1           ; If we go past the maximum block index, wrap around
                   bcc   *+5
                   lda   #0
                   sta   :BlkX

                   dec   :Width                  ; Decrement out count
                   bne   :xloop

                   lda   :Offset                 ; Move to the next line of the Tile Map
                   clc
                   adc   :Span
                   sta   :Offset

                   lda   3,s                     ; Reset the BlkX
                   sta   :BlkX

                   lda   1,s                     ; Reset the width
                   sta   :Width

                   lda   :BlkY                   ; The y lookup has a double-length array, may not need the bounds check
                   inc
                   cmp   #MAX_TILE_Y+1
                   bcc   *+5
                   lda   #0
                   sta   :BlkY

                   dec   :Height                 ; Have we done all of the rows?
                   bne   :yloop

                   pla                           ; Pop off cached values
                   pla

                   rts
