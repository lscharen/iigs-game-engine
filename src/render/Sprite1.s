; Specialized routines that can be assigned to K_TS_ONE_SPRITE for rendering a single sprite into
; a tile. There are more variants of this function because having a single sprite in a tile is a very
; common scenario, so we put additional effort into optimizing this case.

;------------------------------
; Section: Above Tile Renderers

; The simplest implementation.  When drawing a sprite over Tile 0 in FAST mode, we can just copy the
; sprite data into the coe field directly.

OneSpriteFastOver0
            ldy   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            phy                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            tax                                    ; VBuff address from SpriteBitsToVBuffAddrs macro
            plb                                    ; set to the code field bank

_OneSpriteFastOver0
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

; Next implementation; drawing a sprite onto a regular tile. The 1-sprite dispatch preerves the
; X-register, so it already points to the TileStore

OneSpriteFastOverV
            jsr   FastCopyTileDataV
            bra   _OneSpriteFastOver

OneSpriteFastOverA
            jsr   FastCopyTileDataA

_OneSpriteFastOver
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb

_OneSpriteFastOverA
_OneSpriteFastOverV
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

OneSpriteSlowOver0
            ldy   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            phy                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            tax                                    ; VBuff address from SpriteBitsToVBuffAddrs macro
            plb                                    ; set to the code field bank
            jsr   FillPEAOpcode
            jmp   _OneSpriteFastOver0

; Slow variant for regular tile.
OneSpriteSlowOverV
            jsr   FastCopyTileDataV
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb
            jsr   FillPEAOpcode
            jmp   _OneSpriteFastOverV

OneSpriteSlowOverA
            jsr   FastCopyTileDataA
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb
            jsr   FillPEAOpcode
            jmp   _OneSpriteFastOverA

;------------------------------
; Section: Below Tile Renderers

; Drawing under the zero tile is the same as not drawing a sprite fo both the fast and slow cases
OneSpriteFastUnderA
            jsr   FastCopyTileDataAndMaskA
            bra   _OneSpriteFastUnder

OneSpriteFastUnderV
            jsr   FastCopyTileDataAndMaskV

_OneSpriteFastUnder
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb

_OneSpriteFastUnderA
_OneSpriteFastUnderV
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

OneSpriteSlowUnderA
            jsr   FastCopyTileDataAndMaskA
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb
            jsr   FillPEAOpcode
            jmp   _OneSpriteFastUnderA

OneSpriteSlowUnderV
            jsr   FastCopyTileDataAndMaskV
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb
            jsr   FillPEAOpcode
            jmp   _OneSpriteFastUnderV

;-------------------------------
; Dynamic tiles with one sprite.

OneSpriteDynamicUnder
            ldx   sprite_ptr0
]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta   tmp_sprite_data+{]line*4}
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta   tmp_sprite_data+{]line*4}+2
]line       equ   ]line+1
            --^
            jmp   DynamicUnder

OneSpriteDynamicOver
            ldx   sprite_ptr0
]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta   tmp_sprite_data+{]line*4}
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta   tmp_sprite_data+{]line*4}+2

            ldal  spritemask+{]line*SPRITE_PLANE_SPAN},x
            sta   tmp_sprite_mask+{]line*4}
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta   tmp_sprite_mask+{]line*4}+2
]line       equ   ]line+1
            --^
            jmp   DynamicOver

