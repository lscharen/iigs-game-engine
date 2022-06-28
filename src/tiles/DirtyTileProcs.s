; A collection of tile blitters used in the dirty renderer.  These renderers copy data directly
; to the graphics screen.  Also, because the dirty render assumes that the screen is not moving,
; there is no support for two layer tiles.

; Address table of the rendering functions
DirtyTileProcs   dw    _TBDirtyTile_00,_TBDirtyTile_0H,_TBDirtyTile_V0,_TBDirtyTile_VH

; Normal and horizontally flipped tiles.  The horizontal variant is selected by choosing
; and appropriate value for the X register, so these can share the same code.
;
; B = Bank 01
; X = address of tile data
; Y = screen address
_TBDirtyTile_00
_TBDirtyTile_0H
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0000+{]line*160},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0002+{]line*160},y
]line            equ             ]line+1
                 --^
                 rts

; Vertically flipped tile renderers
;
; B = Bank 01
; X = address of tile data
; Y = screen address
_TBDirtyTile_V0
_TBDirtyTile_VH
]line            equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0000+{]dest*160},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0002+{]dest*160},y
]line            equ             ]line-1
]dest            equ             ]dest+1
                 --^
                 rts