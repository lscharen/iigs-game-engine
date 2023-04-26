; Support rotating the BG1 graphics by leveraging the fact that a rotation function can be decomposed
; into an addition of two function parametertized by the angle of rotation: pixel = *(f(x, a) + f(y, a))
;
; The pre-build a number of rotation tables and then populate the direct page values and Y-register values
; for each line of the blitter, such that a single lda (00),y instruction fetches the appropriate data
; 
; This is about as fast of a rotation as we can do.
;
; When possible, off-screen locations are calculated to produce an address of $FFFE, so that the last two bytes
; of the BG1 data buffer provides the "fill value".
;
; Having a fixed table of addresses is limiting due to the size an inability to control what happens at the
; boundaries. Consider generating some pre-processed step + error parameters that can be used in a fast
; DDA stepper to allow a more compact representation or different (scale, angle) pairs.  This could allow for
; a full range of 256 rotation angles + multiple scalings.

ANGLEBNK                   EXT
_ApplyBG1XPosAngle
:ptr  equ $FC
:stbl equ $FA
                          phd                             ; save the direct page because we are going to switch to the
                          pei   BlitterDP                 ; blitter direct page space and fill in the addresses
                          lda   BG1Scaling
                          pld

                          and   #$000F
                          asl
                          tax
                          lda   ScalingTables,x
                          sta   :stbl

                          lda   #^ANGLEBNK
                          sta   :ptr+2
                          sty   :ptr                       ; Store in the new direct page
                          ldx   #162
:loop
                          txy
                          lda   (:stbl),y                  ; Map the through the scaling factor
                          tay
                          lda   [:ptr],y                   ; Load the underlying value
                          sta   00,x                       ; store the value
                          dex
                          dex
                          bpl   :loop
                          pld
                          rts

_ApplyBG1YPosAngle_Orig
:virt_line                equ   tmp0
:lines_left               equ   tmp1
:draw_count               equ   tmp2
:ytbl_idx                 equ   tmp3
:angle_tbl                equ   tmp4
:scale_ptr                equ   tmp5

                          sty   :angle_tbl

                          lda   BG1Scaling                ; Set the scaling table
                          and   #$0007
                          asl
                          tax
                          lda   ScalingTables,x
                          sta   :scale_ptr

                          lda   BG1StartYMod208
                          sta   :ytbl_idx                 ; Start copying from the first entry in the table

                          lda   StartYMod208              ; This is the base line of the virtual screen
                          sta   :virt_line                ; Keep track of it

                          lda   ScreenHeight
                          sta   :lines_left

; Copy out the y-values from the rotation table into a temporary buffer

; Copy the rotation values into the code fields

                          phb
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

                          plb
                          rts

; Unrolled copy routine to move y_angle entries into BG1_ADDR position with an additional
; shift.  This has to be split into two 
;
; A = index into the array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyAngleYTableToBG1Addr
:ptr  equ $FC
:stbl equ $FA
; tax
; ldal ANGLEBNK+XX,x
; sta  BG1_ADDR+$F000,y
                          phy                             ; save y; used when writing
                          phx

; Scale the mapping
                          tay
                          
                          


                          jsr   SaveBG1AngleValues
                          plx                             ; x is used directly in this routine
                          ply
                          jmp   ApplyBG1OffsetValues

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
                          stal  BG1YCache+30
:x15                      ldal  ANGLEBNK+06,x
                          stal   BG1YCache+28
:x14                      ldal  ANGLEBNK+06,x
                          stal   BG1YCache+26
:x13                      ldal  ANGLEBNK+06,x
                          stal   BG1YCache+24
:x12                      ldal  ANGLEBNK+04,x
                          stal   BG1YCache+22
:x11                      ldal  ANGLEBNK+04,x
                          stal   BG1YCache+20
:x10                      ldal  ANGLEBNK+04,x
                          stal   BG1YCache+18
:x09                      ldal  ANGLEBNK+04,x
                          stal   BG1YCache+16
:x08                      ldal  ANGLEBNK+02,x
                          stal   BG1YCache+14
:x07                      ldal  ANGLEBNK+02,x
                          stal   BG1YCache+12
:x06                      ldal  ANGLEBNK+02,x
                          stal   BG1YCache+10
:x05                      ldal  ANGLEBNK+02,x
                          stal   BG1YCache+08
:x04                      ldal  ANGLEBNK+00,x
                          stal   BG1YCache+06
:x03                      ldal  ANGLEBNK+00,x
                          stal   BG1YCache+04
:x02                      ldal  ANGLEBNK+00,x
                          stal   BG1YCache+02
:x01                      ldal  ANGLEBNK+00,x
                          stal   BG1YCache+00
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


; Modified version that copies all of the values to an intermediate buffer and then into the
; code field.  Allows values to be transformed on the fly
TmpAngleTbl               ds    416

_ApplyBG1YPosAngle
:virt_line                equ   tmp0
:lines_left               equ   tmp1
:draw_count               equ   tmp2
:ytbl_idx                 equ   tmp3
:angle_tbl                equ   tmp4
:scale_ptr                equ   tmp5
:lines_left_x2            equ   tmp7
:angle_ptr                equ   tmp8

                          sty   :angle_tbl

                          lda   BG1Scaling                ; Set the scaling table
                          and   #$0007
                          asl
                          tax

                          lda   ScalingTables,x
                          sta   :scale_ptr
                          lda   #^ScalingTables
                          sta   :scale_ptr+2

                          lda   BG1StartYMod208
                          sta   :ytbl_idx                 ; Start copying from the first entry in the table

                          lda   StartYMod208              ; This is the base line of the virtual screen
                          sta   :virt_line                ; Keep track of it

                          lda   ScreenHeight
                          sta   :lines_left
                          asl
                          sta   :lines_left_x2

; Copy out the y-values from the rotation table into a temporary buffer

                          lda   :ytbl_idx
                          asl
                          clc
                          adc   :angle_tbl
                          sta   :angle_ptr
                          lda   #^ANGLEBNK
                          sta   :angle_ptr+2

                          phb
                          phk
                          plb
                          ldx   #0
                          txy
:loop0
                          phy
                          lda   [:scale_ptr],y
                          tay
                          lda   [:angle_ptr],y
                          ply

                          sta   TmpAngleTbl,x
                          sta   TmpAngleTbl+2,x
                          sta   TmpAngleTbl+4,x
                          sta   TmpAngleTbl+6,x

                          iny
                          iny
                          
                          txa
                          clc
                          adc   #8
                          tax
                          cpx   :lines_left_x2
                          bcc   :loop0
                          plb

; Copy the rotation values into the code fields

                          phb
                          stz   :ytbl_idx                 ; just copy from a fixed table
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

;                          lda   :ytbl_idx                 ; Read from this location (duplicate every 4 lines)
;                          lsr
;                          lsr
;                          asl
;                          clc
;                          adc   :angle_tbl
;                          sec
;                          sbc   #ANGLEBNK
;                          jsr   CopyAngleYTableToBG1Addr  ; or CopyBG1YTableToBG1Addr2

                          lda   :ytbl_idx                 ; Read from this location (duplicate every 4 lines)
                          asl
                          jsr   CopyAngleTmpTableToBG1Addr  ; or CopyBG1YTableToBG1Addr2

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

; Unrolled copy routine to move y_angle entries into BG1_ADDR position with an additional
; shift.  This has to be split into two 
;
; A = index into the temp array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
CopyAngleTmpTableToBG1Addr
; tax
; ldal ANGLEBNK+XX,x
; sta  BG1_ADDR+$F000,y
                          phx
                          pha
                          jsr   SaveBG1AngleValues2
                          pla
                          plx                             ; x is used directly in this routine
                          jmp   ApplyBG1OffsetValues

SaveBG1AngleValues2
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
                          ldal  TmpAngleTbl+30,x
                          stal  BG1YCache+30
:x15                      ldal  TmpAngleTbl+28,x
                          stal  BG1YCache+28
:x14                      ldal  TmpAngleTbl+26,x
                          stal  BG1YCache+26
:x13                      ldal  TmpAngleTbl+24,x
                          stal   BG1YCache+24
:x12                      ldal  TmpAngleTbl+22,x
                          stal   BG1YCache+22
:x11                      ldal  TmpAngleTbl+20,x
                          stal   BG1YCache+20
:x10                      ldal  TmpAngleTbl+18,x
                          stal   BG1YCache+18
:x09                      ldal  TmpAngleTbl+16,x
                          stal   BG1YCache+16
:x08                      ldal  TmpAngleTbl+14,x
                          stal   BG1YCache+14
:x07                      ldal  TmpAngleTbl+12,x
                          stal   BG1YCache+12
:x06                      ldal  TmpAngleTbl+10,x
                          stal   BG1YCache+10
:x05                      ldal  TmpAngleTbl+08,x
                          stal   BG1YCache+08
:x04                      ldal  TmpAngleTbl+06,x
                          stal   BG1YCache+06
:x03                      ldal  TmpAngleTbl+04,x
                          stal   BG1YCache+04
:x02                      ldal  TmpAngleTbl+02,x
                          stal   BG1YCache+02
:x01                      ldal  TmpAngleTbl+00,x
                          stal   BG1YCache+00
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