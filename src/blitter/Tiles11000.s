; _TBPrioritySpriteTile
;
; When the sprite is composited with the tile data, the tile mask is used to place the tile data on top of
; any sprite data

; Need to update the X-register before calling this
_TBApplyPrioritySpriteData
                 ldx   _SPR_X_REG                               ; set to the unaligned tile block address in the sprite plane

]line            equ   0
                 lup   8
                 ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 and   blttmp+{]line*4}+32
                 ora   blttmp+{]line*4}
                 sta:  $0004+{]line*$1000},y

                 ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 and   blttmp+{]line*4}+32+2
                 ora   blttmp+{]line*4}+2
                 sta:  $0001+{]line*$1000},y
]line            equ   ]line+1
                 --^

                 ldx   _X_REG                                   ; restore the original value
                 rts 