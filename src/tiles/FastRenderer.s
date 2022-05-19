; If the engine mode has the second background layer disabled, we take advantage of that to
; be more efficient in our rendering.  Basically, without the second layer, there is no need
; to use the tile mask information.
;
; If there are no sprites, then we copy the tile data into the code field as fast as possible.
; If there are sprites, then the sprite data is flattened and stored into a direct page buffer
; and then copied into the code field
_RenderTileFast
;            lda   TileStore+TS_VBUFF_ADDR_COUNT,x   ; How many sprites are on this tile?
;            bne   SpriteDispatch                    ; This is faster if there are no sprites

NoSpriteFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
            jmp   (TileStore+TS_BASE_TILE_DISP,x)  ; go to the tile copy routine (just basics)

; The TS_BASE_TILE_DISP routines will come from this table when ENGINE_MODE_TWO_LAYER and
; ENGINE_MODE_DYN_TILES are both off.
FastTileProcs dw   _TBCopyDataFast,_TBCopyDataFast,_TBCopyDataFast,_TBCopyDataFast
; dw   _TBCopyDataFast,_TBCopyDataFast,_TBCopyDataVFast,_TBCopyDataVFast

SpriteDispatch
            tax
            jmp   (:,x)                            ; Dispatch to the other routines
:           da    NoSpriteFast                     ; Placeholder
            da    OneSpriteFast
            da    TwoSpritesFast
            da    ThreeSpritesFast
            da    FourSpritesFast

; Pointers to sprite data and masks
spritedata_0  equ   tmp0
spritedata_1  equ   tmp2
spritedata_2  equ   tmp4
spritedata_3  equ   tmp6
spritemask_0  equ   tmp8
spritemask_1  equ   tmp10
spritemask_2  equ   tmp12
spritemask_3  equ   tmp14

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

            TwoSpritesToCodeField 0
            TwoSpritesToCodeField 1
            TwoSpritesToCodeField 2
            TwoSpritesToCodeField 3
            TwoSpritesToCodeField 4
            TwoSpritesToCodeField 5
            TwoSpritesToCodeField 6
            TwoSpritesToCodeField 7

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

            ThreeSpritesToCodeField 0
            ThreeSpritesToCodeField 1
            ThreeSpritesToCodeField 2
            ThreeSpritesToCodeField 3
            ThreeSpritesToCodeField 4
            ThreeSpritesToCodeField 5
            ThreeSpritesToCodeField 6
            ThreeSpritesToCodeField 7

            rts