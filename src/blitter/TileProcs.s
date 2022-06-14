; A simple helper function that fills in all of the opcodes of a tile with the PEA opcode.  This is
; a separate functino because we can often just update the tile data if we know the opcodes are already
; set.  When we have to fill the opcodes, this function is used
_TBFillPEAOpcode
                 sep             #$20
                 lda             #$F4
]line            equ   0
                 lup   8
                 sta:            $0000+{]line*$1000},y
                 sta:            $0003+{]line*$1000},y
]line            equ   ]line+1
                 --^
                 rep             #$20
                 rts

; Copy tile data into the direct page compositing buffer.  The main reason to do this in full passes is
; because we can avoid needing to use both the X and Y registers during the compositing process and
; reserve Y to hold the code field address.
;
; Also, we can get away with not setting the bank register, this is a wash in terms of speed, but results
; in simpler, more composable subroutines
_TBCopyTileDataAndMaskToCBuff
                 jsr   _TBCopyTileDataToCBuff
                 jmp   _TBCopyTileMaskToCBuff

_TBCopyTileDataAndMaskToCBuffV
                 jsr   _TBCopyTileDataToCBuffV
                 jmp   _TBCopyTileMaskToCBuffV

_CopyTileDataToDP2
]line            equ   0
                 lup   8
                 lda   tiledata+{]line*4},y
                 sta   tmp_tile_data+{]line*4}

                 lda   tiledata+{]line*4}+2,y
                 sta   tmp_tile_data+{]line*4}+2
]line            equ   ]line+1
                 --^
                 rts

_CopyTileDataToDP2V
]src             equ   7
]dest            equ   0
                 lup   8
                 lda   tiledata+{]src*4},y
                 sta   tmp_tile_data+{]dest*4}

                 lda   tiledata+{]src*4}+2,y
                 sta   tmp_tile_data+{]dest*4}+2
]src             equ   ]src-1
]dest            equ   ]dest+1
                 --^
                 rts


_TBCopyTileDataToCBuff
]line            equ   0
                 lup   8
                 ldal  tiledata+{]line*4},x
                 sta   blttmp+{]line*4}

                 ldal  tiledata+{]line*4}+2,x
                 sta   blttmp+{]line*4}+2
]line            equ   ]line+1
                 --^
                 rts

_TBCopyTileDataToCBuffV
]src             equ   7
]dest            equ   0
                 lup   8
                 ldal  tiledata+{]src*4},x
                 sta   blttmp+{]dest*4}

                 ldal  tiledata+{]src*4}+2,x
                 sta   blttmp+{]dest*4}+2
]src             equ   ]src-1
]dest            equ   ]dest+1
                 --^
                 rts

; Copy tile mask data into the direct page compositing buffer.
_TBCopyTileMaskToCBuff
]line            equ   0
                 lup   8
                 ldal  tiledata+{]line*4}+32,x
                 sta   blttmp+{]line*4}+32

                 ldal  tiledata+{]line*4}+32+2,x
                 sta   blttmp+{]line*4}+32+2
]line            equ   ]line+1
                 --^
                 rts

_TBCopyTileMaskToCBuffV
]src             equ   7
]dest            equ   0
                 lup   8
                 ldal  tiledata+{]src*4}+32,x
                 sta  blttmp+{]dest*4}+32

                 ldal  tiledata+{]src*4}+32+2,x
                 sta   blttmp+{]dest*4}+32+2
]src             equ   ]src-1
]dest            equ   ]dest+1
                 --^
                 rts

; Tile 0 specializations
; _TBConstTile
;
; A specialized routine that fills in a tile with a single constant value.  It's intended to be used to
; fill in solid colors, so there are no specialized horizontal or verical flipped variants
_TBConstTile0    tax
                 lda             #0
_TBConstTileX    sta:            $0001,y
                 sta:            $0004,y
                 sta             $1001,y
                 sta             $1004,y
                 sta             $2001,y
                 sta             $2004,y
                 sta             $3001,y
                 sta             $3004,y
                 sta             $4001,y
                 sta             $4004,y
                 sta             $5001,y
                 sta             $5004,y
                 sta             $6001,y
                 sta             $6004,y
                 sta             $7001,y
                 sta             $7004,y
                 plb
                 rts
;                 jmp             _TBFillPEAOpcode

_TBConstTileDataToDP2
]line            equ   0
                 lup   8
                 stz   tmp_tile_data+{]line*4}
                 stz   tmp_tile_data+{]line*4}+2
]line            equ   ]line+1
                 --^
                 rts
