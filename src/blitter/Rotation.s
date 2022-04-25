; Support rotating the BG1 graphics by leveraging the fact that a rotation function can be decomposed
; into an addition of two function parametertized by the angle of rotation: pixel = *(f(x, a) + f(y, a))
;
; The pre-build a number of rotation tables and then populate the direct page values and Y-register values
; for each line of the blitter, such that a single lda (00),y instruction fetched the appropriate data
; 
; This is about as fast of a rotation as we can do.
;
; When possible, off-screen locations are calculate to produce an address of $FFFE, so that the last two bytes
; of the BG1 data buffer provides the "fill value".

ANGLEBNK                  ext
ApplyBG1XPosAngle         ENT
                          phb
                          phk
                          plb
                          jsr   _ApplyBG1XPosAngle
                          plb
                          rtl

_ApplyBG1XPosAngle
;                          phy

;                          lda   BG1StartX
;                          jsr   Mod164
;                          sta   BG1StartXMod164

;                          lda   #162
;                          sec
;                          sbc   StartXMod164
;                          bpl   *+6
;                          clc
;                          adc   #164
;                          clc
;                          adc   BG1StartXMod164
;                          cmp   #164
;                          bcc   *+5
;                          sbc   #164

;                          clc
;                          adc   1,s
;                          tay                             ; cache the value

;                          pla                             ; pop the value
                          phd                             ; save the direct page because we are going to switch to the
                          lda   BlitterDP                 ; blitter direct page space and fill in the addresses
                          tcd

                          lda   #^ANGLEBNK
                          sta   $fe
                          sty   $fc                       ; Store in the new direct page
                          ldy   #162
                          tyx
:loop
                          lda   [$fc],y
                          sta   00,x                      ; store the value
                          dey
                          dey
                          dex
                          dex
                          bpl   :loop
                          pld
                          rts

ApplyBG1YPosAngle         ENT
                          phb
                          phk
                          plb
                          jsr   _ApplyBG1YPosAngle
                          plb
                          rtl

_ApplyBG1YPosAngle
:virt_line                equ   tmp0
:lines_left               equ   tmp1
:draw_count               equ   tmp2
:ytbl_idx                 equ   tmp3
:angle_tbl                equ   tmp4

                          sty   :angle_tbl

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

                          lda   :ytbl_idx                 ; Read from this location (duplicate every 4 lines)
                          lsr
                          lsr
                          asl
                          clc
                          adc   :angle_tbl
                          sec
                          sbc   #ANGLEBNK
                          jsr   CopyAngleYTableToBG1Addr  ; or CopyBG1YTableToBG1Addr2

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

                          phk
                          plb
                          rts

; Unrolled copy routine to move y_angle entries into BG1_ADDR position with an additional
; shift.  This has to be split into two 
;
; A = index into the array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyAngleYTableToBG1Addr
                          phx
                          phb

                          phk                             ; restore access to this bank
                          plb
                          jsr   SaveBG1AngleValues

                          plb
                          plx                             ; x is used directly in this routine
                          jsr   ApplyBG1OffsetValues
                          rts

SaveBG1AngleValues
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
                          ldal  ANGLEBNK+06,x
                          sta   BG1YCache+30
:x15                      ldal  ANGLEBNK+06,x
                          sta   BG1YCache+28
:x14                      ldal  ANGLEBNK+06,x
                          sta   BG1YCache+26
:x13                      ldal  ANGLEBNK+06,x
                          sta   BG1YCache+24
:x12                      ldal  ANGLEBNK+04,x
                          sta   BG1YCache+22
:x11                      ldal  ANGLEBNK+04,x
                          sta   BG1YCache+20
:x10                      ldal  ANGLEBNK+04,x
                          sta   BG1YCache+18
:x09                      ldal  ANGLEBNK+04,x
                          sta   BG1YCache+16
:x08                      ldal  ANGLEBNK+02,x
                          sta   BG1YCache+14
:x07                      ldal  ANGLEBNK+02,x
                          sta   BG1YCache+12
:x06                      ldal  ANGLEBNK+02,x
                          sta   BG1YCache+10
:x05                      ldal  ANGLEBNK+02,x
                          sta   BG1YCache+08
:x04                      ldal  ANGLEBNK+00,x
                          sta   BG1YCache+06
:x03                      ldal  ANGLEBNK+00,x
                          sta   BG1YCache+04
:x02                      ldal  ANGLEBNK+00,x
                          sta   BG1YCache+02
:x01                      ldal  ANGLEBNK+00,x
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
