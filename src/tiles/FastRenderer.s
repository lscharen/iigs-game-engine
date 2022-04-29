; If the engine mode has the second background layer disabled, we take advantage of that to
; be more efficient in our rendering.  Basically, without the second layer, there is no need
; to use the tile mask information.
;
; If there are no sprites, then we copy the tile data into the code field as fast as possible.
; If there are sprites, then the sprite data is flattened and stored into a direct page buffer
; and then copied into the code field
_RenderTileFast
            ldx   TileStore+TS_VBUFF_ADDR_COUNT,y   ; How many sprites are on this tile?
            beq   NoSpritesFast                     ; This is faster if there are no sprites

            lda   TileStore+TS_TILE_ID,y            ; Check if the tile has 
            jmp   (fast_dispatch,x)
fast_dispatch
            da    NoSpritesFast
            da    OneSpriteFast
            da    TwoSpritesFast
            da    ThreeSpritesFast
            da    FourSpritesFast

NoSpritesFast
            tyx
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has addl bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
            jmp   (TileStore+TS_BASE_TILE_DISP,x)  ; go to the tile copy routine (just basics)

; The TS_BASE_TILE_DISP routines will come from this table when ENGINE_MODE_TWO_LAYER and
; ENGINE_MODE_DYN_TILES are both off.
FastTileProcs dw   _TBCopyDataFast,_TBCopyDataFast,_TBCopyDataVFast,_TBCopyDataVFast

; Where there are sprites involved, the first step is to call a routine to copy the
; tile data into a temporary buffer.  Then the sprite data is merged and placed into
; the code field.
OneSpriteFast
            tyx
            lda   TileStore+TS_TILE_ADDR,y
            per   :-1
            jmp   (TileStore+TS_BASE_TILE_COPY,x)  ; Copy the tile data to the temporary buffer
:
            ldx   TileStore+TS_VBUFF_ADDR_0,y      ; address of the sprite data
            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later.
            lda   TileStore+TS_CODE_ADDR_LOW,y
            tay
            plb                                    ; set the code field bank

]line       equ   0
            lup   8
            lda   blttmp+{]line*4}
            andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
            oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]line*$1000},y

            lda   blttmp+{]line*4}+2
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^
            rts

TwoSpritesFast
            tyx
            lda   TileStore+TS_TILE_ADDR,y
            per   :-1
            jmp   (TileStore+TS_BASE_TILE_COPY,x)  ; Copy the tile data to the temporary buffer
:
            lda   TileStore+TS_VBUFF_ADDR_0,y      ; address of the sprite data
            sta   spritedata_0
            sta   spritemask_0
            lda   TileStore+TS_VBUFF_ADDR_1,y      ; address of the sprite data
            sta   spritedata_1
            sta   spritemask_1

            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later.
            lda   TileStore+TS_CODE_ADDR_LOW,y
            tay
            plb                                    ; set the code field bank

]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            lda   blttmp+{]line*4}
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0004+{]line*$1000},x

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            lda   blttmp+{]line*4}+2
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0001+{]line*$1000},x
]line       equ   ]line+1
            --^
            rts

ThreeSpritesFast
FourSpritesFast
            tyx
            lda   TileStore+TS_TILE_ADDR,y
            per   :-1
            jmp   (TileStore+TS_BASE_TILE_COPY,x)  ; Copy the tile data to the temporary buffer
:
            lda   TileStore+TS_VBUFF_ADDR_0,y      ; address of the sprite data
            sta   spritedata_0
            sta   spritemask_0
            lda   TileStore+TS_VBUFF_ADDR_1,y
            sta   spritedata_1
            sta   spritemask_1
            lda   TileStore+TS_VBUFF_ADDR_2,y
            sta   spritedata_2
            sta   spritemask_2

            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later.
            lda   TileStore+TS_CODE_ADDR_LOW,y
            tay
            plb                                    ; set the code field bank

]line       equ   0
            lup   8
            ldy   #{]line*SPRITE_PLANE_SPAN}
            lda   blttmp+{]line*4}
            andl  [spritemask_2],y
            oral  [spritedata_2],y
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0004+{]line*$1000},x

            ldy   #{]line*SPRITE_PLANE_SPAN}+2
            lda   blttmp+{]line*4}+2
            andl  [spritemask_2],y
            oral  [spritedata_2],y
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0001+{]line*$1000},x
]line       equ   ]line+1
            --^
            rts