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
; There are two major rendering modes: a composited mode and a scanline mode.  The composited mode
; will render all of the sprites into the playfield tiles, and then perform a single blit to update
; the entire playfield.  The scanline mode utilized shadowing and blits the background scanlines
; on sprite lines first, then draws the sprites and finally exposes the updated scanlines.
;
; The composited mode has the advantages of being able to render sprites behind tile data as well
; as avoiding most overdraw.  The scanline mode is able to draw sprites correctly even when scanline
; effect are used on the background and has lower overhead, which can make it faster in some cases,
; even with the additional overdraw.
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

            lda   Overlays+OVERLAY_ID
            beq   :no_ovrly

            jsr   _ShadowOff

; Shadowing is turned off. Render all of the scan lines that need a second pass. One
; optimization that can be done here is that the lines can be rendered in any order
; since it is not shown on-screen yet.

            ldx   Overlays+OVERLAY_TOP                  ; Blit the full virtual buffer to the screen
            ldy   Overlays+OVERLAY_BOTTOM
            iny
            jsr   _BltRange

; Turn shadowing back on

            jsr   _ShadowOn

; Now render all of the remaining lines in top-to-bottom (or bottom-to-top) order

            jsr   _DoOverlay

            ldx   Overlays+OVERLAY_BOTTOM
            inx
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
            lda   Overlays+OVERLAY_PROC
            stal  :disp+1
            lda   Overlays+OVERLAY_PROC+1
            stal  :disp+2

            lda   ScreenY0             ; pass the address of the first line of the overlay
            clc
            adc   Overlays+OVERLAY_TOP
            asl
            tax
            lda   ScreenAddr,x
            clc
            adc   ScreenX0
:disp       jsl   $000000
            rts


; Use the per-scanline tables to set the screen.  This is really meant to be used without the built-in tilemap
; support and is more of a low-level way to control the background rendering
_RenderScanlines
            lda   BG1YTable                   ; Make sure we're in the right mode
            cmp   #$00A0
            beq   :ytbl_ok
            lda   #1
            jsr   _ResetBG1YTable
            lda   BG1YTable
:ytbl_ok

            jsr   _ApplyBG0YPos       ; Set stack addresses for the virtual lines to the physical screen
            jsr   _ApplyScanlineBG1YPos       ; Set the y-register values of the blitter

; _ApplyBG0Xpos need to be split because we have to set the offsets, then draw in any updated tiles, and
; finally patch out the code field.  Right now, the BRA operand is getting overwritten by tile data.

            jsr   _ApplyBG0XPosPre
            jsr   _ApplyBG1XPosPre

;            jsr   _RenderSprites      ; Once the BG0 X and Y positions are committed, update sprite data

;            jsr   _ApplyTiles         ; This function actually draws the new tiles into the code field

             jsr   _ApplyScanlineBG0XPos    ; Patch the code field instructions with exit BRA opcode            
             jsr   _ApplyScanlineBG1XPos

            jsr   _BuildShadowList    ; Create the rages based on the sorted sprite y-values

            jsr   _ShadowOff          ; Turn off shadowing and draw all the scanlines with sprites on them
            jsr   _DrawShadowList
            jsr   _DrawDirectSprites  ; Draw the sprites directly to the Bank $01 graphics buffer (skipping the render-to-tile step)

            jsr   _ShadowOn           ; Turn shadowing back on
;            jsr   _DrawComplementList ; Alternate drawing scanlines and PEI slam to expose the full fram
            jsr   _DrawFinalPass

;            jsr   _ApplyBG1XPos       ; Update the direct page value based on the horizontal position

; The code fields are locked in now and ready to be rendered. See if there is an overlay or any
; other reason to render with shadowing off.  Otherwise, just do things quickly.

;            lda   Overlays
;            beq   :no_ovrly

;            jsr   _ShadowOff

; Shadowing is turned off. Render all of the scan lines that need a second pass. One
; optimization that can be done here is that the lines can be rendered in any order
; since it is not shown on-screen yet.

;            ldx   Overlays+2                  ; Blit the full virtual buffer to the screen
;            ldy   Overlays+4
;            jsr   _BltRange

; Turn shadowing back on

;            jsr   _ShadowOn

; Now render all of the remaining lines in top-to-bottom (or bottom-to-top) order

;            ldx   #0
;            ldy   Overlays+2
;            beq   :skip
;            jsr   _BltRange
:skip
;            jsr   _DoOverlay

;            ldx   Overlays+4
;            cpx   ScreenHeight
;            beq   :done
;            ldy   ScreenHeight
;            jsr   _BltRange
;            bra   :done

;:no_ovrly
;            ldx   #0                  ; Blit the full virtual buffer to the screen
;            ldy   ScreenHeight
;            jsr   _BltRange
;:done

;            ldx   #0
;            ldy   ScreenHeight
;            jsr   _BltSCB

            lda   StartYMod208              ; Restore the fields back to their original state
            ldx   ScreenHeight
            jsr   _RestoreScanlineBG0Opcodes

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

; This rendering mode turns off shadowing and draws all of the relevant background lines and then
; draws sprites on top of the background before turning shadowing on and exposing the lines to the
; screen.  Even though entire lines are drawn twice, it's so efficient that it is often faster
; than using all of the logic to draw/erase tiles in the TileBuffer, even though less visible words
; are touched.
;
; This mode is also necessary if per-scanling rendering it used since sprites would not look correct
; if each line had independent offsets.
_RenderWithShadowing
            sta   RenderFlags
            jsr   _DoTimers           ; Run any pending timer tasks

            jsr   _ApplyBG0YPos       ; Set stack addresses for the virtual lines to the physical screen
            jsr   _ApplyBG1YPos       ; Set the y-register values of the blitter

; _ApplyBG0Xpos need to be split because we have to set the offsets, then draw in any updated tiles, and
; finally patch out the code field.  Right now, the BRA operand is getting overwritten by tile data.

            jsr   _ApplyBG0XPosPre
            jsr   _ApplyBG1XPosPre

            jsr   _UpdateBG0TileMap   ; and the tile maps.  These subroutines build up a list of tiles
;            jsr   _UpdateBG1TileMap   ; that need to be updated in the code field

            jsr   _ApplyTiles         ; This function actually draws the new tiles into the code field

            jsr   _ApplyBG0XPos       ; Patch the code field instructions with exit BRA opcode
            jsr   _ApplyBG1XPos       ; Update the direct page value based on the horizontal position

; At this point, everything in the background has been rendered into the code field.  Next, we need
; to create priority lists of scanline ranges.

            jsr   _BuildShadowList    ; Create the rages based on the sorted sprite y-values

            jsr   _ShadowOff          ; Turn off shadowing and draw all the scanlines with sprites on them
            jsr   _DrawShadowList
            jsr   _DrawDirectSprites  ; Draw the sprites directly to the Bank $01 graphics buffer (skipping the render-to-tile step)

            jsr   _ShadowOn           ; Turn shadowing back on
;            jsr   _DrawComplementList ; Alternate drawing scanlines and PEI slam to expose the full fram
            jsr   _DrawFinalPass

;
; The objects that need to be reasoned about are
;
; 1. Sprites
; 2. Overlays
;    a. Solid High Priority
;    b. Solid Low Priority
;    c. Masked High Priority
;    d. Masked Low Priority
; 3. Background
;
; Notes:
;
;  A High Priority overlay is rendered above the sprites
;  A Low Priority overlay is rendered below the sprites
;  A Solid High Priority overlay obscured everything and if the only thing drawn on the scanline
;
; The order of draw oprations is:
;
; 1. Turn off shadowing
; 2. Draw the background for scanlines with (Sprites OR a Masked Low Priority overlay) AND NOT a Solid Low Priority overlay
; 3. Draw the Solid Low Priority overlays
; 4. Draw the Sprites
; 5. Draw the Masked Low Priority overlays
; 6. Turn on shadowing
; 7. Draw, in top-to-bottom order
;    a. Background lines not drawn yet
;    b. PEI Slam lines with (Sprites OR a Masked Low Priority Overlay) AND NOT a High Priority overlay
;    c. High Priority overlays
;
; The work of this routine is to quickly build a sorted list of scanline ranges that can the appropriate
; sub-renderer

;            jsr   BuildShadowSegments
;
; The trick is to create a bit-field mapping for the different actions to define 

;            lda   Overlays
;            beq   :no_ovrly
;
;            jsr   _ShadowOff

; Shadowing is turned off. Render all of the scan lines that need a second pass. One
; optimization that can be done here is that the lines can be rendered in any order
; since it is not shown on-screen yet.

;            ldx   Overlays+OVERLAY_TOP                  ; Blit the full virtual buffer to the screen
;            ldy   Overlays+OVERLAY_BOTTOM
;            jsr   _BltRange

; Turn shadowing back on

;            jsr   _ShadowOn

; Now render all of the remaining lines in top-to-bottom (or bottom-to-top) order

;            ldx   #0
;            ldy   Overlays+OVERLAY_TOP
;            beq   :skip
;            jsr   _BltRange
;:skip
;            jsr   _DoOverlay

;            ldx   Overlays+OVERLAY_BOTTOM
;            cpx   ScreenHeight
;            beq   :done
;            ldy   ScreenHeight
;            jsr   _BltRange
;            bra   :done

;:no_ovrly

;            ldx   #0                  ; Blit the full virtual buffer to the screen
;            ldy   ScreenHeight
;            jsr   _BltRange

;:done

 ;           ldx   #0
 ;           ldy   ScreenHeight
 ;           jsr   _BltSCB

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

; Look at the overlay list and the sprite list and figure out which scanline ranges need to be 
; blitted in what order.  We try to build all of the scan line segments lists because that 
; saves the work of re-scanning the lists.
;
; The semgent list definitions are:
;
;   BLIT_W_SHADOW_OF
BuildShadowSegments
;            ldx   _SortedHead
;            bmi   :no_sprite
;:loop
;            lda   _Sprites+CLIP_TOP,x
;            lda   _Sprites+SORTED_NEXT,x
;            tax
;            bpl   :loop
;
;            lda   #0                            ; Start at the top of the 

            rts

; Function to iterate through the sprite list and build a merged scanline list of sprites.  Once this is
; done, we re-scan the list to build the complement for scanlines that do not need shadowing.
_BuildShadowList

            ldy    #0                           ; This is the index into the list of shadow segments

            ldx    _SortedHead
            bmi    :empty
            bra    :insert

; Start of loop
:advance
            iny
            iny

:insert
            lda   _Sprites+SPRITE_CLIP_TOP,x      ; Load the sprite's top line
            sta   _ShadowListTop,y                ; Set the top entry of the list to the sprite top

            lda   _Sprites+SPRITE_CLIP_BOTTOM,x   ; Optimistically set the end of the segment to the bottom of this sprite
            inc                                   ; Clip values are on the scanline, so add one to make it a proper interval

:replace
            sta   _ShadowListBottom,y
:skip
            lda   _Sprites+SORTED_NEXT,x          ; If there another sprite in the list?
            bmi   :no_more_sprites                ; If not, we can finish up

            tax
            lda   _ShadowListBottom,y             ; If the bottom of the current sprite is _less than_ the top of the next 
            cmp   _Sprites+SPRITE_CLIP_TOP,x      ; sprite, then there is a gap and we create a new entry
            bcc   :advance

            lda   _Sprites+SPRITE_CLIP_BOTTOM,x   ; Get the bottom value of the next sprite.
            inc
            cmp   _ShadowListBottom,y             ; If it extends the segment then replace the value, otherwise skip
            bcc   :skip
            bra   :replace

:no_more_sprites
            iny                                 ; Set the list count to N * 2
            iny
:empty
            sty   _ShadowListCount
            rts

; Run through the shadow list and make a complementary list, e.g 
;   [[0, 7], [12, 19]] -> [[7, 12], [19, end]]
;   [[2, 10], [20, 40]] -> [[0, 2], [10, 20], [40, end]]

_ComplementList
            ldy   #0
            tyx

            lda   _ShadowListCount
            beq   :empty_list

            lda   _ShadowListTop
            beq   :loop

            stz   _DirectListTop
            sta   _DirectListBottom

            inx
            inx

:loop
            lda   _ShadowListBottom,y
            sta   _DirectListTop,x

            iny                                  ; Move to the next shadow list record
            iny
            cpy   _ShadowListCount               ; Are there any other segments to process
            bcs   :eol

            lda   _ShadowListTop,y
            sta   _DirectListBottom,x            ; Finish the direct list entry

            inx
            inx
            bra   :loop

:eol
            lda   ScreenHeight
            sta   _DirectListBottom,x

            inx                                 ; Set the count to N * 2
            inx
            stx   _DirectListCount
            rts

:empty_list
            lda   #1
            sta   _DirectListCount
            stz   _DirectListTop
            lda   ScreenHeight
            sta   _DirectListBottom
            rts

; Iterate through the shadow list and call _BltRange on each
_DrawShadowList
            ldx   #0
            bra   :start

:loop
            phx                                         ; Save the index
            lda   _ShadowListTop,x
            ldy   _ShadowListBottom,x
            tax
            jsr   _BltRange

            plx
            inx
            inx
:start
            cpx   _ShadowListCount
            bcc   :loop

            rts

; Run through the list of sprites that are not IS_OFFSCREEN and not OVERLAYS and draw them directly to the graphics screen.  We can use
; compiled sprites here, with limitations.
_DrawDirectSprites
            lda    RenderFlags
            bit    #RENDER_SPRITES_SORTED
            bne    :sorted

; Shift through the sprites

            lda    SpriteMap
            beq    :empty
            sta    tmp15
            ldx    #0

:iloop
            lsr    tmp15
            bcc    :next
            jsr    :render

:next       inx
            inx
            lda    tmp15
            bne    :iloop
            rts

:sorted
            ldx    _SortedHead
            bmi    :empty

:loop
            jsr    :render
            lda    _Sprites+SORTED_NEXT,x        ; If there another sprite in the list?
            tax
            bpl    :loop 
:empty
            rts

:render
            lda    _Sprites+SPRITE_ID,x
            bit    #SPRITE_OVERLAY
            beq    *+3
            rts
            lda    _Sprites+SPRITE_STATUS,x
            bit    #SPRITE_STATUS_HIDDEN
            beq    *+3
            rts
            phx
            jsr    _DrawStampToScreen
            plx
            rts


; Run through the sorted list and perform a final render the jumps between calling _PEISlam for shadowed lines,
; _BltRange for clean backgrounds and Overlays as needed.
;
; The trick here is to merge runs of shared render types. 
;
; Loop invariant: X-register is the current object index, Y-register is the next object index
;
; TODO: This does not yet handle the case of a narrow overlay in the middle of a sprite.  The second half of the sprite will not be exposed
;       by a PEISlam.
;
; e.g.                          |--- Overlay ---|
;                    |-------------- Sprite ----------------|
;
; Output Should be   |-- PEI --||--- Overlay ---||--- PEI --|
; But currently is   |-- PEI --||--- Overlay ---|

_DrawFinalPass
:curr_top    equ    tmp0
:curr_bottom equ    tmp1
:curr_type   equ    tmp2

            ldx    _SortedHead
            bmi    :empty

            lda    _Sprites+SPRITE_CLIP_TOP,x      ; Load the first object's top edge
;            sta    :curr_top
            beq    :loop                          ; If it's at the top edge of the screen, proceed. Othrewise _BltRange the top range

            ldx    #0
            tay
            jsr    _BltRange
            ldx    _SortedHead                     ; Reload the register

:loop
            lda    _Sprites+SPRITE_ID,x            ; Save the type of the current segment. Do this first because it can be skipped
            and    #SPRITE_OVERLAY                 ; when merging ranges of the same type
            sta    :curr_type

            lda    _Sprites+SPRITE_CLIP_TOP,x
            sta    :curr_top
            lda    _Sprites+SPRITE_CLIP_BOTTOM,x   ; Optimistically set the end of the segment to the bottom of this object
            inc                                    ; Clip values are on the scanline, so add one to make it a proper interval

:update
            sta    :curr_bottom

:skip
            ldy    _Sprites+SORTED_NEXT,x          ; If there another object in the list?
            bmi    :no_more                        ; If not, we can finish up

            lda    :curr_bottom                    ; If the bottom of the current object is _less than_ the top of the next 
            cmp    _Sprites+SPRITE_CLIP_TOP,y      ; sprite, then there is a gap and we can draw the current object and a
            bcc    :advance                        ; _BltRange up to the next one

; Here, we've established that there is another object segment that starts at or within the bounds of the current
; object.  If they are of the same type, then we can merge them and look at the next object in the list; treating
; the merges range as a larger, single object range.
;
; If they are different, then clip the current object range to the top of the next one, render the current object
; range and then take the new object as the current one.
;
; If the first object extends past the second, we are going to miss the remainder of that object.  We really need a
; stack to put it on so that it can eventually be processed later.

            lda   _Sprites+SPRITE_ID,y
            and   #SPRITE_OVERLAY
            cmp   :curr_type
            bne   :no_merge

            tyx                                   ; Move the next index into the current
            lda   _Sprites+SPRITE_CLIP_BOTTOM,y   ; Get the bottom value of the next sprite.
            inc
            cmp   :curr_bottom                    ; If it extends the segment then replace the bottom value, otherwise skip. In
            bcc   :skip                           ; either case, the type and top value remain the same
            bra   :update

; This is a simpler version of the 'advance' below.  In this case there are overlapping ranges, so we just need to draw a 
; clipped version of the top range and then restart the loop with the next range.
:no_merge
            lda   _Sprites+SPRITE_CLIP_TOP,y      ; Get the top of the next segment
            sta   :curr_bottom                    ; Use it as the bottom of the current segment
            phy                                   ; Save the next index...
            jsr   :PEIOrOverlay                   ; Draw the current segment type
            plx                                   ; ...and restore as the current
            bra   :loop                           ; Start again

:advance
            phy
            jsr   :PEIOrOverlay                   ; Draw the appropriate filler
            lda   1,s
            tax
            ldy   _Sprites+SPRITE_CLIP_TOP,x      ; Draw the background in between
            ldx   :curr_bottom
            jsr   _BltRange
            plx
            bra    :loop

; List is empty, so just do one big _BltRange with a tail call
:empty
            ldx   #0
:no_more2
            ldy   ScreenHeight
            jmp   _BltRange

; Found the end of the list.  Draw current object and then blit the rest of the screen
:no_more
            jsr   :PEIOrOverlay
            ldx   :curr_bottom
            cpx   ScreenHeight
            bcc   :no_more2
            rts

; Help to select between calling an Overlay or PEISlam routine
:PEIOrOverlay
            lda   :curr_type
            bne   :overlay

            ldx   :curr_top
            ldy   :curr_bottom
            jmp   _PEISlam
:overlay
            lda   _Sprites+OVERLAY_PROC,x
            stal  :disp+1
            lda   _Sprites+OVERLAY_PROC+1,x
            stal  :disp+2

            lda   ScreenY0             ; pass the address of the first line of the overlay
            clc
            adc   _Sprites+OVERLAY_TOP,x
            asl
            tax
            lda   ScreenAddr,x
            clc
            adc   ScreenX0
            ldx   :curr_top
            ldy   :curr_bottom
:disp       jsl   $000000
            rts


_DrawComplementList

            ldx   #0

            lda   _DirectListCount                      ; Skip empty lists
            beq   :out

            lda   _DirectListTop                        ; If the first segment starts at 0, begin with _BltRange
            beq   :blt_range

            lda   #0
            bra   :pei_first

:blt_range  
            phx
            lda   _DirectListTop,x
            ldy   _DirectListBottom,x
            tax
;            lda   #0
;            jsr   DebugSCBs
            jsr   _BltRange
            plx

            lda   _DirectListBottom,x                   ; Grab a copy of the bottom of the blit range
            inx
            inx                                         ; Advance to the next entry
            cpx   _DirectListCount
            bcs   :last                                 ; Done, so check if there is any remaining part of the screen to slam

:pei_first
            phx
            ldy   _DirectListTop,x
            tax
;            lda   #1
;            jsr   DebugSCBs
            jsr   _PEISlam
            plx
            bra   :blt_range

:last
            cmp   ScreenHeight                          ; If the bottom on the last segment didn't come to the bottom of the
            bcs   :out                                  ; screen, then expose that range
            tax
            ldy   ScreenHeight
;            lda   #1
;            jsr   DebugSCBs
            jsr   _PEISlam
:out
            rts

; Helper to set a palette index on a range of SCBs to help show whicih actions are applied to which lines
DebugSCBs
            phx
            phy
            sep   #$30          ; short m/x

            pha                 ; save the SCB value
            
            phx
            tya
            sec
            sbc   1,s
            tay                 ; number of scanlines

            pla
            clc
            adc   ScreenY0
            tax                 ; physical line index

            pla
:loop
            stal  SHR_SCB,x
            inx
            dey
            bne   :loop

            rep   #$30
            ply
            plx
            rts


