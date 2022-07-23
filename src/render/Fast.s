; Collection of render function used when the engine is in "FAST" mode.  In this mode
; there are no dynamic tile or two layer tiles enabled, so all of the tiles are comprised
; of PEA opcodes.  These functions take advantage of this as the fact that masks are
; not needed to improve rendering speed.

ConstTile0Fast
            lda   #0
            sta:  $0001,y
            sta:  $0004,y
            sta   $1001,y
            sta   $1004,y
            sta   $2001,y
            sta   $2004,y
            sta   $3001,y
            sta   $3004,y
            sta   $4001,y
            sta   $4004,y
            sta   $5001,y
            sta   $5004,y
            sta   $6001,y
            sta   $6004,y
            sta   $7001,y
            sta   $7004,y
            plb
            rts

SpriteOverAFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteOverAFast                                   ; Alternate entry point for the "Slow" routines
]line       equ   0
            lup   8
            ldal  tiledata+{]line*4},x
            and   tmp_sprite_mask+{]line*4}
            ora   tmp_sprite_data+{]line*4}
            sta:  $0004+{]line*$1000},y

            ldal  tiledata+{]line*4}+2,x
            and   tmp_sprite_mask+{]line*4}+2
            ora   tmp_sprite_data+{]line*4}+2
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteOverVFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteOverVFast
]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*4},x
            and   tmp_sprite_mask+{]dest*4}
            ora   tmp_sprite_data+{]dest*4}
            sta:  $0004+{]dest*$1000},y

            ldal  tiledata+{]src*4}+2,x
            and   tmp_sprite_mask+{]dest*4}+2
            ora   tmp_sprite_data+{]dest*4}+2
            sta:  $0001+{]dest*$1000},y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            plb
            rts

SpriteOver0Fast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb

_SpriteOver0Fast
]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            sta:  $0004+{]line*$1000},y

            lda   tmp_sprite_data+{]line*4}+2
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteUnderAFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteUnderAFast
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

SpriteUnderVFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

_SpriteUnderVFast
]src        equ   7
]dest       equ   0
            lup   8
            lda   tmp_sprite_data+{]dest*4}
            andl  tiledata+{]src*4}+32,x
            oral  tiledata+{]src*4},x
            sta:  $0004+{]dest*$1000},y

            lda   tmp_sprite_data+{]dest*4}+2
            andl  tiledata+{]src*4}+32+2,x
            oral  tiledata+{]src*4}+2,x
            sta:  $0001+{]dest*$1000},y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^

            plb
            rts

SpriteUnder0Fast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb

_SpriteUnder0Fast
            lda   #0
]line       equ   0
            lup   8
            sta:  $0004+{]line*$1000},y
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            plb
            rts

; Simple pair of routines that copies just the tile data to the direct page workspace.  Data Bank
; must be set to the TileData bank in entry.
;
; Preserves the X-register
FastCopyTileDataA
            ldy   TileStore+TS_TILE_ADDR,x         ; load the tile address
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb                                    ; set to the tiledata bank

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

FastCopyTileDataV
            ldy   TileStore+TS_TILE_ADDR,x         ; load the tile address
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb                                    ; set to the tiledata bank

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

FastCopyTileDataAndMaskA
            ldy   TileStore+TS_TILE_ADDR,x         ; load the tile address
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb                                    ; set to the tiledata bank

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

            plb
            rts

FastCopyTileDataAndMaskV
            ldy   TileStore+TS_TILE_ADDR,x         ; load the tile address
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb                                    ; set to the tiledata bank

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
            
            plb
            rts

; The workhorse blitter.  This blitter copies tile data into the code field without masking.  This is the
; most common blitter function.  It is slightly optimized to fall through to the code that sets the PEA
; opcodes in order to be slightly more efficient given it's frequent usage.
;
; There is a small variation of this blitter that just copies the data without setting the PEA opcodes.  This
; is used by the engine when the capabilitiy bits have turned off the second background layer.  In fact, most
; of the tile rendering routines have an optimized version for this important use case.  Skipping the opcode
; step results in a 37% speed boost in tile rendering.
;
; This does not increase the FPS by 37% because only a small number of tiles are drawn each frame, but it
; has an impact and can significantly help out when sprites trigger more dirty tile updates than normal.


; This is called via a JMP (abs,x) with an extra byte on the stack that holds the bank
; register value.  This must be restored prior to returning
CopyTileAFast
                 tax
_CopyTileAFast
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0004+{]line*$1000},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0001+{]line*$1000},y
]line            equ             ]line+1
                 --^
                 plb
                 rts


CopyTileVFast
                 tax
_CopyTileVFast
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4},x
                 sta:            $0004+{]dest*$1000},y
                 ldal            tiledata+{]src*4}+2,x
                 sta:            $0001+{]dest*$1000},y
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 plb
                 rts
