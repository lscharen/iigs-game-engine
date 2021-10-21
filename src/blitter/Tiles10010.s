; _TBMaskedPriorityTile
;
; The priority bit allows the tile to be rendered in front of sprites.  If there's no sprite
; in this tile area, then just fallback to the Tile00000.s implementation
_TBMaskedPriorityTile dw   _TBMaskedTile_00,_TBMaskedTile_0H,_TBMaskedTile_V0,_TBMaskedTile_VH
                      dw   _TBCopyData,_TBCopyDataH,_TBCopyDataV,_TBCopyDataVH

; NOTE: Eventually, we want a way to support this use-case
;
; When the high-priority bit is set for a tile, then the BG0 tile will be rendered behind the BG1 data. In
; order to support this, the optional BG1 mask buffer needs to be enabled and *every* word in the tile
; becomes a JMP handler (similar to masked dynamic tiles)
;
; The 8 bytes of code that is generated in the JMP handler is
;
;   lda #tiledata
;   and [dp],y
;   ora (dp),y
;   nop
