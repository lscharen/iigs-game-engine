; Subroutines that deal with the horizontal scrolling in the "lite" blitter. The
; advantage of the lite blitter is that the entire code field is in one bank, so
; there is no need to chunk up the updates into 16-line pieces.  The entire height
; of the playfield can be done with a single unrolled loop.
;
; A = starting virtual line in the code field (0 - 207)
; X = number of lines to render (0 - 200)

_RestoreBG0OpcodesLite
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


_RestoreBG0OpcodesAltLite
:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:draw_count_x2      equ   tmp3
:exit_offset        equ   tmp4
:base_address       equ   tmp5
:exit_address       equ   tmp6
:draw_count_x6      equ   blttmp+10

; We do need to split the update into two parts so that we can handle the wrap-around portion

                    ldx   :lines_left_x2
                    lda   #208*2
                    sec
                    sbc   :virt_line_x2              ; calculate number of lines to the end of the buffer
                    cmp   :lines_left_x2
                    bcs   :one_pass                  ; if there's room, do it in one shot

; If the virtual screen wraps around the bank, then we need to split the update up
; into two pieces to efficiently restore the values without having to do the
; virtual_line -> physical_line conversion each time.

                    tax
                    jsr   :one_pass                  ; Go through with this draw count

                    stz   :virt_line_x2

                    lda   :lines_left_x2
                    sec
                    sbc   :draw_count_x2              ; this many left to draw. Fall through to finish up
                    tax

:one_pass
                    txa
                    sta   :draw_count_x2              ; this is the number of lines we will do right now
                    asl
                    adc   :draw_count_x2
                    sta   :draw_count_x6

                    phb

                    sep   #$20                       ; Set the data bank to the code field
                    lda   BTableHigh
                    pha
                    plb
                    rep   #$21                       ; clear the carry while we're here...

                    ldx   :virt_line_x2
                    ldal  BTableLow,x                ; Get the address of the first code field line
                    sta   :base_address

                    adc   #_LOW_SAVE
                    sta   :low_save_addr

                    lda   :base_address
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line
                    sta   :exit_address

                    sec
                    CopyXToYPrep  :do_restore;:draw_count_x6

                    ldx   :low_save_addr
                    ldy   :exit_address
:do_restore         jsr   $0000                      ; Jump in to do SCREEN_HEIGHT lines

                    stz   LastPatchOffset            ; Clear the value once completed
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

_ApplyBG0XPosLite
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

_ApplyBG0XPosAltLite
;:stk_save           equ   tmp0
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
:draw_count_x3      equ   blttmp                     ; steal even mode direct page temp space...
:draw_count_x6      equ   blttmp+2
:entry_jmp_addr     equ   blttmp+4
:low_save_addr      equ   blttmp+6
:draw_count_x3      equ   blttmp+8
:draw_count_x6      equ   blttmp+10
:entry_odd_addr     equ   blttmp+12
:exit_odd_addr      equ   blttmp+14

                    bit   #$0001
                    jne   :odd_case                  ; Specialized routines for even/odd cases

; If the exit byte is even, then the left edge is odd-aligned and we exit at this word.

                    tax
                    lda   CodeFieldEvenBRA-2,x
                    sta   :exit_bra

                    lda   Col2CodeOffset-2,x         ; offset from :base that is the exit location
                    sta   :exit_offset
                    sta   LastPatchOffset            ; Cache as a flag for later

; Calculate the entry point into the code field by calculating the right edge

                    txa                              ; lda StartXMod164
                    clc
                    adc   ScreenWidth                ; move to the right edge

                    cmp   #164                       ; Keep the value in range
                    bcc   *+5
                    sbc   #164

; Lookup the relative offset that we will be entering the code field.  Need to adjust the Col2CodeOffset
; to account for the position of the BRL instruction

                    tax
                    lda   Col2CodeOffset-2,x     ; offset from base
                    clc
                    adc   #-{_ENTRY_JMP+3}
                    sta   :opcode

; Now update the code field to get ready to execute. We set the bank register to the code
; field to make updates faster.  The primary actions to do are.
;
; 1. Saves the low operand byte in the code field (opcode is always $F4)
; 2. Writes the BRA instruction to exit the code field
; 3. Writes the JMP entry point to enter the code field
;
; We do need to split the update into two parts so that we can handle the wrap-around portion

                    ldx   :lines_left_x2
                    lda   #208*2
                    sec
                    sbc   :virt_line_x2              ; calculate number of lines to the end of the buffer
                    cmp   :lines_left_x2
                    bcs   :one_pass_even             ; if there's room, do it in one shot

; Since the screen height can be up to 200 lines and the virtual buffer size is 208, the common
; case will be that the blit will wrap around the end of the code field

                    tax
                    jsr   :one_pass_even                  ; Go through with this draw count

                    stz   :virt_line_x2

                    lda   :lines_left_x2
                    sec
                    sbc   :draw_count_x2              ; this many left to draw. Fall through to finish up
                    tax

:one_pass_even
                    txa
                    sta   :draw_count_x2              ; this is the number of lines we will do right now
                    asl
                    adc   :draw_count_x2
                    sta   :draw_count_x6
                    lsr
                    sta   :draw_count_x3

                    phb                              ; Save the existing bank

                    sep   #$20                       ; Set the data bank to the code field
                    lda   BTableHigh
                    pha
                    plb
                    rep   #$21                       ; clear the carry while we're here...

                    ldx   :virt_line_x2
                    ldal  BTableLow,x                ; Get the address of the code field line
                    sta   :base_address              ; Will use this address a few times

                    adc   #_ENTRY_JMP                ; Add the offsets in order to get absolute addresses
                    sta   :entry_jmp_addr
                    adc   #{_LOW_SAVE-_ENTRY_JMP}
                    sta   :low_save_addr

                    lda   :base_address
                    adc   :exit_offset               ; Add the offset to get the absolute address in the code field line
                    sta   :exit_address

; First step is to set the BRA instruction to exit the code field at the proper location.  There
; are two sub-steps to do here; we need to save the 8-bit value that exists at the location+1 and
; then overwrite it with the branch instruction.

                    sec                              ; These macros preform subtractions that do not underflow
                    CopyXToYPrep      :do_save_entry_e;:draw_count_x6
                    LiteSetConstPrep  :do_set_bra_e;:draw_count_x3
                    stal  :do_setopcode_e+1
                    stal  :do_set_rel_e+1

                    sep   #$20
                    ldy   :entry_jmp_addr
                    lda   #$82
:do_setopcode_e     jsr   $0000                       ; Copy in the BRL opcode into the entry point

                    ldx   :exit_address
                    inx
                    ldy   :low_save_addr
                    iny
:do_save_entry_e    jsr   $0000                       ; Copy a byte from offset x to y
                    rep   #$20

                    ldy   :exit_address
                    lda   :exit_bra
:do_set_bra_e       jsr   $0000                       ; Set the BRA instruction in the code field to exit

                    ldy   :entry_jmp_addr
                    iny
                    lda   :opcode
:do_set_rel_e       jsr   $0000                       ; Set the relative offset for all BRL instructions

                    plb
                    rts

; Odd case if very close to the even case, except that the code is entered a word later.  It is still
; exited at the same word.  There is extra work done because we have to save the third byte of the 
; exit location to fill in the left edge and we have to patch a different BRL to enter the code field
; afte the right-edge byte is pushed onto the screen 
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
                    lda   Col2CodeOffset,x
                    clc
                    adc   #-{_ENTRY_JMP+3}        ; In this case it gets loaded in the X-register
                    sta   :opcode

                    lda   Col2CodeOffset-2,x
                    clc
                    adc   #-{_ENTRY_ODD+3}
                    sta   :odd_entry_offset

; Main loop

                    ldx   :lines_left_x2
                    lda   #208*2
                    sec
                    sbc   :virt_line_x2              ; calculate number of lines to the end of the buffer
                    cmp   :lines_left_x2
                    bcs   :one_pass_odd             ; if there's room, do it in one shot

                    tax
                    jsr   :one_pass_odd

                    stz   :virt_line_x2

                    lda   :lines_left_x2
                    sec
                    sbc   :draw_count_x2              ; this many left to draw. Fall through to finish up
                    tax

:one_pass_odd
                    txa
                    sta   :draw_count_x2              ; this is the number of lines we will do right now
                    asl
                    adc   :draw_count_x2
                    sta   :draw_count_x6
                    lsr
                    sta   :draw_count_x3

                    phb                              ; Save the existing bank

                    sep   #$20
                    lda   BTableHigh                 ; Get the bank
                    pha
                    plb
                    rep   #$21

                    ldx   :virt_line_x2
                    ldal  BTableLow,x                ; Get the address of the first code field line
                    sta   :base_address              ; Save it to use as the base address

                    adc   #_ENTRY_JMP                ; Add the offsets in order to get absolute addresses
                    sta   :entry_jmp_addr
                    adc   #{_ENTRY_ODD-_ENTRY_JMP}
                    sta   :entry_odd_addr
                    adc   #{_EXIT_ODD-_ENTRY_ODD}
                    sta   :exit_odd_addr
                    adc   #{_LOW_SAVE-_EXIT_ODD}
                    sta   :low_save_addr

                    lda   :base_address
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line
                    sta   :exit_address

; Setup the jumps into the unrolled loops

                    sec
                    CopyXToYPrep      :do_save_entry_o;:draw_count_x6
                    stal  :do_save_high_byte+1
                    LiteSetConstPrep  :do_set_bra_o;:draw_count_x3
                    stal  :do_setopcode_o+1
                    stal  :do_set_rel_o+1
                    stal  :do_odd_code_entry+1

                    sep   #$20
                    ldy   :entry_jmp_addr
                    lda   #$A2
:do_setopcode_o     jsr   $0000                      ; Copy in the LDX opcode into the entry point

                    ldx   :exit_address
                    inx
                    inx
                    ldy   :exit_odd_addr
                    iny
:do_save_high_byte  jsr   $0000                      ; Copy high byte of the exit location into the odd handling path

                    ldx   :exit_address
                    inx
                    ldy   :low_save_addr
                    iny
:do_save_entry_o    jsr   $0000                      ; Save the low byte of the exit operand into a save location for restore later
                    rep   #$20

                    ldy   :exit_address
                    lda   :exit_bra
:do_set_bra_o       jsr   $0000                      ; Insert a BRA instruction over the saved word

                    ldy   :entry_jmp_addr
                    iny
                    lda   :opcode                    ; Store the same relative address to use for loading the entry word data
:do_set_rel_o       jsr   $0000

; The odd case need to do a bit of extra work

                    ldy   :entry_odd_addr
                    iny
                    lda   :odd_entry_offset
:do_odd_code_entry  jsr   $0000                          ; Fill in the BRL argument for the odd entry

                    plb
                    rts

_RestoreScanlineBG0OpcodesLite
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
                    jsr   _RestoreBG0OpcodesAltLite

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
;
; NOTE: This function is *exactly* the same as _ApplyScanlineBG0XPos with the exception that it calls
;       _ApplyBG0XPosAltLite instead of _ApplyBG0XPosAlt.  Should unify with an subroutine selector
_ApplyScanlineBG0XPosLite

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
                    jsr   _ApplyBG0XPosAltLite

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

; Copy from the offset at X to the offset at Y
;
; Y = code field offset
; X = value
CopyXToYPrep        mac
                    lda   #x2y_bottom
                    sbc   ]2                      ; count_x6
                    stal  ]1+1                    ; A jmp/jsr instruction
                    <<<
]line               equ   199
                    lup   200
                    lda:  {]line*_LINE_SIZE},x
                    sta:  {]line*_LINE_SIZE},y
]line               equ   ]line-1
                    --^
x2y_bottom          rts

; Set a constant 8-bit value across the code field
;
; Y = code field offset
LiteSetConstPrep    mac
                    lda   #lsc_bottom
                    sbc   ]2                   ; count_x3
                    stal  ]1+1                 ; A jmp/jsr instruction
                    <<<

]line               equ   199
                    lup   200
                    sta:  {]line*_LINE_SIZE},y
]line               equ   ]line-1
                    --^
lsc_bottom          rts
