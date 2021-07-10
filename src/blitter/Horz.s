; Subroutines that deal with the horizontal scrolling.  The primary function of
; these routines are to adjust tables and patch in new values into the code field
; when the virtual X-position of the play field changes.


; SetBG0XPos
;
; Set the virtual horizontal position of the primary background layer.  In addition to 
; updating the direct page state locations, this routine needs to preserve the original
; value as well.  This is a bit subtle, because if this routine is called multiple times
; with different values, we need to make sure the *original* value is preserved and not
; continuously overwrite it.
;
; We assume that there is a clean code field in this routine
SetBG0XPos
                    cmp   StartX
                    beq   :out                 ; Easy, if nothing changed, then nothing changes

                    ldx   StartX               ; Load the old value (but don't save it yet)
                    sta   StartX               ; Save the new position

                    lda   #DIRTY_BIT_BG0_X
                    tsb   DirtyBits            ; Check if the value is already dirty, if so exit
                    bne   :out                 ; without overwriting the original value

                    stx   OldStartX            ; First change, so preserve the value
:out                rts

; Simple function that restores the saved opcode that are stached in _applyBG0Xpos.  It is
; very important that opcodes are restored before new ones are inserted, because there is 
; only one, fixed storage location and old values will be overwritten if operations are not
; performed in order.
;
; Experimental -- this is a parameterized version that does not rely on direct page
; state variables for input and attempts to be more optimized.
;
; A = starting virtual line in the code field (0 - 207)
; X = number of lines to render (0 - 200)

_RestoreBG0Opcodes

:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:draw_count_x2      equ   tmp3
:exit_offset        equ   tmp4

                    asl
                    sta   :virt_line_x2        ; Keep track of it

                    txa
                    asl
                    sta   :lines_left_x2

                    lda   StartX               ; Repeat with adding the screen width
                    clc                        ; to calculate the exit column
                    adc   ScreenWidth
                    and   #$FFFE
                    tax
                    lda   Col2CodeOffset,X
                    sta   :exit_offset

:loop
                    ldx   :virt_line_x2
                    ldal  BTableLow,x          ; Get the address of the first code field line
                    tay

                    sep   #$20
                    ldal  BTableHigh,x
                    pha
                    plb                        ; This is the bank that will receive the updates
                    rep   #$20

                    txa                        ; lda   :virt_line_x2
                    and   #$001E
                    eor   #$FFFF
                    inc
                    clc
                    adc   #32
                    min   :lines_left_x2
                    sta   :draw_count_x2       ; Do half of this many lines

                                               ; y is already set to :base_address
                    tax                        ; :draw_count * 2

                    tya
                    clc
                    adc   :exit_offset         ; Add some offsets to get the base address in the code field line

                    jsr   RestoreOpcode

                    lda   :virt_line_x2        ; advance to the virtual line after the segment we just
                    clc                        ; filled in
                    adc   :draw_count_x2
                    sta   :virt_line_x2

                    lda   :lines_left_x2       ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count_x2
                    sta   :lines_left_x2

                    jne   :loop

                    phk
                    plb
                    rts

; Based on the current value of StartX in the direct page, patch up the code fields
; to render the correct data. Note that we do *not* do the OpcodeRestore in this
; routine.  The reason is that the restore *must* be applied using the (StartX, StartY)
; values from the previous frame, which requires logic that is not relevant to setting
; up the code field.
_ApplyBG0XPos

:virt_line          equ   tmp1
:lines_left         equ   tmp2
:draw_count         equ   tmp3
:exit_offset        equ   tmp4
:entry_offset       equ   tmp5
:exit_bra           equ   tmp6
:exit_address       equ   tmp7
:base_address       equ   tmp8
:draw_count_x2      equ   tmp9

; This code is fairly succinct.  See the corresponding code in Vert.s for more detailed comments.

                    lda   StartY               ; This is the base line of the virtual screen
                    sta   :virt_line           ; Keep track of it

                    lda   ScreenHeight
                    sta   :lines_left

; Calculate the exit and entry offsets into the code fields.  This is a bit tricky, because odd-aligned
; rendering causes the left and right edges to move in a staggered fashion.
;
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;       | 04 | 06 | 08 | 0A | 0C |       | 44 | 46 | 48 | 4A |
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;                 |                                |
;                 +---- screen width --------------+
;           entry |                                | exit
;
; Here is an example of a screen 64 bytes wide. When everything is aligned to an even offset
; then the entry point is column $08 and the exit point is column $48
;
; If we move the screen forward one byte (which means the pointers move backwards) then the low-byte
; of column $06 will be on the right edge of the screen and the high-byte of column $46 will left-edge
; of the screen. Since the one-byte edges are handled specially, the exit point shifts one column, but
; the entry point does not.
;
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;       | 04 | 06 | 08 | 0A | 0C |       | 44 | 46 | 48 | 4A |
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;              |  |                           |  |
;              +--|------ screen width -------|--+
;           entry |                           | exit
;
; When the screen is moved one more byte forward, then the entry point will move to the 
; next column.
;
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;       | 04 | 06 | 08 | 0A | 0C |       | 44 | 46 | 48 | 4A |
;   ... +----+----+----+----+----+- ... -+----+----+----+----+----+
;            |                                |
;            +------ screen width ------------+
;      entry |                                | exit
;
; So, in short, the entry tile position is rounded up from the x-position and the exit
; tile position is rounded down.

                    lda   StartX               ; This is the starting byte offset (0 - 163)
                    inc                        ; round up to calculate the entry column
                    and   #$FFFE
                    tax
                    lda   Col2CodeOffset,X     ; This is an offset from the base page boundary
                    sta   :entry_offset

                    lda   StartX               ; Repeat with adding the screen width
                    clc                        ; to calculate the exit column
                    adc   ScreenWidth
                    bit   #$0001               ; Check if odd or even
                    bne   :isOdd

                    and   #$FFFE
                    tax
                    lda   CodeFieldEvenBRA,x
                    sta   :exit_bra
                    bra   :wasEven
:isOdd
                    and   #$FFFE
                    tax
                    lda   CodeFieldOddBRA,x
                    sta   :exit_bra
:wasEven
                    lda   Col2CodeOffset,X
                    sta   :exit_offset

; Main loop that 
;
; 1. Saves the opcodes in the code field
; 2. Writes the BRA instruction to exit the code field
; 3. Writes the JMP entry point to enter the code field

:loop
                    lda   :virt_line
                    asl                        ; This will clear the carry bit
                    tax
                    ldal  BTableLow,x          ; Get the address of the first code field line
                    tay                        ; Save it to use as the base address
                    adc   :exit_offset         ; Add some offsets to get the base address in the code field line
                    sta   :exit_address
                    sty   :base_address

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
                    sta   :draw_count_x2

; First step is to set the BRA instruction to exit the code field at the proper location.  There
; are two sub-steps to do here; we need to save the 16-bit value that exists at the location and
; then overwrite it with the branch instruction.
;
; Special note, the SaveOpcode function stores the opcode *within* the code field as it is
; used in odd-aligned cases to determine how to draw the 8-bit value on the left edge of the
; screen

                                               ; y is already set to :base_address
                    tax                        ; :draw_count_x2
                    lda   :exit_address        ; Save from this location
                    jsr   SaveOpcode

                    ldx   :draw_count_x2       ; Do this many lines
                    lda   :exit_bra            ; Copy this value into all of the lines
                    ldy   :exit_address        ; starting at this address
                    jsr   SetConst

; Next, patch in the CODE_ENTRY value, which is the low byte of a JMP instruction. This is an
; 8-bit operation and, since the PEA code is bank aligned, we use the entry_offset value directly

                    sep   #$20
                    ldx   :draw_count_x2
                    lda   :entry_offset
                    ldy   :base_address
                    jsr   SetCodeEntry
                    rep   #$20

; Do the end of the loop -- update the virtual line counter and reduce the number
; of lines left to render

                    lda   :virt_line           ; advance to the virtual line after the segment we just
                    clc                        ; filled in
                    adc   :draw_count
                    sta   :virt_line

                    lda   :lines_left          ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count
                    sta   :lines_left

                    jne   :loop

                    phk
                    plb
                    rts

; SaveOpcode
;
; Save the values to the restore location.  This should only be used to patch the
; code field since the save location is fixed.  
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = code field location * $1000
SaveOpcode
                    jmp   (:tbl,x)

:tbl                da    :bottom
                    da    :do01,:do02,:do03,:do04
                    da    :do05,:do06,:do07,:do08
                    da    :do09,:do10,:do11,:do12
                    da    :do13,:do14,:do15,:do16

:do15               tax
                    bra   :x15
:do14               tax
                    bra   :x14
:do13               tax
                    bra   :x13
:do12               tax
                    bra   :x12
:do11               tax
                    bra   :x11
:do10               tax
                    bra   :x10
:do09               tax
                    bra   :x09
:do08               tax
                    bra   :x08
:do07               tax
                    bra   :x07
:do06               tax
                    bra   :x06
:do05               tax
                    bra   :x05
:do04               tax
                    bra   :x04
:do03               tax
                    bra   :x03
:do02               tax
                    bra   :x02
:do01               tax
                    bra   :x01
:do16               tax
:x16                lda   $F000,x
                    sta   OPCODE_SAVE+$F000,y
:x15                lda   $E000,x
                    sta   OPCODE_SAVE+$E000,y
:x14                lda   $D000,x
                    sta   OPCODE_SAVE+$D000,y
:x13                lda   $C000,x
                    sta   OPCODE_SAVE+$C000,y
:x12                lda   $B000,x
                    sta   OPCODE_SAVE+$B000,y
:x11                lda   $A000,x
                    sta   OPCODE_SAVE+$A000,y
:x10                lda   $9000,x
                    sta   OPCODE_SAVE+$9000,y
:x09                lda   $8000,x
                    sta   OPCODE_SAVE+$8000,y
:x08                lda   $7000,x
                    sta   OPCODE_SAVE+$7000,y
:x07                lda   $6000,x
                    sta   OPCODE_SAVE+$6000,y
:x06                lda   $5000,x
                    sta   OPCODE_SAVE+$5000,y
:x05                lda   $4000,x
                    sta   OPCODE_SAVE+$4000,y
:x04                lda   $3000,x
                    sta   OPCODE_SAVE+$3000,y
:x03                lda   $2000,x
                    sta   OPCODE_SAVE+$2000,y
:x02                lda   $1000,x
                    sta   OPCODE_SAVE+$1000,y
:x01                lda:  $0000,x
                    sta:  OPCODE_SAVE+$0000,y
:bottom             rts


; RestoreOpcode
;
; Restore the values back to the code field.
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = code field location * $1000
RestoreOpcode
                    jmp   (:tbl,x)

:tbl                da    :bottom
                    da    :do01,:do02,:do03,:do04
                    da    :do05,:do06,:do07,:do08
                    da    :do09,:do10,:do11,:do12
                    da    :do13,:do14,:do15,:do16

:do15               tax
                    bra   :x15
:do14               tax
                    bra   :x14
:do13               tax
                    bra   :x13
:do12               tax
                    bra   :x12
:do11               tax
                    bra   :x11
:do10               tax
                    bra   :x10
:do09               tax
                    bra   :x09
:do08               tax
                    bra   :x08
:do07               tax
                    bra   :x07
:do06               tax
                    bra   :x06
:do05               tax
                    bra   :x05
:do04               tax
                    bra   :x04
:do03               tax
                    bra   :x03
:do02               tax
                    bra   :x02
:do01               tax
                    bra   :x01
:do16               tax
:x16                lda   OPCODE_SAVE+$F000,y
                    sta   $F000,x
:x15                lda   OPCODE_SAVE+$E000,y
                    sta   $E000,x
:x14                lda   OPCODE_SAVE+$D000,y
                    sta   $D000,x
:x13                lda   OPCODE_SAVE+$C000,y
                    sta   $C000,x
:x12                lda   OPCODE_SAVE+$B000,y
                    sta   $B000,x
:x11                lda   OPCODE_SAVE+$A000,y
                    sta   $A000,x
:x10                lda   OPCODE_SAVE+$9000,y
                    sta   $9000,x
:x09                lda   OPCODE_SAVE+$8000,y
                    sta   $8000,x
:x08                lda   OPCODE_SAVE+$7000,y
                    sta   $7000,x
:x07                lda   OPCODE_SAVE+$6000,y
                    sta   $6000,x
:x06                lda   OPCODE_SAVE+$5000,y
                    sta   $5000,x
:x05                lda   OPCODE_SAVE+$4000,y
                    sta   $4000,x
:x04                lda   OPCODE_SAVE+$3000,y
                    sta   $3000,x
:x03                lda   OPCODE_SAVE+$2000,y
                    sta   $2000,x
:x02                lda   OPCODE_SAVE+$1000,y
                    sta   $1000,x
:x01                lda:  OPCODE_SAVE+$0000,y
                    sta:  $0000,x
:bottom             rts

; SetCodeEntry
;
; Patch in the low byte at the CODE_ENTRY. Must be called with 8-bit accumulator
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = address low byte
SetCodeEntry
                    jmp   (:tbl,x)
:tbl                da    :bottom-00,:bottom-03,:bottom-06,:bottom-09
                    da    :bottom-12,:bottom-15,:bottom-18,:bottom-21
                    da    :bottom-24,:bottom-27,:bottom-30,:bottom-33
                    da    :bottom-36,:bottom-39,:bottom-42,:bottom-45
                    da    :bottom-48
:top                sta   CODE_ENTRY+$F000,y
                    sta   CODE_ENTRY+$E000,y
                    sta   CODE_ENTRY+$D000,y
                    sta   CODE_ENTRY+$C000,y
                    sta   CODE_ENTRY+$B000,y
                    sta   CODE_ENTRY+$A000,y
                    sta   CODE_ENTRY+$9000,y
                    sta   CODE_ENTRY+$8000,y
                    sta   CODE_ENTRY+$7000,y
                    sta   CODE_ENTRY+$6000,y
                    sta   CODE_ENTRY+$5000,y
                    sta   CODE_ENTRY+$4000,y
                    sta   CODE_ENTRY+$3000,y
                    sta   CODE_ENTRY+$2000,y
                    sta   CODE_ENTRY+$1000,y
                    sta:  CODE_ENTRY+$0000,y
:bottom             rts

































































