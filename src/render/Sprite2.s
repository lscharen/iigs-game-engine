; Specialize routines for handling two sprites.  Like Sprite3.s and Sprite4.s there are four
; variants -- one to handle over / under sprite orders and one each for whether the mask needs
; to be used or not.
TwoSpriteLine mac
            db    $37,sprite_ptr1                  ; and   [sprite_ptr1],y
            ora   (sprite_ptr1),y
            db    $37,sprite_ptr0                  ; and   [sprite_ptr0],y
            ora   (sprite_ptr0),y
            <<<

TwoSpriteData mac
            lda   (sprite_ptr1),y
            db    $37,sprite_ptr0                  ; and   [sprite_ptr0],y
            ora   (sprite_ptr0),y
            <<<

TwoSpriteMask mac
            db    $B7,sprite_ptr1                  ; lda   [sprite_ptr1],y
            db    $37,sprite_ptr0                  ; and   [sprite_ptr0],y
            <<<

TwoSpritesOver
            tyx                                    ; save after compositing the sprites
            phb                                    ; save the current bank
            jsr   CopyTileToDPSprite               ; copy necessary tile data to the direct page

]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            lda   tmp_tile_data+{]line*4}
            TwoSpriteLine
            sta   tmp_tile_data+{]line*4}

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            lda   tmp_tile_data+{]line*4}+2
            TwoSpriteLine
            sta   tmp_tile_data+{]line*4}+2
]line       equ   ]line+1
            --^

            plb
            jmp   (K_TS_APPLY_TILE_DATA,x)


TwoSpritesUnderFast
            tyx                                    ; save after compositing the sprites
            phb                                    ; save the current bank
            jsr   CopyTwoSpritesDataToDP           ; copy necessary sprite data to the direct page
            jmp   MergeSpriteWithTileFast

]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            lda   tmp_tile_data+{]line*4}
            TwoSpriteLine
            sta   tmp_tile_data+{]line*4}

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            lda   tmp_tile_data+{]line*4}+2
            TwoSpriteLine
            sta   tmp_tile_data+{]line*4}+2
]line       equ   ]line+1
            --^

            plb
            jmp   (K_TS_APPLY_TILE_DATA,x)

;---------------------------------
; Helper functions for two Sprites
CopyTwoSpritesDataToDP
]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            TwoSpriteData
            sta   tmp_sprite_data+{]line*4}

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            TwoSpriteData
            sta   tmp_sprite_data+{]line*4}+2
]line       equ   ]line+1
            --^
            rts
CopyFourSpritesDataAndMaskToDP
CopyThreeSpritesDataAndMaskToDP
CopyTwoSpritesDataAndMaskToDP
]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            TwoSpriteData
            sta   tmp_sprite_data+{]line*4}
            TwoSpriteMask
            sta   tmp_sprite_mask+{]line*4}

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            TwoSpriteData
            sta   tmp_sprite_data+{]line*4}+2
            TwoSpriteMask
            sta   tmp_sprite_mask+{]line*4}+2
]line       equ   ]line+1
            --^
            jmp   (K_TS_SPRITE_TILE_DISP,x)

