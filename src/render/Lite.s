; Collection of render function used when the engine is in "GTE Lite" mode.  In this mode
; there are no dynamic tile or two layer tiles enabled, so all of the tiles are comprised
; of PEA opcodes.  These functions take advantage of this and the fact that masks are
; not needed to improve rendering speed.
;
; The GTE Lite mode uses a compact code field that fits in a single bank of memory, so
; all of the rendering routines are basically the same as those in Fast.s, but use a
; different stride.

SpriteUnder0Lite
ConstTile0Lite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb

            lda   #0
]line       equ   0
            lup   8
            sta:  {_LINE_SIZE*]line}+$0001,y
            sta:  {_LINE_SIZE*]line}+$0004,y
]line       equ   ]line+1
            --^
            plb
            rts

SpriteOverALite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteOverALite
]line       equ   0
            lup   8
            ldal  tiledata+{]line*4},x
            and   tmp_sprite_mask+{]line*4}
            ora   tmp_sprite_data+{]line*4}
            sta:  $0004+{]line*_LINE_SIZE},y

            ldal  tiledata+{]line*4}+2,x
            and   tmp_sprite_mask+{]line*4}+2
            ora   tmp_sprite_data+{]line*4}+2
            sta:  $0001+{]line*_LINE_SIZE},y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteOverVLite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteOverVLite
]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*4},x
            and   tmp_sprite_mask+{]dest*4}
            ora   tmp_sprite_data+{]dest*4}
            sta:  $0004+{]dest*_LINE_SIZE},y

            ldal  tiledata+{]src*4}+2,x
            and   tmp_sprite_mask+{]dest*4}+2
            ora   tmp_sprite_data+{]dest*4}+2
            sta:  $0001+{]dest*_LINE_SIZE},y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            plb
            rts

SpriteOver0Lite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb

_SpriteOver0Lite
]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            sta:  $0004+{]line*_LINE_SIZE},y

            lda   tmp_sprite_data+{]line*4}+2
            sta:  $0001+{]line*_LINE_SIZE},y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteUnderALite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteUnderALite
]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            andl  tiledata+{]line*4}+32,x
            oral  tiledata+{]line*4},x
            sta:  $0004+{]line*_LINE_SIZE},y

            lda   tmp_sprite_data+{]line*4}+2
            andl  tiledata+{]line*4}+32+2,x
            oral  tiledata+{]line*4}+2,x
            sta:  $0001+{]line*_LINE_SIZE},y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteUnderVLite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteUnderVLite
]src        equ   7
]dest       equ   0
            lup   8
            lda   tmp_sprite_data+{]dest*4}
            andl  tiledata+{]src*4}+32,x
            oral  tiledata+{]src*4},x
            sta:  $0004+{]dest*_LINE_SIZE},y

            lda   tmp_sprite_data+{]dest*4}+2
            andl  tiledata+{]src*4}+32+2,x
            oral  tiledata+{]src*4}+2,x
            sta:  $0001+{]dest*_LINE_SIZE},y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^

            plb
            rts

CopyTileALite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb
            tax
;            brk   $ac
_CopyTileALite
]line       equ   0
            lup   8
            ldal  tiledata+{]line*4},x
            sta:  $0004+{]line*_LINE_SIZE},y
            ldal  tiledata+{]line*4}+2,x
            sta:  $0001+{]line*_LINE_SIZE},y
]line       equ   ]line+1
            --^
            plb
            rts

CopyTileVLite
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb

            tax
_CopyTileVLite
]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*4},x
            sta:  $0004+{]dest*_LINE_SIZE},y
            ldal  tiledata+{]src*4}+2,x
            sta:  $0001+{]dest*_LINE_SIZE},y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            plb
            rts

OneSpriteLiteOver0
            ldy   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            phy                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            tax                                    ; VBuff address from SpriteBitsToVBuffAddrs macro
            plb                                    ; set to the code field bank

_OneSpriteLiteOver0
]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]line*_LINE_SIZE},y
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]line*_LINE_SIZE},y
]line       equ   ]line+1
            --^

            plb                                    ; Restore the TileStore bank
            rts

; Next implementation; drawing a sprite onto a regular tile. The 1-sprite dispatch preserves the
; X-register, so it already points to the TileStore

OneSpriteLiteOverV
            jsr   FastCopyTileDataV
            bra   _OneSpriteLiteOver

OneSpriteLiteOverA
            jsr   FastCopyTileDataA

_OneSpriteLiteOver
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb

_OneSpriteLiteOverA
_OneSpriteLiteOverV
]line       equ   0
            lup   8
            lda   tmp_tile_data+{]line*4}
            andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
            oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]line*_LINE_SIZE},y

            lda   tmp_tile_data+{]line*4}+2
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]line*_LINE_SIZE},y
]line       equ   ]line+1
            --^
            plb
            rts

OneSpriteLiteUnderA
            jsr   FastCopyTileDataAndMaskA
            bra   _OneSpriteLiteUnder

OneSpriteLiteUnderV
            jsr   FastCopyTileDataAndMaskV

_OneSpriteLiteUnder
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            ldx   sprite_ptr0
            plb

_OneSpriteLiteUnderA
_OneSpriteLiteUnderV
]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            and   tmp_tile_mask+{]line*4}
            ora   tmp_tile_data+{]line*4}
            sta:  $0004+{]line*_LINE_SIZE},y

            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            and   tmp_tile_mask+{]line*4}+2
            ora   tmp_tile_data+{]line*4}+2
            sta:  $0001+{]line*_LINE_SIZE},y
]line       equ   ]line+1
            --^

            plb
            rts
