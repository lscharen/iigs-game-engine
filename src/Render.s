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
Render

; TODO -- actually check the dirty bits and be selective on what gets updated.  For example, if
;         only the Y position changes, then we should only need to set new values on the 
;         virtual lines that were brought on screen.  If the X position only changes by one
;         byte, then we may have to change the CODE_ENTRY values or restore/set new OPCODE
;         values, but not both.

            jsr   ShadowOff
            jsr   ShadowOn

; It's important to do _ApplyBG0YPos first because it calculates the value of StartY % 208 which is
; used in all of the other loops

            jsr   _ApplyBG0YPos       ; Set stack addresses for the virtual lines to the physical screen
            jsr   _ApplyBG0XPos       ; Patch the PEA instructions with exit BRA opcode
            jsr   _ApplyBG1YPos       ; Adjust the index values into the BG1 bank buffer
            jsr   _ApplyBG1XPos       ; Adjust the direct page pointers to the BG1 bank

            ldx   #0                  ; Blit the full virtual buffer to the screen
            ldy   ScreenHeight
            jsr   _BltRange

            lda   StartY              ; Restore the fields back to their original state
            ldx   ScreenHeight
            jsr   _RestoreBG0Opcodes

            rts














