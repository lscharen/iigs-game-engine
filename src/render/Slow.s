; Identical routines to those in Fast.s, but also set the opcode.  Used to render solid
; tiles when the engine mode has other capabilities turned on
;
; The following functions are defined here
;
; GenericOverSlow  : Places data from tmp_sprite_data on top of the TileStore's tile
; GenericUnderSlow : Places the TileStore's tile on top of tmp_sprite_data

GenericOverSlow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax

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
            jmp   _FillPEAOpcode

GenericUnderSlow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax

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
            jmp   _FillPEAOpcode
