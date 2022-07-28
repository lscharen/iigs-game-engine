; Subroutines that deal with the vertical scrolling and rendering.  The primary function
; of these routines are to adjust tables and patch in new values into the code field
; when the virtual Y-position of the play field changes.

; Based on the current value of StartY in the direct page.  Set up the dispatch
; information so that the BltRange driver will render the correct code field
; lines in the correct order
_ApplyBG0YPos

:rtbl_idx_x2         equ   tmp0
:virt_line_x2        equ   tmp1
:lines_left_x2       equ   tmp2
:draw_count_x2       equ   tmp3
:stk_save            equ   tmp4

; First task is to fill in the STK_ADDR values by copying them from the RTable array.  We
; copy from RTable[i] into BlitField[StartY+i].  As with all of this code, the difficult part
; is decomposing the update across banks

                     stz   :rtbl_idx_x2         ; Start copying from the first entry in the table

                     lda   StartY               ; This is the base line of the virtual screen
                     jsr   Mod208
                     sta   StartYMod208

                     asl
                     sta   :virt_line_x2        ; Keep track of it

                     phb                        ; Save the current bank
                     tsc                        ; we intentionally leak one byte of stack in each loop
                     sta   :stk_save            ; iteration, so save the stack to repair at the end

; copy a range of address from the table into the destination bank. If we restrict ourselves to
; rectangular playfields, this can be optimized to just subtracting a constant value.  See the 
; Templates::SetScreenAddrs subroutine.

                     lda   ScreenHeight
                     asl
                     sta   :lines_left_x2

; This is the verbose part -- figure out how many lines to draw.  We don't want to artificially limit
; the height of the visible screen (for example, doing an animated wipe while scrolling), so the screen
; height could be anything from 1 to 200.
;
; For larger values, we want to break things up on 16-line boundaries based on the virt_line value. So,
;
; draw_count = min(lines_left, (16 - (virt_line % 16))

:loop
                     ldx   :virt_line_x2
                     ldal  BTableLow,x          ; Get the address of the first code field line
                     tay

                     ldal  BTableHigh,x         ; Target bank in low byte, current bank in high
                     pha

                     txa
                     and   #$001E
                     eor   #$FFFF
                     sec
                     adc   #32
                     min   :lines_left_x2

                     sta   :draw_count_x2       ; Do this many lines
                     tax

                     clc                        ; pre-advance virt_line_2 because we have the value
                     adc   :virt_line_x2
                     sta   :virt_line_x2

                     plb
                     CopyRTableToStkAddr :rtbl_idx_x2    ; X = rtbl_idx_x2 on return

                     txa                        ; carry flag is unchanged
                     adc   :draw_count_x2       ; advance the index into the RTable
                     sta   :rtbl_idx_x2

                     lda   :lines_left_x2       ; subtract the number of lines we just completed
                     sec
                     sbc   :draw_count_x2
                     sta   :lines_left_x2

                     jne   :loop

                     lda   :stk_save
                     tcs
                     plb
                     rts

; Unrolled copy routine to move RTable intries into STK_ADDR position.  
;
; A = intect into the RTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyRTableToStkAddr  mac
                     jmp   (dispTbl,x)
dispTbl              da    bottom
                     da    do01,do02,do03,do04
                     da    do05,do06,do07,do08
                     da    do09,do10,do11,do12
                     da    do13,do14,do15,do16
do15                 ldx   ]1
                     bra   x15
do14                 ldx   ]1
                     bra   x14
do13                 ldx   ]1
                     bra   x13
do12                 ldx   ]1
                     bra   x12
do11                 ldx   ]1
                     bra   x11
do10                 ldx   ]1
                     bra   x10
do09                 ldx   ]1
                     bra   x09
do08                 ldx   ]1
                     bra   x08
do07                 ldx   ]1
                     bra   x07
do06                 ldx   ]1
                     bra   x06
do05                 ldx   ]1
                     bra   x05
do04                 ldx   ]1
                     bra   x04
do03                 ldx   ]1
                     bra   x03
do02                 ldx   ]1
                     bra   x02
do01                 ldx   ]1
                     bra   x01
do16                 ldx   ]1
                     ldal  RTable+30,x
                     sta   STK_ADDR+$F000,y
x15                  ldal  RTable+28,x
                     sta   STK_ADDR+$E000,y
x14                  ldal  RTable+26,x
                     sta   STK_ADDR+$D000,y
x13                  ldal  RTable+24,x
                     sta   STK_ADDR+$C000,y
x12                  ldal  RTable+22,x
                     sta   STK_ADDR+$B000,y
x11                  ldal  RTable+20,x
                     sta   STK_ADDR+$A000,y
x10                  ldal  RTable+18,x
                     sta   STK_ADDR+$9000,y
x09                  ldal  RTable+16,x
                     sta   STK_ADDR+$8000,y
x08                  ldal  RTable+14,x
                     sta   STK_ADDR+$7000,y
x07                  ldal  RTable+12,x
                     sta   STK_ADDR+$6000,y
x06                  ldal  RTable+10,x
                     sta   STK_ADDR+$5000,y
x05                  ldal  RTable+08,x
                     sta   STK_ADDR+$4000,y
x04                  ldal  RTable+06,x
                     sta   STK_ADDR+$3000,y
x03                  ldal  RTable+04,x
                     sta   STK_ADDR+$2000,y
x02                  ldal  RTable+02,x
                     sta   STK_ADDR+$1000,y
x01                  ldal  RTable+00,x
                     sta:  STK_ADDR+$0000,y
bottom
                     <<<