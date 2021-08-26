; Support routinges for the primary background
_InitBG0
                 jsr   _ApplyBG0YPos
                 jsr   _ApplyBG0XPos
                 rts

; Copy a raw data file into the code field
;
; A=low word of picture address
; X=high word of pixture address
CopyBinToField   ENT
                 phb
                 phk
                 plb
                 jsr   _CopyBinToField
                 plb
                 rtl

_CopyBinToField
:srcptr          equ   tmp0
:line_cnt        equ   tmp2
:dstptr          equ   tmp3
:col_cnt         equ   tmp5
:mask            equ   tmp6
:data            equ   tmp7
:mask_color      equ   tmp8

                 sta   :srcptr
                 stx   :srcptr+2

; Check that this is a GTERAW image and save the transparent color

                 ldy   #4
:chkloop
                 lda   [:srcptr],y
                 cmp   :headerStr,y
                 beq   *+3
                 rts
                 dey
                 dey
                 bpl   :chkloop

; We have a valid header, now get the transparency word and load it in
                 ldy   #6
                 lda   [:srcptr],y
                 sta   :mask_color

; Advance over the header
                 lda   :srcptr
                 clc
                 adc   #8
                 sta   :srcptr

                 stz   :line_cnt
:rloop
                 lda   :line_cnt         ; get the pointer to the code field line
                 asl
                 tax

                 lda   BTableLow,x
                 sta   :dstptr
                 lda   BTableHigh,x
                 sta   :dstptr+2

;                     ldx        #162                    ; move backwards in the code field
                 ldy   #0                ; move forward in the image data

                 lda   #82               ; keep a running column count
                 sta   :col_cnt

:cloop
                 phy
                 lda   [:srcptr],y       ; load the picture data
                 cmp   :mask_color
                 beq   :transparent      ; a value of $0000 is transparent

                 jsr   :toMask           ; Infer a mask value for this. If it's $0000, then
                 cmp   #$0000
                 bne   :mixed            ; the data is solid, otherwise mixed

; This is a solid word
:solid
                 lda   [:srcptr],y
                 pha                     ; Save the data

                 lda   Col2CodeOffset,y  ; Get the offset to the code from the line start
                 tay

                 lda   #$00F4            ; PEA instruction
                 sta   [:dstptr],y
                 iny
                 pla
                 sta   [:dstptr],y       ; PEA operand
                 bra   :next
:transparent
                 lda   :mask_color       ; Make sure we actually have to mask
                 cmp   #$A5A5
                 beq   :solid

                 lda   Col2CodeOffset,y  ; Get the offset to the code from the line start
                 tay
                 lda   #$B1              ; LDA (dp),y
                 sta   [:dstptr],y
                 iny
                 lda   1,s               ; load the saved Y-index
                 ora   #$4800            ; put a PHA after the offset
                 sta   [:dstptr],y
                 bra   :next

:mixed
                 sta   :mask             ; Save the mask
                 lda   [:srcptr],y       ; Refetch the screen data
                 sta   :data

                 tyx
                 lda   Col2CodeOffset,y  ; Get the offset into the code field
                 tay
                 lda   #$4C              ; JMP exception
                 sta   [:dstptr],y
                 iny

                 lda   JTableOffset,x    ; Get the address offset and add to the base address
                 clc
                 adc   :dstptr
                 sta   [:dstptr],y

                 ldy   JTableOffset,x    ; This points to the code fragment
                 lda   1,s               ; load the offset
                 xba
                 ora   #$00B1
                 sta   [:dstptr],y       ; write the LDA (--),y instruction
                 iny
                 iny
                 iny                     ; advance to the AND #imm operand
                 lda   :mask
                 sta   [:dstptr],y
                 iny
                 iny
                 iny                     ; advance to the ORA #imm operand
                 lda   :mask
                 eor   #$FFFF            ; invert the mask to clear up the data
                 and   :data
                 sta   [:dstptr],y

:next
                 ply

;                     dex
;                     dex
                 iny
                 iny

                 dec   :col_cnt
                 bne   :cloop

                 lda   :srcptr
                 clc
                 adc   #164
                 sta   :srcptr

                 inc   :line_cnt
                 lda   :line_cnt
                 cmp   #200
                 bcs   :exit
                 brl   :rloop

:exit
                 rts

:toMask          pha                     ; save original

                 lda   1,s
                 eor   :mask_color       ; only identical bits produce zero
                 and   #$F000
                 beq   *+7
                 pea   #$0000
                 bra   *+5
                 pea   #$F000


                 lda   3,s
                 eor   :mask_color
                 and   #$0F00
                 beq   *+7
                 pea   #$0000
                 bra   *+5
                 pea   #$0F00

                 lda   5,s
                 eor   :mask_color
                 and   #$00F0
                 beq   *+7
                 pea   #$0000
                 bra   *+5
                 pea   #$00F0

                 lda   7,s
                 eor   :mask_color
                 and   #$000F
                 beq   *+7
                 lda   #$0000
                 bra   *+5
                 lda   #$000F

                 ora   1,s
                 sta   1,s
                 pla
                 ora   1,s
                 sta   1,s
                 pla
                 ora   1,s
                 sta   1,s
                 pla

                 sta   1,s               ; pop the saved word
                 pla
                 rts

:headerStr       asc   'GTERAW'

; Copy a loaded SHR picture into the code field
;
; A=low word of picture address
; X=high workd of pixture address
;
; Picture must be within one bank
CopyPicToField   ENT
                 phb
                 phk
                 plb
                 jsr   _CopyPicToField
                 plb
                 rtl

_CopyPicToField
:srcptr          equ   tmp0
:line_cnt        equ   tmp2
:dstptr          equ   tmp3
:col_cnt         equ   tmp5
:mask            equ   tmp6
:data            equ   tmp7

                 sta   :srcptr
                 stx   :srcptr+2

                 stz   :line_cnt
:rloop
                 lda   :line_cnt         ; get the pointer to the code field line
                 asl
                 tax

                 lda   BTableLow,x
                 sta   :dstptr
                 lda   BTableHigh,x
                 sta   :dstptr+2

;                     ldx        #162                    ; move backwards in the code field
                 ldy   #0                ; move forward in the image data

                 lda   #80               ; keep a running column count
;                     lda        #82                  ; keep a running column count
                 sta   :col_cnt

:cloop
                 phy
                 lda   [:srcptr],y       ; load the picture data
                 beq   :transparent      ; a value of $0000 is transparent

                 jsr   :toMask           ; Infer a mask value for this. If it's $0000, then
                 bne   :mixed            ; the data is solid, otherwise mixed

; This is a solid word
                 lda   [:srcptr],y
                 pha                     ; Save the data

                 lda   Col2CodeOffset,y  ; Get the offset to the code from the line start
                 tay

                 lda   #$00F4            ; PEA instruction
                 sta   [:dstptr],y
                 iny
                 pla
                 sta   [:dstptr],y       ; PEA operand
                 bra   :next
:transparent
                 lda   Col2CodeOffset,y  ; Get the offset to the code from the line start
                 tay

                 lda   #$B1              ; LDA (dp),y
                 sta   [:dstptr],y
                 iny
                 lda   1,s               ; load the saved Y-index
                 ora   #$4800            ; put a PHA after the offset
                 sta   [:dstptr],y
                 bra   :next

:mixed
                 sta   :mask             ; Save the mask
                 lda   [:srcptr],y       ; Refetch the screen data
                 sta   :data

                 tyx
                 lda   Col2CodeOffset,y  ; Get the offset into the code field
                 tay

                 lda   #$4C              ; JMP exception
                 sta   [:dstptr],y
                 iny

                 lda   JTableOffset,x    ; Get the address offset and add to the base address
                 clc
                 adc   :dstptr
                 sta   [:dstptr],y

                 ldy   JTableOffset,x    ; This points to the code fragment
                 lda   1,s               ; load the offset
                 xba
                 ora   #$00B1
                 sta   [:dstptr],y       ; write the LDA (--),y instruction
                 iny
                 iny
                 iny                     ; advance to the AND #imm operand
                 lda   :mask
                 sta   [:dstptr],y
                 iny
                 iny
                 iny                     ; advance to the ORA #imm operand
                 lda   :data
                 sta   [:dstptr],y

:next
                 ply

;                     dex
;                     dex
                 iny
                 iny

                 dec   :col_cnt
                 bne   :cloop

                 lda   :srcptr
                 clc
;                     adc        #164
                 adc   #160
                 sta   :srcptr

                 inc   :line_cnt
                 lda   :line_cnt
;                     cmp        #208
                 cmp   #200
                 bcs   :exit
                 brl   :rloop

:exit
                 rts

:toMask          bit   #$F000
                 beq   *+7
                 and   #$0FFF
                 bra   *+5
                 ora   #$F000

                 bit   #$0F00
                 beq   *+7
                 and   #$F0FF
                 bra   *+5
                 ora   #$0F00

                 bit   #$00F0
                 beq   *+7
                 and   #$FF0F
                 bra   *+5
                 ora   #$00F0

                 bit   #$000F
                 beq   *+7
                 and   #$FFF0
                 bra   *+5
                 ora   #$000F
                 rts





