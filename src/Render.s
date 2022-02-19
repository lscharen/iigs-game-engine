; Renders a frame of animation
;
; The rendering engine is built around the idea of compositing all of the moving components
; on to the Bank 01 graphics buffer and then revealing everything in a single, vertical pass.
;
; If there was just a scrolling screen with no sprites, the screen would just get rendered
; in a single pass, but it gets more complicated with sprites and various effects.
;
; Here is the high-level pipeline:
;
; 1. Identify row ranges with effects.  These effects can be sprites or user-defined overlays
; 2. Turn shadowing off
; 3. Render the background for each effect row range (in any order)
; 4. Render the sprites (in any order)
; 5. Turn shadowing on
; 6. Render the background for each non-effect row, a pei slam for sprite rows, and
;    the user-defined overlays (in sorted order)
; 
; As a concrete example, consider:
;
;  Rows 0 - 9  have a user-defined floating overlay for a score board
;  Rows 10 - 100 are background only
;  Rows 101 - 120 have one or more sprites
;  Rows 121 - 140 are background only
;  Rows 141 - 159 have a user-defined solid overlay for an animated platform
;
; A floating overlay means that some background data bay show through.  A solid overlay means that
; the user-defined data covers the entire scan line.
;
; The renderer would proceed as:
;
; - shadow off
; - render_background(0, 10)
; - render_background(101, 121)
; - render_sprites()
; - shadow_on
; - render_user_overlay_1()
; - render_background(10, 101)
; - pei_slam(101, 121)
; - render_background(121, 141)
; - render_user_overlay_2()
;
; Generally speaking, a PEI Slam is faster that trying to do any sort of dirty-rectangle update by
; tracking sprinte bounding boxes.  But, if an application would benefit from skipping some background
; drawing on sprite rows, that can be handled by using the low level routines to control the left/right
; edges of the rendered play field.


; The render function is the point of committment -- most of the APIs that set sprintes and 
; update coordinates are lazy; they simply save the value and set a dirty flag in the
; DirtyBits word.
;
; This function examines the dirty bits and actually performs the work to update the code field
; and internal data structure to properly render the play field.  Then the update pipeline is
; executed.
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

            jsr   _RenderSprites      ; Once the BG0 X and Y positions are committed, update sprite data

            jsr   _UpdateBG0TileMap   ; and the tile maps.  These subroutines build up a list of tiles
            jsr   _UpdateBG1TileMap   ; that need to be updated in the code field

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

            ldx   #0
            ldy   ScreenHeight
            jsr   _BltSCB

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
RenderDirty ENT
            phb
            phk
            plb
            jsr   _RenderDirty
            plb
            rtl

; In this renderer, we assume that thwere is no scrolling, so no need to update any information about
; the BG0/BG1 positions
_RenderDirty
            lda   LastRender                    ; If the full renderer was last called, we assume that
            bne   :norecalc                     ; the scroll positions have likely changed, so recalculate
            jsr   _RecalcTileScreenAddrs        ; them to make sure sprites draw at the correct screen address
:norecalc
            jsr   _RenderSprites
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
            pea   >TileStore                     ; Need that addressing flexibility here.  Callers responsible for restoring bank reg
            plb
            plb

            lda   TileStore+TS_SPRITE_FLAG,y     ; This is a bitfield of all the sprites that intersect this tile, only care if non-zero or not
            beq   :nosprite

            jsr   BuildActiveSpriteArray          ; Build the sprite index list from the bit field

;            ldx   TileStore+TS_SPRITE_ADDR,y
;            stx   _SPR_X_REG

            lda   TileStore+TS_TILE_ID,y         ; build the finalized tile descriptor
            and   #TILE_VFLIP_BIT+TILE_HFLIP_BIT ; get the lookup value
            xba
            tax
            ldal  DirtyTileSpriteProcs,x
            stal  :tiledisp+1
            bra   :sprite

:nosprite
            lda   TileStore+TS_TILE_ID,y         ; build the finalized tile descriptor
            and   #TILE_VFLIP_BIT+TILE_HFLIP_BIT ; get the lookup value
            xba
            tax
            ldal  DirtyTileProcs,x               ; load and patch in the appropriate subroutine
            stal  :tiledisp+1

:sprite
            ldx   TileStore+TS_TILE_ADDR,y       ; load the address of this tile's data (pre-calculated)
            lda   TileStore+TS_SCREEN_ADDR,y     ; Get the on-screen address of this tile
            pha

            lda   TileStore+TS_WORD_OFFSET,y
            ply
            pea   $0101
            plb
            plb                                  ; set the bank

; B is set to Bank 01
; A is set to the tile word offset (0 through 80 in steps of 4)
; Y is set to the top-left address of the tile in SHR screen
; X is set to the address of the tile data

:tiledisp   jmp   $0000                          ; render the tile

DirtyTileProcs       dw  _TBDirtyTile_00,_TBDirtyTile_0H,_TBDirtyTile_V0,_TBDirtyTile_VH
DirtyTileSpriteProcs dw  _TBDirtySpriteTile_00,_TBDirtySpriteTile_0H,_TBDirtySpriteTile_V0,_TBDirtySpriteTile_VH

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

_TBDirtySpriteTile_00
_TBDirtySpriteTile_0H
                 jsr             _TBCopyTileDataToCBuff     ; Copy the tile into the compositing buffer (using correct x-register)
                 jmp             _TBApplyDirtySpriteData    ; Overlay the data from the sprite plane (and copy into the code field)

_TBDirtySpriteTile_V0
_TBDirtySpriteTile_VH
                 jsr             _TBCopyTileDataToCBuffV
                 jmp             _TBApplyDirtySpriteData

_TBApplyDirtySpriteData
                 ldx   _SPR_X_REG                               ; set to the unaligned tile block address in the sprite plane

]line            equ   0
                 lup   8
                 lda   blttmp+{]line*4}
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta:  $0000+{]line*160},y

                 lda   blttmp+{]line*4}+2
                 andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 oral  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta:  $0002+{]line*160},y
]line            equ   ]line+1
                 --^
                 rts 

; Input:  A = bit field, assumed non-zero
; Output: A = number of bits set
; Side Effect: Fill in the ActiveSprite list with sprite indices.
;
; We try very hard to be fast and clever here.  Early out, keeping everything in
; registers when possible, and reducing overhead.

spriteIdx equ tmp12
BuildActiveSpriteArray

; Push a sentinel value on the stack so we know where to end later.  We con't count during the
; initial process, because the Z flag needs to be maintained and almost evey opcode affects it.

;                 cmp   lastActiveValue        ; Assume that there is a decent chance of having the same
;                 beq   early_out              ; sprite bitfield in consecutive dirty tiles. Saves a lot.

                 tsx                           ; save the stack pointer
                 pea   $FFFF                   ; sentinel value

; This first loop scans the bits in the accumulator and pushed a sprite index onto the stack. We
; could push any constanct, which gives us some flexibility.  This only works because the PEA
; instruction does not affect any register.  We also check to see if the acumulator is zero as
; an early-out test, but only do that every 4 bits in order to amortize the overhead a bit.

]step            equ   0
                 lup   4
                 ror
                 bcc   :skip_1
                 pea   ]step
:skip_1          ror
                 bcc   :skip_2
                 pea   ]step+2
:skip_2          ror
                 bcc   :skip_3
                 pea   ]step+4
:skip_3          ror
                 bcc   :skip_4
                 pea   ]step+6
:skip_4          beq   :end_1
]step            equ   ]step+8
                 --^
:end_1

; This second loop pops values off of the stack and places them into a linear array.  We also
; set the count on exit. As an optimization / restriction, we only allow up to four overlapping
; sprites.  This is similar to the NES/C64 "8 sprites per line" restriction.

                 pla                        ; Can always assume at least one bit was set...
                 sta   spriteIdx

                 pla
                 bmi   :out_1
                 sta   spriteIdx+2

                 pla
                 bmi   :out_2
                 sta   spriteIdx+4

                 pla
                 bmi   :out_3
                 sta   spriteIdx+6

; Reset the stack point if we did not pop everything off yet
                 txs

; These are the exit points which know exactly how many items (x2) have been processed
:out_4           lda   #8
                 rts
:out_0           lda   #0
                 rts
:out_1           lda   #2
                 rts
:out_2           lda   #4
                 rts
:out_3           lda   #6
                 rts

; Run through all of the active sprites and put then on-screen.  We have three different heuristics depending on
; how many active sprites there are intersecting this tile.

; Version 2. No sprite place, instead each sprite has a set of pre-rendered panels and we render from
; those panels in tile-sized blocks.
;
; If there is only one sprite + tile background, then we can render directly to the screen
;  
;  ldal  tiledata+0,x
;  and   sprite+MASK_OFFSET,y
;  ora   sprite,y
;  sta   00
;  ...
;  sta   02
;  ...
;  sta   A0
;  ...
;  sta   A2
;  tdc
;  adc   #320
;  tcd
;
; Since this is a common case, it is reasonable to do so.  Otherwise, we must explode the TS_SPRITE_FLAG to
; get a list of sprite origin addresses and then flatten against the tile
;
;  ldal  tiledata+0,x
;  ldx   spriteCount
;  jmp   (disp,x)
;  ...
;  ldy   list+2
;  and   sprite+MASK_OFFSET,y
;  ora   sprite,y
;  ldy   list
;  and   sprite+MASK_OFFSET,y
;  ora   sprite,y
;  sta   00

;  sta   02
;  sta   A0
;  sta   A2
;  tdc
;  adc   #320
;  tcd