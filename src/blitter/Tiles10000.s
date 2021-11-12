; _TBSolidSpriteTile
;
; Renders solid tiles with sprites layered on top of the tile data.  Because we need to combine
; data from the sprite plane, tile data and write to the code field (which are all in different banks),
; there is no way to do everything inline, so a composite tile is created on the fly and written to
; a direct page buffer.  This direct page buffer is then used to render the tile.
_TBSolidSpriteTile_00
;                 ldx             #45*128
                 jsr             _TBCopyTileDataToCBuff     ; Copy the tile into the compositing buffer (using correct x-register)
                 jsr             _TBApplySpriteData         ; Overlay the data form the sprite plane (and copy into the code field)
                 jmp             _TBFillPEAOpcode           ; Fill in the code field opcodes

_TBSolidSpriteTile_0H
                 jsr             _TBCopyTileDataToCBuffH
                 jsr             _TBApplySpriteData
                 jmp             _TBFillPEAOpcode

_TBSolidSpriteTile_V0
                 jsr             _TBCopyTileDataToCBuffV
                 jsr             _TBApplySpriteData
                 jmp             _TBFillPEAOpcode

_TBSolidSpriteTile_VH
                 jsr             _TBCopyTileDataToCBuffVH
                 jsr             _TBApplySpriteData
                 jmp             _TBFillPEAOpcode

; Fast variation that does not need to set the opcode
_TBFastSpriteTile_00
                 jsr             _TBCopyTileDataToCBuff     ; Copy the tile into the compositing buffer
                 jmp             _TBApplySpriteData         ; Overlay the data form the sprite plane (and copy into the code field)

_TBFastSpriteTile_0H
                 jsr             _TBCopyTileDataToCBuffH
                 jmp             _TBApplySpriteData

_TBFastSpriteTile_V0
                 jsr             _TBCopyTileDataToCBuffV
                 jmp             _TBApplySpriteData

_TBFastSpriteTile_VH
                 jsr             _TBCopyTileDataToCBuffVH
                 jmp             _TBApplySpriteData

; Need to update the X-register before calling this
_TBApplySpriteData
                 ldx   _SPR_X_REG                               ; set to the unaligned tile block address in the sprite plane

]line            equ   0
                 lup   8
                 lda   blttmp+{]line*4}
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta:  $0004+{]line*$1000},y

                 lda   blttmp+{]line*4}+2
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta:  $0001+{]line*$1000},y
]line            equ   ]line+1
                 --^
                 rts 

; Copy tile data into the direct page compositing buffer.  The main reason to do this in full passes is
; because we can avoid needing to use both the X and Y registers during the compositing process and
; reserve Y to hold the code field address.
;
; Also, we can get away with not setting the bank register, this is a wash in terms of speed, but results
; in simpler, more composable subroutines
_TBCopyTileDataToCBuff
]line            equ   0
                 lup   8
                 ldal  tiledata+{]line*4},x
                 sta   blttmp+{]line*4}

                 ldal  tiledata+{]line*4}+2,x
                 sta   blttmp+{]line*4}+2
]line            equ   ]line+1
                 --^
                 rts

_TBCopyTileDataToCBuffH
]line            equ   0
                 lup   8
                 ldal  tiledata+{]line*4}+64,x
                 sta   blttmp+{]line*4}

                 ldal  tiledata+{]line*4}+64+2,x
                 sta   blttmp+{]line*4}+2
]line            equ   ]line+1
                 --^
                 rts

_TBCopyTileDataToCBuffV
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4},x
                 sta             blttmp+{]dest*4}

                 ldal            tiledata+{]src*4}+2,x
                 sta             blttmp+{]dest*4}+2
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

_TBCopyTileDataToCBuffVH
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4}+64,x
                 sta             blttmp+{]dest*4}

                 ldal            tiledata+{]src*4}+64+2,x
                 sta             blttmp+{]dest*4}+2
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts


; Copy tile mask data into the direct page compositing buffer.
_TBCopyTileMaskToCBuff
]line            equ   0
                 lup   8
                 ldal  tiledata+{]line*4}+32,x
                 sta   blttmp+{]line*4}+32

                 ldal  tiledata+{]line*4}+32+2,x
                 sta   blttmp+{]line*4}+32+2
]line            equ   ]line+1
                 --^
                 rts

_TBCopyTileMaskToCBuffH
]line            equ   0
                 lup   8
                 ldal  tiledata+{]line*4}+32+64,x
                 sta   blttmp+{]line*4}+32

                 ldal  tiledata+{]line*4}+32+64+2,x
                 sta   blttmp+{]line*4}+32+2
]line            equ   ]line+1
                 --^
                 rts

_TBCopyTileMaskToCBuffV
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4}+32,x
                 sta             blttmp+{]dest*4}+32

                 ldal            tiledata+{]src*4}+32+2,x
                 sta             blttmp+{]dest*4}+32+2
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

_TBCopyTileMaskToCBuffVH
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4}+32+64,x
                 sta             blttmp+{]dest*4}+32

                 ldal            tiledata+{]src*4}+32+64+2,x
                 sta             blttmp+{]dest*4}+32+2
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
