; If there are no sprites, then we copy the tile data into the code field as fast as possible.
; If there are sprites, then additional work is required
_RenderTile
            lda   TileStore+TS_SPRITE_FLAG,x       ; any sprites on this line?
            bne   :sprites

            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
            jmp   (K_TS_BASE_TILE_DISP,x)          ; go to the tile copy routine

; Execute the sprite tree.  If there is only one sprite, control will immediately be passed to
; the routine at K_TS_ONE_SPRITE.  Otherwise, the control passed to the routines with a different
; number of sprites.  These routines need to copy the flattened sprite data and mask into the
; direct page workspace to be used by the K_TS_SPRITE_TILE_DISP routine
:sprites    txy
            SpriteBitsToVBuffAddrs $0000;TwoSprites;ThreeSprites;FourSprites

; Dispatch vectors for the two, three and four sprite functions.  These just
; flatten the sprite data into the direct page workspace and then pass control
; to the configurable routine which is set in SetTile and knows what to do
; based on the tile properties (over/under, engine mode, etc.)
TwoSprites  tyx
            jsr   CopyTwoSpritesDataAndMaskToDP
            jmp   (K_TS_SPRITE_TILE_DISP,x)

ThreeSprites tyx
            jsr   CopyThreeSpritesDataAndMaskToDP
            jmp   (K_TS_SPRITE_TILE_DISP,x)

FourSprites tyx
            jsr   CopyFourSpritesDataAndMaskToDP
            jmp   (K_TS_SPRITE_TILE_DISP,x)

; Helper functions (and macros)

; CopyTileToDP -- executes the K_TS_COPY_TILE_DATA routine.  This may copy just data or data+mask
;                 information to the direct page
_CopyTileToDP mac
            ldy   TileStore+TS_TILE_ADDR,x         ; load the tile address
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb                                    ; set to the tiledata bank
            jsr   (K_TS_COPY_TILE_DATA,x)          ; preserves X-reg
            plb
            <<<
CopyTileToDP
            _CopyTileToDP
            rts

; CopyTileToDPSprite -- same as above, but returns with the Data BAnk set to the sprite data bank
_CopyTileToDPSprite mac
            ldy   TileStore+TS_TILE_ADDR,x         ; load the tile address
            pei   DP2_TILEDATA_AND_SPRITEDATA_BANKS
            plb                                    ; set to the tiledata bank
            jsr   (K_TS_COPY_TILE_DATA,x)          ; preserves X-reg
            plb
            <<<
CopyTileToDPSprite
            _CopyTileToDPSprite
            rts

; Simple pair of routines that copies just the tile data to the direct page workspace.  Data Bank
; must be set to the TileData bank in entry.
;
; Preserves the X-register
CopyTileDataToDPA
]line       equ   0
            lup   8
            lda   tiledata+{]line*4},y
            sta   tmp_tile_data+{]line*4}

            lda   tiledata+{]line*4}+2,y
            sta   tmp_tile_data+{]line*4}+2
]line       equ   ]line+1
            --^
            rts

CopyTileDataToDPV
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
            rts

; Copy both the tile and mask data to the driect page space
_CopyTileDataAndMaskToDP
]line       equ   0
            lup   8
            lda   tiledata+{]line*4},y
            sta   tmp_tile_data+{]line*4}
            lda   tiledata+{]line*4}+32,y
            sta   tmp_tile_mask+{]line*4}

            lda   tiledata+{]line*4}+2,y
            sta   tmp_tile_data+{]line*4}+2
            lda   tiledata+{]line*4}+32+2,y
            sta   tmp_tile_mask+{]line*4}+2
]line       equ   ]line+1
            --^
            rts

_CopyTileDataAndMaskToDPV
]src        equ   7
]dest       equ   0
            lup   8
            lda   tiledata+{]src*4},y
            sta   tmp_tile_data+{]dest*4}
            lda   tiledata+{]src*4}+32,y
            sta   tmp_tile_mask+{]dest*4}

            lda   tiledata+{]src*4}+2,y
            sta   tmp_tile_data+{]dest*4}+2
            lda   tiledata+{]src*4}+32+2,y
            sta   tmp_tile_mask+{]dest*4}+2
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            rts

; Given a populate tmp_sprite_data buffer to use as a base, merge it with a tile and write to the 
; code field
MergeSpriteWithTileFast
            ldx   TileStore+TS_TILE_ADDR,y
            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            lda   TileStore+TS_CODE_ADDR_LOW,y     ; load the address of the code field
            tay
            plb

]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            andl  tiledata+{]line*4}+32,x
            oral  tiledata+{]line*4},x
            sta:  $0004+{]line*$1000},y

            lda   tmp_sprite_data+{]line*4}+2
            andl  tiledata+{]line*4}+32+2,x
            oral  tiledata+{]line*4}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^
            plb
            rts

MergeSpriteWithTileSlow
            ldx   TileStore+TS_TILE_ADDR,y
            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            lda   TileStore+TS_CODE_ADDR_LOW,y     ; load the address of the code field
            tay
            plb

]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            andl  tiledata+{]line*4}+32,x
            oral  tiledata+{]line*4},x
            sta:  $0004+{]line*$1000},y

            lda   tmp_sprite_data+{]line*4}+2
            andl  tiledata+{]line*4}+32+2,x
            oral  tiledata+{]line*4}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^
            jmp   _FillPEAOpcode





; Now, implement the generic Two, Three and Four sprite routines for both Over and Under rendering. These
; are fairly involved, so we try to only have a single implementation of them for now without excessve
; specialization.


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
]line       equ   ]line+1
            --^

            plb
            jmp   (K_TS_APPLY_TILE_DATA,x)


