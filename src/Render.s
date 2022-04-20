; Renders a frame of animation
;
; The render function is the point of committment -- most of the APIs that set sprites and 
; update coordinates are lazy; they simply save their values and set a dirty flag in the
; DirtyBits word.
;
; This function examines the dirty bits and actually performs the work to update the code field
; and internal data structure to properly render the play field.  Then the update pipeline is
; executed.
;
; Everything is composited into the tiles in the playfield and then the screen is rendered in
; a single pass.

Render      ENT
            phb
            phk
            plb
            jsr   _Render
            plb
            rtl

; TODO -- actually check the dirty bits and be selective on what gets updated.  For example, if
;         only the Y position changes, then we should only need to set new values on the 
;         virtual lines that were brought on screen.  If the X position only changes by one
;         byte, then we may have to change the CODE_ENTRY values or restore/set new OPCODE
;         values, but not both.

; It's important to do _ApplyBG0YPos first because it calculates the value of StartY % 208 which is
; used in all of the other loops
_Render
            jsr   _ApplyBG0YPos       ; Set stack addresses for the virtual lines to the physical screen
            jsr   _ApplyBG1YPos

; _ApplyBG0Xpos need to be split because we have to set the offsets, then draw in any updated tiles, and
; finally patch out the code field.  Right now, the BRA operand is getting overwritten by tile data.
            jsr   _ApplyBG0XPosPre
            jsr   _ApplyBG1XPosPre

            nop
            jsr   _RenderSprites      ; Once the BG0 X and Y positions are committed, update sprite data

            jsr   _UpdateBG0TileMap   ; and the tile maps.  These subroutines build up a list of tiles
            jsr   _UpdateBG1TileMap   ; that need to be updated in the code field

            nop
            jsr   _ApplyTiles         ; This function actually draws the new tiles into the code field

            jsr   _ApplyBG0XPos       ; Patch the code field instructions with exit BRA opcode
            jsr   _ApplyBG1XPos       ; Update the direct page value based on the horizontal position

; The code fields are locked in now and ready to be rendered

;            jsr   _ShadowOff

; Shadowing is turned off. Render all of the scan lines that need a second pass. One
; optimization that can be done here is that the lines can be rendered in any order
; since it is not shown on-screen yet.

;            ldx   #0                  ; Blit the full virtual buffer to the screen
;            ldy   #8
;            jsr   _BltRange

; Turn shadowing back on

;            jsr   _ShadowOn

; Now render all of the remaining lines in top-to-bottom (or bottom-to-top) order

;            lda   ScreenY0             ; pass the address of the first line of the overlay
;            clc
;            adc   #0
;            asl
;            tax
;            lda   ScreenAddr,x
;            clc
;            adc   ScreenX0
;            jsl   Overlay

            ldx   #0                  ; Blit the full virtual buffer to the screen
            ldy   ScreenHeight
            jsr   _BltRange

;            ldx   #0
;            ldy   ScreenHeight
;            jsr   _BltSCB

            lda   StartY              ; Restore the fields back to their original state
            ldx   ScreenHeight
            jsr   _RestoreBG0Opcodes

            lda   StartY
            sta   OldStartY
            lda   StartX
            sta   OldStartX

            lda   BG1StartY
            sta   OldBG1StartY
            lda   BG1StartX
            sta   OldBG1StartX

            stz   DirtyBits
            stz   LastRender                    ; Mark that a full render was just performed
            rts

; This is a specialized render function that only updates the dirty tiles *and* draws them
; directly onto the SHR graphics buffer.  The playfield is not used at all.  In some way, this
; ignores almost all of the capabilities of GTE, but it does provide a convenient way to use
; the sprite subsystem + tile attributes for single-screen games which should be able to run
; close to 60 fps.
;
; Because we are register starved, there is a lot of inline code to quickly fetch the information
; needed to render sprites appropriately.  If there was a way to efficiently maintain an ordered
; and compact array of per-tile VBUFF addresses, rather than the current sparse array, then
; the sprite handling code could be significantly streamlined.  A note for anyone attempting
; this optimization:
;
; The _MarkDirtyTiles simply stores a sprite's per-tile VBUFF address and marks the tile 
; as being occupied by the sprite with just 4 instructions
;
;    sta (vbuff_array_ptr),y
;    lda TileStore+TS_SPRITE_FLAG,x
;    ora SpriteBit,y
;    sta TileStore+TS_SPRITE_FLAG,x
;
; Then, we have an unrolled loop that does repeated tests of
;
;    lsr
;    bcc *+
;    lda vbuff_array_ptr,y
;    sta spriteVBuffArr
;
; The only gain to be had is if the sprites that are marked are in the high bits and there are no low-index
; sprites.  Skipping over N bits of the SPRITE_FLAG takes only 5*N cycles.  So, on average, we might waste 
; 40 cycles looking for the proper bit.
;
; Any improvement to the existing code would need to be able to maintain a data structure and get the final
; values into the spriteVBuffArr for a total cost of under 75 cycles per tile.

RenderDirty ENT
            phb
            phk
            plb
            jsr   _RenderDirty
            plb
            rtl

; In this renderer, we assume that there is no scrolling, so no need to update any information about
; the BG0/BG1 positions
_RenderDirty
            lda   LastRender                    ; If the full renderer was last called, we assume that
            bne   :norecalc                     ; the scroll positions have likely changed, so recalculate
            lda   #2                            ; blue
            jsr   _SetBorderColor
            jsr   _RecalcTileScreenAddrs        ; them to make sure sprites draw at the correct screen address
:norecalc
            lda   #3                            ; purple
            jsr   _SetBorderColor
            jsr   _RenderSprites

            lda   #4                            ; dk. green
            jsr   _SetBorderColor
            jsr   _ApplyDirtyTiles
            lda   #1
            sta   LastRender
            rts

_ApplyDirtyTiles
            bra  :begin

:loop
; Retrieve the offset of the next dirty Tile Store items in the Y-register

            jsr  _PopDirtyTile2

; Call the generic dispatch with the Tile Store record pointer at by the Y-register.  

            phb
            jsr  _RenderDirtyTile
            plb

; Loop again until the list of dirty tiles is empty

:begin      ldy  DirtyTileCount
            bne  :loop
            rts

; Only render solid tiles and sprites
_RenderDirtyTile
            ldal  TileStore+TS_SPRITE_FLAG,x     ; This is a bitfield of all the sprites that intersect this tile, only care if non-zero or not
            bne   dirty_sprite

; The rest of this function handles that non-sprite blit, which is super fast since it blits directly from the
; tile data store to the graphics screen with no masking. The only extra work is selecting a blit function
; based on the tile flip flags.

            pei   TileStoreBankAndBank01         ; Special value that has the TileStore bank in LSB and $01 in MSB
            plb

            lda   TileStore+TS_DIRTY_TILE_DISP,x ; load and patch in the appropriate subroutine
            stal  :tiledisp+1

            ldy   TileStore+TS_SCREEN_ADDR,x     ; Get the on-screen address of this tile
            lda   TileStore+TS_TILE_ADDR,y       ; load the address of this tile's data (pre-calculated)
            tax

            plb                                  ; set the bank

; B is set to Bank 01
; A is set to the tile word offset (0 through 80 in steps of 4)
; Y is set to the top-left address of the tile in SHR screen
; X is set to the address of the tile data

:tiledisp   jmp   $0000                          ; render the tile

; Use some temporary space for the spriteIdx array (maximum of 4 entries)

stkSave     equ tmp9
screenAddr  equ tmp10
tileAddr    equ tmp11
spriteIdx   equ tmp12

; Handler for the sprite path
dirty_sprite
                 pei   TileStoreBankAndTileDataBank   ; Special value that has the TileStore bank in LSB and TileData bank in MSB
                 plb

; Cache a couple of values into the direct page, but preserve the Accumulator

                 ldy   TileStore+TS_TILE_ADDR,x       ; load the address of this tile's data (pre-calculated)
                 sty   tileAddr
                 ldy   TileStore+TS_SCREEN_ADDR,x     ; Get the on-screen address of this tile
                 sty   screenAddr

; Now do all of the deferred work of actually drawing the sprites.  We put considerable effort into
; figuring out if there is only one sprite or more than one since we optimize the former case as it
; is very common and can be done significantly faster.
;
; This is a big, unrolled chunk of code that packs the VBUFF addresses for the sprite positions marked
; in the bitfield into the spriteIdx array and then jumps to an optimized rendering function based on
; the number of sprites on the tile.
;
; After each set bit is identified, we check to see if that was the last one and immediately exit.  Since
; a maximum of 4 sprites are processed per tile, this only results in (at most) 4 extra branch instructions.

                 ldy   TileStore+TS_VBUFF_ARRAY_ADDR,x     ; base address of the VBUFF sprite address array for this tile

                 lsr
                 bcc   :loop_0_bit_1
                 ldx:  $0000,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_1
                 jmp   BlitOneSprite

:loop_0_bit_1    lsr
                 bcc   :loop_0_bit_2
                 ldx:  $0002,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_2
                 jmp   BlitOneSprite

:loop_0_bit_2    lsr
                 bcc   :loop_0_bit_3
                 ldx:  $0004,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_3
                 jmp   BlitOneSprite

:loop_0_bit_3    lsr
                 bcc   :loop_0_bit_4
                 ldx:  $0006,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_4
                 jmp   BlitOneSprite

:loop_0_bit_4    lsr
                 bcc   :loop_0_bit_5
                 ldx:  $0008,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_5
                 jmp   BlitOneSprite

:loop_0_bit_5    lsr
                 bcc   :loop_0_bit_6
                 ldx:  $000A,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_6
                 jmp   BlitOneSprite

:loop_0_bit_6    lsr
                 bcc   :loop_0_bit_7
                 ldx:  $000C,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_7
                 jmp   BlitOneSprite

:loop_0_bit_7    lsr
                 bcc   :loop_0_bit_8
                 ldx:  $000E,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_8
                 jmp   BlitOneSprite

:loop_0_bit_8    lsr
                 bcc   :loop_0_bit_9
                 ldx:  $0010,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_9
                 jmp   BlitOneSprite

:loop_0_bit_9    lsr
                 bcc   :loop_0_bit_10
                 ldx:  $0012,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_10
                 jmp   BlitOneSprite

:loop_0_bit_10   lsr
                 bcc   :loop_0_bit_11
                 ldx:  $0014,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_11
                 jmp   BlitOneSprite

:loop_0_bit_11   lsr
                 bcc   :loop_0_bit_12
                 ldx:  $0016,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_12
                 jmp   BlitOneSprite

:loop_0_bit_12   lsr
                 bcc   :loop_0_bit_13
                 ldx:  $0018,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_13
                 jmp   BlitOneSprite

:loop_0_bit_13   lsr
                 bcc   :loop_0_bit_14
                 ldx:  $001A,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_14
                 jmp   BlitOneSprite

:loop_0_bit_14   lsr
                 bcc   :loop_0_bit_15
                 ldx:  $001C,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_15
                 jmp   BlitOneSprite

; If we get to bit 15, then it *must* be a bit that is set
:loop_0_bit_15   ldx:  $001E,y
                 stx   spriteIdx
                 jmp   BlitOneSprite

:loop_1_bit_1    lsr
                 bcc   :loop_1_bit_2
                 ldx:  $0002,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_2
                 jmp   BlitTwoSprites

:loop_1_bit_2    lsr
                 bcc   :loop_1_bit_3
                 ldx:  $0004,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_3
                 jmp   BlitTwoSprites

:loop_1_bit_3    lsr
                 bcc   :loop_1_bit_4
                 ldx:  $0006,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_4
                 jmp   BlitTwoSprites

:loop_1_bit_4    lsr
                 bcc   :loop_1_bit_5
                 ldx:  $0008,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_5
                 jmp   BlitTwoSprites

:loop_1_bit_5    lsr
                 bcc   :loop_1_bit_6
                 ldx:  $000A,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_6
                 jmp   BlitTwoSprites

:loop_1_bit_6    lsr
                 bcc   :loop_1_bit_7
                 ldx:  $000C,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_7
                 jmp   BlitTwoSprites

:loop_1_bit_7    lsr
                 bcc   :loop_1_bit_8
                 ldx:  $000E,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_8
                 jmp   BlitTwoSprites

:loop_1_bit_8    lsr
                 bcc   :loop_1_bit_9
                 ldx:  $0010,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_9
                 jmp   BlitTwoSprites

:loop_1_bit_9    lsr
                 bcc   :loop_1_bit_10
                 ldx:  $0012,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_10
                 jmp   BlitTwoSprites

:loop_1_bit_10   lsr
                 bcc   :loop_1_bit_11
                 ldx:  $0014,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_11
                 jmp   BlitTwoSprites

:loop_1_bit_11   lsr
                 bcc   :loop_1_bit_12
                 ldx:  $0016,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_12
                 jmp   BlitTwoSprites

:loop_1_bit_12   lsr
                 bcc   :loop_1_bit_13
                 ldx:  $0018,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_13
                 jmp   BlitTwoSprites

:loop_1_bit_13   lsr
                 bcc   :loop_1_bit_14
                 ldx:  $001A,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_14
                 jmp   BlitTwoSprites

:loop_1_bit_14   lsr
                 bcc   :loop_1_bit_15
                 ldx:  $001C,y
                 stx   spriteIdx+2
                 cmp   #0
                 jne   :loop_2_bit_15
                 jmp   BlitTwoSprites

:loop_1_bit_15   ldx:  $001E,y
                 stx   spriteIdx+2
                 jmp   BlitTwoSprites

:loop_2_bit_2    lsr
                 bcc   :loop_2_bit_3
                 ldx:  $0004,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_3
                 jmp   BlitThreeSprites

:loop_2_bit_3    lsr
                 bcc   :loop_2_bit_4
                 ldx:  $0006,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_4
                 jmp   BlitThreeSprites

:loop_2_bit_4    lsr
                 bcc   :loop_2_bit_5
                 ldx:  $0008,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_5
                 jmp   BlitThreeSprites

:loop_2_bit_5    lsr
                 bcc   :loop_2_bit_6
                 ldx:  $000A,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_6
                 jmp   BlitThreeSprites

:loop_2_bit_6    lsr
                 bcc   :loop_2_bit_7
                 ldx:  $000C,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_7
                 jmp   BlitThreeSprites

:loop_2_bit_7    lsr
                 bcc   :loop_2_bit_8
                 ldx:  $000E,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_8
                 jmp   BlitThreeSprites

:loop_2_bit_8    lsr
                 bcc   :loop_2_bit_9
                 ldx:  $0010,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_9
                 jmp   BlitThreeSprites

:loop_2_bit_9    lsr
                 bcc   :loop_2_bit_10
                 ldx:  $0012,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_10
                 jmp   BlitThreeSprites

:loop_2_bit_10   lsr
                 bcc   :loop_2_bit_11
                 ldx:  $0014,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_11
                 jmp   BlitThreeSprites

:loop_2_bit_11   lsr
                 bcc   :loop_2_bit_12
                 ldx:  $0016,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_12
                 jmp   BlitThreeSprites

:loop_2_bit_12   lsr
                 bcc   :loop_2_bit_13
                 ldx:  $0018,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_13
                 jmp   BlitThreeSprites

:loop_2_bit_13   lsr
                 bcc   :loop_2_bit_14
                 ldx:  $001A,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_14
                 jmp   BlitThreeSprites

:loop_2_bit_14   lsr
                 bcc   :loop_2_bit_15
                 ldx:  $001C,y
                 stx   spriteIdx+4
                 cmp   #0
                 jne   :loop_3_bit_15
                 jmp   BlitThreeSprites

:loop_2_bit_15   ldx:  $001E,y
                 stx   spriteIdx+4
                 jmp   BlitThreeSprites

:loop_3_bit_3    lsr
                 bcc   :loop_3_bit_4
                 ldx   $0006,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_4    lsr
                 bcc   :loop_3_bit_5
                 ldx   $0008,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_5    lsr
                 bcc   :loop_3_bit_6
                 ldx   $000A,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_6    lsr
                 bcc   :loop_3_bit_7
                 ldx   $000C,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_7    lsr
                 bcc   :loop_3_bit_8
                 ldx   $000E,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_8    lsr
                 bcc   :loop_3_bit_9
                 ldx   $0010,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_9    lsr
                 bcc   :loop_3_bit_10
                 ldx   $0012,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_10   lsr
                 bcc   :loop_3_bit_11
                 ldx   $0014,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_11   lsr
                 bcc   :loop_3_bit_12
                 ldx   $0016,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_12   lsr
                 bcc   :loop_3_bit_13
                 ldx   $0018,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_13   lsr
                 bcc   :loop_3_bit_14
                 ldx   $001A,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_14   lsr
                 bcc   :loop_3_bit_15
                 ldx   $001C,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

:loop_3_bit_15   ldx   $001E,y
                 stx   spriteIdx+6
                 jmp   BlitFourSprites

DirtyTileProcs   dw  _TBDirtyTile_00,_TBDirtyTile_0H,_TBDirtyTile_V0,_TBDirtyTile_VH
;DirtyTileSpriteProcs dw  _TBDirtySpriteTile_00,_TBDirtySpriteTile_0H,_TBDirtySpriteTile_V0,_TBDirtySpriteTile_VH

; Blit tiles directly to the screen.
_TBDirtyTile_00
_TBDirtyTile_0H
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0000+{]line*160},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0002+{]line*160},y
]line            equ             ]line+1
                 --^
                 rts

_TBDirtyTile_V0
_TBDirtyTile_VH
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4},x
                 sta:            $0000+{]dest*160},y
                 ldal            tiledata+{]src*4}+2,x
                 sta:            $0002+{]dest*160},y
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

TILE_DATA_SPAN equ 4

; If there are two or more sprites at a tile, we can still be fast, but need to do extra work because
; the VBUFF values need to be read from the direct page.  Thus, the direct page cannot be mapped onto
; the graphics screen.  We use the stack instead, but have to do extra work to save and restore the
; stack value.
BlitFourSprites
BlitThreeSprites
BlitTwoSprites
                 plb
                 tsc
                 sta   stkSave                          ; Save the stack on the direct page
                 
                 sei
                 clc

                 ldy   tileAddr
                 lda   screenAddr                     ; Saved in direct page locations
                 tcs

                 _R0W1

                 lda   tiledata+{0*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{0*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{0*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{0*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{0*SPRITE_PLANE_SPAN},x
                 sta   $00,s

                 lda   tiledata+{0*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{0*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{0*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{0*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{0*SPRITE_PLANE_SPAN}+2,x
                 sta   $02,s

                 lda   tiledata+{1*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{1*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{1*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{1*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{1*SPRITE_PLANE_SPAN},x
                 sta   $A0,s

                 lda   tiledata+{1*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{1*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{1*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{1*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{1*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2,s

                 tsc
                 adc   #320
                 tcs

                 lda   tiledata+{2*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{2*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{2*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{2*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{2*SPRITE_PLANE_SPAN},x
                 sta   $00,s

                 lda   tiledata+{2*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{2*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{2*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{2*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{2*SPRITE_PLANE_SPAN}+2,x
                 sta   $02,s

                 lda   tiledata+{3*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{3*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{3*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{3*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{3*SPRITE_PLANE_SPAN},x
                 sta   $A0,s

                 lda   tiledata+{3*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{3*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{3*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{3*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{3*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2,s

                 tsc
                 adc   #320
                 tcs

                 lda   tiledata+{4*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{4*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{4*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{4*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{4*SPRITE_PLANE_SPAN},x
                 sta   $00,s

                 lda   tiledata+{4*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{4*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{4*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{4*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{4*SPRITE_PLANE_SPAN}+2,x
                 sta   $02,s

                 lda   tiledata+{5*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{5*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{5*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{5*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{5*SPRITE_PLANE_SPAN},x
                 sta   $A0,s

                 lda   tiledata+{5*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{5*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{5*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{5*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{5*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2,s

                 tsc
                 adc   #320
                 tcs

                 lda   tiledata+{6*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{6*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{6*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{6*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{6*SPRITE_PLANE_SPAN},x
                 sta   $00,s

                 lda   tiledata+{6*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{6*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{6*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{6*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{6*SPRITE_PLANE_SPAN}+2,x
                 sta   $02,s

                 lda   tiledata+{7*TILE_DATA_SPAN},y
                 ldx   spriteIdx+2
                 andl  spritemask+{7*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{7*SPRITE_PLANE_SPAN},x
                 ldx   spriteIdx
                 andl  spritemask+{7*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{7*SPRITE_PLANE_SPAN},x
                 sta   $A0,s

                 lda   tiledata+{7*TILE_DATA_SPAN}+2,y
                 ldx   spriteIdx+2
                 andl  spritemask+{7*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{7*SPRITE_PLANE_SPAN}+2,x
                 ldx   spriteIdx
                 andl  spritemask+{7*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{7*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2,s

                 _R0W0

                 lda   stkSave
                 tcs
                 cli
                 rts

; There is only one sprite at this tile, so do a fast blit that directly combines a tile with a single
; sprite and renders directly to the screen
;
; NOTE: Expect X-register to already have been set to the correct VBUFF address
BlitOneSprite
                 ldy   tileAddr                               ; load the address of this tile's data
                 lda   screenAddr                             ; Get the on-screen address of this tile

                 plb

                 phd
                 sei
                 clc
                 tcd

                 _R0W1

                 lda   tiledata+{0*TILE_DATA_SPAN},y
                 andl  spritemask+{0*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{0*SPRITE_PLANE_SPAN},x
                 sta   $00

                 lda   tiledata+{0*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{0*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{0*SPRITE_PLANE_SPAN}+2,x
                 sta   $02

                 lda   tiledata+{1*TILE_DATA_SPAN},y
                 andl  spritemask+{1*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{1*SPRITE_PLANE_SPAN},x
                 sta   $A0

                 lda   tiledata+{1*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{1*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{1*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2

                 tdc
                 adc   #320
                 tcd

                 lda   tiledata+{2*TILE_DATA_SPAN},y
                 andl  spritemask+{2*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{2*SPRITE_PLANE_SPAN},x
                 sta   $00

                 lda   tiledata+{2*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{2*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{2*SPRITE_PLANE_SPAN}+2,x
                 sta   $02

                 lda   tiledata+{3*TILE_DATA_SPAN},y
                 andl  spritemask+{3*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{3*SPRITE_PLANE_SPAN},x
                 sta   $A0

                 lda   tiledata+{3*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{3*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{3*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2

                 tdc
                 adc   #320
                 tcd

                 lda   tiledata+{4*TILE_DATA_SPAN},y
                 andl  spritemask+{4*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{4*SPRITE_PLANE_SPAN},x
                 sta   $00

                 lda   tiledata+{4*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{4*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{4*SPRITE_PLANE_SPAN}+2,x
                 sta   $02

                 lda   tiledata+{5*TILE_DATA_SPAN},y
                 andl  spritemask+{5*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{5*SPRITE_PLANE_SPAN},x
                 sta   $A0

                 lda   tiledata+{5*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{5*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{5*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2

                 tdc
                 adc   #320
                 tcd

                 lda   tiledata+{6*TILE_DATA_SPAN},y
                 andl  spritemask+{6*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{6*SPRITE_PLANE_SPAN},x
                 sta   $00

                 lda   tiledata+{6*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{6*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{6*SPRITE_PLANE_SPAN}+2,x
                 sta   $02

                 lda   tiledata+{7*TILE_DATA_SPAN},y
                 andl  spritemask+{7*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{7*SPRITE_PLANE_SPAN},x
                 sta   $A0

                 lda   tiledata+{7*TILE_DATA_SPAN}+2,y
                 andl  spritemask+{7*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{7*SPRITE_PLANE_SPAN}+2,x
                 sta   $A2

                 _R0W0
                 cli
                 pld
                 rts
