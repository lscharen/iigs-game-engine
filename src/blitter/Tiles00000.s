; _TBSolidTile
;
; Define the addresses of the subroutines that draw the normal and flipped variants of the tiles, both 
; in the optimized (no second background) and normal cases.
;
; On entry, the following register values need to be set
;
;  X : address of base tile in the tiledata bank (tileId * 128)
;  Y : address of the top-left corder of the tile location in the code field
;  B : set to the code field bank  

_TBSolidTile_00
                 jsr             _TBCopyData
                 jmp             _TBFillPEAOpcode

_TBSolidTile_0H
                 jsr             _TBCopyData
                 jmp             _TBFillPEAOpcode

_TBSolidTile_V0
                 jsr             _TBCopyDataV
                 jmp             _TBFillPEAOpcode

_TBSolidTile_VH
                 jsr             _TBCopyDataV
                 jmp             _TBFillPEAOpcode

; Old routines
_TBCopyData
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0004+{]line*$1000},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0001+{]line*$1000},y
]line            equ             ]line+1
                 --^
                 rts

_TBCopyDataV
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4},x
                 sta:            $0004+{]dest*$1000},y
                 ldal            tiledata+{]src*4}+2,x
                 sta:            $0001+{]dest*$1000},y
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

