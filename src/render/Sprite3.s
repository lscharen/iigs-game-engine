
ThreeSpriteLine mac
            db    $37,sprite_ptr2                    ; and   [sprite_ptr2],y
            ora   (sprite_ptr2),y
            db    $37,sprite_ptr1                    ; and   [sprite_ptr1],y
            ora   (sprite_ptr1),y
            db    $37,sprite_ptr0                    ; and   [sprite_ptr0],y
            ora   (sprite_ptr0),y
            <<<

; Three sprites wiithout extra masking
ThreeSpritesFast
            tyx                                      ; save for after compositing the sprites

            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_SPRITEDATA_BANKS
            plb                                      ; set to the tiledata bank
            jsr   (K_TS_COPY_TILE_DATA,x)
            plb                                      ; set to the sprite data bank

]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            lda   tmp_tile_data+{]line*4}
            ThreeSpriteLine
            sta   tmp_tile_data+{]line*4}

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            lda   tmp_tile_data+{]line*4}+2
            ThreeSpriteLine
            sta   tmp_tile_data+{]line*4}+2
]line       equ   ]line+1
            --^

            plb
            jmp   _CopyDP2ToCodeField
