; Collection of data tables
;

; Tile2CodeOffset
;
; Takes a tile number (0 - 40) and returns the offset into the blitter code
; template.
;
; This is used for rendering tile data into the code field. For example, is we assume that
; we are filling in the operans for a bunch of PEA values, we could do this
;
;  ldy tileNumber*2
;  lda #DATA
;  ldx Tile2CodeOffset,y
;  sta $0001,x 
;
; This table is necessary, because due to the data being draw via stack instructions, the
; tile order is reversed.

PER_TILE_SIZE    equ   6
]step            equ   0
Tile2CodeOffset  lup   41
                 dw    CODE_TOP+{]step*PER_TILE_SIZE}
]step            equ   ]step+1
                 --^

