; _TBPriorityDynamicMaskTile
;
; The priority bit allows the tile to be rendered in front of sprites.  If there's no sprite
; in this tile area, then just fallback to the Tile00000.s implementation
_TBPriorityDynamicMaskTile dw   _TBDynamicMaskTile_00,_TBDynamicMaskTile_00,_TBDynamicMaskTile_00,_TBDynamicMaskTile_00
                           dw   _TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00
