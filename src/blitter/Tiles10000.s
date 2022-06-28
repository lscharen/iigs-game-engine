; _TBSolidSpriteTile
;
; Renders solid tiles with sprites layered on top of the tile data.  Because we need to combine
; data from the sprite plane, tile data and write to the code field (which are all in different banks),
; there is no way to do everything inline, so a composite tile is created on the fly and written to
; a direct page buffer.  This direct page buffer is then used to render the tile.
_TBSolidSpriteTile_00
_TBSolidSpriteTile_0H
                 jsr             _TBCopyTileDataToCBuff     ; Copy the tile into the compositing buffer (using correct x-register)
                 jsr             _TBApplySpriteData         ; Overlay the data from the sprite plane (and copy into the code field)
                 jmp             _TBFillPEAOpcode           ; Fill in the code field opcodes

_TBSolidSpriteTile_V0
_TBSolidSpriteTile_VH
                 jsr             _TBCopyTileDataToCBuffV
                 jsr             _TBApplySpriteData
                 jmp             _TBFillPEAOpcode

; Fast variation that does not need to set the opcode
_TBFastSpriteTile_00
_TBFastSpriteTile_0H
                 jsr             _TBCopyTileDataToCBuff     ; Copy the tile into the compositing buffer
                 jmp             _TBApplySpriteData         ; Overlay the data form the sprite plane (and copy into the code field)

_TBFastSpriteTile_V0
_TBFastSpriteTile_VH
                 jsr             _TBCopyTileDataToCBuffV
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

_TBApplySpriteDataOne
                 ldx  spriteIdx
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

_TBApplySpriteDataTwo
]line            equ   0
                 lup   8
                 lda   blttmp+{]line*4}
                 ldx  spriteIdx+2
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 ldx  spriteIdx
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta:  $0004+{]line*$1000},y

                 lda   blttmp+{]line*4}+2
                 ldx  spriteIdx+2
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 ldx  spriteIdx
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta:  $0001+{]line*$1000},y
]line            equ   ]line+1
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
