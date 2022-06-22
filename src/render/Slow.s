; Identical routines to those in Fast.s, but also set the opcode.  Used to render solid
; tiles when the engine mode has other capabilities turned on
;
; The following functions are defined here
;
; GenericOverSlow  : Places data from tmp_sprite_data on top of the TileStore's tile
; GenericUnderSlow : Places the TileStore's tile on top of tmp_sprite_data

ConstTile0Slow
            jsr   FillPEAOpcode
            jmp   ConstTile0Fast

SpriteOverASlow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb
            jsr   FillPEAOpcode
            jmp   _SpriteOverAFast

SpriteOverVSlow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb
            jsr   FillPEAOpcode
            jmp   _SpriteOverVFast

SpriteOver0Slow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb
            jsr   FillPEAOpcode
            jmp   _SpriteOver0Fast

SpriteUnderASlow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb
            jsr   FillPEAOpcode
            jmp   _SpriteUnderAFast

SpriteUnderVSlow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x
            tax
            plb
            jsr   FillPEAOpcode
            jmp   _SpriteUnderVFast

SpriteUnder0Slow
            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            plb
            jsr   FillPEAOpcode
            jmp   _SpriteUnder0Fast

; Helper function; no stack manipulation
FillPEAOpcode
            sep   #$20
            lda   #$F4
]line       equ   0
            lup   8
            sta:  $0000+{]line*$1000},y
            sta:  $0003+{]line*$1000},y
]line       equ   ]line+1
            --^
            rep   #$20
            rts

; This is a dtub; will be removed eventually
_FillPEAOpcode
            jsr   FillPEAOpcode
            plb                                    ; Restore the TileStore bank
            rts