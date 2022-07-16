; Initialization and setup routines for the second background
_InitBG1
                          jsr   _ApplyBG1YPos
                          jsr   _ApplyBG1XPos
                          rts

; Copy a binary image data file into BG1.  Assumes the file is the correct size (328 x 208)
;
; A=low word of picture address
; X=high word of pixture address
; Y=high word of BG1 bank
_CopyBinToBG1
:src_width                equ   tmp6
:src_height               equ   tmp7

                          clc
                          adc   #8                        ; Advance over the header
                          pha

                          lda   #164
                          sta   :src_width
                          lda   #208
                          sta   :src_height

                          pla
                          jmp   _CopyToBG1


; Copy a IIgs $C1 picture into BG1.  Assumes the file is the correct size (320 x 200)
;
; A=low word of picture address
; X=high word of pixture address
; Y=high word of BG1 bank
_CopyPicToBG1
:src_width                equ   tmp6
:src_height               equ   tmp7
:src_stride               equ   tmp8

                          pha
                          lda    #160
                          sta    :src_width
                          sta    :src_stride
                          lda    #200
                          sta    :src_height
                          pla
                          jmp    _CopyToBG1

; Generic routine to copy image data into BG1
_CopyToBG1
:srcptr                   equ   tmp0
:line_cnt                 equ   tmp2
:dstptr                   equ   tmp3
:col_cnt                  equ   tmp5
:src_width                equ   tmp6
:src_height               equ   tmp7
:src_stride               equ   tmp8

                          sta   :srcptr
                          stx   :srcptr+2
                          sty   :dstptr+2                 ; Everything goes into this bank

                          stz   :line_cnt
:rloop
                          lda   :line_cnt                 ; get the pointer to the code field line
                          asl
                          tax

                          lda   BG1YTable,x
                          sta   :dstptr

                          ldy   #0                        ; move forward in the image data and image data
:cloop
                          lda   [:srcptr],y
                          sta   [:dstptr],y

                          iny
                          iny

                          cpy   :src_width
                          bcc   :cloop

                          ldy   #164
                          lda   [:srcptr]                 ; Duplicate the last couple of words in the extra space at the end of the line
                          sta   [:dstptr],y

                          ldy   #2
                          lda   [:srcptr],y
                          ldy   #166
                          sta   [:dstptr],y

                          lda   :srcptr
                          clc
                          adc   :src_stride
                          sta   :srcptr

                          inc   :line_cnt
                          lda   :line_cnt
                          cmp   :src_height
                          bcc   :rloop
                          rts

_SetBG1XPos
                          cmp   BG1StartX
                          beq   :out                      ; Easy, if nothing changed, then nothing changes

                          ldx   BG1StartX                 ; Load the old value (but don't save it yet)
                          sta   BG1StartX                 ; Save the new position

                          lda   #DIRTY_BIT_BG1_X
                          tsb   DirtyBits                 ; Check if the value is already dirty, if so exit
                          bne   :out                      ; without overwriting the original value

                          stx   OldBG1StartX              ; First change, so preserve the value
:out                      rts

_SetBG1YPos
                          cmp   BG1StartY
                          beq   :out                      ; Easy, if nothing changed, then nothing changes

                          ldx   BG1StartY                 ; Load the old value (but don't save it yet)
                          sta   BG1StartY                 ; Save the new position

                          lda   #DIRTY_BIT_BG1_Y
                          tsb   DirtyBits                 ; Check if the value is already dirty, if so exit
                          bne   :out                      ; without overwriting the original value

                          stx   OldBG1StartY              ; First change, so preserve the value
:out                      rts


; Everytime either BG1 or BG0 X-position changes, we have to update the direct page values.  We 
; *could* do this by adjusting the since the address offset, but we have to change up to 200 values
; when the vertical position changes, and only 41 when the horizontal value changes.  Plus
; these are all direct page values
;
; Note: This routine can be optimized as an unrolled loop of PEI instructions
_ApplyBG1XPosPre
                          lda   BG1StartX                 ; This is the starting byte offset (0 - 163)
                          jsr   Mod164
                          sta   BG1StartXMod164
                          rts

_ApplyBG1XPos
                          lda   #162
                          sec
                          sbc   StartXMod164              ; Need to compensate for both BG0 and BG1 positions
                          bpl   *+6
                          clc
                          adc   #164
                          clc
                          adc   BG1StartXMod164
                          cmp   #164
                          bcc   *+5
                          sbc   #164
                          tay

                          phd                             ; save the direct page because we are going to switch to the
                          lda   BlitterDP                 ; blitter direct page space and fill in the addresses
                          tcd

                          ldx   #162
                          tya
:loop
                          sta   00,x                      ; store the value
                          dec
                          dec
                          bpl   :nowrap
                          clc
                          adc   #164

:nowrap
                          dex
                          dex
                          bpl   :loop
                          pld
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
                          inx
                          inx
                          cpx   #0
                          bne   :loop

                          plb
                          rts

; Everytime either BG1 or BG0 Y-position changes, we have to update the Y-register
; value in all of the code fields (within the visible screen)
_ApplyBG1YPos
:virt_line                equ   tmp0
:lines_left               equ   tmp1
:draw_count               equ   tmp2
:ytbl_idx                 equ   tmp3

                          phb                             ; Save the bank

                          lda   BG1StartY
                          jsr   Mod208
                          sta   BG1StartYMod208
                          sta   :ytbl_idx                 ; Start copying from the first entry in the table

                          lda   StartYMod208              ; This is the base line of the virtual screen
                          sta   :virt_line                ; Keep track of it

                          lda   ScreenHeight
                          sta   :lines_left

:loop
                          lda   :virt_line
                          asl
                          tax
                          ldal  BTableLow,x               ; Get the address of the first code field line
                          tay

                          sep   #$20
                          ldal  BTableHigh,x
                          pha                             ; push the bank on the stack
                          plb
                          rep   #$20

                          lda   :virt_line
                          and   #$000F
                          eor   #$FFFF
                          inc
                          clc
                          adc   #16
                          min   :lines_left

                          sta   :draw_count               ; Do this many lines
                          asl
                          tax

                          lda   RenderFlags
                          bit   #RENDER_BG1_HORZ_OFFSET   ; Are we using horizontal displacement?
                          beq   :no_displacement

                          lda   :ytbl_idx                 ; Read from this location in the BG1YTable
                          asl
                          jsr   CopyBG1YTableToBG1Addr2
                          bra   :next_step

:no_displacement
                          lda   :ytbl_idx                 ; Read from this location in the BG1YTable
                          asl
                          jsr   CopyBG1YTableToBG1Addr    ; or CopyBG1YTableToBG1Addr2

:next_step
                          lda   :virt_line                ; advance to the virtual line after the segment we just
                          clc                             ; filled in
                          adc   :draw_count
                          sta   :virt_line

                          lda   :ytbl_idx                 ; advance the index into the YTable
                          adc   :draw_count
                          sta   :ytbl_idx

                          lda   :lines_left               ; subtract the number of lines we just completed
                          sec
                          sbc   :draw_count
                          sta   :lines_left

                          jne   :loop

                          plb
                          rts

; Unrolled copy routine to move BG1YTable entries into BG1_ADDR position.
;
; A = index into the BG1YTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyBG1YTableToBG1Addr
                          jmp   (:tbl,x)
:tbl                      da    :none
                          da    :do01,:do02,:do03,:do04
                          da    :do05,:do06,:do07,:do08
                          da    :do09,:do10,:do11,:do12
                          da    :do13,:do14,:do15,:do16
:do15                     tax
                          bra   :x15
:do14                     tax
                          bra   :x14
:do13                     tax
                          bra   :x13
:do12                     tax
                          bra   :x12
:do11                     tax
                          bra   :x11
:do10                     tax
                          bra   :x10
:do09                     tax
                          bra   :x09
:do08                     tax
                          bra   :x08
:do07                     tax
                          bra   :x07
:do06                     tax
                          bra   :x06
:do05                     tax
                          bra   :x05
:do04                     tax
                          bra   :x04
:do03                     tax
                          bra   :x03
:do02                     tax
                          bra   :x02
:do01                     tax
                          bra   :x01
:do16                     tax
                          ldal  BG1YTable+30,x
                          sta   BG1_ADDR+$F000,y
:x15                      ldal  BG1YTable+28,x
                          sta   BG1_ADDR+$E000,y
:x14                      ldal  BG1YTable+26,x
                          sta   BG1_ADDR+$D000,y
:x13                      ldal  BG1YTable+24,x
                          sta   BG1_ADDR+$C000,y
:x12                      ldal  BG1YTable+22,x
                          sta   BG1_ADDR+$B000,y
:x11                      ldal  BG1YTable+20,x
                          sta   BG1_ADDR+$A000,y
:x10                      ldal  BG1YTable+18,x
                          sta   BG1_ADDR+$9000,y
:x09                      ldal  BG1YTable+16,x
                          sta   BG1_ADDR+$8000,y
:x08                      ldal  BG1YTable+14,x
                          sta   BG1_ADDR+$7000,y
:x07                      ldal  BG1YTable+12,x
                          sta   BG1_ADDR+$6000,y
:x06                      ldal  BG1YTable+10,x
                          sta   BG1_ADDR+$5000,y
:x05                      ldal  BG1YTable+08,x
                          sta:  BG1_ADDR+$4000,y
:x04                      ldal  BG1YTable+06,x
                          sta   BG1_ADDR+$3000,y
:x03                      ldal  BG1YTable+04,x
                          sta   BG1_ADDR+$2000,y
:x02                      ldal  BG1YTable+02,x
                          sta   BG1_ADDR+$1000,y
:x01                      ldal  BG1YTable+00,x
                          sta:  BG1_ADDR+$0000,y
:none                     rts

; Unrolled copy routine to move BG1YTable entries into BG1_ADDR position with an additional
; shift.  This has to be split into two 
;
; A = index into the BG1YTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyBG1YTableToBG1Addr2
                          phy                             ; save the registers
                          phx
                          phb
                          pha
                          jsr   _SetDataBank              ; Set to toolbox data bank

                          pla
                          ldy   BG1OffsetIndex            ; Get the offset and save the values
                          jsr   SaveBG1OffsetValues

                          plb
                          plx                             ; x is used directly in this routine
                          ply
                          jmp   ApplyBG1OffsetValues

SaveBG1OffsetValues
                          jmp   (:tbl,x)
:tbl                      da    :none
                          da    :do01,:do02,:do03,:do04
                          da    :do05,:do06,:do07,:do08
                          da    :do09,:do10,:do11,:do12
                          da    :do13,:do14,:do15,:do16
:do15                     tax
                          bra   :x15
:do14                     tax
                          bra   :x14
:do13                     tax
                          bra   :x13
:do12                     tax
                          bra   :x12
:do11                     tax
                          bra   :x11
:do10                     tax
                          bra   :x10
:do09                     tax
                          bra   :x09
:do08                     tax
                          bra   :x08
:do16                     tax
                          lda   BG1YTable+30,x
                          adc   BG1YOffsetTable+30,y
                          sta   BG1YCache+30
:x15                      lda   BG1YTable+28,x
                          adc   BG1YOffsetTable+28,y
                          sta   BG1YCache+28
:x14                      lda   BG1YTable+26,x
                          adc   BG1YOffsetTable+26,y
                          sta   BG1YCache+26
:x13                      lda   BG1YTable+24,x
                          adc   BG1YOffsetTable+24,y
                          sta   BG1YCache+24
:x12                      lda   BG1YTable+22,x
                          adc   BG1YOffsetTable+22,y
                          sta   BG1YCache+22
:x11                      lda   BG1YTable+20,x
                          adc   BG1YOffsetTable+20,y
                          sta   BG1YCache+20
:x10                      lda   BG1YTable+18,x
                          adc   BG1YOffsetTable+18,y
                          sta   BG1YCache+18
:x09                      lda   BG1YTable+16,x
                          adc   BG1YOffsetTable+16,y
                          sta   BG1YCache+16
:x08                      lda   BG1YTable+14,x
                          adc   BG1YOffsetTable+14,y
                          sta   BG1YCache+14
:x07                      lda   BG1YTable+12,x
                          adc   BG1YOffsetTable+12,y
                          sta   BG1YCache+12
:x06                      lda   BG1YTable+10,x
                          adc   BG1YOffsetTable+10,y
                          sta   BG1YCache+10
:x05                      lda   BG1YTable+08,x
                          adc   BG1YOffsetTable+08,y
                          sta   BG1YCache+08
:x04                      lda   BG1YTable+06,x
                          adc   BG1YOffsetTable+06,y
                          sta   BG1YCache+06
:x03                      lda   BG1YTable+04,x
                          adc   BG1YOffsetTable+04,y
                          sta   BG1YCache+04
:x02                      lda   BG1YTable+02,x
                          adc   BG1YOffsetTable+02,y
                          sta   BG1YCache+02
:x01                      lda   BG1YTable+00,x
                          adc   BG1YOffsetTable+00,y
                          sta   BG1YCache+00
:none                     rts
:do07                     tax
                          bra   :x07
:do06                     tax
                          bra   :x06
:do05                     tax
                          bra   :x05
:do04                     tax
                          bra   :x04
:do03                     tax
                          bra   :x03
:do02                     tax
                          bra   :x02
:do01                     tax
                          bra   :x01


ApplyBG1OffsetValues
                          jmp   (:tbl,x)
:tbl                      da    :none
                          da    :do01,:do02,:do03,:do04
                          da    :do05,:do06,:do07,:do08
                          da    :do09,:do10,:do11,:do12
                          da    :do13,:do14,:do15,:do16
:do16                     ldal  BG1YCache+30
                          sta   BG1_ADDR+$F000,y
:do15                     ldal  BG1YCache+28
                          sta   BG1_ADDR+$E000,y
:do14                     ldal  BG1YCache+26
                          sta   BG1_ADDR+$D000,y
:do13                     ldal  BG1YCache+24
                          sta   BG1_ADDR+$C000,y
:do12                     ldal  BG1YCache+22
                          sta   BG1_ADDR+$B000,y
:do11                     ldal  BG1YCache+20
                          sta   BG1_ADDR+$A000,y
:do10                     ldal  BG1YCache+18
                          sta   BG1_ADDR+$9000,y
:do09                     ldal  BG1YCache+16
                          sta   BG1_ADDR+$8000,y
:do08                     ldal  BG1YCache+14
                          sta   BG1_ADDR+$7000,y
:do07                     ldal  BG1YCache+12
                          sta   BG1_ADDR+$6000,y
:do06                     ldal  BG1YCache+10
                          sta   BG1_ADDR+$5000,y
:do05                     ldal  BG1YCache+08
                          sta:  BG1_ADDR+$4000,y
:do04                     ldal  BG1YCache+06
                          sta   BG1_ADDR+$3000,y
:do03                     ldal  BG1YCache+04
                          sta   BG1_ADDR+$2000,y
:do02                     ldal  BG1YCache+02
                          sta   BG1_ADDR+$1000,y
:do01                     ldal  BG1YCache+00
                          sta:  BG1_ADDR+$0000,y
:none                     rts