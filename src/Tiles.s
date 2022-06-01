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

; Initialize the Tile Store

                 ldx  #TILE_STORE_SIZE-2
                 lda  #25
                 sta  :row
                 lda  #40
                 sta  :col
                 lda  #$8000
                 sta  :vbuff

:loop 

; The first set of values in the Tile Store that are changed during each frame based on the actions
; that are happening

                 lda  #0
                 sta  TileStore+TS_TILE_ID,x            ; clear the tile store with the special zero tile
                 sta  TileStore+TS_TILE_ADDR,x
                 sta  TileStore+TS_SPRITE_FLAG,x        ; no sprites are set at the beginning
                 sta  TileStore+TS_DIRTY,x              ; none of the tiles are dirty

; Set the default tile rendering functions

                 lda  EngineMode
                 bit  #ENGINE_MODE_DYN_TILES+ENGINE_MODE_TWO_LAYER
                 beq  :fast
;                 ldal TileProcs
;                 sta  TileStore+TS_BASE_TILE_DISP,x
                 bra  :out
:fast
                 ldal FastTileProcs
                 sta  TileStore+TS_BASE_TILE_DISP,x
:out

;                 lda  DirtyTileProcs                    ; Fill in with the first dispatch address
;                 stal TileStore+TS_DIRTY_TILE_DISP,x
;
;                 lda  TileProcs                         ; Same for non-dirty, non-sprite base case
;                 stal TileStore+TS_BASE_TILE_DISP,x     


; The next set of values are constants that are simply used as cached parameters to avoid needing to
; calculate any of these values during tile rendering

                 lda  :row                              ; Set the long address of where this tile
                 asl                                    ; exists in the code fields
                 tay
                 lda  #>TileStore                       ; get middle 16 bits: "00 -->BBHH<-- LL"
                 and  #$FF00                            ; merge with code field bank
                 ora  BRowTableHigh,y
                 sta  TileStore+TS_CODE_ADDR_HIGH,x     ; High word of the tile address (just the bank)

                 lda  BRowTableLow,y
                 sta  TileStore+TS_BASE_ADDR,x          ; May not be needed later if we can figure out the right constant...

                 lda  :col                              ; Set the offset values based on the column
                 asl                                    ; of this tile
                 asl
                 sta  TileStore+TS_WORD_OFFSET,x        ; This is the offset from 0 to 82, used in LDA (dp),y instruction
                 
                 tay
                 lda  Col2CodeOffset+2,y
                 clc
                 adc  TileStore+TS_BASE_ADDR,x
                 sta  TileStore+TS_CODE_ADDR_LOW,x      ; Low word of the tile address in the code field

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

; Macro helper for the bit test tree
;           dobit   bit_position,dest;next;exit
dobit       mac
            lsr
            bcc   next_bit
            beq   last_bit
            tax
            lda   (SPRITE_VBUFF_PTR+{]2*2}),y
            sta   sprite_ptr0+{]2*4}
            txa
            jmp   ]3
last_bit    lda   (SPRITE_VBUFF_PTR+{]2*2}),y
            sta   sprite_ptr0+{]2*4}
            jmp   ]4
next_bit
            <<<

; Specialization for the first sprite which can just return the vbuff address
; in a register if there is only one sprite intersecting the tile
dobit1      mac
            lsr
            bcc   next_bit
            beq   last_bit
            tax
            lda   (SPRITE_VBUFF_PTR+{]2*2}),y
            sta   sprite_ptr0+{]2*4}
            txa
            jmp   ]3
last_bit    lda   (SPRITE_VBUFF_PTR+{]2*2}),y
            jmp   ]4
next_bit
            <<<

; Optimization discussion.  In the Sprite2.s file, we calculate the VBUFF address for each tile overlapped
; by a sprite:
;
;    4 lda   VBuffOrigin
;    3 adc   ]2
;    7 sta   [tmp0],y
;
; and then in this macro it is loaded again and copied to the direct page.  If a sprite is never drawn, this is
; wasted work (which is not too ofter since >4 sprites would need to be overlapping), but still.
;
;    6 ldy:  {]1*TILE_STORE_SIZE},x
;    4 sty   sprite_ptr0+{]2*4}
;
; Since we know *exactly* which sprite is being accessed, the _Sprites+TS_VBUFF_BASE,y value can be loaded without
; an index
;
;    5 lda   _Sprites+TS_VBUFF_BASE+{]1*2}
;    6 adc   {]1*TILE_STORE_SIZE},x
;    4 sta   sprite_ptr0+{]2*4}
;    2 tya   
;
;    = a savings of at least (24 - 17) = 7 cycles per tile and more if the sprite is skipped.
;
; The problem is that this still required storing a value for the sprite in the tile store.  What is ideal is
; if there is a way to know implicitly which relative tile offset we are on for a given sprite and use
; that to calculate the offset...
;
; What do we know
;   X = current tile
;   Sprite+TS_LOOKUP_INDEX
;
;   txa
;   sbc   _Sprites+TS_LOOKUP_INDEX+{]1*2}
;   tay
;   lda   _Sprites+TS_VBUFF_BASE+{]1*2}
;   adc   DisplacementTable,y
;   sta   sprite_ptr0+{]2*4}
;
; Have the sprite select a table base which holds the offset values, pre-adjusted for the TS_LOOKUP_INDEX. The table
; values are fixed. Yes!! This is the solution!!  It will only need 288 bytes of total space
;
; Best implementation will pass the Tile Store index in Y instead of X
;
; 5          lda   _Sprites+VBUFF_TABLE+{]1*2}
; 6          sta   self_mod
; 6          lda   $0000,x
; 4          sta   sprite_ptr0+{]2*4}
; 2          tya
;
; or
;
; 5          lda   _Sprites+VBUFF_TABLE+{]1*2}
; 4          sta   tmp0
; 7          lda   (tmp0),y
; 4          sta   sprite_ptr0+{]2*4}
; 2          txa
;
; Even better, if the VBUFF_TABLE (only 32 bytes) was already stored in the second direct page
;
; 7          lda   (VBUFF_TABLE+{]1*2}),y
; 5          adc   _Sprites+VBUFF_TABLE+{]1*2}
; 4          sta   sprite_ptr0+{]2*4}
; 2          txa
;
; Final saving compared to current implementation is (24 - 18) = 6 cycles per tile and we eliminate
; the need to pre-calculate
;

; If we find a last bit (4th in this case) and will exit
stpbit      mac
            lsr
            bcc   next_bit
            lda   (SPRITE_VBUFF_PTR+{]2*2}),y
            sta   sprite_ptr0+{]2*4}
            jmp   ]3
next_bit
            <<<

; Last bit test which *must* be set
endbit      mac
            lda   (SPRITE_VBUFF_PTR+{]2*2}),y
            sta   sprite_ptr0+{]2*4}
            jmp   ]3
            <<<

; OPTIMIZATION:
;
;           bit     #$00FF                    ; Optimization to skip the first 8 bits if they are all zeros
;           bne     norm_entry
;           xba
;           jmp     skip_entry
;
; Placed at the entry point

; This is a complex, but fast subroutine that is called from the core tile rendering code.  It
; Takes a bitmap of sprites in the Accumulator and then extracts the VBuff addresses for the
; target TileStore entry and places them in specific direct page locations.
;
; Inputs:
;  A = sprite bitmap (assumed to be non-zero)
;  Y = tile store index
;  D = second work page
;  B = vbuff array bank
; Output:
;  X = 
;
; ]1 address of single sprite process
; ]2 address of two sprite process
; ]3 address of three sprite process
; ]4 address of four sprite process

SpriteBitsToVBuffAddrs mac
           dobit1  0;0;b_1_1;]1
           dobit1  1;0;b_2_1;]1
           dobit1  2;0;b_3_1;]1
           dobit1  3;0;b_4_1;]1
           dobit1  4;0;b_5_1;]1
           dobit1  5;0;b_6_1;]1
           dobit1  6;0;b_7_1;]1
           dobit1  7;0;b_8_1;]1
           dobit1  8;0;b_9_1;]1
           dobit1  9;0;b_10_1;]1
           dobit1  10;0;b_11_1;]1
           dobit1  11;0;b_12_1;]1
           dobit1  12;0;b_13_1;]1
           dobit1  13;0;b_14_1;]1
           dobit1  14;0;b_15_1;]1
           endbit 15;0;]1

b_1_1      dobit  1;1;b_2_2;]2
b_2_1      dobit  2;1;b_3_2;]2
b_3_1      dobit  3;1;b_4_2;]2
b_4_1      dobit  4;1;b_5_2;]2
b_5_1      dobit  5;1;b_6_2;]2
b_6_1      dobit  6;1;b_7_2;]2
b_7_1      dobit  7;1;b_8_2;]2
b_8_1      dobit  8;1;b_9_2;]2
b_9_1      dobit  9;1;b_10_2;]2
b_10_1     dobit  10;1;b_11_2;]2
b_11_1     dobit  11;1;b_12_2;]2
b_12_1     dobit  12;1;b_13_2;]2
b_13_1     dobit  13;1;b_14_2;]2
b_14_1     dobit  14;1;b_15_2;]2
b_15_1     endbit 15;1;]2

b_2_2      dobit  2;2;b_3_3;]3
b_3_2      dobit  3;2;b_4_3;]3
b_4_2      dobit  4;2;b_5_3;]3
b_5_2      dobit  5;2;b_6_3;]3
b_6_2      dobit  6;2;b_7_3;]3
b_7_2      dobit  7;2;b_8_3;]3
b_8_2      dobit  8;2;b_9_3;]3
b_9_2      dobit  9;2;b_10_3;]3
b_10_2     dobit  10;2;b_11_3;]3
b_11_2     dobit  11;2;b_12_3;]3
b_12_2     dobit  12;2;b_13_3;]3
b_13_2     dobit  13;2;b_14_3;]3
b_14_2     dobit  14;2;b_15_3;]3
b_15_2     endbit 15;2;]3

b_3_3      stpbit 3;3;]4
b_4_3      stpbit 4;3;]4
b_5_3      stpbit 5;3;]4
b_6_3      stpbit 6;3;]4
b_7_3      stpbit 7;3;]4
b_8_3      stpbit 8;3;]4
b_9_3      stpbit 9;3;]4
b_10_3     stpbit 10;3;]4
b_11_3     stpbit 11;3;]4
b_12_3     stpbit 12;3;]4
b_13_3     stpbit 13;3;]4
b_14_3     stpbit 14;3;]4
b_15_3     endbit 15;3;]4
           <<<