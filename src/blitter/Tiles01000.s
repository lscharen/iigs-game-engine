; _TBPriorityTile
;
; The priority bit allows the tile to be rendered in front of sprites.  If there's no sprite
; in this tile area, then just fallback to the Tile00000.s implementation
_TBPriorityTile  dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH
                 dw              _TBCopyData,_TBCopyDataH,_TBCopyDataV,_TBCopyDataVH
