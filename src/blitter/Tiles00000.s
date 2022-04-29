; _TBSolidTile
;
; Define the addresses of the subroutines that draw the normal and flipped variants of the tiles, both 
; in the optimized (no second background) and normal cases.
;
; On entry, the following register values need to be set
;
;  X : address of base tile in the tiledata bank (tileId * 128)
;  Y : address of the top-left corder of the tile location in the code field
;  B : set to the code field bank  

_TBSolidTile_00
                 jsr             _TBCopyData
                 jmp             _TBFillPEAOpcode

_TBSolidTile_0H
                 jsr             _TBCopyData
                 jmp             _TBFillPEAOpcode

_TBSolidTile_V0
                 jsr             _TBCopyDataV
                 jmp             _TBFillPEAOpcode

_TBSolidTile_VH
                 jsr             _TBCopyDataV
                 jmp             _TBFillPEAOpcode

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
_TBCopyDataFast
                 tax
_TBCopyData
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0004+{]line*$1000},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0001+{]line*$1000},y
]line            equ             ]line+1
                 --^
                 rts

_TBCopyDataVFast
                 tax
_TBCopyDataV
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
                 rts

