; If the engine mode has the second background layer disabled, we take advantage of that to
; be more efficient in our rendering.  Basically, without the second layer, there is no need
; to use the tile mask information.
;
; If there are no sprites, then we copy the tile data into the code field as fast as possible.
; If there are sprites, then the sprite data is flattened and stored into a direct page buffer
; and then copied into the code field
_RenderTileFast
            lda   TileStore+TS_SPRITE_FLAG,x       ; any sprites on this line?
            bne   :sprites

_OneSpriteFastUnder0
_RenderNoSprite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
            jmp   (K_TS_BASE_TILE_DISP,x)          ; go to the tile copy routine
:sprites    jmp   (K_TS_SPRITE_TILE_DISP,x)        ; go to the sprite+tile routine

; Optimized routines to render sprites on top of the tile data and update the code field
; assuming that the opcode will never need to be reset, e.g. all of the instructions are
; PEA opcodes, so only the operands need to be set.
;
; Since the sprite is drawn on top of the tile, the first step is to copy the tile data
; into the direct page temporary space, then dispatch to the appropriate sprite rendering
; subroutine
FastSpriteOver
            txy
            SpriteBitsToVBuffAddrs OneSpriteFast;TwoSpritesFast;ThreeSpritesFast;FourSpritesFast

; Optimized routines for drawing sprites underneath the tile.  In this case, the sprite is drawn first,
; so we have to calculate the sprite dispatch subrotine to copy the sprite data into the direct
; page space and then merge it with the tile data at the end.
FastSpriteUnder
            txy
            SpriteBitsToVBuffAddrs OneSpriteFastUnder;OneSpriteFastUnder;OneSpriteFastUnder;OneSpriteFastUnder

; This handles sprites with the tile above
OneSpriteFastUnder
            tyx
            jmp   (K_TS_ONE_SPRITE,x)

; General copy
_OneSpriteFastUnder
            tax
            jsr   _CopySpriteDataToDP2             ; preserves Y

            ldx   TileStore+TS_TILE_ADDR,y
            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            lda   TileStore+TS_CODE_ADDR_LOW,y     ; load the address of the code field
            tay
            plb

]line       equ   0
            lup   8
            lda   tmp_tile_data+{]line*4}
            andl  tiledata+{]line*4}+32,x
            oral  tiledata+{]line*4},x
            sta:  $0004+{]line*$1000},y

            lda   tmp_tile_data+{]line*4}+2
            andl  tiledata+{]line*4}+32+2,x
            oral  tiledata+{]line*4}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^
            plb
            rts 


_CopySpriteDataToDP2
]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta   tmp_tile_data+{]line*4}

            ldal   spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta   tmp_tile_data+{]line*4}+2
]line       equ   ]line+1
            --^
            rts

; Where there are sprites involved, the first step is to call a routine to copy the
; tile data into a temporary buffer.  Then the sprite data is merged and placed into
; the code field.
;
; A = vbuff address
; Y = tile store address
OneSpriteFast
            tyx
            jmp   (K_TS_ONE_SPRITE,x)

; Specialize when the tile is Tile 0
_OneSpriteFastOver0
            ldy   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            phy                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            tax
            plb

]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]line*$1000},y
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^
            plb
            rts

; General copy
_OneSpriteFastOver
            sta   sprite_ptr0
            ldy   TileStore+TS_TILE_ADDR,x         ; load the tile address
            jsr   (K_TS_COPY_TILE_DATA,x)          ; This routine *must* preserve X register

            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb

]line       equ   0
            lup   8
            lda   tmp_tile_data+{]line*4}
            andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
            oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]line*$1000},y

            lda   tmp_tile_data+{]line*4}+2
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^
            plb
            rts

TwoSpriteLine mac
;            and   [sprite_ptr1],y
            db    $37,sprite_ptr1
            ora   (sprite_ptr1),y
;            and   [sprite_ptr0],y
            db    $37,sprite_ptr0
            ora   (sprite_ptr0),y
            <<<

TwoSpritesFast
            tyx                                    ; save for after compositing the sprites

            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb
            jsr   (K_TS_COPY_TILE_DATA,x)
            plb

            pei   DP2_SPRITEDATA_AND_TILESTORE_BANKS 
            plb                                    ; set the sprite data bank

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

            plb                                    ; restore access to data bank

; Fall through
_CopyDP2ToCodeField
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb                                    ; Set the CODE_ADDR_HIGH bank

]line       equ   0
            lup   8
            lda   tmp_tile_data+{]line*4}
            sta:  $0004+{]line*$1000},y
            lda   tmp_tile_data+{]line*4}+2
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            plb                                   ; Reset to the bank in the top byte of CODE_ADDR_HIGH
            rts

ThreeSpriteLine mac
;            and   [sprite_ptr2],y
            db    $37,sprite_ptr2
            ora   (sprite_ptr2),y
;            and   [sprite_ptr1],y
            db    $37,sprite_ptr1
            ora   (sprite_ptr1),y
;            and   [sprite_ptr0],y
            db    $37,sprite_ptr0
            ora   (sprite_ptr0),y
            <<<

ThreeSpritesFast
            tyx                                    ; save for after compositing the sprites

            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb
            jsr   (K_TS_COPY_TILE_DATA,x)
            plb

            pei   DP2_SPRITEDATA_AND_TILESTORE_BANKS 
            plb                                    ; set the sprite data bank

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

FourSpriteLine mac
;            and   [sprite_ptr3],y
            db    $37,sprite_ptr3
            ora   (sprite_ptr3),y
;            and   [sprite_ptr2],y
            db    $37,sprite_ptr2
            ora   (sprite_ptr2),y
;            and   [sprite_ptr1],y
            db    $37,sprite_ptr1
            ora   (sprite_ptr1),y
;            and   [sprite_ptr0],y
            db    $37,sprite_ptr0
            ora   (sprite_ptr0),y
            <<<

FourSpritesFast
            tyx                                    ; save for after compositing the sprites

            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb
            jsr   (K_TS_COPY_TILE_DATA,x)
            plb

            pei   DP2_SPRITEDATA_AND_TILESTORE_BANKS 
            plb                                    ; set the sprite data bank

]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            lda   tmp_tile_data+{]line*4}
            FourSpriteLine
            sta   tmp_tile_data+{]line*4}

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            lda   tmp_tile_data+{]line*4}+2
            FourSpriteLine
            sta   tmp_tile_data+{]line*4}+2
]line            equ   ]line+1
            --^

            plb
            jmp   _CopyDP2ToCodeField

_CopyTileDataToDP2
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS ; Setting the bank saves 16 cycles and costs 14, so it's a bit faster,
            plb                                    ; but we really do it to preserve the X register
]line       equ   0
            lup   8
            lda   tiledata+{]line*4},y
            sta   tmp_tile_data+{]line*4}

            lda   tiledata+{]line*4}+2,y
            sta   tmp_tile_data+{]line*4}+2
]line       equ   ]line+1
            --^
            plb
            rts

_CopyTileDataToDP2V
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS ; Setting the bank saves 16 cycles and costs 14, so it's a bit faster,
            plb                                    ; but we really do it to preserve the X register
]src        equ   7
]dest       equ   0
            lup   8
            lda   tiledata+{]src*4},y
            sta   tmp_tile_data+{]dest*4}

            lda   tiledata+{]src*4}+2,y
            sta   tmp_tile_data+{]dest*4}+2
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            plb
            rts