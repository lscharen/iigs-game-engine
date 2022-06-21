; Specialized routines that can be assigned to K_TS_ONE_SPRITE for rendering a single sprite into
; a tile. There are more variants of this function because having a single sprite in a tile is a very
; common scenario, so we put additional effort into optimizing this case.

;------------------------------
; Section: Above Tile Renderers

; The simplest implementation.  When drawing a sprite over Tile 0 in FAST mode, we can just copy the
; sprite data into the coe field directly.

_OneSpriteFastOver0
            ldy   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            phy                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            tax                                    ; VBuff address from SpriteBitsToVBuffAddrs macro
            plb                                    ; set to the code field bank

]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]line*$1000},y
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            plb                                    ; Restore the TileStore bank
            rts

; Next implementation; drawing a sprite onto a regular tile.  In this case we need to make
; use of the K_TS_COPY_TILE_DATA function because that takes care of copying the correct
; tile data into the direct page buffer.

; The 1-sprite dispatch prserves the X-register, so it already points to the TileStore

_OneSpriteFastOverV
            jsr   FastCopyTileDataV
            bra   _OneSpriteFastOver

_OneSpriteFastOverA
            jsr   FastCopyTileDataA

_OneSpriteFastOver
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

; This is the "SLOW" variant that fills in the PEA opcode specialized for Tile 0.

_OneSpriteSlowOver0
            ldy   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            phy                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            tax                                    ; VBuff address from SpriteBitsToVBuffAddrs macro
            plb                                    ; set to the code field bank

]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]line*$1000},y
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            jmp   _FillPEAOpcode

; Slow variant for regular tile.

_OneSpriteSlowOver
            jsr   CopyTileDataToDPA

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

; Fall through here to give the common case a small boost
_FillPEAOpcode
            sep   #$20
            lda   #$F4
]line       equ   0
            lup   8
            sta:  $0000+{]line*$1000},y
            sta:  $0003+{]line*$1000},y
]line       equ   ]line+1
            --^
            rep             #$20

            plb                                    ; Restore the TileStore bank
            rts

;------------------------------
; Section: Below Tile Renderers

; Drawing under the zero tile is the same as not drawing a sprite fo both the fast and slow cases
_OneSpriteFastUnderA
            jsr   FastCopyTileDataAndMaskA
            bra   _OneSpriteFastUnder

_OneSpriteFastUnderV
            jsr   FastCopyTileDataAndMaskV

_OneSpriteFastUnder
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb

]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            and   tmp_tile_mask+{]line*4}
            ora   tmp_tile_data+{]line*4}
            sta:  $0004+{]line*$1000},y

            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            and   tmp_tile_mask+{]line*4}+2
            ora   tmp_tile_data+{]line*4}+2
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            plb
            rts

_OneSpriteSlowUnder0
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
            jmp   (K_TS_BASE_TILE_DISP,x)          ; go to the tile copy routine

;--------------------------------
; Helper functions for one Sprite
CopyOneSpriteDataToDP
]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta   tmp_sprite_data+{]line*4}
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta   tmp_sprite_data+{]line*4}+2
]line       equ   ]line+1
            --^
            rts