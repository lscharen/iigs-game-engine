; If the engine mode has the second background layer disabled, we take advantage of that to
; be more efficient in our rendering.  Basically, without the second layer, there is no need
; to use the tile mask information.
;
; If there are no sprites, then we copy the tile data into the code field as fast as possible.
; If there are sprites, then the sprite data is flattened and stored into a direct page buffer
; and then copied into the code field
_RenderTileFast
            lda   TileStore+TS_SPRITE_FLAG,x       ; any sprites on this line?
            bne   SpriteDispatch

NoSpriteFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_BASE_TILE_DISP,x    ; go to the tile copy routine (just basics)
            stal  nsf_patch+1
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
nsf_patch   jmp   $0000

; The TS_BASE_TILE_DISP routines will come from this table when ENGINE_MODE_TWO_LAYER and
; ENGINE_MODE_DYN_TILES are both off.
FastTileProcs dw   _TBCopyDataFast,_TBCopyDataFast,_TBCopyDataFast,_TBCopyDataFast
; dw   _TBCopyDataFast,_TBCopyDataFast,_TBCopyDataVFast,_TBCopyDataVFast

; NOTE: Inlining the dispatch would eliminate a JSR,RTS,LDX, and JMP (abs,x) because the exit code
;       could jump directly to the target address.  Net savings of 20 cycles per tile.  For a 16x16
;       sprite with a 3x3 block coverage this is 180 cycles per frame per block...  This would also 
;       preserve a register
;
;       For comparison, a fast one sprite copy takes 22 cycles per word, so this would save
;       about 1/2 block of render time per tile.
;
; Need to determine if the sprite or tile data is on top, as that will decide whether the
; sprite or tile data is copied into the temporary buffer first.  Also, if TWO_LAYER is set
; then the mask information must be copied as well....This is the last decision point.

SpriteDispatch
            txy
            SpriteBitsToVBuffAddrs OneSpriteFast;OneSpriteFast;OneSpriteFast;OneSpriteFast

; Where there are sprites involved, the first step is to call a routine to copy the
; tile data into a temporary buffer.  Then the sprite data is merged and placed into
; the code field.
;
; A = vbuff address
; Y = tile store address
OneSpriteFast
            sta   sprite_ptr0
            ldx   TileStore+TS_TILE_ADDR,y
            jsr   _CopyTileDataToDP2               ; preserves Y
            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldx   sprite_ptr0                      ; address of sprite vbuff info
            lda   TileStore+TS_CODE_ADDR_LOW,y     ; load the address of the code field
            tay
            plb

;            jmp   _TBApplySpriteData2
_TBApplySpriteData2
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


OneSpriteFastX
            tax                                    ; address of the sprite data
            lda   TileStore+TS_BASE_TILE_COPY,y    ; copy routine (handles flips and other behaviors)
            stal  osf_copy+1
osf_copy    jsr   $0000

;            ldx   TileStore+TS_VBUFF_ADDR_0,y      ; address of the sprite data
            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later.
            lda   TileStore+TS_CODE_ADDR_LOW,y
            tay
            plb                                    ; set the code field bank

            OneSpriteToCodeField 0
            OneSpriteToCodeField 1
            OneSpriteToCodeField 2
            OneSpriteToCodeField 3
            OneSpriteToCodeField 4
            OneSpriteToCodeField 5
            OneSpriteToCodeField 6
            OneSpriteToCodeField 7

            rts

TwoSpritesFast
;            tyx
;            lda   TileStore+TS_TILE_ADDR,y
;            per   :-1
;            jmp   (TileStore+TS_BASE_TILE_COPY,x)  ; Copy the tile data to the temporary buffer
;:
;            lda   TileStore+TS_VBUFF_ADDR_0,y      ; address of the sprite data
;            sta   spritedata_0
;            sta   spritemask_0
;            lda   TileStore+TS_VBUFF_ADDR_1,y      ; address of the sprite data
;            sta   spritedata_1
;            sta   spritemask_1

            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later.
            lda   TileStore+TS_CODE_ADDR_LOW,y
            tay
            plb                                    ; set the code field bank

;            TwoSpritesToCodeField 0
;            TwoSpritesToCodeField 1
;            TwoSpritesToCodeField 2
;            TwoSpritesToCodeField 3
;            TwoSpritesToCodeField 4
;            TwoSpritesToCodeField 5
;            TwoSpritesToCodeField 6
;            TwoSpritesToCodeField 7

            rts

ThreeSpritesFast
FourSpritesFast
;            tyx
;            lda   TileStore+TS_TILE_ADDR,y
;            per   :-1
;            jmp   (TileStore+TS_BASE_TILE_COPY,x)  ; Copy the tile data to the temporary buffer
;:
;            lda   TileStore+TS_VBUFF_ADDR_0,y      ; address of the sprite data
;            sta   spritedata_0
;            sta   spritemask_0
;            lda   TileStore+TS_VBUFF_ADDR_1,y
;            sta   spritedata_1
;            sta   spritemask_1
;            lda   TileStore+TS_VBUFF_ADDR_2,y
;            sta   spritedata_2
;            sta   spritemask_2

            lda   TileStore+TS_CODE_ADDR_HIGH,y    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later.
            lda   TileStore+TS_CODE_ADDR_LOW,y
            tay
            plb                                    ; set the code field bank

;            ThreeSpritesToCodeField 0
;            ThreeSpritesToCodeField 1
;            ThreeSpritesToCodeField 2
;            ThreeSpritesToCodeField 3
;            ThreeSpritesToCodeField 4
;            ThreeSpritesToCodeField 5
;            ThreeSpritesToCodeField 6
;            ThreeSpritesToCodeField 7

            rts