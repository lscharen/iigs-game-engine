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

; Small helper function to draw a single overlay
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

; Callback structure with pointers to internal rendering functions
ExtFuncBlock
            adrl  BltRange
            adrl  PEISlam

; Special NES renderer that externalizes the sprite rendering in order to exceed the internal limit of 16 sprites
_RenderNES
            jsr   _ApplyBG0YPos
            jsr   _ApplyBG0XPosPre

; Callback to update the tilestore with any new tiles

            lda   ExtUpdateBG0Tiles
            ora   ExtUpdateBG0Tiles+2
            beq   :no_tile

            lda   ExtUpdateBG0Tiles
            stal  :patch0+1
            lda   ExtUpdateBG0Tiles+1
            stal  :patch0+2
:patch0     jsl   $000000
:no_tile

            jsr   _ApplyTiles         ; This function actually draws the new tiles into the code field

            stz   tmp1                ; virt_line_x2
            lda   #16*2
            sta   tmp2                ; lines_left_x2
            lda   #0                  ; Xmod164
            jsr   _ApplyBG0XPosAlt
            lda   tmp4                ; :exit_offset
            stal  nesTopOffset

            lda   #16*2
            sta   tmp1                ; virt_line_x2
            lda   ScreenHeight
            sec
            sbc   #16
            asl
            sta   tmp2                ; lines_left_x2
            lda   StartXMod164        ; Xmod164
            jsr   _ApplyBG0XPosAlt
            lda   tmp4
            stal  nesBottomOffset

; This is a tricky part. The NES does not keep sprites sorted, so we need an alternative way to figure out
; which lines to shadow and which ones not to.  Our compromise is to build a bitmap of lines that the sprite
; occupy and then scan through that quickly.
;
; This is handled by the callback in two phases.  We pass pointers to the internal function the callback needs
; access to.  If there is no function defined, do nothing

            lda   GTEControlBits
            bit   #CTRL_SPRITE_DISABLE
            bne   :no_render

            lda   ExtSpriteRenderer
            ora   ExtSpriteRenderer+2
            beq   :no_render

            lda   ExtSpriteRenderer
            stal  :patch1+1
            stal  :patch2+1
            lda   ExtSpriteRenderer+1
            stal  :patch1+2
            stal  :patch2+2

; Start the two-phase rendering process.  First turn off shading and invoke the callback to 
; draw sprite regions

            jsr   _ShadowOff

            lda   #0                  ; Signal we're in phase 1 (shadowing off)
            ldx   #^ExtFuncBlock
            ldy   #ExtFuncBlock
:patch1     jsl   $000000

; Now perform the second phase which renders the whole screen and exposes the sprites that were
; drawins in the first phase

            jsr   _ShadowOn

            lda   #1                  ; Signal we're in phase 2 (shadowing on)
            ldx   #^ExtFuncBlock
            ldy   #ExtFuncBlock
:patch2     jsl   $000000

:no_render
            stz  tmp1            ; :virt_line_x2
            lda  #16*2
            sta  tmp2            ; :lines_left_x2
            ldal nesTopOffset
            sta  tmp4            ; :exit_offset
            jsr   _RestoreBG0OpcodesAlt

            lda   #16*2
            sta   tmp1                 ; :virt_line_x2
            lda   ScreenHeight
            sec
            sbc   #16
            asl
            sta   tmp2                ; lines_left_x2
            ldal  nesBottomOffset
            sta   tmp4                ; :exit_offset
            jsr   _RestoreBG0OpcodesAlt

;            lda   StartYMod208              ; Restore the fields back to their original state
;            ldx   ScreenHeight
;            jsr   _RestoreBG0Opcodes

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

nesTopOffset ds 2
nesBottomOffset ds 2

; Use the per-scanline tables to set the screen.  This is really meant to be used without the built-in tilemap
; support and is more of a low-level way to control the background rendering
_RenderScanlines
            lda   BG1YTable                   ; Make sure we're in the right mode (0 = scanline mode, $1800 = normal mode)
            beq   :ytbl_ok
            lda   #1
            jsr   _ResetBG1YTable
:ytbl_ok

            jsr   _ApplyBG0YPos               ; Set stack addresses for the virtual lines to the physical screen
            jsr   _ApplyScanlineBG1YPos       ; Set the y-register values of the blitter

            jsr   _ApplyBG0XPosPre
            jsr   _ApplyBG1XPosPre

            jsr   _ApplyScanlineBG0XPos    ; Patch the code field instructions with exit BRA opcode            
            jsr   _ApplyScanlineBG1XPos

            jsr   _FilterObjectList        ; Walk the sorted list and create an array of objects that need to be rendered

            jsr   _ShadowOff               ; Turn off shadowing and draw all the scanlines with sprites on them
            jsr   _DrawObjShadow           ; Draw the background 
            jsr   _DrawDirectSprites       ; Draw the sprites directly to the Bank $01 graphics buffer (skipping the render-to-tile step)

            jsr   _ShadowOn                ; Turn shadowing back on
            jsr   _DrawFinalPass           ; Expose the shadowed areas and draw overlays

            lda   StartYMod208             ; Restore the fields back to their original state
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


; After the sprites have been filtered, we have a linked list with all of the contiguous sprite regions merged together, so
; when provessing this list we really only have to consider complications from overlays.
;
; Pseudo-code
;
; 0. Set the cursor to the top of the screen
; 1. Load the next segment
;    a. If no segments, just draw the full screen
; 2. Draw the background from the cursor to the top of the current segment
; 3. If the current segment is a sprite
;    a. Peek at the next segment
;    b. If no more segments, then finish
;    c. If it's past the bottom, PEI slam the current segment and go to [1]
;    d. Must be an overlay
;       i.   PEI slam up to the overlay top
;       ii.  Does the sprite extend past the overlay? If yes, split the sprite and insert into the list
;       iii. Go to [1]
; 4. If the current segment is an overlay
;    a. Peek at the next segment
;    b. If no more segments, then finish
;    c. If it's past the bottom, draw the overlay and go to [1]
;    d. Must be a sprite
;       i.   Draw the overlay
;       ii.  Change the sprite segment to start after the overlay
;       iii. Go to [1]
_DrawFinalPass
:cursor     equ    tmp8
:bottom     equ    tmp9

            stz    :cursor
            ldy    #0
            cpy    ObjectListCount
            bne    :enter

            ldx    #0                            ; If there are no object to render, just draw the screen
            ldy    ScreenHeight
            jmp    _BltRange

:enter
            ldx    ObjectList+OL_INDEX,y         ; Load the index of the next object record

; Draw the background up to the top line of the next object

            phxy
            ldy    _Sprites+SPRITE_CLIP_TOP,x
            ldx    :cursor
            sty    :cursor                       ; Update the cursor since we have the value
            jsr    _BltRange
            plyx

:_oloop
            lda    _Sprites+SPRITE_CLIP_BOTTOM,x
            sta    :bottom

; Load the ID to see what kind of object comes next

            lda    _Sprites+SPRITE_ID,x          ; See if we are processing an overlay or a sprite region
            bit    #SPRITE_OVERLAY
            jne    :_overlay

:_sprite
            iny
            iny
            cpy    ObjectListCount
            jeq    :_sprite_end                  ; If this is the last object, end now on the sprite

            ldx    ObjectList+OL_INDEX,y         ; Load the index of the next item
            lda    :bottom
            cmp    _Sprites+SPRITE_CLIP_TOP,x
            bcs    :_smerge                      ; If the prior sprite ends before this object, then handle it

            phxy
            ldy    _Sprites+SPRITE_CLIP_TOP,x    ; A = :bottom, so load the top of the next object and
            sty    :bottom                       ; save it as it is the bottom after the PEISlam

            ldx    :cursor                       ; X = :cursor
            sta    :cursor                       ; The current :bottom becomes the :cursor after the PEISlam
            tay                                  ; Y = :bottom
            jsr    _PEISlam
            ldx    :cursor                       ; This is the previous :bottom value
            ldy    :bottom                       ; This is the SPRITE_CLIP_TOP,x value
            sty    :cursor
            jsr    _BltRange
            plyx
            brl    :_oloop                       ; Branch back, it's like starting from from scratch

:_smerge
            lda    _Sprites+SPRITE_ID,x          ; Before we merge, need to know if objects are compatible
            bit    #SPRITE_OVERLAY
            bne    :_somerge

            lda    _Sprites+SPRITE_CLIP_BOTTOM,x ; Can be merged, so pick the largest bottom value and 
            max    :bottom                       ; continue on as a sprite
            sta    :bottom
            brl    :_sprite

:_somerge
            phxy
            ldy    _Sprites+SPRITE_CLIP_TOP,x    ; PEI Slam to the top of the overlay (:bottom is greater than this value)
            ldx    :cursor
            sty    :cursor
            jsr    _PEISlam
            lda    3,s                           ; Retrieve the sprite index
            tax
            jsr    _DrawOverlay
            plyx

            lda    _Sprites+SPRITE_CLIP_BOTTOM,x ; This is how far we've drawn.  Check to see if we're beyond the current :bottom
            sta    :cursor
            cmp    :bottom
            jcc    :_sprite                      ; Previous sprite extends past the overlay, continue

; The overlay can cause the cursor to jump ahead an arbitrary distance.  We need to continue to scan through the list until
; we find an item that has a bottom greater than the current :cursor
:_so_loop
            iny
            iny
            cpy    ObjectListCount
            beq    :_end

            ldx    ObjectList+OL_INDEX,y
            lda    :cursor
            cmp    _Sprites+SPRITE_CLIP_BOTTOM,x
            bcs    :_so_loop

            cmp    _Sprites+SPRITE_CLIP_TOP,x    ; Check to see if there is any background that need to be drawn
            jcs    :_oloop                       ; If not, go back the see what kind of object it is

            phxy
            ldy    _Sprites+SPRITE_CLIP_TOP,x
            ldx    :cursor
            sty    :cursor
            jsr    _BltRange
            plyx
            brl    :_oloop

; If the last item is a sprite, do a PEI slam from the cursor to the sprite bottom and then blit any remaining
; backround
:_sprite_end
            ldx   :cursor
            ldy   :bottom
            jsr   _PEISlam
            ldx   :bottom
            ldy   ScreenHeight
            jmp   _BltRange

; If there are no more items to process, but we haven't reached the end of the screen, blit the rest of the 
; background
:_end
            ldx   :cursor
            ldy   ScreenHeight
            jmp   _BltRange

; An overlay is a bit easier.  It just needs to be rendered and then advance to the next object that's not
; covered by it
:_overlay
            phxy
            jsr    _DrawOverlay                   ; Draw the overlay
            plyx
            lda    :bottom
            sta    :cursor
            brl    :_so_loop

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
; This mode is also necessary if per-scanling rendering is used since sprites would not look correct
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

            jsr   _FilterObjectList        ; Walk the sorted list and create an array of objects that need to be rendered

            jsr   _ShadowOff                ; Turn off shadowing and draw all the scanlines with sprites on them
            jsr   _DrawObjShadow           ; Draw the background 
            jsr   _DrawDirectSprites        ; Draw the sprites directly to the Bank $01 graphics buffer (skipping the render-to-tile step)

            jsr   _ShadowOn                 ; Turn shadowing back on
            jsr   _DrawFinalPass

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

; Specail mode for rendering in GTE-lite mode.  No secondary background is possible
_RenderLite
            sta   RenderFlags
            jsr   _DoTimers            ; Run any pending timer tasks

;            brk   $65
            jsr   _ApplyBG0YPosLite    ; Set stack addresses for the virtual lines to the physical screen
;            brk   $66
            jsr   _ApplyBG0XPosPre     ; Lock in certain rendering variables (not lite/non-lite specific)
;            brk   $67


            jsr   _UpdateBG0TileMap   ; and the tile maps.  These subroutines build up a list of tiles
            jsr   _ApplyTiles         ; This function actually draws the new tiles into the code field

            jsr   _ApplyBG0XPosLite   ; Patch the code field instructions with exit BRA opcode

; At this point, everything in the background has been rendered into the code field.  Next, we need
; to create priority lists of scanline ranges.

;            jsr   _FilterObjectList        ; Walk the sorted list and create an array of objects that need to be rendered
;
;            jsr   _ShadowOff                ; Turn off shadowing and draw all the scanlines with sprites on them
;            jsr   _DrawObjShadow            ; Draw the background 
;            jsr   _DrawDirectSprites        ; Draw the sprites directly to the Bank $01 graphics buffer (skipping the render-to-tile step)
;
;            jsr   _ShadowOn                 ; Turn shadowing back on
;
;            jsr   _DrawFinalPass

            ldx    #0
            lda    ScreenHeight
            jsr    _BltRange

            lda   StartYMod208              ; Restore the fields back to their original state
            ldx   ScreenHeight
            jsr   _RestoreBG0OpcodesLite

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

; Run through the list of sprites that are not OFFSCREEN and not OVERLAYS and draw them directly to the graphics screen.  We can use
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

            phx
            jsr    _DrawStampToScreen
            plx

:next       inx
            inx
            lda    tmp15
            bne    :iloop
            rts

:sorted
            ldx    _SortedHead
            bmi    :empty

:loop
            phx
            jsr    _DrawStampToScreen
            plx

            lda    _Sprites+SORTED_NEXT,x        ; If there another sprite in the list?
            tax
            bpl    :loop 
:empty
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
;
; The conceptual model of this routine is that it toggles between BltRange and PEISlam modes, but overlays are special and get drawn
; immediately but don't change the mode.
;
; General case to handle is this
;
; 0  1  2  3  4  5  6  7  8  9
; |------ sprite ---------|      = A
;    |-- overlay ------|         = B
;       |-- sprite -|            = C
;             |--- sprite ---|   = D
;
; To handle this for each, we need to be able to slice off a piece of a sprite or overlay and insert it into the list for
; handling later.  In this case, after the range [0, 1] is exposed for A, it should be dropped and moved like this
;
; 0  1  2  3  4  5  6  7  8  9
;    |-- overlay ------|         = B
;       |-- sprite -|            = C
;             |--- sprite ---|   = D
;                      |--|      = A
;
; We can't alter that actual sorted list of items, so we create a reduced list which allows items to be filtered and
; to keep a simple, single-linked list
EOL         equ    $FFFF


; New approach here.  Walk the sorted, double linked list and copy the IDs into an array.  There is
; a parallel structure to use later, but this is the easiest thing to work with
_FilterObjectList
            ldy    #0
            ldx    _SortedHead                    ; Walk the list
            bra    :entry

:loop
            txa
            sta    ObjectList+OL_INDEX,y
            iny
            iny

            lda    _Sprites+SORTED_NEXT,x
            tax

:entry
            jsr    _GetNextItem                   ; Get the first item from the list
            cpx    #EOL
            bne    :loop                          ; Exit if there are no more items

            sty    ObjectListCount
            rts

_DrawObjShadow
:top        equ    tmp8
:bottom     equ    tmp9

            ldy    #0
            cpy    ObjectListCount                ; Exit if the list of objects is empty
            beq    :exit

; Initialize with the record

            ldx    ObjectList+OL_INDEX,y

:loop
            lda    _Sprites+SPRITE_CLIP_TOP,x     ; Get the top scanline
            sta    :top
            lda    _Sprites+SPRITE_CLIP_BOTTOM,x
:skip       sta    :bottom

; Advance to the next record.

            iny
            iny
            cpy    ObjectListCount                ; Is this the last item
            beq    :done

; Check to see if the two items overlap

            ldx    ObjectList+OL_INDEX,y
            cmp    _Sprites+SPRITE_CLIP_TOP,x     ; Compare to the top line of the next item
            bcc    :no_merge

            max    _Sprites+SPRITE_CLIP_BOTTOM,x  ; Keep the largest of the two bottom values
            bra    :skip

:no_merge 
            phx
            phy
            ldx    :top
            ldy    :bottom
            jsr    _BltRange
            ply
            plx
            bra    :loop
:exit
            rts

:done
            ldx    :top                           ; X = top line
            ldy    :bottom                        ; Y = bottom line
            jmp    _BltRange                      ; If so, draw the background and return

;:loop
; Check if the current node and the next node are both sprites and, if they overlap, merge their ranges
;            lda    _Sprites+SPRITE_ID,x
;            ora    ObjectList+OL_SPRITE_ID,y
;            and    #SPRITE_OVERLAY
;            bne    :no_merge;

;            lda    ObjectList+OL_CLIP_BOTTOM,y
;            cmp    _Sprites+SPRITE_CLIP_TOP,x
;            bcc    :no_merge

;            lda    _Sprites+SPRITE_CLIP_BOTTOM,x
;            max    ObjectList+OL_CLIP_BOTTOM,y
;            sta    ObjectList+OL_CLIP_BOTTOM,y
;            bra    :skip

;:no_merge
;            iny
;            iny
;            tya
;            sta    ObjectList+OL_NEXT-2,y         ; Store link to this record in the previous node

;:entry
;            lda    _Sprites+SPRITE_ID,x
;            sta    ObjectList+OL_SPRITE_ID,y
;            lda    _Sprites+SPRITE_CLIP_TOP,x
;            sta    ObjectList+OL_CLIP_TOP,y
;            lda    _Sprites+SPRITE_CLIP_BOTTOM,x
;            sta    ObjectList+OL_CLIP_BOTTOM,y

;:skip
;            lda    _Sprites+SORTED_NEXT,x         ; Advance to the next source item
;            tax
;            jsr    _GetNextItem                   ; Get the first item from the list
;            cpx    #EOL
;            bne    :loop                          ; Exit if there are no valid entries

;:exit
;            lda    #EOL                           ; End-of-list marker
;            sta    ObjectList+OL_NEXT,y
;:empty
;            rts

; Helper function to only return object from the sorted list if they are relevant for
; display.
_GetNextItem
            cpx    #EOL                     ; early out if we're at the end of the list
            bne    *+3
            rts

            lda    _Sprites+SPRITE_ID,x     ; always return overlays
            bit    #SPRITE_OVERLAY
            beq    *+3
            rts

            bit    #SPRITE_HIDE             ; skip hidden sprites
            bne    :next
            lda    _Sprites+IS_OFF_SCREEN,x ; skip off-screen sprites
            bne    :next

            rts                             ; found an object to return
:next
            lda    _Sprites+SORTED_NEXT,x
            tax
            bra    _GetNextItem

DrawOverlayY
            phx
            phy

            txy                          ; Swap X/Y
            plx
            phx
            jsr   _DrawOverlay

            ply
            plx
            rts

; A = top line
; X = sprite record
; Y = bottom line
_DrawOverlay
            pha
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
            plx
:disp       jsl   $000000
            rts

; Helper to set a palette index on a range of SCBs to help show which actions are applied to which lines
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


