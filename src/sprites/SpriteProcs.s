; Functions to handle rendering sprite information into buffers for updates to the 
; code field.  Due to lack of parallel structure, the sprites are combined with the
; tile data and then written to a single direct page buffer.  The data is read from
; this buffer and then applied to the code field

; Merge a single block of sprite data with a tile
_OneSprite_00
_OneSprite_H0
                 ldx   TileStore+TS_VBUFF_ADDR_0,y
                 lda   TileStore+TS_TILE_ADDR,y
                 tay

]line            equ   0
                 lup   8
                 lda   tiledata+{]line*TILE_DATA_SPAN},y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta   tmp_sprite_data+{]line*4}

                 lda   tiledata+{]line*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta   tmp_sprite_data+{]line*4}+2
]line            equ   ]line+1
                 --^

_OneSprite_V0
_OneSprite_VH
                 ldx   TileStore+TS_VBUFF_ADDR_0,y
                 lda   TileStore+TS_TILE_ADDR,y
                 tay

]line            equ   7
]dest            equ   0
                 lup   8
                 lda   tiledata+{]line*TILE_DATA_SPAN},y
                 andl  spritemask+{]dest*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]dest*SPRITE_PLANE_SPAN},x
                 sta   tmp_sprite_data+{]dest*4}

                 lda   tiledata+{]line*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{]dest*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]dest*SPRITE_PLANE_SPAN}+2,x
                 sta   tmp_sprite_data+{]dest*4}+2
]line            equ   ]line-1
]dest            equ   ]dest+1
                 --^
                 rts


; Merge two blocks of sprite data.  This is more involved because we need to use the
; direct page pointers to stack the sprite information
_TwoSprite_00
_TwoSprite_H0
                 lda   TileStore+TS_VBUFF_ADDR_0,y
                 sta   sprite_0
                 lda   TileStore+TS_VBUFF_ADDR_1,y
                 sta   sprite_1
                 ldx   TileStore+TS_TILE_ADDR,y

; line 0
                 lda   tiledata+{0*TILE_DATA_SPAN},x
                 and   [sprite_1]
                 ora   (sprite_1)
                 and   [sprite_0]
                 ora   (sprite_0)
                 sta   tmp_sprite_data+{0*4}

                 ldy   #{0*SPRITE_PLANE_SPAN}+2
                 lda   tiledata+{0*TILE_DATA_SPAN}+2,x
                 and   [sprite_1],y
                 ora   (sprite_1),y
                 and   [sprite_0],y
                 ora   (sprite_0),y
                 sta   tmp_sprite_data+{0*4}+2

; line 1
                 ldy   #{1*SPRITE_PLANE_SPAN}
                 lda   tiledata+{1*TILE_DATA_SPAN},x
                 and   [sprite_1],y
                 ora   (sprite_1),y
                 and   [sprite_0],y
                 ora   (sprite_0),y
                 sta   tmp_sprite_data+{1*4}

                 ldy   #{1*SPRITE_PLANE_SPAN}+2
                 lda   tiledata+{1*TILE_DATA_SPAN}+2,x
                 and   [sprite_1],y
                 ora   (sprite_1),y
                 and   [sprite_0],y
                 ora   (sprite_0),y
                 sta   tmp_sprite_data+{1*4}+2

                 rts


; Merge three blocks of sprite data.  This is more involved because we need to use the
; direct page pointers to stack the sprite information
_ThreeSprite_00
_ThreeSprite_H0
                 lda   TileStore+TS_VBUFF_ADDR_0,y
                 sta   sprite_0
                 lda   TileStore+TS_VBUFF_ADDR_1,y
                 sta   sprite_1
                 lda   TileStore+TS_VBUFF_ADDR_2,y
                 sta   sprite_2
                 ldx   TileStore+TS_TILE_ADDR,y

; line 0
                 lda   tiledata+{0*TILE_DATA_SPAN},x
                 and   [sprite_2]
                 ora   (sprite_2)
                 and   [sprite_1]
                 ora   (sprite_1)
                 and   [sprite_0]
                 ora   (sprite_0)
                 sta   tmp_sprite_data+{0*4}

                 ldy   #{0*SPRITE_PLANE_SPAN}+2
                 lda   tiledata+{0*TILE_DATA_SPAN}+2,x
                 and   [sprite_2],y
                 ora   (sprite_2),y
                 and   [sprite_1],y
                 ora   (sprite_1),y
                 and   [sprite_0],y
                 ora   (sprite_0),y
                 sta   tmp_sprite_data+{0*4}+2

; line 1
                 ldy   #{1*SPRITE_PLANE_SPAN}
                 lda   tiledata+{1*TILE_DATA_SPAN},x
                 and   [sprite_2],y
                 ora   (sprite_2),y
                 and   [sprite_1],y
                 ora   (sprite_1),y
                 and   [sprite_0],y
                 ora   (sprite_0),y
                 sta   tmp_sprite_data+{1*4}

                 ldy   #{1*SPRITE_PLANE_SPAN}+2
                 lda   tiledata+{1*TILE_DATA_SPAN}+2,x
                 and   [sprite_2],y
                 ora   (sprite_2),y
                 and   [sprite_1],y
                 ora   (sprite_1),y
                 and   [sprite_0],y
                 ora   (sprite_0),y
                 sta   tmp_sprite_data+{1*4}+2

                 rts