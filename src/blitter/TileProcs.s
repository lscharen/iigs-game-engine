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
                 ldal  tiledata+{]line*4},x
                 sta   tmp_tile_data+{]line*4}

                 ldal  tiledata+{]line*4}+2,x
                 sta   tmp_tile_data+{]line*4}+2
]line            equ   ]line+1
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

