; _TBPriorityDynamicTile
;
; The priority bit allows the tile to be rendered in front of sprites.  If there's no sprite
; in this tile area, then just fallback to the Tile00001.s implementation
_TBPriorityDynamicTile   dw      _TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00
                         dw      _TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00
