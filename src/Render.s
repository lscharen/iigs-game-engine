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
;
; TODO -- actually check the dirty bits and be selective on what gets updated.  For example, if
;         only the Y position changes, then we should only need to set new values on the 
;         virtual lines that were brought on screen.  If the X position only changes by one
;         byte, then we may have to change the CODE_ENTRY values or restore/set new OPCODE
;         values, but not both.

; It's important to do _ApplyBG0YPos first because it calculates the value of StartY % 208 which is
; used in all of the other loops
_Render
            jsr   _DoTimers            ; Run any pending timer tasks

            stz   SpriteRemovedFlag   ; If we remove a sprite, then we need to flag a rebuild for the next frame

            jsr   _ApplyBG0YPos       ; Set stack addresses for the virtual lines to the physical screen
            jsr   _ApplyBG1YPos

; _ApplyBG0Xpos need to be split because we have to set the offsets, then draw in any updated tiles, and
; finally patch out the code field.  Right now, the BRA operand is getting overwritten by tile data.
            jsr   _ApplyBG0XPosPre
            jsr   _ApplyBG1XPosPre

            jsr   _RenderSprites      ; Once the BG0 X and Y positions are committed, update sprite data

            jsr   _UpdateBG0TileMap   ; and the tile maps.  These subroutines build up a list of tiles
;            jsr   _UpdateBG1TileMap   ; that need to be updated in the code field

            jsr   _ApplyTilesFast      ; This function actually draws the new tiles into the code field

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

            lda   StartYMod208              ; Restore the fields back to their original state
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

            lda   SpriteRemovedFlag             ; If any sprite was removed, set the rebuild flag
            beq   :no_removal
            lda   #DIRTY_BIT_SPRITE_ARRAY
            sta   DirtyBits
:no_removal
            rts

; The _ApplyTilesFast is the same as _ApplyTiles, but we use the _RenderTileFast subroutine
_ApplyTilesFast
            ldx  DirtyTileCount

            tdc
            clc
            adc  #$100                  ; move to the next page
            tcd

            stx  DP2_DIRTY_TILE_COUNT   ; Cache the dirty tile count
            jsr  _PopDirtyTilesFast

            tdc                         ; Move back to the original direct page
            sec
            sbc  #$100
            tcd

            stz  DirtyTileCount         ; Reset the dirty tile count
            rts

; The _ApplyTiles function is responsible for rendering all of the dirty tiles into the code
; field.  In this function we switch to the second direct page which holds the temporary
; working buffers for tile rendering.
;
_ApplyTiles
            tdc
            clc
            adc  #$100                  ; move to the next page
            tcd

            bra  :begin

:loop
; Retrieve the offset of the next dirty Tile Store items in the X-register

            jsr  _PopDirtyTile2

; Call the generic dispatch with the Tile Store record pointer at by the X-register.

            phb
;            jsr  _RenderTile2
            plb

; Loop again until the list of dirty tiles is empty

:begin      ldy  DirtyTileCount
            bne  :loop

            tdc                         ; Move back to the original direct page
            sec
            sbc  #$100
            tcd
            rts

; This is a specialized render function that only updates the dirty tiles *and* draws them
; directly onto the SHR graphics buffer.  The playfield is not used at all.  In some way, this
; ignores almost all of the capabilities of GTE, but it does provide a convenient way to use
; the sprite subsystem + tile attributes for single-screen games which should be able to run
; close to 60 fps.
;
; In this renderer, we assume that there is no scrolling, so no need to update any information about
; the BG0/BG1 positions
_RenderDirty
            lda   LastRender                    ; If the full renderer was last called, we assume that
            bne   :norecalc                     ; the scroll positions have likely changed, so recalculate
            jsr   _RecalcTileScreenAddrs        ; them to make sure sprites draw at the correct screen address
;            jsr   _ClearSpritesFromCodeField    ; Restore the tiles to their non-sprite versions
:norecalc

;            jsr   _RenderSprites
;            jsr   _ApplyDirtyTiles

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
            lda   TileStore+TS_SPRITE_FLAG,y
            beq   NoSpritesDirty                    ; This is faster if there are no sprites

;           TODO: handle sprite drawing

; The rest of this function handles that non-sprite blit, which is super fast since it blits directly from the
; tile data store to the graphics screen with no masking. The only extra work is selecting a blit function
; based on the tile flip flags.
;
; B is set to Bank 01
; Y is set to the top-left address of the tile in SHR screen
; A is set to the address of the tile data
NoSpritesDirty
;            lda   TileStore+TS_DIRTY_TILE_DISP,y
;            stal  :nsd+1
            ldx   TileStore+TS_SCREEN_ADDR,y       ; Get the on-screen address of this tile
            lda   TileStore+TS_TILE_ADDR,y         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
:nsd        jmp   $0000
; Use some temporary space for the spriteIdx array (maximum of 4 entries)

stkSave     equ tmp9
screenAddr  equ tmp10
tileAddr    equ tmp11
spriteIdx   equ tmp12

; If there are two or more sprites at a tile, we can still be fast, but need to do extra work because
; the VBUFF values need to be read from the direct page.  Thus, the direct page cannot be mapped onto
; the graphics screen.  We use the stack instead, but have to do extra work to save and restore the
; stack value.
FourSpritesDirty
ThreeSpritesDirty
TwoSpritesDirty

            sta  tileAddr
            stx  screenAddr

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
OneSpriteDirty
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
