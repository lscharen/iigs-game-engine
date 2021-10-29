; _TBMaskedSpriteTile
;
; Renders a composited tile with masking to the code field.
_TBMaskedSpriteTile dw           _TBMaskedSpriteTile_00
                    dw           _TBMaskedSpriteTile_0H
                    dw           _TBMaskedSpriteTile_V0
                    dw           _TBMaskedSpriteTile_VH
;                    dw              _TBCopyData,_TBCopyDataH,_TBCopyDataV,_TBCopyDataVH

_TBMaskedSpriteTile_00
                 jsr             _TBCreateComposite
                 jsr             _TBSolidComposite
                 jmp             _TBFillPEAOpcode

_TBMaskedSpriteTile_0H
                 jsr             _TBCreateCompositeH
                 jsr             _TBSolidComposite
                 jmp             _TBFillPEAOpcode

_TBMaskedSpriteTile_V0
                 jsr             _TBCreateCompositeV
                 jsr             _TBSolidComposite
                 jmp             _TBFillPEAOpcode

_TBMaskedSpriteTile_VH
                 jsr             _TBCreateCompositeVH
                 jsr             _TBSolidComposite
                 jmp             _TBFillPEAOpcode

_TBCreateCompositeDataAndMask
                 phb            
                 pea   #^tiledata
                 plb

]line            equ   0
                 lup   8
                 lda:  tiledata+{]line*4},y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta   blttmp+{]line*4}

                 lda:  tiledata+{]line*4}+32,y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 sta   blttmp+{]line*4}+32

                 lda:  tiledata+{]line*4}+2,y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta   blttmp+{]line*4}+2

                 lda:  tiledata+{]line*4}+32+2,y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta   blttmp+{]line*4}+32+2
]line            equ   ]line+1
                 --^

                 plb
                 plb
                 rts

_TBCreateCompositeH
                 phb            
                 pea   #^tiledata
                 plb

]line            equ   0
                 lup   8
                 lda:  tiledata+{]line*4}+64,y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta   blttmp+{]line*4}

                 lda:  tiledata+{]line*4}+64+2,y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta   blttmp+{]line*4}+2
]line            equ   ]line+1
                 --^

                 plb
                 plb
                 rts


_TBCreateCompositeV
]src             equ             7
]dest            equ             0
                 lup             8
                 lda:            tiledata+{]src*4},y
                 andl            spritemask+{]dest*SPRITE_PLANE_SPAN},x
                 oral            spritedata+{]dest*SPRITE_PLANE_SPAN},x
                 sta             blttmp+{]dest*4}

                 lda:            tiledata+{]src*4}+2,y
                 andl            spritemask+{]dest*SPRITE_PLANE_SPAN}+2,x
                 oral            spritedata+{]dest*SPRITE_PLANE_SPAN}+2,x
                 sta             blttmp+{]dest*4}+2
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

_TBCreateCompositeVH
]src             equ             7
]dest            equ             0
                 lup             8
                 lda:            tiledata+{]src*4}+64,y
                 andl            spritemask+{]dest*SPRITE_PLANE_SPAN},x
                 oral            spritedata+{]dest*SPRITE_PLANE_SPAN},x
                 sta             blttmp+{]dest*4}

                 lda:            tiledata+{]src*4}+64+2,y
                 andl            spritemask+{]dest*SPRITE_PLANE_SPAN}+2,x
                 oral            spritedata+{]dest*SPRITE_PLANE_SPAN}+2,x
                 sta             blttmp+{]dest*4}+2
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

; Copy just the data into the code field from the composite buffer
_TBSolidComposite
]line            equ             0
                 lup             8
                 lda             blttmp+{]line*4}
                 sta:            $0004+{]line*$1000},y
                 lda             blttmp+{]line*4}+2
                 sta:            $0001+{]line*$1000},y
]line            equ             ]line+1
                 --^
                 rts

