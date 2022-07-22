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
            sta   RenderFlags

            lda   LastRender          ; Check to see what kind of rendering was done on the last frame. If
            beq   :no_change          ; it was not this renderer, 
            jsr   _ResetToNormalTileProcs
            jsr   _Refresh
:no_change

            jsr   _DoTimers           ; Run any pending timer tasks

            stz   SpriteRemovedFlag   ; If we remove a sprite, then we need to flag a rebuild for the next frame

            jsr   _ApplyBG0YPos       ; Set stack addresses for the virtual lines to the physical screen

            lda   #RENDER_BG1_ROTATION
            bit   RenderFlags
            bne   :skip_bg1_y
            jsr   _ApplyBG1YPos       ; Set the y-register values of the blitter
:skip_bg1_y

; _ApplyBG0Xpos need to be split because we have to set the offsets, then draw in any updated tiles, and
; finally patch out the code field.  Right now, the BRA operand is getting overwritten by tile data.

            jsr   _ApplyBG0XPosPre
            jsr   _ApplyBG1XPosPre

            jsr   _RenderSprites      ; Once the BG0 X and Y positions are committed, update sprite data

            jsr   _UpdateBG0TileMap   ; and the tile maps.  These subroutines build up a list of tiles
;            jsr   _UpdateBG1TileMap   ; that need to be updated in the code field

            jsr   _ApplyTiles         ; This function actually draws the new tiles into the code field

            jsr   _ApplyBG0XPos       ; Patch the code field instructions with exit BRA opcode            
            lda   #RENDER_BG1_ROTATION
            bit   RenderFlags
            bne   :skip_bg1_x
            jsr   _ApplyBG1XPos       ; Update the direct page value based on the horizontal position
:skip_bg1_x

; The code fields are locked in now and ready to be rendered. See if there is an overlay or any
; other reason to render with shadowing off.  Otherwise, just do things quickly.

            lda   Overlays
            beq   :no_ovrly

            jsr   _ShadowOff

; Shadowing is turned off. Render all of the scan lines that need a second pass. One
; optimization that can be done here is that the lines can be rendered in any order
; since it is not shown on-screen yet.

            ldx   Overlays+2                  ; Blit the full virtual buffer to the screen
            ldy   Overlays+4
            jsr   _BltRange

; Turn shadowing back on

            jsr   _ShadowOn

; Now render all of the remaining lines in top-to-bottom (or bottom-to-top) order

            ldx   #0
            ldy   Overlays+2
            beq   :skip
            jsr   _BltRange
:skip
            jsr   _DoOverlay

            ldx   Overlays+4
            cpx   ScreenHeight
            beq   :done
            ldy   ScreenHeight
            jsr   _BltRange
            bra   :done

:no_ovrly
            ldx   #0                  ; Blit the full virtual buffer to the screen
            ldy   ScreenHeight
            jsr   _BltRange
:done

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

_DoOverlay
            lda   Overlays+6
            stal  :disp+1
            lda   Overlays+7
            stal  :disp+2

            lda   ScreenY0             ; pass the address of the first line of the overlay
            clc
            adc   Overlays+2
            asl
            tax
            lda   ScreenAddr,x
            clc
            adc   ScreenX0
:disp       jsl   $000000
            rts

; Run through all of the tiles on the DirtyTile list and render them
_ApplyTiles
            ldx  DirtyTileCount

            phd                         ; sve the current direct page
            tdc
            clc
            adc  #$100                  ; move to the next page
            tcd

            stx  DP2_DIRTY_TILE_COUNT   ; Cache the dirty tile count
            jsr  _PopDirtyTilesFast

            pld                         ; Move back to the original direct page
            stz  DirtyTileCount         ; Reset the dirty tile count
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
            lda   LastRender                     ; If the full renderer was last called, we assume that
            bne   :norecalc                      ; the scroll positions have likely changed, so recalculate
            jsr   _RecalcTileScreenAddrs         ; them to make sure sprites draw at the correct screen address
            jsr   _ResetToDirtyTileProcs         ; Switch the tile procs to the dirty tile rendering functions
;            jsr   _ClearSpritesFromCodeField    ; Restore the tiles to their non-sprite versions
:norecalc
            jsr   _RenderSprites
            jsr   _ApplyDirtyTiles

            lda   #1
            sta   LastRender
            rts

_ApplyDirtyTiles
            phd                         ; save the current direct page
            tdc
            clc
            adc  #$100                  ; move to the next page
            tcd

            bra  :begin

:loop
; Retrieve the offset of the next dirty Tile Store items in the Y-register

            jsr  _PopDirtyTile2

; Call the generic dispatch with the Tile Store record pointer at by the Y-register.  

            jsr  _RenderDirtyTile

; Loop again until the list of dirty tiles is empty

:begin      ldy  DirtyTileCount
            bne  :loop

            pld                         ; Move back to the original direct page
            stz  DirtyTileCount         ; Reset the dirty tile count
            rts

