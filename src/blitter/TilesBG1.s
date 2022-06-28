
; On entry
;
; B is set to the correct BG1 data bank
; A is set to the the tile descriptor
; Y is set to the top-left address of the tile in the BG1 data bank
;
; tmp0/tmp1 is reserved 
_RenderTileBG1
                 pha                                               ; Save the tile descriptor

                 and             #TILE_VFLIP_BIT+TILE_HFLIP_BIT    ; Only horizontal and vertical flips are supported for BG1
                 xba
                 tax

                 pla
                 and             #TILE_ID_MASK                     ; Mask out the ID and save just that
                 _Mul128                                           ; multiplied by 128
                 jmp             (:actions,x)
:actions         dw              _TBSolidBG1_00,_TBSolidBG1_0H,_TBSolidBG1_V0,_TBSolidBG1_VH

_TBSolidBG1_00
                 tax
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0000+{]line*$0100},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0002+{]line*$0100},y
]line            equ             ]line+1
                 --^
                 rts

_TBSolidBG1_0H
                 tax
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4}+64,x
                 sta:            $0000+{]line*$0100},y
                 ldal            tiledata+{]line*4}+64+2,x
                 sta:            $0002+{]line*$0100},y
]line            equ             ]line+1
                 --^
                 rts

_TBSolidBG1_V0
                 tax
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4},x
                 sta:            $0000+{]dest*$0100},y
                 ldal            tiledata+{]src*4}+2,x
                 sta:            $0002+{]dest*$0100},y
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

_TBSolidBG1_VH
                 tax
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4}+64,x
                 sta:            $0000+{]dest*$0100},y
                 ldal            tiledata+{]src*4}+64+2,x
                 sta:            $0002+{]dest*$0100},y
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts
