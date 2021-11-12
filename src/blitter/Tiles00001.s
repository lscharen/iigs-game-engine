; _TBDynamicTile
;
; These subroutines fill in the code field with the instructions to render data from the dynamic
; code buffer.  This is a bit different, because no tile data is manipulated.  It is the
; responsibiliy of the user of the API to use the CopyTileToDyn subroutine to get data 
; into the correct location.
;
; This tile type does not explicitly support horizontal or vertical flipping.  An appropriate tile
; descriptor should be passed into CopyTileToDyn to put the horizontally or vertically flipped source
; data into the dynamic tile buffer
_TBDynamicTile_00
                 jsr             _TBDynamicData
                 jmp             _TBFillLdaDpOpcode

; Primitive to render a dynamic tile
;
; LDA 00,x / PHA where the operand is fixed when the tile is rendered
; $B5 $00 $48
_TBDynamicData
                 txa
                 asl
                 asl
                 asl
                 xba                                               ; Undo the x128 we just need x4
                 and             #$007F                            ; clamp to < (32 * 4)
                 ora             #$4800                            ; insert the PHA instruction

]line            equ             0                                 ; render the first column
                 lup             8
                 sta:            $0004+{]line*$1000},y
]line            equ             ]line+1
                 --^

                 inc                                               ; advance to the next word
                 inc

]line            equ             0                                 ; render the second column
                 lup             8
                 sta:            $0001+{]line*$1000},y
]line            equ             ]line+1
                 --^

                 rts

; A simple helper function that fill in all of the opcodes of a tile with the LDA dp,x opcode.
_TBFillLdaDpOpcode
                 sep             #$20
                 lda             #$B5
                 sta:            $0000,y
                 sta:            $0003,y
                 sta             $1000,y
                 sta             $1003,y
                 sta             $2000,y
                 sta             $2003,y
                 sta             $3000,y
                 sta             $3003,y
                 sta             $4000,y
                 sta             $4003,y
                 sta             $5000,y
                 sta             $5003,y
                 sta             $6000,y
                 sta             $6003,y
                 sta             $7000,y
                 sta             $7003,y
                 rep             #$20
                 rts
