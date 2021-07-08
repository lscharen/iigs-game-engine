; Subroutines that deal with the vertical scrolling and rendering.  The primary function
; of these routines are to adjust tables and patch in new values into the code field
; when the virtual Y-position of the play field changes.


; SetBG0YPos
;
; Set the virtual position of the primary background layer.  In addition to 
; updating the direct page state locations, this routine needs to
SetBG0YPos
               cmp   StartY
               beq   :nochange
               sta   StartY            ; Save the position
               lda   #DIRTY_BIT_BG0_Y  ; Mark that it has changed
               tsb   DirtyBits
:nochange
               rts

; Based on the current value of StartY in the direct page.  Set up the dispatch
; information so that the BltDispatch driver will render the correct code field
; lines in the the correct order
_ApplyBG0YPos



