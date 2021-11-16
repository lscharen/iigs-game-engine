; _TBMaskedSpriteTile
;
; Renders a composited tile with masking to the code field.
_TBMaskedSpriteTile_00
                 sta             _X_REG                       ; Immedately stash the parameters
                 sty             _Y_REG
;                 stx             _T_PTR

                 jsr             _TBCopyTileDataToCBuff       ; Copy the tile data into the compositing buffer (using correct x-register)
                 jsr             _TBCopyTileMaskToCBuff       ; Copy the tile mask into the compositing buffer (using correct x-register)
                 jsr             _TBMergeSpriteDataAndMask    ; Overlay the data and mask from the sprite plane into the compositing buffer
                 jmp             _TBMaskedCBuff               ; Render the masked tile from the compositing buffer into the code field

_TBMaskedSpriteTile_0H
                 sta             _X_REG
                 sty             _Y_REG
                 jsr             _TBCopyTileDataToCBuffH
                 jsr             _TBCopyTileMaskToCBuffH
                 jsr             _TBMergeSpriteDataAndMask
                 jmp             _TBMaskedCBuff

_TBMaskedSpriteTile_V0
                 sta             _X_REG
                 sty             _Y_REG
                 jsr             _TBCopyTileDataToCBuffV
                 jsr             _TBCopyTileMaskToCBuffV
                 jsr             _TBMergeSpriteDataAndMask
                 jmp             _TBMaskedCBuff

_TBMaskedSpriteTile_VH
                 sta             _X_REG
                 sty             _Y_REG
                 jsr             _TBCopyTileDataToCBuffVH
                 jsr             _TBCopyTileMaskToCBuffVH
                 jsr             _TBMergeSpriteDataAndMask
                 jmp             _TBMaskedCBuff

_TBMergeSpriteDataAndMask
                 ldx   _SPR_X_REG                               ; set to the unaligned tile block address in the sprite plane

]line            equ   0
                 lup   8
                 lda   blttmp+{]line*4}
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta   blttmp+{]line*4}

                 ldal  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 and   blttmp+{]line*4}+32
                 sta   blttmp+{]line*4}+32

                 lda   blttmp+{]line*4}+2
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta   blttmp+{]line*4}+2

                 ldal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 and   blttmp+{]line*4}+32+2
                 sta   blttmp+{]line*4}+32+2
]line            equ   ]line+1
                 --^
                 rts 

; See the Tiles00010.s blitter for additional details
_TBMaskedCBuff
                 CopyMaskedWordD  blttmp+0;$0003
                 CopyMaskedWordD  blttmp+4;$1003
                 CopyMaskedWordD  blttmp+8;$2003
                 CopyMaskedWordD  blttmp+12;$3003
                 CopyMaskedWordD  blttmp+16;$4003
                 CopyMaskedWordD  blttmp+20;$5003
                 CopyMaskedWordD  blttmp+24;$6003
                 CopyMaskedWordD  blttmp+28;$7003

                 inc             _X_REG
                 inc             _X_REG

                 CopyMaskedWordD  blttmp+2;$0000
                 CopyMaskedWordD  blttmp+6;$1000
                 CopyMaskedWordD  blttmp+10;$2000
                 CopyMaskedWordD  blttmp+14;$3000
                 CopyMaskedWordD  blttmp+18;$4000
                 CopyMaskedWordD  blttmp+22;$5000
                 CopyMaskedWordD  blttmp+26;$6000
                 CopyMaskedWordD  blttmp+30;$7000

                 rts
