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
:draw_count_x2      equ   tmp3
:exit_offset        equ   tmp4
:stk_save           equ   tmp5

                    phb                              ; Save data bank

                    asl
                    sta   :virt_line_x2              ; Keep track of it

                    txa
                    asl
                    sta   :lines_left_x2

                    lda   LastPatchOffset            ; If zero, there are no saved opcodes
                    sta   :exit_offset

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

; If there are saved opcodes that have not been restored, do not run this routine
                    lda   LastPatchOffset
                    beq   :ok
                    rts

; This code is fairly succinct.  See the corresponding code in Vert.s for more detailed comments.
:ok
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
                    lda   Col2CodeOffset-1,x
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

; This is a variant of the above routine that allows each x-position to be set independently from a table of value.  This is
; quite a bit slower than the other routine since we cannot store constant values for each line.
;
; We still want to perform operation in blocks of 16 to avoid repeatedly setting the data bank register for each line.  In
; order to accomplish this, the even/odd cases are split into separate code blocks and the unrolled loop will patch up
; all of the memory locations on each line, rather than doing each patch one at a time.  This may actually be more efficient
; since it eliminates several jmp (abs,x) / tax instructions and removed some register reloading.
;
; The two unrolled loop elements are:
;
; Even:
;   lda:  $0000,x                 ; Load from X = BTableLow + exit_offset
;   sta:  OPCODE_SAVE,y           ; Save the two byte in another area of the line code
;   lda   :exit_bra[n]
;   sta   $0000,x                 ; Replace the two bytes with a BRA instruction to exit the blitter
;   lda   :opcode[n]
;   sta:  CODE_ENTRY_OPCODE,y     ; CODE_ENTRY_OPCODE and CODE_ENTRY are adjacent -- could make this a single 16-bit store
;
; Odd:
;   Same as above, plus...
;   lda   :odd_entry_offset[n]    ; [8-bit] Get back into the code after fixing up the odd edge
;   sta:  ODD_ENTRY,y
;   lda:  $0001,x                 ; Save the high word in case the last instruction is PEA and we need to load the top byte
;   sta:  OPCODE_HIGH_SAVE,y
; 
_ApplyBG0XPosPerScanline
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

; If there are saved opcodes that have not been restored, do not run this routine
                    lda   LastPatchOffset
                    beq   :ok
                    rts

; In this routine, basically every horizontal parameter is based off of the :virt_line_x2 index
:ok
                    lda   StartYMod208               ; This is the base line of the virtual screen
                    asl
                    sta   :virt_line_x2              ; Keep track of it

                    lda   ScreenHeight
                    asl
                    sta   :lines_left_x2

; Sketch out the core structural elements of the loop + bank management

                    phb                              ; Save the existing bank
                    tsc
                    sta   :stk_save

:loop
                    ldx   :virt_line_x2

                    txa
                    and   #$001E
                    eor   #$FFFF
                    sec
                    adc   #2*16                      ; 2 * (16 - virt_line % 16).  This get us aligned to 16-line boundaries
                    min   :lines_left_x2             ; Make sure we handle cases where lines_left < aligned remainder
                    sta   :draw_count_x2             ; We are drawing this many lines on this iteration starting at _virt_line_x2

                    ldal  BTableHigh,x               ; Set the bank
                    pha
                    plb

                    jsr   :DoScanlineRange           ; Patch in the code field for this range (Bank is set)

                    lda   :draw_count_x2
                    clc                              ; advance to the virtual line after the segment we just
                    adc   :virt_line_x2              ; filled in
                    sta   :virt_line_x2

                    lda   :lines_left_x2             ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count_x2
                    sta   :lines_left_x2
                    jne   :loop

                    lda   :stk_save
                    tcs
                    plb
                    rts

; Run through and build an array of scanline data and place it in temporary zero page space.  Need a total of 48 bytes.
:BuildScanlineData

; First step, run though and create the tables for the copy routine
                    lda   StartXMod164Tbl,x
                    bit   #$0001
;                    bne   :bsd_odd

                    tay
                    lda   CodeFieldEvenBRA-2,y       ; The exit point comes after the left edge (reverse order due to stack)
                    sta   :exit_bra,x
                    lda   Col2CodeOffset-2,y
                    sta   :exit_offset,x
                    

:DoScanlineRange
                    ldx   :virt_line_x2

; First, calculate the exit point

                    ldal  StartXMod164Tbl,x          ; Get the origin for this line
                    bit   #$0001
                    bne   :is_odd                    ; Quickly switch to specialized even/odd routines

; For even offsets, the index is x - 2
; For odd offsets, the index is x - 1
;
; So, for both we can do (x - 1) & $FFFE = dec / and #$FFFE = lsr / asl + clears the carry

; This is an even-aligned line

;                    dec                              ; Move to the previous address for entry (a - 1) % 164
;                    dec                              ; Optimization: Coule eliminate this with a double-width tbale for CodeFieldEvenBRA
;                    bpl   *+5
;                    lda   #162

                    tay
                    lda   CodeFieldEvenBRA-2,y
                    sta   :exit_bra                  ; Store are exit_offset + 
                    lda   Col2CodeOffset-2,y
                    sta   :exit_offset

;                    tya
;                    adc   ScreenWidth
;                    cmp   #164                       ; Keep the value in range
;                    bcc   *+5
;                    sbc   #164
;                    tay

                    lda   Col2CodeOffset-2-1,y        ; -2 for even case , -1 to load value into high byte
                    and   #$FF00
;                    sta   :entry_offset
                    ora   #$004C                     ; set the entry_jmp opcode to JMP
                    sta   :opcode
;                    stz   :odd_entry_offset          ; mark as an even case

                    ldal  BTableLow,x                ; Get the address of the code field line
                    tay                              ; Save it to use as the base address
                    clc
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line
                    tax

                    clc
; This is the core even patch loop. The y-register tracks the base address of the starting line.  Set the x-register
; based on the per-line exit_offset and eveything else references other data

;                    tya
;                    adc   :exit_offset+{]line*2}
;                    tax
;                    lda:  {]line*$1000},x
;                    sta:  OPCODE_SAVE+{]line*$1000},y
;                    lda   :exit_bra+{]line*2}         ; Copy this value into all of the lines
;                    sta:  {]line*$1000},x
;                    lda   :entry_offset+{]line*2}     ; Pre-merged with the appropriate opcode + offset
;                    sta:  CODE_ENTRY_OPCODE+{]line*$1000},y

                    bra   :prep_complete

; This is an odd-aligned line
:is_odd
                    dec                              ; Remove the least-significant byte (must stay positive)
                    tay
                    lda   CodeFieldOddBRA,y
                    sta   :exit_bra
                    lda   Col2CodeOffset,y
                    sta   :exit_offset

                    tya
                    adc   ScreenWidth
                    cmp   #164                       ; Keep the value in range
                    bcc   *+5
                    sbc   #164
                    tay
                    lda   Col2CodeOffset,y
                    sta   :entry_offset              ; Will be used to load the data
                    lda   Col2CodeOffset-2,y
                    sta   :odd_entry_offset          ; will be the actual location to jump to
                    lda   #$00AF                     ; set the entry_jmp opcode to LDAL
                    sta   :opcode

:prep_complete
                    ldal  BTableLow,x                ; Get the address of the code field line
                    tay                              ; Save it to use as the base address
                    clc
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line

;                    sta   :exit_address
;                    sty   :base_address


;                    ldy   :base_address
;                    ldx   :exit_address              ; Save from this location (not needed in fast mode)
;                    SaveOpcode                       ; X = :exit_address on return
                    tax
                    lda:  $0000,x
                    sta:  OPCODE_SAVE+$0000,y


;                    txy                              ; ldy :exit_address -- starting at this address
;                    ldx   :draw_count_x2             ; Do this many lines
                    lda   :exit_bra                  ; Copy this value into all of the lines
;                    SetConst                         ; All registers are preserved
                    sta:  $0000,x

; Next, patch in the CODE_ENTRY value, which is the low byte of a JMP instruction. This is an
; 8-bit operation and, since the PEA code is bank aligned, we use the entry_offset value directly

                    sep   #$20

                    lda   :entry_offset
;                    ldy   :base_address
;                    SetCodeEntry                     ; All registers are preserved
                    sta:  CODE_ENTRY+$0000,y

; Now, patch in the opcode

                    lda   :opcode
;                    SetCodeEntryOpcode               ; All registers are preserved
                    sta:  CODE_ENTRY_OPCODE+$0000,y

; If this is an odd entry, also set the odd_entry low byte and save the operand high byte

                    lda   :odd_entry_offset
                    jeq   :not_odd

;                    SetOddCodeEntry                  ; All registers are preserved
                    sta:  ODD_ENTRY+$0000,y
;                    SaveHighOperand  :exit_address   ; Only used once, so "inline" it
                    ldx   :exit_address
                    lda:  $0002,x
                    sta:  OPCODE_HIGH_SAVE+$0000,y

:not_odd
                    rep   #$21                       ; clear the carry

                    lda   :virt_line_x2              ; advance to the virtual line after
                    adc   :draw_count_x2             ; filled in
                    sta   :virt_line_x2

                    lda   :lines_left_x2             ; subtract the number of lines we just completed
                    sec
                    sbc   :draw_count_x2
                    sta   :lines_left_x2
                    
                    jne   :loop

                    rts


; DoEvenRange
;
; Does all the core operations for an even range (16-bit accumulator and registers)
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = code field location * $1000
DoEvenRange         mac
                    asl                     ; mult the offset by 2 and clear the carry at the same time
                    adc   #dispTbl
                    stal  patch+1
patch               jmp   $0000
dispTbl             jmp   bottom
                    db    1
                    jmp   x01
                    db    1
                    jmp   x02
                    db    1
                    jmp   x03
                    db    1
                    jmp   x04
                    db    1
                    jmp   x05
                    db    1
                    jmp   x06
                    db    1
                    jmp   x07
                    db    1
                    jmp   x08
                    db    1
                    jmp   x09
                    db    1
                    jmp   x10
                    db    1
                    jmp   x11
                    db    1
                    jmp   x12
                    db    1
                    jmp   x13
                    db    1
                    jmp   x14
                    db    1
                    jmp   x15
                    db    1
x16                 tya
                    adc   :exit_offset+$1E
                    tax
                    lda:  $F000,x
                    sta:  OPCODE_SAVE+$F000,y
                    lda   :exit_bra+$1E
                    sta:  $F000,x
                    lda   :entry_offset+$1E                    ; Pre-merged with the appropriate opcode + offset
                    sta:  CODE_ENTRY_OPCODE+$F000,y

x15                 tya
                    adc   :exit_offset+$1E
                    tax
                    lda:  $E000,x
                    sta:  OPCODE_SAVE+$E000,y
                    lda   :exit_bra+$1C
                    sta:  $E000,x
                    lda   :entry_offset+$1C
                    sta:  CODE_ENTRY_OPCODE+$E000,y

x14                 lda   $D002,x
                    sta   OPCODE_HIGH_SAVE+$D000,y
x13                 lda   $C002,x
                    sta   OPCODE_HIGH_SAVE+$C000,y
x12                 lda   $B002,x
                    sta   OPCODE_HIGH_SAVE+$B000,y
x11                 lda   $A002,x
                    sta   OPCODE_HIGH_SAVE+$A000,y
x10                 lda   $9002,x
                    sta   OPCODE_HIGH_SAVE+$9000,y
x09                 lda   $8002,x
                    sta   OPCODE_HIGH_SAVE+$8000,y
x08                 lda   $7002,x
                    sta   OPCODE_HIGH_SAVE+$7000,y
x07                 lda   $6002,x
                    sta   OPCODE_HIGH_SAVE+$6000,y
x06                 lda   $5002,x
                    sta   OPCODE_HIGH_SAVE+$5000,y
x05                 lda   $4002,x
                    sta   OPCODE_HIGH_SAVE+$4000,y
x04                 lda   $3002,x
                    sta   OPCODE_HIGH_SAVE+$3000,y
x03                 lda   $2002,x
                    sta   OPCODE_HIGH_SAVE+$2000,y
x02                 lda   $1002,x
                    sta   OPCODE_HIGH_SAVE+$1000,y
x01                 lda:  $0002,x
                    sta:  OPCODE_HIGH_SAVE+$0000,y
bottom              <<<

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
