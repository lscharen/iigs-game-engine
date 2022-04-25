; Basic tile functions


; Low-level function to take a tile descriptor and return the address in the tiledata
; bank.  This is not too useful in the fast-path because the fast-path does more
; incremental calculations, but it is handy for other utility functions
;
; A = tile descriptor
;
; The address is the TileID * 128 + (HFLIP * 64)
GetTileAddr      ENT
                 jsr             _GetTileAddr
                 rtl
_GetTileAddr
                 asl                                               ; Multiply by 2
                 bit             #2*TILE_HFLIP_BIT                 ; Check if the horizontal flip bit is set
                 beq             :no_flip
                 inc                                               ; Set the LSB
:no_flip         asl                                               ; x4
                 asl                                               ; x8
                 asl                                               ; x16
                 asl                                               ; x32
                 asl                                               ; x64
                 asl                                               ; x128
                 rts

; Ignore the horizontal flip bit
_GetBaseTileAddr
                 asl                                               ; Multiply by 2
                 asl                                               ; x4
                 asl                                               ; x8
                 asl                                               ; x16
                 asl                                               ; x32
                 asl                                               ; x64
                 asl                                               ; x128
                 rts


; Initialize the tile storage data structures.  This takes care of populating the tile records with the
; appropriate constant values.
InitTiles
:col             equ  tmp0
:row             equ  tmp1
:vbuff           equ  tmp2

; Fill in the TileStoreYTable.  This is just a table of offsets into the Tile Store for each row.  There
; are 26 rows with a stride of 41
                 ldy  #0
                 lda  #0
:yloop
                 sta  TileStoreYTable,y
                 clc
                 adc  #41*2
                 iny
                 iny
                 cpy  #26*2
                 bcc  :yloop

; Next, initialize the Tile Store itself

                 ldx  #TILE_STORE_SIZE-2
                 lda  #25
                 sta  :row
                 lda  #40
                 sta  :col
                 lda  #$8000
                 sta  :vbuff

:loop 

; The first set of values in the Tile Store are changed during each frame based on the actions
; that are happening

                 lda  #0
                 stal TileStore+TS_TILE_ID,x            ; clear the tile store with the special zero tile
                 stal TileStore+TS_TILE_ADDR,x
                 stal TileStore+TS_SPRITE_FLAG,x        ; no sprites are set at the beginning
                 stal TileStore+TS_DIRTY,x              ; none of the tiles are dirty

;                 lda  DirtyTileProcs                    ; Fill in with the first dispatch address
;                 stal TileStore+TS_DIRTY_TILE_DISP,x
;
;                 lda  TileProcs                         ; Same for non-dirty, non-sprite base case
;                 stal TileStore+TS_BASE_TILE_DISP,x     

                 lda  :vbuff                            ; array of sprite vbuff addresses per tile
                 stal TileStore+TS_VBUFF_ARRAY_ADDR,x
                 clc
                 adc  #32
                 sta  :vbuff

; The next set of values are constants that are simply used as cached parameters to avoid needing to
; calculate any of these values during tile rendering

                 lda  :row                              ; Set the long address of where this tile
                 asl                                    ; exists in the code fields
                 tay
                 lda  BRowTableHigh,y
                 stal TileStore+TS_CODE_ADDR_HIGH,x     ; High word of the tile address (just the bank)
                 lda  BRowTableLow,y
                 stal TileStore+TS_BASE_ADDR,x          ; May not be needed later if we can figure out the right constant...

                 lda  :col                              ; Set the offset values based on the column
                 asl                                    ; of this tile
                 asl
                 stal TileStore+TS_WORD_OFFSET,x        ; This is the offset from 0 to 82, used in LDA (dp),y instruction
                 
                 tay
                 lda  Col2CodeOffset+2,y
                 clc
                 adcl TileStore+TS_BASE_ADDR,x
                 stal TileStore+TS_CODE_ADDR_LOW,x      ; Low word of the tile address in the code field

                 dec  :col
                 bpl  :hop
                 dec  :row
                 lda  #40
                 sta  :col
:hop

                 dex
                 dex
                 bpl  :loop
                 rts
