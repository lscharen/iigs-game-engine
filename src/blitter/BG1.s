; Initialization and setup routines for the second background
_InitBG1
                         jsr   _ApplyBG1YPos
                         jsr   _ApplyBG1XPos
                         rts

SetBG1XPos
                         cmp   BG1StartX
                         beq   :out                    ; Easy, if nothing changed, then nothing changes

                         ldx   BG1StartX               ; Load the old value (but don't save it yet)
                         sta   BG1StartX               ; Save the new position

                         lda   #DIRTY_BIT_BG1_X
                         tsb   DirtyBits               ; Check if the value is already dirty, if so exit
                         bne   :out                    ; without overwriting the original value

                         stx   OldBG1StartX            ; First change, so preserve the value
:out                     rts


SetBG1YPos
                         cmp   BG1StartY
                         beq   :out                    ; Easy, if nothing changed, then nothing changes

                         ldx   BG1StartY               ; Load the old value (but don't save it yet)
                         sta   BG1StartY               ; Save the new position

                         lda   #DIRTY_BIT_BG1_Y
                         tsb   DirtyBits               ; Check if the value is already dirty, if so exit
                         bne   :out                    ; without overwriting the original value

                         stx   OldBG1StartY            ; First change, so preserve the value
:out                     rts


; Everytime either BG1 or BG0 X-position changes, we have to update the direct page values.  We 
; *could* do this by adjusting the since address offset, but we have to change up to 200 values
; when the vertical position changes, and only 41 when the horizontal value changes.  Plus
; these are all direct page values
;
; Note: This routine can be optimized as an unrolled loop of PEI instructions
_ApplyBG1XPos
                         lda   BG1StartX
                         jsr   Mod164
                         sta   BG1StartXMod164

                         lda   #162
                         sec
                         sbc   StartXMod164
                         bpl   *+6
                         clc
                         adc   #164
                         clc
                         adc   BG1StartXMod164
                         cmp   #164
                         bcc   *+5
                         sbc   #164
                         tay

                         phd                           ; save the direct page because we are going to switch to the
                         lda   BlitterDP               ; blitter direct page space and fill in the addresses
                         tcd

                         ldx   #162
:loop
                         tya
                         clc
                         adc   affine,x
                         sta   00,x                    ; store the value
                         dey
                         dey
                         bpl   :nowrap
                         tya
                         clc
                         adc   #164
                         tay

:nowrap
                         dex
                         dex
                         bpl   :loop
                         pld
                         rts

affine                   ds    164

; Pass accumulator to set every (A / 256) pitch
SetAffine
                         ldx   #0
                         ldy   #0
                         and   #$00FF
                         pha                           ; step size
                         pea   $0000

:loop                    lda   1,s
                         clc
                         adc   3,s
                         cmp   #256
                         bcc   :skip
                         tya
                         clc
                         adc   #256                    ; Move to next BG1 line
                         tay

:skip                    and   #$00FF                  ; always clamp to 256
                         sta   1,s

                         tya
                         sta   affine,x
                         inx
                         inx
                         cpx   #164
                         bcc   :loop

                         pla
                         pla
                         rts

_ClearBG1Buffer
                         phb
                         pha
                         sep   #$20
                         lda   BG1DataBank
                         pha
                         plb
                         rep   #$20

                         pla
                         ldx   #0
:loop
                         sta:  $0000,x
                         inc
                         inx
                         inx
                         cpx   #0
                         bne   :loop

                         plb
                         rts

; Everytime either BG1 or BG0 Y-position changes, we have to update the Y-register
; value in all of the code fields (within the visible screen)
_ApplyBG1YPos
:virt_line               equ   tmp0
:lines_left              equ   tmp1
:draw_count              equ   tmp2
:ytbl_idx                equ   tmp3

                         lda   BG1StartY
                         jsr   Mod208
                         sta   BG1StartYMod208
                         sta   :ytbl_idx               ; Start copying from the first entry in the table

                         lda   StartYMod208            ; This is the base line of the virtual screen
                         sta   :virt_line              ; Keep track of it

                         lda   ScreenHeight
                         sta   :lines_left

:loop
                         lda   :virt_line
                         asl
                         tax
                         ldal  BTableLow,x             ; Get the address of the first code field line
                         tay

                         sep   #$20
                         ldal  BTableHigh,x
                         pha
                         plb                           ; This is the bank that will receive the updates
                         rep   #$20

                         lda   :virt_line
                         and   #$000F
                         eor   #$FFFF
                         inc
                         clc
                         adc   #16
                         min   :lines_left

                         sta   :draw_count             ; Do this many lines
                         asl
                         tax

                         lda   :ytbl_idx               ; Read from this location in the BG1YTable
                         asl
                         jsr   CopyBG1YTableToBG1Addr

                         lda   :virt_line              ; advance to the virtual line after the segment we just
                         clc                           ; filled in
                         adc   :draw_count
                         sta   :virt_line

                         lda   :ytbl_idx               ; advance the index into the YTable
                         adc   :draw_count
                         sta   :ytbl_idx

                         lda   :lines_left             ; subtract the number of lines we just completed
                         sec
                         sbc   :draw_count
                         sta   :lines_left

                         jne   :loop

                         phk
                         plb
                         rts

; Unrolled copy routine to move BG1YTable entries into BG1_ADDR position.
;
; A = index into the BG1YTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyBG1YTableToBG1Addr
                         jmp   (:tbl,x)
:tbl                     da    :none
                         da    :do01,:do02,:do03,:do04
                         da    :do05,:do06,:do07,:do08
                         da    :do09,:do10,:do11,:do12
                         da    :do13,:do14,:do15,:do16
:do15                    tax
                         bra   :x15
:do14                    tax
                         bra   :x14
:do13                    tax
                         bra   :x13
:do12                    tax
                         bra   :x12
:do11                    tax
                         bra   :x11
:do10                    tax
                         bra   :x10
:do09                    tax
                         bra   :x09
:do08                    tax
                         bra   :x08
:do07                    tax
                         bra   :x07
:do06                    tax
                         bra   :x06
:do05                    tax
                         bra   :x05
:do04                    tax
                         bra   :x04
:do03                    tax
                         bra   :x03
:do02                    tax
                         bra   :x02
:do01                    tax
                         bra   :x01
:do16                    tax
                         ldal  BG1YTable+30,x
                         sta   BG1_ADDR+$F000,y
:x15                     ldal  BG1YTable+28,x
                         sta   BG1_ADDR+$E000,y
:x14                     ldal  BG1YTable+26,x
                         sta   BG1_ADDR+$D000,y
:x13                     ldal  BG1YTable+24,x
                         sta   BG1_ADDR+$C000,y
:x12                     ldal  BG1YTable+22,x
                         sta   BG1_ADDR+$B000,y
:x11                     ldal  BG1YTable+20,x
                         sta   BG1_ADDR+$A000,y
:x10                     ldal  BG1YTable+18,x
                         sta   BG1_ADDR+$9000,y
:x09                     ldal  BG1YTable+16,x
                         sta   BG1_ADDR+$8000,y
:x08                     ldal  BG1YTable+14,x
                         sta   BG1_ADDR+$7000,y
:x07                     ldal  BG1YTable+12,x
                         sta   BG1_ADDR+$6000,y
:x06                     ldal  BG1YTable+10,x
                         sta   BG1_ADDR+$5000,y
:x05                     ldal  BG1YTable+08,x
                         sta:  BG1_ADDR+$4000,y
:x04                     ldal  BG1YTable+06,x
                         sta   BG1_ADDR+$3000,y
:x03                     ldal  BG1YTable+04,x
                         sta   BG1_ADDR+$2000,y
:x02                     ldal  BG1YTable+02,x
                         sta   BG1_ADDR+$1000,y
:x01                     ldal  BG1YTable+00,x
                         sta:  BG1_ADDR+$0000,y
:none                    rts

; Unrolled copy routine to move BG1YTable entries into BG1_ADDR position with an additional
; shift
;
; A = index into the BG1YTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyBG1YTableToBG1Addr2
                         jmp   (:tbl,x)
:tbl                     da    :none
                         da    :do01,:do02,:do03,:do04
                         da    :do05,:do06,:do07,:do08
                         da    :do09,:do10,:do11,:do12
                         da    :do13,:do14,:do15,:do16
:do15                    tax
                         bra   :x15
:do14                    tax
                         bra   :x14
:do13                    tax
                         bra   :x13
:do12                    tax
                         bra   :x12
:do11                    tax
                         bra   :x11
:do10                    tax
                         bra   :x10
:do09                    tax
                         bra   :x09
:do08                    tax
                         bra   :x08
:do16                    tax
                         ldal  BG1YTable+30,x
                         adcl  BG1YOffsetTable+30,x
                         sta   BG1_ADDR+$F000,y
:x15                     ldal  BG1YTable+28,x
                         adcl  BG1YOffsetTable+28,x
                         sta   BG1_ADDR+$E000,y
:x14                     ldal  BG1YTable+26,x
                         adcl  BG1YOffsetTable+26,x
                         sta   BG1_ADDR+$D000,y
:x13                     ldal  BG1YTable+24,x
                         adcl  BG1YOffsetTable+24,x
                         sta   BG1_ADDR+$C000,y
:x12                     ldal  BG1YTable+22,x
                         adcl  BG1YOffsetTable+22,x
                         sta   BG1_ADDR+$B000,y
:x11                     ldal  BG1YTable+20,x
                         adcl  BG1YOffsetTable+20,x
                         sta   BG1_ADDR+$A000,y
:x10                     ldal  BG1YTable+18,x
                         adcl  BG1YOffsetTable+18,x
                         sta   BG1_ADDR+$9000,y
:x09                     ldal  BG1YTable+16,x
                         adcl  BG1YOffsetTable+16,x
                         sta   BG1_ADDR+$8000,y
:x08                     ldal  BG1YTable+14,x
                         adcl  BG1YOffsetTable+14,x
                         sta   BG1_ADDR+$7000,y
:x07                     ldal  BG1YTable+12,x
                         adcl  BG1YOffsetTable+12,x
                         sta   BG1_ADDR+$6000,y
:x06                     ldal  BG1YTable+10,x
                         adcl  BG1YOffsetTable+10,x
                         sta   BG1_ADDR+$5000,y
:x05                     ldal  BG1YTable+08,x
                         adcl  BG1YOffsetTable+08,x
                         sta:  BG1_ADDR+$4000,y
:x04                     ldal  BG1YTable+06,x
                         adcl  BG1YOffsetTable+06,x
                         sta   BG1_ADDR+$3000,y
:x03                     ldal  BG1YTable+04,x
                         adcl  BG1YOffsetTable+04,x
                         sta   BG1_ADDR+$2000,y
:x02                     ldal  BG1YTable+02,x
                         adcl  BG1YOffsetTable+02,x
                         sta   BG1_ADDR+$1000,y
:x01                     ldal  BG1YTable+00,x
                         adcl  BG1YOffsetTable+00,x
                         sta:  BG1_ADDR+$0000,y
:none                    rts
:do07                    tax
                         bra   :x07
:do06                    tax
                         bra   :x06
:do05                    tax
                         bra   :x05
:do04                    tax
                         bra   :x04
:do03                    tax
                         bra   :x03
:do02                    tax
                         bra   :x02
:do01                    tax
                         bra   :x01









































































