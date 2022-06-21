; Collection of render function used when the engine is in "FAST" mode.  In this mode
; there are no dynamic tile or two layer tiles enabled, so all of the tiles are comprised
; of PEA opcodes.  These functions take advantage of this as the fact that masks are
; not needed to improve rendering speed.
;
; The following functions are defined here
;
; GenericOverAFast  : Places data from tmp_sprite_data on top of the TileStore's tile
; GenericUnderAFast : Places the TileStore's tile on top of tmp_sprite_data

GenericOverAFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

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

GenericOverVFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*4},x
            and   tmp_sprite_mask+{]line*4}
            ora   tmp_sprite_data+{]line*4}
            sta:  $0004+{]line*$1000},y

            ldal  tiledata+{]src*4}+2,x
            and   tmp_sprite_mask+{]line*4}+2
            ora   tmp_sprite_data+{]line*4}+2
            sta:  $0001+{]line*$1000},y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            plb
            rts

GenericOverZero
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb

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

GenericUnderAFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            andl  tiledata+{]line*4}+32,x
            oral  tiledata+{]line*4}+32,x
            sta:  $0004+{]line*$1000},y

            lda   tmp_sprite_data+{]line*4}+2
            andl  tiledata+{]line*4}+32+2,x
            oral  tiledata+{]line*4}+32+2,x
            sta:  $0001+{]line*$1000},y
]line       equ   ]line+1
            --^

            plb
            rts

GenericUnderVFast
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

]src        equ   7
]dest       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            andl  tiledata+{]src*4}+32,x
            oral  tiledata+{]src*4}+32,x
            sta:  $0004+{]line*$1000},y

            lda   tmp_sprite_data+{]line*4}+2
            andl  tiledata+{]src*4}+32+2,x
            oral  tiledata+{]src*4}+32+2,x
            sta:  $0001+{]line*$1000},y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^

            plb
            rts

GenericUnderZero
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb
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
