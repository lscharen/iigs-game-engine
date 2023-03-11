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
:src_flags                equ   tmp9

                          clc
                          adc   #8                        ; Advance over the header
                          pha

                          lda   #164
                          sta   :src_width
                          lda   #208
                          sta   :src_height
                          stz   :src_flags

                          pla
                          jmp   _CopyToBG1

; Reset the BG1 Y-table depending on the rendering mode
;
; A = mode
;     0 = default   (base = $1800, stride = 256)
;     1 = scanline  (base = $A0, stride = 324)
_ResetBG1YTable
:base    equ  tmp0
:stride  equ  tmp1
                          cmp   #1                 ; scanline mode?
                          bne   :default
                          lda   #0
                          sta   :base
                          lda   #327
                          sta   :stride
                          bra   :begin
:default
                          lda   #$1800
                          sta   :base
                          lda   #256
                          sta   :stride
:begin
                          ldx   #0
                          lda   :base
:loop
                          sta   BG1YTable,x
                          sta   BG1YTable+{208*2},x

                          clc
                          adc   :stride

                          inx
                          inx
                          cpx   #{208*2}
                          bcc   :loop
                          rts

; Copy a IIgs $C1 picture into BG1.  Assumes the file is the correct size (320 x 200)
;
; A=low word of picture address
; X=high word of pixture address
; Y=high word of BG1 bank
_CopyPicToBG1
:src_width                equ   tmp6
:src_height               equ   tmp7
:src_stride               equ   tmp8
:src_flags                equ   tmp9

                          pha
                          lda    #160
                          sta    :src_width
                          sta    :src_stride
                          lda    #200
                          sta    :src_height
                          pla
                          stz    :src_flags
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
:src_flags                equ   tmp9
:dstptr2                  equ   tmp10

; scanline mode is tricky -- there's not enough space to make two full copies of a 328x200 bitmap buffer, but we can 
; *barely* fit a (164 + 163) x 200 buffer.  And, since the zero offset could use either end, this covers all of the cases.

                          sta   :srcptr
                          stx   :srcptr+2
                          sty   :dstptr+2                 ; Everything goes into this bank
                          sty   :dstptr2+2

                          lda   #0                        ; Start a byte 1 because odd offsets might go back 1 byte and don't want to wrap around
                          sta   :dstptr
                          clc
                          adc   #164                      ; The first part is 1-byte short, the second part is a full 164 bytes
                          sta   :dstptr2

; "Normal" BG1 mode as a stride of 164 bytes and mirrors the BG0 size (328 x 208)
; In "Scanline" mode, the BG1 is treated as a 320x200 bitfield with each horizontal line doubled

                          lda   :src_width
                          min   #164
                          sta   :src_width

                          lda   :src_height
                          min   #200
                          sta   :src_height

                          stz   :line_cnt
:rloop
                          ldy   #0                        ; move forward in the image data and image data
; Handle first word as a special case

                          lda   [:srcptr],y
                          sta   [:dstptr2],y              ; copy directly into the 164-byte buffer
                          iny
                          xba
                          sep   #$20
                          sta   [:dstptr],y               ; only copy the high byte because the previous line occupies the low byte
                          rep   #$20
                          iny

:cloop
                          lda   [:srcptr],y
                          sta   [:dstptr],y
                          sta   [:dstptr2],y

                          iny
                          iny

                          cpy   :src_width
                          bcc   :cloop

                          lda   :dstptr
                          clc
                          adc   #327
                          sta   :dstptr
                          adc   #164
                          sta   :dstptr2

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

; Save as _ApplyBG1XPos, but we pretend that StartXMod164 is always zero and deal with the per-line offset adjustment in
; _ApplyScanlineBG1YPos.  The tweak here is that the buffer is only 160 bytes wide in scanine mode, instead of 164 bytes wide
_ApplyScanlineBG1XPos
                          lda   BG1StartXMod164           ; How far into the BG1 buffer is the left edge?
                          tay

                          phd                             ; save the direct page because we are going to switch to the
                          lda   BlitterDP                 ; blitter direct page space and fill in the addresses
                          tcd

                          ldx   #0
;                          tya
                          lda   #0
:loop
                          sta   00,x                      ; store the value
                          inc
                          inc
                          cmp   #164
                          bcc   *+5
                          sbc   #164

                          inx
                          inx
                          cpx   #164
                          bcc   :loop

                          pld
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

; Variation to take care of horizontal adjustments within the BG1 buffer to compensate for the
; per-scanline BG0 displacement.  It is up to the caller to manage the memeory layout to make
; this visually work.
;
; In the scanline mode we have to be able to adjust the base address of each BG1 line up to
; a full screen, so scanline mode treats bank as a 640x200 pixel bitmap (64000 byte).
;
; This is just a limitation of scanline displacement mode that there is no extra vertical space.
_ApplyScanlineBG1YPos
:stk_save           equ   tmp0
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:draw_count_x2      equ   tmp3
:ytbl_idx_x2        equ   tmp4
:shift_value        equ   tmp5

; Avoid local var collision
:ptr2               equ   tmp8
:ytbl_idx_pos_x2    equ   tmp10
:virt_line_pos_x2   equ   tmp11
:total_left_x2      equ   tmp12
:current_count_x2   equ   tmp13
:ptr                equ   tmp14

                    lda   StartXMod164Tbl
                    sta   :ptr
                    lda   StartXMod164Tbl+2
                    sta   :ptr+2

                    lda   BG1StartXMod164Tbl
                    sta   :ptr2
                    lda   BG1StartXMod164Tbl+2
                    sta   :ptr2+2
                    ora   :ptr2

                    lda   BG1StartY
                    jsr   Mod208
                    sta   BG1StartYMod208
                    asl
                    sta   :ytbl_idx_pos_x2            ; Start copying from the first entry in the table

                    lda   StartYMod208               ; This is the base line of the virtual screen
                    asl
                    sta   :virt_line_pos_x2
                    tay

                    lda   ScreenHeight
                    asl
                    sta   :total_left_x2

:loop0
                    lda   [:ptr],y
                    tax

                    and   #$FF00                    ; Determine how many sequential lines have this mod value
                    xba
                    inc
                    asl
                    min   :total_left_x2            ; Don't draw more than the number of lines that are left to process
                    sta   :current_count_x2         ; Save a copy for later

                    sta   :lines_left_x2            ; Set the parameter
                    lda   :ytbl_idx_pos_x2          ; Set the parameter
                    sta   :ytbl_idx_x2
                    sty   :virt_line_x2             ; Set the parameter
                    txa                             ; Put the X mod 164 value in the offset value
                    and   #$00FF
                    sta   :shift_value

                    jsr   :_ApplyConstBG1YPos       ; Shift this range by a constant amount

                    clc
                    lda   :virt_line_pos_x2   
                    adc   :current_count_x2
                    cmp   #208*2                    ; Do the modulo check in this loop
                    bcc   *+5
                    sbc   #208*2
                    sta   :virt_line_pos_x2
                    tay

                    clc
                    lda   :ytbl_idx_pos_x2
                    adc   :current_count_x2
                    sta   :ytbl_idx_pos_x2

                    lda   :total_left_x2
                    sec
                    sbc   :current_count_x2
                    sta   :total_left_x2
                    bne   :loop0

                    rts

:_ApplyConstBG1YPos
                     
                    lda   #164
                    sec
                    sbc   :shift_value
                    clc
                    adc   BG1StartXMod164
                    cmp   #164+1
                    bcc   *+5
                    sbc   #164
                    sta   :shift_value               ; Base shift value

                    cmp   #165
                    bcc   *+4
                    brk   $04

                    phb                              ; Save the existing bank
                    tsc
                    sta   :stk_save

:loop
                    ldx   :virt_line_x2

                    ldal  BTableHigh,x               ; Get the bank
                    pha
                    plb

                    ldal  BTableLow,x                ; Get the address of the first code field line
                    tay

                    txa                              ; Calculate number of lines to draw on this iteration
                    and   #$001E
                    eor   #$FFFF
                    sec
                    adc   #32
                    min   :lines_left_x2
                    sta   :draw_count_x2
                    tax

                    lda   :ytbl_idx_x2                 ; Read from this location in the BG1YTable
;                    clc
;                    CopyBG1YTableToBG1Addr3 :shift_value
                    CopyBG1YTableToBG1Addr4 :shift_value;blttmp

                    lda   :virt_line_x2              ; advance to the virtual line after
                    adc   :draw_count_x2             ; filled in
                    sta   :virt_line_x2

                    lda   :ytbl_idx_x2
                    adc   :draw_count_x2
                    sta   :ytbl_idx_x2

                    lda   :lines_left_x2             ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count_x2
                    sta   :lines_left_x2

                    jne   :loop

                    lda   :stk_save
                    tcs
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

; Unrolled copy routine to move BG1YTable entries into BG1_ADDR position
; with a constant shift applied
;
; A = index into the BG1YTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
; ]1 = offset
CopyBG1YTableToBG1Addr3   mac
                          jmp   (tbl,x)
tbl                       da    none
                          da    do01,do02,do03,do04
                          da    do05,do06,do07,do08
                          da    do09,do10,do11,do12
                          da    do13,do14,do15,do16
do15                      tax
                          jmp   x15
do14                      tax
                          jmp   x14
do13                      tax
                          jmp   x13
do12                      tax
                          jmp   x12
do11                      tax
                          jmp   x11
do10                      tax
                          jmp   x10
do09                      tax
                          jmp   x09
do08                      tax
                          jmp   x08
do07                      tax
                          jmp   x07
do06                      tax
                          jmp   x06
do05                      tax
                          jmp   x05
do04                      tax
                          jmp   x04
do03                      tax
                          jmp   x03
do02                      tax
                          jmp   x02
do01                      tax
                          jmp   x01
do16                      tax
                          ldal  BG1YTable+30,x
                          adc   ]1
                          sta   BG1_ADDR+$F000,y
x15                       ldal  BG1YTable+28,x
                          adc   ]1
                          sta   BG1_ADDR+$E000,y
x14                       ldal  BG1YTable+26,x
                          adc   ]1
                          sta   BG1_ADDR+$D000,y
x13                       ldal  BG1YTable+24,x
                          adc   ]1
                          sta   BG1_ADDR+$C000,y
x12                       ldal  BG1YTable+22,x
                          adc   ]1
                          sta   BG1_ADDR+$B000,y
x11                       ldal  BG1YTable+20,x
                          adc   ]1
                          sta   BG1_ADDR+$A000,y
x10                       ldal  BG1YTable+18,x
                          adc   ]1
                          sta   BG1_ADDR+$9000,y
x09                       ldal  BG1YTable+16,x
                          adc   ]1
                          sta   BG1_ADDR+$8000,y
x08                       ldal  BG1YTable+14,x
                          adc   ]1
                          sta   BG1_ADDR+$7000,y
x07                       ldal  BG1YTable+12,x
                          adc   ]1
                          sta   BG1_ADDR+$6000,y
x06                       ldal  BG1YTable+10,x
                          adc   ]1
                          sta   BG1_ADDR+$5000,y
x05                       ldal  BG1YTable+08,x
                          adc   ]1
                          sta:  BG1_ADDR+$4000,y
x04                       ldal  BG1YTable+06,x
                          adc   ]1
                          sta   BG1_ADDR+$3000,y
x03                       ldal  BG1YTable+04,x
                          adc   ]1
                          sta   BG1_ADDR+$2000,y
x02                       ldal  BG1YTable+02,x
                          adc   ]1
                          sta   BG1_ADDR+$1000,y
x01                       ldal  BG1YTable+00,x
                          adc   ]1
                          sta:  BG1_ADDR+$0000,y
none                      <<<

; Copy routine to move BG1YTable entries into BG1_ADDR position with an additional
; shift on every line form the user-provided BG1StartXMod164Tbl.
;
; A = index into the BG1YTable array (x2)
; Y = starting line * $1000
; X = number of lines (x2)
;
; ]1 = constant shift value
; ]2 = temp storage space
CopyBG1YTableToBG1Addr4   mac
                          phy                             ; save the registers
                          phx
                          phb
                          pha
                          jsr   _SetDataBank              ; Set to toolbox data bank

                          clc
                          lda   1,s                       ; virtual_index_x2
                          adc   BG1StartXMod164Tbl        ; Get the starting address in the array for this chunk
                          tay

                          lda   BG1StartXMod164Tbl+1      ; Set the bank to the array location
                          pha
                          plb
                          plb

                          pla                             ; POp back the original value 
                          ApplyBG1ModXToShift ]1;]2       ; Copy the array into direct page storage and apply the shift

                          plb                             ; Restore the code field bank
                          plx                             ; x is used directly in this routine
                          ply
                          ApplyBG1ShiftToCode ]2
                          <<<

; Unrolled copy routine to move BG1YTable entries into BG1_ADDR position with an additional
; shift on every line.  This has to be split into two 
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

; Apply the per-scanline shift from the BG1StartXMod164Tbl pointer. Save the relevant values to the
; direct page since the array could be in any bank.
;
; This does bounds checking to make sure the shift value remains in the valid range
;
; ]1 = source array offset
; ]2 = constant shift value
; ]3 = destination address
_BG1ShiftTemplate         mac
                          lda   ]1,y                          ; Load the value from the array
                          adc   ]2                            ; Add to the direct page shift_value
                          cmp   #165                          ; If below this value, we're good
                          bcc   *+6
                          sbc   #164
                          clc
                          adcl  BG1YTable+]1,x
                          sta   ]3+]1
                          <<<

AToX                      mac
                          tax
                          brl   ]1
                          <<<

ApplyBG1ModXToShift       mac
                          jmp   (agmxts_tbl,x)
agmxts_tbl                da    none
                          da    do01,do02,do03,do04
                          da    do05,do06,do07,do08
                          da    do09,do10,do11,do12
                          da    do13,do14,do15,do16
do16                      AToX  o16
do15                      AToX  o15
do14                      AToX  o14
do13                      AToX  o13
do12                      AToX  o12
do11                      AToX  o11
do10                      AToX  o10
do09                      AToX  o09
do08                      AToX  o08
do07                      AToX  o07
do06                      AToX  o06
do05                      AToX  o05
do04                      AToX  o04
do03                      AToX  o03
do02                      AToX  o02
do01                      AToX  o01

o16                       _BG1ShiftTemplate 30;]1;]2
o15                       _BG1ShiftTemplate 28;]1;]2
o14                       _BG1ShiftTemplate 26;]1;]2
o13                       _BG1ShiftTemplate 24;]1;]2
o12                       _BG1ShiftTemplate 22;]1;]2
o11                       _BG1ShiftTemplate 20;]1;]2
o10                       _BG1ShiftTemplate 18;]1;]2
o09                       _BG1ShiftTemplate 16;]1;]2
o08                       _BG1ShiftTemplate 14;]1;]2
o07                       _BG1ShiftTemplate 12;]1;]2
o06                       _BG1ShiftTemplate 10;]1;]2
o05                       _BG1ShiftTemplate 8;]1;]2
o04                       _BG1ShiftTemplate 6;]1;]2
o03                       _BG1ShiftTemplate 4;]1;]2
o02                       _BG1ShiftTemplate 2;]1;]2
o01                       _BG1ShiftTemplate 0;]1;]2
none                      <<<

; After the values are saved, the data bank can be repointed at the current code bank and the values copied in
; from the direct page
;
; ]1 = offset in temp buffer
; ]2 = address of temp buffer
; ]3 = 4k offset in code buffer
_BG1ShiftToCodeTemplate   mac
                          lda   ]2+]1
                          sta:  BG1_ADDR+]3,y
                          <<<

ApplyBG1ShiftToCode       mac
                          jmp   (abstc_tbl,x)
abstc_tbl                 da    none
                          da    do01,do02,do03,do04
                          da    do05,do06,do07,do08
                          da    do09,do10,do11,do12
                          da    do13,do14,do15,do16
do16                     _BG1ShiftToCodeTemplate 30;]1;$F000
do15                     _BG1ShiftToCodeTemplate 28;]1;$E000
do14                     _BG1ShiftToCodeTemplate 26;]1;$D000
do13                     _BG1ShiftToCodeTemplate 24;]1;$C000
do12                     _BG1ShiftToCodeTemplate 22;]1;$B000
do11                     _BG1ShiftToCodeTemplate 20;]1;$A000
do10                     _BG1ShiftToCodeTemplate 18;]1;$9000
do09                     _BG1ShiftToCodeTemplate 16;]1;$8000
do08                     _BG1ShiftToCodeTemplate 14;]1;$7000
do07                     _BG1ShiftToCodeTemplate 12;]1;$6000
do06                     _BG1ShiftToCodeTemplate 10;]1;$5000
do05                     _BG1ShiftToCodeTemplate 8;]1;$4000
do04                     _BG1ShiftToCodeTemplate 6;]1;$3000
do03                     _BG1ShiftToCodeTemplate 4;]1;$2000
do02                     _BG1ShiftToCodeTemplate 2;]1;$1000
do01                     _BG1ShiftToCodeTemplate 0;]1;$0000
none                     <<<