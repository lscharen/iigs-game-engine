
; A list of dirty tiles that need to be updated in a given frame
DirtyTileCount   ds   2
DirtyTiles       ds   TILE_STORE_SIZE    ; At most this many tiles can possibly be update at once

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
