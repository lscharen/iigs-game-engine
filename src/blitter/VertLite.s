; Subroutines that deal with the vertical scrolling and rendering.  The primary function
; of these routines are to adjust tables and patch in new values into the code field
; when the virtual Y-position of the play field changes.
_ApplyBG0YPosPreLite
                     lda   StartY               ; This is the base line of the virtual screen
                     jsr   Mod208
                     sta   StartYMod208
                     rts

_ApplyBG0YPosLite

:virt_line_x2        equ   tmp1
:lines_left_x2       equ   tmp2

; First task is to fill in the STK_ADDR values by copying them from the RTable array.  We
; copy from RTable[i] into BlitField[StartY+i].

                     lda   ScreenHeight
                     asl
                     sta   :lines_left_x2

                     lda   StartYMod208
                     asl
                     sta   :virt_line_x2        ; Keep track of it

                     lda   #0

_ApplyBG0YPosAltLite
:rtbl_idx_x2         equ   tmp0
:virt_line_x2        equ   tmp1
:lines_left_x2       equ   tmp2
:draw_count_x2       equ   tmp3

; Check to see if we need to split the update into two parts, e.g. do we wrap around the end
; of the code field?
                     sta   :rtbl_idx_x2

                     ldx   :lines_left_x2
                     lda   #208*2
                     sec
                     sbc   :virt_line_x2              ; calculate number of lines to the end of the buffer
                     cmp   :lines_left_x2
                     bcs   :one_pass                  ; if there's room, do it in one shot

                     tax                              ; Only do this many lines right now (saved to draw_count_x2)
                     jsr   :one_pass                  ; Go through with this draw count

                     stz   :virt_line_x2              ; virtual line is at the top (by construction)

                     lda   :rtbl_idx_x2
                     clc
                     adc   :draw_count_x2
                     sta   :rtbl_idx_x2

                     lda   :lines_left_x2
                     sec
                     sbc   :draw_count_x2              ; this many left to draw. Fall through to finish up
                     tax

; Set up the addresses for filling in the code field
:one_pass
                     stx   :draw_count_x2

                     phb                             ; Save the current bank

                     ldx   :virt_line_x2
                     lda   BTableLow,x                ; Get the address of the first code field line
                     tay
                     iny                              ; Fill in the first byte (_ENTRY_1 = 0)

                     ldx   :rtbl_idx_x2               ; Load the stack address from here

                     sep   #$20                       ; Set the data bank to the code field
                     lda   BTableHigh
                     pha
                     plb
                     rep   #$21                       ; clear the carry while we're here...

                     lda   :draw_count_x2             ; Do this many lines
                     asl                              ; x4
                     asl                              ; x8
                     asl                              ; x16
                     sec
                     sbc   :draw_count_x2             ; x14
                     lsr                              ; x7
                     eor   #$FFFF
                     sec
                     adc   #:bottom
                     stal  :entry+1                   ; patch in the dispatch address

; This is an inline, unrolled version of CopyRTableToStkAddr
:entry               jmp   $0000
]line                equ   199
                     lup   200
                     ldal  RTable+{]line*2},x
                     sta   {]line*_LINE_SIZE},y
]line                equ   ]line-1
                     --^
:bottom
                     plb
                     rts
