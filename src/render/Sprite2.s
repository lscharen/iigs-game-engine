; Specialize routines for handling two sprites.
TwoSpriteData mac
            lda   (sprite_ptr1),y
            db    $37,sprite_ptr0                  ; and   [sprite_ptr0],y
            ora   (sprite_ptr0),y
            <<<

TwoSpriteMask mac
            db    $B7,sprite_ptr1                  ; lda   [sprite_ptr1],y
            db    $37,sprite_ptr0                  ; and   [sprite_ptr0],y
            <<<

CopyFourSpritesDataAndMaskToDP
CopyThreeSpritesDataAndMaskToDP
CopyTwoSpritesDataAndMaskToDP
            pei   DP2_SPRITEDATA_AND_TILESTORE_BANKS
            plb

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

            plb
            jmp   (K_TS_SPRITE_TILE_DISP,x)

