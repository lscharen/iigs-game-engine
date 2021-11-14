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

            nop
            jsr   _RenderSprites      ; Once the BG0 X and Y positions are committed, update sprite data
            nop

            jsr   _UpdateBG0TileMap   ; and the tile maps.  These subroutines build up a list of tiles
            jsr   _UpdateBG1TileMap   ; that need to be updated in the code field

            jsr   _ApplyTiles         ; This function actually draws the new tiles into the code field

            jsr   _ApplyBG0XPos       ; Patch the code field instructions with exit BRA opcode
            jsr   _ApplyBG1XPos       ; Update the direct page value based on the horizontal position

; The code fields are locked in now and ready to be rendered

            jsr   _ShadowOff

; Shadowing is turned off. Render all of the scan lines that need a second pass. One
; optimization that can be done here is that the lines can be rendered in any order
; since it is not shown on-screen yet.

            ldx   #0                  ; Blit the full virtual buffer to the screen
            ldy   #8
            jsr   _BltRange

; Turn shadowing back on

            jsr   _ShadowOn

; Now render all of the remaining lines in top-to-bottom (or bottom-to-top) order

            lda   ScreenY0             ; pass the address of the first line of the overlay
            clc
            adc   #0
            asl
            tax
            lda   ScreenAddr,x
            clc
            adc   ScreenX0
            jsl   Overlay

            ldx   #8                  ; Blit the full virtual buffer to the screen
            ldy   ScreenHeight
            jsr   _BltRange

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
            rts
