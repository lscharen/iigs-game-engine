; Subroutines that deal with the vertical scrolling and rendering.  The primary function
; of these routines are to adjust tables and patch in new values into the code field
; when the virtual Y-position of the play field changes.


; SetBG0YPos
;
; Set the virtual position of the primary background layer.  In addition to 
; updating the direct page state locations, this routine needs to
SetBG0YPos
                     cmp   StartY
                     beq   :out                 ; Easy, if nothing changed, then nothing changes

                     ldx   StartY               ; Load the old value (but don't save it yet)
                     sta   StartY               ; Save the new position

                     lda   #DIRTY_BIT_BG0_Y
                     tsb   DirtyBits            ; Check if the value is already dirty, if so exit
                     bne   :out                 ; without overwriting the original value

                     stx   OldStartY            ; First change, so preserve the value
:out                 rts

; Based on the current value of StartY in the direct page.  Set up the dispatch
; information so that the BltRange driver will render the correct code field
; lines in the correct order
_ApplyBG0YPos

:rtbl_idx            equ   tmp0
:virt_line           equ   tmp1
:lines_left          equ   tmp2
:draw_count          equ   tmp3

; First task is to fill in the STK_ADDR values by copying them from the RTable array.  We
; copy from RTable[i] into BlitField[StartY+i].  As with all of this code, the difficult part
; is decomposing the update across banks

                     stz   :rtbl_idx            ; Start copying from the first entry in the table

                     lda   StartY               ; This is the base line of the virtual screen
                     sta   :virt_line           ; Keep track of it

; copy a range of address from the table into the destination bank. If we restrict ourselves to
; rectangular playfields, this can be optimized to just subtracting a constant value.  See the 
; Templates::SetScreenAddrs subroutine.

                     lda   ScreenHeight
                     sta   :lines_left

; This is the verbose part -- figure out how many lines to draw.  We don't want to artificially limit
; the height of the visible screen (for example, doing an animated wipe while scrolling), so the screen
; height could be anything from 1 to 200.
;
; For larger values, we want to break things up on 16-line boundaries based on the virt_line value. So,
;
; draw_count = min(lines_left, (16 - (virt_line % 16))
;
; Note that almost everything in this loop can be done with 8-bit operations sincc the values are
; all under 200.  The one exception is the virt_line value which could exceed 256.  This will be
; a later optimization and might save around 10 cycles per iteration, or up to ~120 cycles per frame
; and ~2,500 per secord.  This is ~1% of our total CPU budget and is *just* enough cycles to be
; interesting.... Another 8 cycles could be removed by doing all calculatinos pre-multiplied by 2
; to avoid several 'asl' instructions
:loop
                     lda   :virt_line
                     asl
                     tax
                     ldal  BTableLow,x          ; Get the address of the first code field line
                     tay

                     sep   #$20
                     ldal  BTableHigh,x
                     pha
                     plb                        ; This is the bank that will receive the updates
                     rep   #$20

                     lda   :virt_line
                     and   #$000F
                     eor   #$FFFF
                     inc
                     clc
                     adc   #16
                     min   :lines_left

                     sta   :draw_count          ; Do this many lines
                     asl
                     tax

                     lda   :rtbl_idx            ; Read from this location in the RTable
                     asl

                     jsr   CopyRTableToStkAddr

                     lda   :virt_line           ; advance to the virtual line after the segment we just
                     clc                        ; filled in
                     adc   :draw_count
                     sta   :virt_line

                     lda   :rtbl_idx            ; advance the index into the RTable
                     adc   :draw_count
                     sta   :rtbl_idx

                     lda   :lines_left          ; subtract the number of lines we just completed
                     sec
                     sbc   :draw_count
                     sta   :lines_left

                     jne   :loop

                     phk
                     plb
                     rts

; Unrolled copy routine to move RTable intries into STK_ADDR position.  
;
; A = intect into the RTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyRTableToStkAddr
                     jmp   (:tbl,x)
:tbl                 da    :none
                     da    :do01,:do02,:do03,:do04
                     da    :do05,:do06,:do07,:do08
                     da    :do09,:do10,:do11,:do12
                     da    :do13,:do14,:do15,:do16
:do15                tax
                     bra   :x15
:do14                tax
                     bra   :x14
:do13                tax
                     bra   :x13
:do12                tax
                     bra   :x12
:do11                tax
                     bra   :x11
:do10                tax
                     bra   :x10
:do09                tax
                     bra   :x09
:do08                tax
                     bra   :x08
:do07                tax
                     bra   :x07
:do06                tax
                     bra   :x06
:do05                tax
                     bra   :x05
:do04                tax
                     bra   :x04
:do03                tax
                     bra   :x03
:do02                tax
                     bra   :x02
:do01                tax
                     bra   :x01
:do16                tax
                     ldal  RTable+30,x
                     sta   STK_ADDR+$F000,y
:x15                 ldal  RTable+28,x
                     sta   STK_ADDR+$E000,y
:x14                 ldal  RTable+26,x
                     sta   STK_ADDR+$D000,y
:x13                 ldal  RTable+24,x
                     sta:  STK_ADDR+$C000,y
:x12                 ldal  RTable+22,x
                     sta   STK_ADDR+$B000,y
:x11                 ldal  RTable+20,x
                     sta   STK_ADDR+$A000,y
:x10                 ldal  RTable+18,x
                     sta   STK_ADDR+$9000,y
:x09                 ldal  RTable+16,x
                     sta:  STK_ADDR+$8000,y
:x08                 ldal  RTable+14,x
                     sta   STK_ADDR+$7000,y
:x07                 ldal  RTable+12,x
                     sta   STK_ADDR+$6000,y
:x06                 ldal  RTable+10,x
                     sta   STK_ADDR+$5000,y
:x05                 ldal  RTable+08,x
                     sta:  STK_ADDR+$4000,y
:x04                 ldal  RTable+06,x
                     sta   STK_ADDR+$3000,y
:x03                 ldal  RTable+04,x
                     sta   STK_ADDR+$2000,y
:x02                 ldal  RTable+02,x
                     sta   STK_ADDR+$1000,y
:x01                 ldal  RTable+00,x
                     sta:  STK_ADDR+$0000,y
:none                rts

