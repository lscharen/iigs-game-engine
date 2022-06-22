; Collection of render function used when the engine is in "Two Layer" mode. Other than the Tile 0
; routines, there's nothing in here that is particularly well optimized.

Tile0TwoLyr
            and   #$00FF
            ora   #$4800
            sta:  $0004,y
            sta   $1004,y
            sta   $2004,y
            sta   $3004,y
            sta   $4004,y
            sta   $5004,y
            sta   $6004,y
            sta   $7004,y
            inc
            inc
            sta:  $0001,y
            sta   $1001,y
            sta   $2001,y
            sta   $3001,y
            sta   $4001,y
            sta   $5001,y
            sta   $6001,y
            sta   $7001,y

            sep   #$20
            lda   #$B1          ; This is a special case where we can set all the words to LDA (DP),y
            sta:  $0000,y
            sta:  $0003,y
            sta   $1000,y
            sta   $1003,y
            sta   $2000,y
            sta   $2003,y
            sta   $3000,y
            sta   $3003,y
            sta   $4000,y
            sta   $4003,y
            sta   $5000,y
            sta   $5003,y
            sta   $6000,y
            sta   $6003,y
            sta   $7000,y
            sta   $7003,y
            rep   #$20
            rts

; Draw from the sprite buffer into a fully transparent tile
SpriteOver0TwoLyr

            lda   TileStore+TS_JMP_ADDR,x      ; Get the address of the exception handler
            sta   _JTBL_CACHE

            lda   TileStore+TS_WORD_OFFSET,x   ; Load the word offset of this tile (0 to 82 in steps of 2)
            ora   #$B100                       ; Pre-calc the LDA (dp),y opcode + operand
            xba
            sta   _OP_CACHE

            lda   TileStore+TS_CODE_ADDR_HIGH,x
            pha
            ldy   TileStore+TS_CODE_ADDR_LOW,x
            plb

            CopyTwoLayerOver  tmp_sprite_data+0;$0003
            CopyTwoLayerOver  tmp_sprite_data+4;$1003
            CopyTwoLayerOver  tmp_sprite_data+8;$2003
            CopyTwoLayerOver  tmp_sprite_data+12;$3003
            CopyTwoLayerOver  tmp_sprite_data+16;$4003
            CopyTwoLayerOver  tmp_sprite_data+20;$5003
            CopyTwoLayerOver  tmp_sprite_data+24;$6003
            CopyTwoLayerOver  tmp_sprite_data+28;$7003

            sec
            lda     _JTBL_CACHE
            sbc     #SNIPPET_SIZE      ; Advance to the next snippet (Reverse indexing)
            sta     _JTBL_CACHE

            clc
            lda     _OP_CACHE
            adc     #$0200             ; Advance to the next word
            sta     _OP_CACHE

            CopyTwoLayerOver  tmp_sprite_data+2;$0000
            CopyTwoLayerOver  tmp_sprite_data+6;$1000
            CopyTwoLayerOver  tmp_sprite_data+10;$2000
            CopyTwoLayerOver  tmp_sprite_data+14;$3000
            CopyTwoLayerOver  tmp_sprite_data+18;$4000
            CopyTwoLayerOver  tmp_sprite_data+22;$5000
            CopyTwoLayerOver  tmp_sprite_data+26;$6000
            CopyTwoLayerOver  tmp_sprite_data+30;$7000

            plb
            rts

TmpTileDataToCodeField
            lda   TileStore+TS_JMP_ADDR,x      ; Get the address of the exception handler
            sta   _JTBL_CACHE

            lda   TileStore+TS_WORD_OFFSET,x   ; Load the word offset of this tile (0 to 82 in steps of 2)
            ora   #$B100                       ; Pre-calc the LDA (dp),y opcode + operand
            xba
            sta   _OP_CACHE

            lda   TileStore+TS_CODE_ADDR_HIGH,x
            pha
            ldy   TileStore+TS_CODE_ADDR_LOW,x
            plb

_TmpTileDataToCodeField

            CopyTwoLayerOver  tmp_tile_data+0;$0003
            CopyTwoLayerOver  tmp_tile_data+4;$1003
            CopyTwoLayerOver  tmp_tile_data+8;$2003
            CopyTwoLayerOver  tmp_tile_data+12;$3003
            CopyTwoLayerOver  tmp_tile_data+16;$4003
            CopyTwoLayerOver  tmp_tile_data+20;$5003
            CopyTwoLayerOver  tmp_tile_data+24;$6003
            CopyTwoLayerOver  tmp_tile_data+28;$7003

            sec
            lda     _JTBL_CACHE
            sbc     #SNIPPET_SIZE      ; Advance to the next snippet (Reverse indexing)
            sta     _JTBL_CACHE

            clc
            lda     _OP_CACHE
            adc     #$0200             ; Advance to the next word
            sta     _OP_CACHE

            CopyTwoLayerOver  tmp_tile_data+2;$0000
            CopyTwoLayerOver  tmp_tile_data+6;$1000
            CopyTwoLayerOver  tmp_tile_data+10;$2000
            CopyTwoLayerOver  tmp_tile_data+14;$3000
            CopyTwoLayerOver  tmp_tile_data+18;$4000
            CopyTwoLayerOver  tmp_tile_data+22;$5000
            CopyTwoLayerOver  tmp_tile_data+26;$6000
            CopyTwoLayerOver  tmp_tile_data+30;$7000

            plb
            rts

; Copy a tile into the tile data buffer and then render to the code field
CopyTileATwoLyr
            lda   TileStore+TS_JMP_ADDR,x      ; Get the address of the exception handler
            sta   _JTBL_CACHE

            lda   TileStore+TS_WORD_OFFSET,x   ; Load the word offset of this tile (0 to 82 in steps of 2)
            ora   #$B100                       ; Pre-calc the LDA (dp),y opcode + operand
            xba
            sta   _OP_CACHE

            lda   TileStore+TS_CODE_ADDR_HIGH,x
            pha
            ldy   TileStore+TS_CODE_ADDR_LOW,x
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

]line       equ   0
            lup   8
            ldal  tiledata+{]line*4},x
            sta   tmp_tile_data+{]line*4}
            ldal  tiledata+{]line*4}+32,x
            sta   tmp_tile_mask+{]line*4}

            ldal  tiledata+{]line*4}+2,x
            sta   tmp_tile_data+{]line*4}+2
            ldal  tiledata+{]line*4}+32+2,x
            sta   tmp_tile_mask+{]line*4}+2
]line       equ   ]line+1
            --^
            jmp   _TmpTileDataToCodeField

CopyTileVTwoLyr
            lda   TileStore+TS_JMP_ADDR,x      ; Get the address of the exception handler
            sta   _JTBL_CACHE

            lda   TileStore+TS_WORD_OFFSET,x   ; Load the word offset of this tile (0 to 82 in steps of 2)
            ora   #$B100                       ; Pre-calc the LDA (dp),y opcode + operand
            xba
            sta   _OP_CACHE

            lda   TileStore+TS_CODE_ADDR_HIGH,x
            pha
            ldy   TileStore+TS_CODE_ADDR_LOW,x
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb

]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*4},x
            sta   tmp_tile_data+{]dest*4}
            ldal  tiledata+{]src*4}+32,x
            sta   tmp_tile_mask+{]dest*4}

            ldal  tiledata+{]src*4}+2,x
            sta   tmp_tile_data+{]dest*4}+2
            ldal  tiledata+{]src*4}+32+2,x
            sta   tmp_tile_mask+{]dest*4}+2
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            jmp   _TmpTileDataToCodeField

; Handle sprites + tiles.  Strategy is to merge the sprite and tile data and write it to the
; temporary space an defer the actual work to the _TmpTileDataToCodeField helper
SpriteOverATwoLyr
            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb

]line       equ   0
            lup   8
            lda   tiledata+{]line*4},y
            and   tmp_sprite_mask+{]line*4}
            ora   tmp_sprite_data+{]line*4}
            sta   tmp_tile_data+{]line*4}

            lda   tiledata+{]line*4}+32,y
            and   tmp_sprite_mask+{]line*4}
            sta   tmp_tile_mask+{]line*4}

            lda   tiledata+{]line*4}+2,y
            and   tmp_sprite_mask+{]line*4}+2
            ora   tmp_sprite_data+{]line*4}+2
            sta   tmp_tile_data+{]line*4}+2

            lda   tiledata+{]line*4}+32+2,y
            and   tmp_sprite_mask+{]line*4}+2
            sta   tmp_tile_mask+{]line*4}+2
]line       equ   ]line+1
            --^
            plb
            jmp   TmpTileDataToCodeField

SpriteOverVTwoLyr
            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb

]src        equ   7
]dest       equ   0
            lup   8
            lda   tiledata+{]src*4},y
            and   tmp_sprite_mask+{]dest*4}
            ora   tmp_sprite_data+{]dest*4}
            sta   tmp_tile_data+{]dest*4}

            lda   tiledata+{]src*4}+32,y
            and   tmp_sprite_mask+{]dest*4}
            sta   tmp_tile_mask+{]dest*4}

            lda   tiledata+{]src*4}+2,y
            and   tmp_sprite_mask+{]dest*4}+2
            ora   tmp_sprite_data+{]dest*4}+2
            sta   tmp_tile_data+{]dest*4}+2

            lda   tiledata+{]src*4}+32+2,y
            and   tmp_sprite_mask+{]dest*4}+2
            sta   tmp_tile_mask+{]dest*4}+2

]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            plb
            jmp   TmpTileDataToCodeField

SpriteUnderATwoLyr
            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb

]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}
            and   tiledata+{]line*4}+32,y
            ora   tiledata+{]line*4},y
            sta   tmp_tile_data+{]line*4}

            lda   tiledata+{]line*4}+32,y
            and   tmp_sprite_mask+{]line*4}
            sta   tmp_tile_mask+{]line*4}

            lda   tmp_sprite_data+{]line*4}+2
            and   tiledata+{]line*4}+32+2,y
            ora   tiledata+{]line*4}+2,y
            sta   tmp_tile_data+{]line*4}+2

            lda   tiledata+{]line*4}+32+2,y
            and   tmp_sprite_mask+{]line*4}+2
            sta   tmp_tile_mask+{]line*4}+2
]line       equ   ]line+1
            --^
            plb
            jmp   TmpTileDataToCodeField

SpriteUnderVTwoLyr
            ldy   TileStore+TS_TILE_ADDR,x
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb

]src        equ   7
]dest       equ   0
            lup   8
            lda   tmp_sprite_data+{]dest*4}
            and   tiledata+{]src*4}+32,y
            ora   tiledata+{]src*4},y
            sta   tmp_tile_data+{]dest*4}

            lda   tiledata+{]src*4}+32,y
            and   tmp_sprite_mask+{]dest*4}
            sta   tmp_tile_mask+{]dest*4}

            lda   tmp_sprite_data+{]dest*4}+2
            and   tiledata+{]src*4}+32+2,y
            ora   tiledata+{]src*4}+2,y
            sta   tmp_tile_data+{]dest*4}+2

            lda   tiledata+{]src*4}+32+2,y
            and   tmp_sprite_mask+{]dest*4}+2
            sta   tmp_tile_mask+{]dest*4}+2

]src        equ   ]src-1
]dest       equ   ]dest+1
            --^
            plb
            jmp   TmpTileDataToCodeField

; Macro to fill in the code field from a direct page temporary buffer
;
; ]1 : direct page address with data, the mask direct page address is data + 32
; ]2 : code field offset
;
; Y is the code field address
CopyTwoLayerOver mac
            lda   {]1}+32           ; load the mask value
            bne   mixed             ; a non-zero value may be mixed

; This is a solid word
            lda   #$00F4            ; PEA instruction
            sta:  ]2,y
            lda   {]1}              ; load the tile data
            sta:  ]2+1,y            ; PEA operand
            bra   next

mixed       cmp   #$FFFF            ; All 1's in the mask is fully transparent
            beq   transparent

            lda   #$004C            ; JMP instruction
            sta:  {]2},y
            lda   _JTBL_CACHE       ; Get the offset to the exception handler for this column
            ora   #{]2&$7000}       ; adjust for the current row offset
            sta:  {]2}+1,y
            tax                     ; This becomes the new address that we use to patch in

            lda   #$29
            sta:  $0002,x         ; AND #$0000 opcode
            lda   #$09
            sta:  $0005,x         ; ORA #$0000 opcode

            lda   _OP_CACHE       ; Get the LDA (dp),y instruction for this column
            sta:  $0000,x

            lda   {]1}+32           ; insert the tile mask and data into the exception
            sta:  $0003,x         ; handler.
            lda   {]1}
            sta:  $0006,x

            lda   #$0D80          ; branch to the prologue (BRA *+15)
            sta:  $0008,x

            bra   next

; This is a transparent word, so just show the second background layer
transparent
            lda   #$4800          ; put a PHA after the offset
            sta:  {]2}+1,y
            lda   _OP_CACHE
            sta:  {]2},y
next
            eom