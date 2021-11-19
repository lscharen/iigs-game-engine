; _TBMaskedPrioritySpriteTile
;
; Renders a composited tile with masking to the code field.  The sprite is underlaid
_TBMaskedPrioritySpriteTile_00
                 sta             _X_REG                       ; Immedately stash the parameters
                 sty             _Y_REG

                 jsr             _TBCopyTileDataToCBuff       ; Copy the tile data into the compositing buffer (using correct x-register)
                 jsr             _TBCopyTileMaskToCBuff       ; Copy the tile mask into the compositing buffer (using correct x-register)
                 jsr             _TBUnderlaySpriteDataAndMask ; Underlay the data and mask from the sprite plane into the compositing buffer
                 jmp             _TBMaskedCBuff               ; Render the masked tile from the compositing buffer into the code field

_TBMaskedPrioritySpriteTile_0H
                 sta             _X_REG
                 sty             _Y_REG
                 jsr             _TBCopyTileDataToCBuffH
                 jsr             _TBCopyTileMaskToCBuffH
                 jsr             _TBUnderlaySpriteDataAndMask
                 jmp             _TBMaskedCBuff

_TBMaskedPrioritySpriteTile_V0
                 sta             _X_REG
                 sty             _Y_REG
                 jsr             _TBCopyTileDataToCBuffV
                 jsr             _TBCopyTileMaskToCBuffV
                 jsr             _TBUnderlaySpriteDataAndMask
                 jmp             _TBMaskedCBuff

_TBMaskedPrioritySpriteTile_VH
                 sta             _X_REG
                 sty             _Y_REG
                 jsr             _TBCopyTileDataToCBuffVH
                 jsr             _TBCopyTileMaskToCBuffVH
                 jsr             _TBUnderlaySpriteDataAndMask
                 jmp             _TBMaskedCBuff

_TBUnderlaySpriteDataAndMask
                 ldx   _SPR_X_REG                               ; set to the unaligned tile block address in the sprite plane

]line            equ   0
                 lup   8
                 ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 and   blttmp+{]line*4}+32
                 ora   blttmp+{]line*4}                         ; Maybe this can be a TSB???
                 sta   blttmp+{]line*4}

                 ldal  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 and   blttmp+{]line*4}+32
                 sta   blttmp+{]line*4}+32

                 ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 and   blttmp+{]line*4}+32+2
                 ora   blttmp+{]line*4}+2
                 sta   blttmp+{]line*4}+2

                 ldal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 and   blttmp+{]line*4}+32+2
                 sta   blttmp+{]line*4}+32+2
]line            equ   ]line+1
                 --^
                 rts 
