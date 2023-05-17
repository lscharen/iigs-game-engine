; Subroutines that deal with the horizontal scrolling.  The primary function of
; these routines are to adjust tables and patch in new values into the code field
; when the virtual X-position of the play field changes.

; NOTE: There is still quite a bit of work done in the blitter to figure out if an
; opcode is a PEA, LDA or JMP.  If there _some_ way that we could engineer a single
; target opcode change that would allow us to take different code branches in the 
; blitter based on the opcode since the save/restore code has a change to look
; at the opcode now; before the blitter executes.
;
; PEA       = $F4 = %1111 0100
; LDA (),y  = $B1 = %1011 0001
; LDA 0,x   = $B5 = %1011 0101
; JMP addr  = $4C = %0100 1100
;
; IDEA: Save the 2-byte code directly after a BRA opcode to unconditionally branch out after masking. Would be a
;       bit tricky to handle the forward and backward branches.  
;
; Improvement.  The current "fast path" for the PEA operand is
;
; ldal  l_is_jmp+1-base   ; 6
; bit   #$000B            ; 3
; bne   :chk_jmp          ; 2
; sep   #$20              ; 3
; ldal  l_is_jmp+3-base   ; 5
; pha                     ; 3 = 22 cycles
;
; If we do an immediate branch to a routine that we _know_ is the right one, the code reduces to
;
; bra   pea               ; 3
; sep   #$20              ; 3
; ldal  l_is_jmp+3-base   ; 5
; pha                     ; 3 = 17 cycles
;
; Even if some additional branch is needed, it is likely to be a small improvement for the PEA case
; and a significant improvement for the other cases since it avoids the chain of BIT instructions

; Simple function that restores the saved opcode that are stashed in _applyBG0Xpos.  It is
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
:exit_offset        equ   tmp4

                    asl
                    sta   :virt_line_x2              ; Keep track of it

                    txa
                    asl
                    sta   :lines_left_x2

                    lda   LastPatchOffset            ; If zero, there are no saved opcodes
                    sta   :exit_offset

_RestoreBG0OpcodesAlt
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:draw_count_x2      equ   tmp3
:exit_offset        equ   tmp4
:stk_save           equ   tmp5

                    phb                              ; Save data bank
                    tsc
                    sta   :stk_save

:loop
                    ldx   :virt_line_x2
                    ldal  BTableLow,x                ; Get the address of the first code field line
                    tay

                    ldal  BTableHigh,x               ; This intentionally leaks one byte on the stack
                    pha
                    plb                              ; This is the bank that will receive the updates

                    txa                              ; lda   :virt_line_x2
                    and   #$001E
                    eor   #$FFFF
                    sec
                    adc   #32
                    min   :lines_left_x2
                    sta   :draw_count_x2             ; Do half of this many lines

                                                     ; y is already set to :base_address
                    tax                              ; :draw_count * 2
                    clc
                    adc   :virt_line_x2
                    sta   :virt_line_x2

                    tya
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line

                    RestoreOpcode

                    lda   :lines_left_x2             ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count_x2
                    sta   :lines_left_x2

                    jne   :loop

                    stz   LastPatchOffset            ; Clear the value once completed

                    lda   :stk_save
                    tcs
                    plb
                    rts

; Based on the current value of StartX in the direct page, patch up the code fields
; to render the correct data. Note that we do *not* do the OpcodeRestore in this
; routine.  The reason is that the restore *must* be applied using the (StartX, StartY)
; values from the previous frame, which requires logic that is not relevant to setting
; up the code field.
;
; This function is where the reverse-mapping aspect of the code field is compensated
; for.  In the initialize case where X = 0, the exit point is at the *end* of 
; the code buffer line
;
; +----+----+ ... +----+----+----+
; | 82 | 80 |     | 04 | 02 | 00 |
; +----+----+ ... +----+----+----+
;                                ^ x=0
;
; As the screen scrolls right-to-left, the exit position moves to earlier memory
; locations until wrapping around from 163 to 0.
;
; The net calculation are
;
;   x_exit = (164 - x) % 164
;   x_enter = (164 - x - width) % 164
;

; Small routine to put the data in a consistent state. Called before any routines need to draw on
; the code buffer, but before we patch out the instructions.
_ApplyBG0XPosPre
                    lda   StartX                     ; This is the starting byte offset (0 - 163)
                    jsr   Mod164
                    sta   StartXMod164
                    rts

_ApplyBG0XPos
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2

; If there are saved opcodes that have not been restored, do not run this routine
                    lda   LastPatchOffset
                    beq   *+3
                    rts

; This code is fairly succinct.  See the corresponding code in Vert.s for more detailed comments.

                    lda   StartYMod208               ; This is the base line of the virtual screen
                    asl
                    sta   :virt_line_x2              ; Keep track of it

                    lda   ScreenHeight
                    asl
                    sta   :lines_left_x2

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
;
; Now, the left edge of the screen is pushed last, so we need to exit one instruction *after*
; the location (163 - StartX % 164)
;
; x = 0
;
;  | PEA $0000 |
;  +-----------+
;  | PEA $0000 | 
;  +-----------+ 
;  | JMP loop  | <-- Exit here
;  +-----------+
;
; x = 1 and 2
;
;  | PEA $0000 |
;  +-----------+
;  | PEA $0000 | <-- Exit Here
;  +-----------+ 
;  | JMP loop  |
;  +-----------+

                    lda   StartXMod164

; Alternate entry point if the virt_line_x2 and lines_left_x2 and XMod164 values are passed in externally

_ApplyBG0XPosAlt
:stk_save           equ   tmp0
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:draw_count_x2      equ   tmp3
:exit_offset        equ   tmp4
:entry_offset       equ   tmp5
:exit_bra           equ   tmp6
:exit_address       equ   tmp7
:base_address       equ   tmp8
:opcode             equ   tmp9
:odd_entry_offset   equ   tmp10

                    bit   #$0001
                    jne   :odd_case                  ; Specialized routines for even/odd cases

; If the exit byte is odd, then the left edge is even-aligned and we round down and exit at at
; that word.
;
; If the exit byte is even, then the left edge is odd-aligned and we exit at this word.

                    tax
                    lda   CodeFieldEvenBRA-2,x
                    sta   :exit_bra
                    lda   Col2CodeOffset-2,x
                    sta   :exit_offset
                    sta   LastPatchOffset            ; Cache as a flag for later

; Calculate the entry point into the code field by calculating the right edge

                    txa                              ; lda StartXMod164
                    clc
                    adc   ScreenWidth                ; move to the right edge

                    cmp   #164                       ; Keep the value in range
                    bcc   *+5
                    sbc   #164

; Same logic as above. If the right edge is odd, then the full word needs to be drawn and we
; will enter at that index, rounded down.
;
; If the right edge is even, then only the low byte needs to be drawn, which is handled before
; entering the code field.  So enter one word before the right edge.
;
; We performan an optimization here and fuse the entry_offset byte with the opcode that is
; changed depending on even/odd alignment in order to do the work with a single 16-bit
; store instead of two 8-bit stores.

                    tax
                    lda   Col2CodeOffset-3,x          ; Only use the one byte for the entry_offset
                    and   #$FF00
                    ora   #$004C                      ; Merge in the JMP instruction
                    sta   :opcode

; Main loop that 
;
; 1. Saves the opcodes in the code field
; 2. Writes the BRA instruction to exit the code field
; 3. Writes the JMP entry point to enter the code field

                    phb                              ; Save the existing bank
                    tsc
                    sta   :stk_save

:even_loop
                    ldx   :virt_line_x2

                    ldal  BTableHigh,x               ; Get the bank
                    pha
                    plb

                    ldal  BTableLow,x                ; Get the address of the first code field line
                    tay                              ; Save it to use as the base address

                    txa                              ; Calculate number of lines to draw on this iteration
                    and   #$001E
                    eor   #$FFFF
                    sec
                    adc   #32
                    min   :lines_left_x2
                    sta   :draw_count_x2
                    tax                              ; Use for the first iteration

                    tya
                    clc
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line
                    sta   :exit_address
                    sty   :base_address

; First step is to set the BRA instruction to exit the code field at the proper location.  There
; are two sub-steps to do here; we need to save the 16-bit value that exists at the location and
; then overwrite it with the branch instruction.
;
; Special note, the SaveOpcode function stores the opcode *within* the code field as it is
; used in odd-aligned cases to determine how to draw the 8-bit value on the left edge of the
; screen
                                                     ; y is already set to :base_address
;                    ldx   :draw_count_x2            ; :draw_count_x2
;                    lda   :exit_address             ; Save from this location (not needed in fast mode)
                    SaveOpcode                       ; X = :exit_address on return

                    txy                              ; ldy :exit_address -- starting at this address
                    ldx   :draw_count_x2             ; Do this many lines
                    lda   :exit_bra                  ; Copy this value into all of the lines
                    SetConst                         ; All registers are preserved

; Now, patch in the opcode + code entry_offset

                    ldy   :base_address
                    lda   :opcode
                    SetCodeEntryOpcode               ; All registers are preserved

; Do the end of the loop -- update the virtual line counter and reduce the number
; of lines left to render

                    clc
                    lda   :virt_line_x2              ; advance to the virtual line after
                    adc   :draw_count_x2             ; filled in
                    sta   :virt_line_x2

                    lda   :lines_left_x2             ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count_x2
                    sta   :lines_left_x2

                    jne   :even_loop

                    lda   :stk_save
                    tcs
                    plb
                    rts

:odd_case
                    dec
                    tax
                    lda   CodeFieldOddBRA,x
                    sta   :exit_bra
                    lda   Col2CodeOffset,x
                    sta   :exit_offset
                    sta   LastPatchOffset            ; Cache as a flag for later

                    txa                              ; StartXMod164 - 1
                    clc
                    adc   ScreenWidth
                    cmp   #164                       ; Keep the value in range
                    bcc   *+5
                    sbc   #164

                    tax
                    lda   Col2CodeOffset-1,x         ; Odd offset to get the value in the high byte
                    and   #$FF00
                    ora   #$00AF
                    sta   :opcode

                    lda   Col2CodeOffset-2,x
                    sta   :odd_entry_offset

; Main loop

                    phb                              ; Save the existing bank
                    tsc
                    sta   :stk_save

:odd_loop
                    ldx   :virt_line_x2

                    ldal  BTableHigh,x               ; Get the bank
                    pha
                    plb

                    ldal  BTableLow,x                ; Get the address of the first code field line
                    tay                              ; Save it to use as the base address

                    txa                              ; Calculate number of lines to draw on this iteration
                    and   #$001E
                    eor   #$FFFF
                    sec
                    adc   #32
                    min   :lines_left_x2
                    sta   :draw_count_x2
                    tax                              ; Use for the first iteration

                    tya
                    clc
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line
                    sta   :exit_address
                    sty   :base_address

; At this point y = :base_address, x = :draw_count_x2 and the accumulator is the exit_address

                    SaveOpcodeAndOperand             ; X = :exit_address on return

                    txy                              ; ldy :exit_address -- starting at this address
                    ldx   :draw_count_x2             ; Do this many lines
                    lda   :exit_bra                  ; Copy this value into all of the lines
                    SetConst                         ; All registers are preserved

; Now, patch in the opcode + code entry_offset

                    ldy   :base_address
                    lda   :opcode
                    SetCodeEntryOpcode               ; All registers are preserved

; The odd case need to do a bit of extra work

                    sep   #$20
                    lda   :odd_entry_offset
                    SetOddCodeEntry                  ; All registers are preserved
                    rep   #$21                       ; Clear the carry

                    lda   :virt_line_x2              ; advance to the virtual line after
                    adc   :draw_count_x2             ; filled in
                    sta   :virt_line_x2

                    lda   :lines_left_x2             ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count_x2
                    sta   :lines_left_x2

                    jne   :odd_loop

                    lda   :stk_save
                    tcs
                    plb
                    rts

_RestoreScanlineBG0Opcodes
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:exit_offset        equ   tmp4

; Avoid local var collisions
:virt_line_pos_x2   equ   tmp11
:total_left_x2      equ   tmp12
:current_count_x2   equ   tmp13
:ptr                equ   tmp14

                    asl
                    sta   :virt_line_pos_x2
                    tay

                    txa
                    asl
                    sta   :total_left_x2

                    lda   StartXMod164Tbl
                    sta   :ptr
                    lda   StartXMod164Tbl+2
                    sta   :ptr+2

; Patch our the ranges from the StartXMod164Tbl array starting at the first virtual line
:loop
                    lda   [:ptr],y
                    and   #$FF00                    ; Determine how many sequential lines to restore
                    xba
                    inc
                    asl
                    min   :total_left_x2            ; Don't draw more than the number of lines that are left to process
                    sta   :current_count_x2         ; Save a copy for later

                    sta   :lines_left_x2            ; Set the parameter
                    sty   :virt_line_x2             ; Set the parameter
                    lda   LastOffsetTbl,y
                    sta   :exit_offset
                    jsr   _RestoreBG0OpcodesAlt

                    clc
                    lda   :virt_line_pos_x2   
                    adc   :current_count_x2
                    cmp   #208*2                    ; Do the modulo check in this loop
                    bcc   *+5
                    sbc   #208*2
                    sta   :virt_line_pos_x2
                    tay

                    lda   :total_left_x2
                    sec
                    sbc   :current_count_x2
                    sta   :total_left_x2
                    bne   :loop

                    rts

; This is a variant of the above routine that allows each x-position to be set independently from a table of value.  This is
; quite a bit slower than the other routine since we cannot store constant values for each line.
;
; This routine operates at a higher level and does not try to be super optimized for the case where every line has a different
; set of parameters.  Instead, we optimize for the case where there are a few large ranges of the screen moving at different
; rates, e.g. a fixed status bar area on top, a slow-scrolling area in the middle and a fast are in the foreground.
;
; The table that drives this is dense and has the following format for each word
;
; Bits 0 - 7:  X mod 164 value
; Bits 8 - 15: Number of scanline to persist this mod value
;
; So, if the first 10 entries has a mod value of 5, they would look like: $0905, $0805, $0705, ... $0105, $0005 
;
; This allows the code to start an an arbitrary location and immeditely sync up with the modulo list. It also allows
; the code to easily skip ranges of constant values using the existing _ApplyBG0XPos function as a subroutine.
_ApplyScanlineBG0XPos

; Copies of the local variables in _ApplyBG0XPos
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:exit_offset        equ   tmp4

; Avoid local var collision with _ApplyBG0XPos
:virt_line_pos_x2   equ   tmp11
:total_left_x2      equ   tmp12
:current_count_x2   equ   tmp13
:ptr                equ   tmp14

                    lda   StartXMod164Tbl
                    sta   :ptr
                    lda   StartXMod164Tbl+2
                    sta   :ptr+2
                    ora   :ptr
                    bne   *+3                        ; null pointer check
                    rts

                    lda   StartYMod208               ; This is the base line of the virtual screen
                    asl
                    sta   :virt_line_pos_x2
                    tay

                    lda   ScreenHeight
                    asl
                    sta   :total_left_x2

; Patch our the ranges from the StartXMod164Tbl array starting at the first virtual line
:loop
                    lda   [:ptr],y
                    tax

                    and   #$FF00                    ; Determine how many sequential lines have this mod value
                    xba
                    inc
                    asl
                    min   :total_left_x2            ; Don't draw more than the number of lines that are left to process
                    sta   :current_count_x2         ; Save a copy for later

                    sta   :lines_left_x2            ; Set the parameter
                    sty   :virt_line_x2             ; Set the parameter
                    txa                             ; Put the X mod 164 value in the accumulator
                    and   #$00FF
                    jsr   _ApplyBG0XPosAlt

                    lda   :exit_offset              ; Get the direct address in the code field that was overwritten
                    ldy   :virt_line_pos_x2   
                    sta   LastOffsetTbl,y           ; Stash it for use by the per-scanline resotre function

                    tya
                    clc
                    adc   :current_count_x2
                    cmp   #208*2                    ; Do the modulo check in this loop
                    bcc   *+5
                    sbc   #208*2
                    sta   :virt_line_pos_x2
                    tay

                    lda   :total_left_x2
                    sec
                    sbc   :current_count_x2
                    sta   :total_left_x2
                    bne   :loop

                    rts

; SaveHighOperand
;
; Save the high byte of the 3-byte code field instruction into the odd handler at the end
; of each line.  This is only needed
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = code field location * $1000
SaveHighOperand     mac
                    jmp   (dispTbl,x)
dispTbl             da    bottom
                    da    do01,do02,do03,do04
                    da    do05,do06,do07,do08
                    da    do09,do10,do11,do12
                    da    do13,do14,do15,do16

do15                ldx   ]1                   ; accumulator is in 8-bit mode, so can't use TAX
                    bra   x15
do14                ldx   ]1
                    bra   x14
do13                ldx   ]1
                    bra   x13
do12                ldx   ]1
                    bra   x12
do11                ldx   ]1
                    bra   x11
do10                ldx   ]1
                    bra   x10
do09                ldx   ]1
                    bra   x09
do08                ldx   ]1
                    bra   x08
do07                ldx   ]1
                    bra   x07
do06                ldx   ]1
                    bra   x06
do05                ldx   ]1
                    bra   x05
do04                ldx   ]1
                    bra   x04
do03                ldx   ]1
                    bra   x03
do02                ldx   ]1
                    bra   x02
do01                ldx   ]1
                    bra   x01
do16                ldx   ]1
x16                 lda   $F001,x
                    sta   OPCODE_HIGH_SAVE+$F000,y
x15                 lda   $E001,x
                    sta   OPCODE_HIGH_SAVE+$E000,y
x14                 lda   $D001,x
                    sta   OPCODE_HIGH_SAVE+$D000,y
x13                 lda   $C001,x
                    sta   OPCODE_HIGH_SAVE+$C000,y
x12                 lda   $B001,x
                    sta   OPCODE_HIGH_SAVE+$B000,y
x11                 lda   $A001,x
                    sta   OPCODE_HIGH_SAVE+$A000,y
x10                 lda   $9001,x
                    sta   OPCODE_HIGH_SAVE+$9000,y
x09                 lda   $8001,x
                    sta   OPCODE_HIGH_SAVE+$8000,y
x08                 lda   $7001,x
                    sta   OPCODE_HIGH_SAVE+$7000,y
x07                 lda   $6001,x
                    sta   OPCODE_HIGH_SAVE+$6000,y
x06                 lda   $5001,x
                    sta   OPCODE_HIGH_SAVE+$5000,y
x05                 lda   $4001,x
                    sta   OPCODE_HIGH_SAVE+$4000,y
x04                 lda   $3001,x
                    sta   OPCODE_HIGH_SAVE+$3000,y
x03                 lda   $2001,x
                    sta   OPCODE_HIGH_SAVE+$2000,y
x02                 lda   $1001,x
                    sta   OPCODE_HIGH_SAVE+$1000,y
x01                 lda:  $0001,x
                    sta:  OPCODE_HIGH_SAVE+$0000,y
bottom              <<<

; SaveOpcode
;
; Save the values to the restore location.  This should only be used to patch the
; code field since the save location is fixed.  
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = code field location * $1000
SaveOpcode          mac
                    jmp   (dispTbl,x)
dispTbl             da    bottom
                    da    do01,do02,do03,do04
                    da    do05,do06,do07,do08
                    da    do09,do10,do11,do12
                    da    do13,do14,do15,do16

do15                tax
                    bra   x15
do14                tax
                    bra   x14
do13                tax
                    bra   x13
do12                tax
                    bra   x12
do11                tax
                    bra   x11
do10                tax
                    bra   x10
do09                tax
                    bra   x09
do08                tax
                    bra   x08
do07                tax
                    bra   x07
do06                tax
                    bra   x06
do05                tax
                    bra   x05
do04                tax
                    bra   x04
do03                tax
                    bra   x03
do02                tax
                    bra   x02
do01                tax
                    bra   x01
do16                tax
x16                 lda   $F000,x
                    sta   OPCODE_SAVE+$F000,y
x15                 lda   $E000,x
                    sta   OPCODE_SAVE+$E000,y
x14                 lda   $D000,x
                    sta   OPCODE_SAVE+$D000,y
x13                 lda   $C000,x
                    sta   OPCODE_SAVE+$C000,y
x12                 lda   $B000,x
                    sta   OPCODE_SAVE+$B000,y
x11                 lda   $A000,x
                    sta   OPCODE_SAVE+$A000,y
x10                 lda   $9000,x
                    sta   OPCODE_SAVE+$9000,y
x09                 lda   $8000,x
                    sta   OPCODE_SAVE+$8000,y
x08                 lda   $7000,x
                    sta   OPCODE_SAVE+$7000,y
x07                 lda   $6000,x
                    sta   OPCODE_SAVE+$6000,y
x06                 lda   $5000,x
                    sta   OPCODE_SAVE+$5000,y
x05                 lda   $4000,x
                    sta   OPCODE_SAVE+$4000,y
x04                 lda   $3000,x
                    sta   OPCODE_SAVE+$3000,y
x03                 lda   $2000,x
                    sta   OPCODE_SAVE+$2000,y
x02                 lda   $1000,x
                    sta   OPCODE_SAVE+$1000,y
x01                 lda:  $0000,x
                    sta:  OPCODE_SAVE+$0000,y
bottom
                    <<<

; SaveOpcodeAndOperand
;
; Save both the opcode and operand at the same time
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = code field location * $1000
SaveOpcodeAndOperand mac
                    jmp   (dispTbl,x)
dispTbl             da    bottom
                    da    do01,do02,do03,do04
                    da    do05,do06,do07,do08
                    da    do09,do10,do11,do12
                    da    do13,do14,do15,do16

do15                tax
                    jmp   x15
do14                tax
                    jmp   x14
do13                tax
                    jmp   x13
do12                tax
                    jmp   x12
do11                tax
                    jmp   x11
do10                tax
                    jmp   x10
do09                tax
                    jmp   x09
do08                tax
                    jmp   x08
do07                tax
                    jmp   x07
do06                tax
                    jmp   x06
do05                tax
                    jmp   x05
do04                tax
                    jmp   x04
do03                tax
                    jmp   x03
do02                tax
                    jmp   x02
do01                tax
                    jmp   x01
do16                tax
x16                 lda   $F000,x
                    sta   OPCODE_SAVE+$F000,y
                    lda   $F001,x
                    sta   OPCODE_HIGH_SAVE+$F000,y
x15                 lda   $E000,x
                    sta   OPCODE_SAVE+$E000,y
                    lda   $E001,x
                    sta   OPCODE_HIGH_SAVE+$E000,y
x14                 lda   $D000,x
                    sta   OPCODE_SAVE+$D000,y
                    lda   $D001,x
                    sta   OPCODE_HIGH_SAVE+$D000,y
x13                 lda   $C000,x
                    sta   OPCODE_SAVE+$C000,y
                    lda   $C001,x
                    sta   OPCODE_HIGH_SAVE+$C000,y
x12                 lda   $B000,x
                    sta   OPCODE_SAVE+$B000,y
                    lda   $B001,x
                    sta   OPCODE_HIGH_SAVE+$B000,y
x11                 lda   $A000,x
                    sta   OPCODE_SAVE+$A000,y
                    lda   $A001,x
                    sta   OPCODE_HIGH_SAVE+$A000,y
x10                 lda   $9000,x
                    sta   OPCODE_SAVE+$9000,y
                    lda   $9001,x
                    sta   OPCODE_HIGH_SAVE+$9000,y
x09                 lda   $8000,x
                    sta   OPCODE_SAVE+$8000,y
                    lda   $8001,x
                    sta   OPCODE_HIGH_SAVE+$8000,y
x08                 lda   $7000,x
                    sta   OPCODE_SAVE+$7000,y
                    lda   $7001,x
                    sta   OPCODE_HIGH_SAVE+$7000,y
x07                 lda   $6000,x
                    sta   OPCODE_SAVE+$6000,y
                    lda   $6001,x
                    sta   OPCODE_HIGH_SAVE+$6000,y
x06                 lda   $5000,x
                    sta   OPCODE_SAVE+$5000,y
                    lda   $5001,x
                    sta   OPCODE_HIGH_SAVE+$5000,y
x05                 lda   $4000,x
                    sta   OPCODE_SAVE+$4000,y
                    lda   $4001,x
                    sta   OPCODE_HIGH_SAVE+$4000,y
x04                 lda   $3000,x
                    sta   OPCODE_SAVE+$3000,y
                    lda   $3001,x
                    sta   OPCODE_HIGH_SAVE+$3000,y
x03                 lda   $2000,x
                    sta   OPCODE_SAVE+$2000,y
                    lda   $2001,x
                    sta   OPCODE_HIGH_SAVE+$2000,y
x02                 lda   $1000,x
                    sta   OPCODE_SAVE+$1000,y
                    lda   $1001,x
                    sta   OPCODE_HIGH_SAVE+$1000,y
x01                 lda:  $0000,x
                    sta:  OPCODE_SAVE+$0000,y
                    lda:  $0001,x
                    sta:  OPCODE_HIGH_SAVE+$0000,y
bottom
                    <<<

; RestoreOpcode
;
; Restore the values back to the code field.
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = code field location * $1000
RestoreOpcode       mac
                    jmp   (dispTbl,x)
dispTbl             da    bottom
                    da    do01,do02,do03,do04
                    da    do05,do06,do07,do08
                    da    do09,do10,do11,do12
                    da    do13,do14,do15,do16

do15                tax
                    bra   x15
do14                tax
                    bra   x14
do13                tax
                    bra   x13
do12                tax
                    bra   x12
do11                tax
                    bra   x11
do10                tax
                    bra   x10
do09                tax
                    bra   x09
do08                tax
                    bra   x08
do07                tax
                    bra   x07
do06                tax
                    bra   x06
do05                tax
                    bra   x05
do04                tax
                    bra   x04
do03                tax
                    bra   x03
do02                tax
                    bra   x02
do01                tax
                    bra   x01
do16                tax
x16                 lda   OPCODE_SAVE+$F000,y
                    sta   $F000,x
x15                 lda   OPCODE_SAVE+$E000,y
                    sta   $E000,x
x14                 lda   OPCODE_SAVE+$D000,y
                    sta   $D000,x
x13                 lda   OPCODE_SAVE+$C000,y
                    sta   $C000,x
x12                 lda   OPCODE_SAVE+$B000,y
                    sta   $B000,x
x11                 lda   OPCODE_SAVE+$A000,y
                    sta   $A000,x
x10                 lda   OPCODE_SAVE+$9000,y
                    sta   $9000,x
x09                 lda   OPCODE_SAVE+$8000,y
                    sta   $8000,x
x08                 lda   OPCODE_SAVE+$7000,y
                    sta   $7000,x
x07                 lda   OPCODE_SAVE+$6000,y
                    sta   $6000,x
x06                 lda   OPCODE_SAVE+$5000,y
                    sta   $5000,x
x05                 lda   OPCODE_SAVE+$4000,y
                    sta   $4000,x
x04                 lda   OPCODE_SAVE+$3000,y
                    sta   $3000,x
x03                 lda   OPCODE_SAVE+$2000,y
                    sta   $2000,x
x02                 lda   OPCODE_SAVE+$1000,y
                    sta   $1000,x
x01                 lda:  OPCODE_SAVE+$0000,y
                    sta:  $0000,x
bottom
                    <<<

; SetCodeEntry
;
; Patch in the low byte at the CODE_ENTRY. Must be called with 8-bit accumulator
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = address low byte
SetCodeEntry        mac
                    jmp   (dispTbl,x)
dispTbl             da    bottom-00,bottom-03,bottom-06,bottom-09
                    da    bottom-12,bottom-15,bottom-18,bottom-21
                    da    bottom-24,bottom-27,bottom-30,bottom-33
                    da    bottom-36,bottom-39,bottom-42,bottom-45
                    da    bottom-48
                    sta   CODE_ENTRY+$F000,y
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
bottom
                    <<<

; SetOddCodeEntry
;
; Patch in the low byte at the ODD_ENTRY. Must be called with 8-bit accumulator
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = address low byte
SetOddCodeEntry     mac
                    jmp   (dispTbl,x)
dispTbl             da    bottom-00,bottom-03,bottom-06,bottom-09
                    da    bottom-12,bottom-15,bottom-18,bottom-21
                    da    bottom-24,bottom-27,bottom-30,bottom-33
                    da    bottom-36,bottom-39,bottom-42,bottom-45
                    da    bottom-48
                    sta   ODD_ENTRY+$F000,y
                    sta   ODD_ENTRY+$E000,y
                    sta   ODD_ENTRY+$D000,y
                    sta   ODD_ENTRY+$C000,y
                    sta   ODD_ENTRY+$B000,y
                    sta   ODD_ENTRY+$A000,y
                    sta   ODD_ENTRY+$9000,y
                    sta   ODD_ENTRY+$8000,y
                    sta   ODD_ENTRY+$7000,y
                    sta   ODD_ENTRY+$6000,y
                    sta   ODD_ENTRY+$5000,y
                    sta   ODD_ENTRY+$4000,y
                    sta   ODD_ENTRY+$3000,y
                    sta   ODD_ENTRY+$2000,y
                    sta   ODD_ENTRY+$1000,y
                    sta:  ODD_ENTRY+$0000,y
bottom
                    <<<

; SetCodeEntryOpcode
;
; Patch in the opcode at the CODE_ENTRY_OPCODE. Must be called with 8-bit accumulator
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = opcode value
SetCodeEntryOpcode  mac
                    jmp   (dispTbl,x)
dispTbl             da    bottom-00,bottom-03,bottom-06,bottom-09
                    da    bottom-12,bottom-15,bottom-18,bottom-21
                    da    bottom-24,bottom-27,bottom-30,bottom-33
                    da    bottom-36,bottom-39,bottom-42,bottom-45
                    da    bottom-48
                    sta   CODE_ENTRY_OPCODE+$F000,y
                    sta   CODE_ENTRY_OPCODE+$E000,y
                    sta   CODE_ENTRY_OPCODE+$D000,y
                    sta   CODE_ENTRY_OPCODE+$C000,y
                    sta   CODE_ENTRY_OPCODE+$B000,y
                    sta   CODE_ENTRY_OPCODE+$A000,y
                    sta   CODE_ENTRY_OPCODE+$9000,y
                    sta   CODE_ENTRY_OPCODE+$8000,y
                    sta   CODE_ENTRY_OPCODE+$7000,y
                    sta   CODE_ENTRY_OPCODE+$6000,y
                    sta   CODE_ENTRY_OPCODE+$5000,y
                    sta   CODE_ENTRY_OPCODE+$4000,y
                    sta   CODE_ENTRY_OPCODE+$3000,y
                    sta   CODE_ENTRY_OPCODE+$2000,y
                    sta   CODE_ENTRY_OPCODE+$1000,y
                    sta:  CODE_ENTRY_OPCODE+$0000,y
bottom
                    <<<
