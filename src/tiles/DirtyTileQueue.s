_ClearDirtyTiles
                 bra  :hop
:loop
                 jsr  _PopDirtyTile
:hop
                 lda  DirtyTileCount
                 bne  :loop
                 rts


; Append a new dirty tile record 
;
;  A = result of _GetTileStoreOffset for X, Y
;
; The main purpose of this function is to
;
;  1. Avoid marking the same tile dirty multiple times, and
;  2. Pre-calculating all of the information necessary to render the tile
_PushDirtyTile
                 tax

; alternate entry point if the x-register is already set
_PushDirtyTileX
                 ldal TileStore+TS_DIRTY,x
                 bne  :occupied2

                 inc                                  ; any non-zero value will work
                 stal TileStore+TS_DIRTY,x            ; and is 1 cycle faster than loading a constant value

                 txa
                 ldx  DirtyTileCount ; 4
                 sta  DirtyTiles,x   ; 6
                 inx                 ; 2
                 inx                 ; 2
                 stx  DirtyTileCount ; 4 = 18
                 rts
:occupied2
                 txa                                ; Make sure TileStore offset is returned in the accumulator
                 rts

; Remove a dirty tile from the list and return it in state ready to be rendered.  It is important
; that the core rendering functions *only* use _PopDirtyTile to get a list of tiles to update,
; because this routine merges the tile IDs stored in the Tile Store with the Sprite
; information to set the TILE_SPRITE_BIT.  This is the *only* place in the entire code base that
; applies this bit to a tile descriptor.
_PopDirtyTile
                 ldy  DirtyTileCount
                 bne  _PopDirtyTile2
                 rts

_PopDirtyTile2                                       ; alternate entry point
                 dey
                 dey
                 sty  DirtyTileCount                 ; remove last item from the list

                 ldx  DirtyTiles,y                   ; load the offset into the Tile Store
                 lda  #$FFFF
                 stal TileStore+TS_DIRTY,x           ; clear the occupied backlink
                 rts

; An optimized subroutine that runs through the dirty tile list and executes a callback function
; for each dirty tile.  This is an unrolled loop, so we avoid the need to track a register and
; decrement on each iteration.
;
; Also, if we are handling less that 8 dirty tiles, we use a code path that does not
; need to use an index register
;
; Bank = Tile Store
; D    = Page 2
_PopDirtyTilesFast
                 ldx  DP2_DIRTY_TILE_COUNT        ; This is pre-multiplied by 2
                 bne  pdtf_not_empty              ; If there are no items, exit
at_exit          rts
pdtf_not_empty
                 cpx  #16                         ; If there are >= 8 elements, then
                 bcs  full_chunk                  ; do a full chunk

                 stz  DP2_DIRTY_TILE_COUNT        ; Otherwise, this pass will handle them all
                 jmp  (at_table,x)
at_table         da   at_exit,at_one,at_two,at_three
                 da   at_four,at_five,at_six,at_seven

full_chunk       txa
                 sbc  #16                         ; carry set from branch
                 sta  DP2_DIRTY_TILE_COUNT        ; fall through
                 tay                              ; use the Y-register for the index

; Because all of the registers get used in the subroutine, we
; push the values from the DirtyTiles array onto the stack and then pop off
; the values as we go

                 ldx   DirtyTiles+14,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

                 ldy   DP2_DIRTY_TILE_COUNT
                 ldx   DirtyTiles+12,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

                 ldy   DP2_DIRTY_TILE_COUNT
                 ldx   DirtyTiles+10,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

                 ldy   DP2_DIRTY_TILE_COUNT
                 ldx   DirtyTiles+8,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

                 ldy   DP2_DIRTY_TILE_COUNT
                 ldx   DirtyTiles+6,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

                 ldy   DP2_DIRTY_TILE_COUNT
                 ldx   DirtyTiles+4,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

                 ldy   DP2_DIRTY_TILE_COUNT
                 ldx   DirtyTiles+2,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

                 ldy   DP2_DIRTY_TILE_COUNT
                 ldx   DirtyTiles+0,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast
                 jmp   _PopDirtyTilesFast

; These routines just handle between 1 and 7 dirty tiles
at_seven
                 ldx   DirtyTiles+12
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

at_six
                 ldx   DirtyTiles+10
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

at_five
                 ldx   DirtyTiles+8
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

at_four
                 ldx   DirtyTiles+6
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

at_three
                 ldx   DirtyTiles+4
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

at_two
                 ldx   DirtyTiles+2
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTileFast

at_one
                 ldx   DirtyTiles+0
                 stz   TileStore+TS_DIRTY,x
                 jmp   _RenderTileFast
