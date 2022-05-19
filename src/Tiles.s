; Basic tile functions

; Copy tileset data from a pointer in memory to the tiledata back
; X = high word
; A = low word
_LoadTileSet
                sta  tmp0
                stx  tmp1
                ldy  #0
                tyx
:loop           lda  [tmp0],y
                stal tiledata,x
                dex
                dex
                dey
                dey
                bne  :loop
                rts


; Low-level function to take a tile descriptor and return the address in the tiledata
; bank.  This is not too useful in the fast-path because the fast-path does more
; incremental calculations, but it is handy for other utility functions
;
; A = tile descriptor
;
; The address is the TileID * 128 + (HFLIP * 64)
_GetTileAddr
                 asl                                               ; Multiply by 2
                 bit   #2*TILE_HFLIP_BIT                           ; Check if the horizontal flip bit is set
                 beq   :no_flip
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


; Helper function to get the address offset into the tile cachce / tile backing store
; X = tile column [0, 40] (41 columns)
; Y = tile row    [0, 25] (26 rows)
_GetTileStoreOffset
                 phx                        ; preserve the registers
                 phy

                 jsr  _GetTileStoreOffset0

                 ply
                 plx
                 rts

_GetTileStoreOffset0
                 tya
                 asl
                 tay
                 txa
                 asl
                 clc
                 adc  TileStoreYTable,y
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

; *** DEPRECATED ***
;                 lda  :vbuff                            ; array of sprite vbuff addresses per tile
;                 stal TileStore+TS_VBUFF_ARRAY_ADDR,x
;                 clc
;                 adc  #32
;                 sta  :vbuff
; *** ********** ***

; The next set of values are constants that are simply used as cached parameters to avoid needing to
; calculate any of these values during tile rendering

                 lda  :row                              ; Set the long address of where this tile
                 asl                                    ; exists in the code fields
                 tay
                 lda  #>TileStore                       ; get middle 16 bits: "00 -->BBHH<-- LL"
                 and  #$FF00                            ; merge with code field bank
                 ora  BRowTableHigh,y
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

; Set a tile value in the tile backing store.  Mark dirty if the value changes
;
; A = tile id
; X = tile column [0, 40] (41 columns)
; Y = tile row    [0, 25] (26 rows)
;
; Registers are not preserved
_SetTile
                 pha
                 jsr  _GetTileStoreOffset0          ; Get the address of the X,Y tile position
                 tay
                 pla
                 
                 cmp  TileStore+TS_TILE_ID,y        ; Only set to dirty if the value changed
                 beq  :nochange

                 sta  TileStore+TS_TILE_ID,y        ; Value is different, store it.
                 jsr  _GetTileAddr
                 sta  TileStore+TS_TILE_ADDR,y      ; Committed to drawing this tile, so get the address of the tile in the tiledata bank for later

; Set the standard renderer procs for this tile.
;
;  1. The dirty render proc is always set the same.
;  2. If BG1 and DYN_TILES are disabled, then the TS_BASE_TILE_DISP is selected from the Fast Renderers, otherwise
;     it is selected from the full tile rendering functions.
;  3. The copy process is selected based on the flip bits
;
; When a tile overlaps the sprite, it is the responsibility of the Render function to compose the appropriate
; functionality.  Sometimes it is simple, but in cases of the sprites overlapping Dynamic Tiles and other cases
; it can be more involved.

                 lda  TileStore+TS_TILE_ID,y
                 and  #TILE_VFLIP_BIT+TILE_HFLIP_BIT ; get the lookup value
                 xba
                 tax
;                 ldal DirtyTileProcs,x
;                 sta  TileStore+TS_DIRTY_TILE_DISP,y

;                 ldal CopyTileProcs,x
;                 sta  TileStore+TS_DIRTY_TILE_COPY,y

                 lda  EngineMode
                 bit  #ENGINE_MODE_DYN_TILES+ENGINE_MODE_TWO_LAYER
                 beq  :fast

                 lda  TileStore+TS_TILE_ID,y        ; Get the non-sprite dispatch address
                 and  #TILE_CTRL_MASK
                 xba
                 tax
;                 ldal TileProcs,x
;                 sta  TileStore+TS_BASE_TILE_DISP,y
                 bra  :out

:fast
                 ldal FastTileProcs,x
                 sta  TileStore+TS_BASE_TILE_DISP,y
:out
                 jmp  _PushDirtyTileY               ; on the next call to _ApplyTiles

:nochange        rts


; SetBG0XPos
;
; Set the virtual horizontal position of the primary background layer.  In addition to 
; updating the direct page state locations, this routine needs to preserve the original
; value as well.  This is a bit subtle, because if this routine is called multiple times
; with different values, we need to make sure the *original* value is preserved and not
; continuously overwrite it.
;
; We assume that there is a clean code field in this routine
SetBG0XPos          ENT
                    jsr   _SetBG0XPos
                    rtl

_SetBG0XPos
                    cmp   StartX
                    beq   :out                       ; Easy, if nothing changed, then nothing changes

                    ldx   StartX                     ; Load the old value (but don't save it yet)
                    sta   StartX                     ; Save the new position

                    lda   #DIRTY_BIT_BG0_X
                    tsb   DirtyBits                  ; Check if the value is already dirty, if so exit
                    bne   :out                       ; without overwriting the original value

                    stx   OldStartX                  ; First change, so preserve the value
:out                rts


; SetBG0YPos
;
; Set the virtual position of the primary background layer.
SetBG0YPos           ENT
                     jsr   _SetBG0YPos
                     rtl

_SetBG0YPos
                     cmp   StartY
                     beq   :out                 ; Easy, if nothing changed, then nothing changes

                     ldx   StartY               ; Load the old value (but don't save it yet)
                     sta   StartY               ; Save the new position

                     lda   #DIRTY_BIT_BG0_Y
                     tsb   DirtyBits            ; Check if the value is already dirty, if so exit
                     bne   :out                 ; without overwriting the original value

                     stx   OldStartY            ; First change, so preserve the value
:out                 rts
