; This support an alternate engine mode.  When in scanline mode the renderer does not use the
; global StartX and StartY parameters to set up the code field.  Instead, an array of scanline
; parameters must be provided to the blitter.
;
; This is a low-level mode and it is assumed that the arrays will contain valid values.  This
; process is quite a bit slower that the normal setup because it must calculate code field
; entry points for each line, instead of once for the entire frame.

_ScanlineBG0XPos

:stk_save           equ   tmp0
:virt_line_x2       equ   tmp1
:last_line_x2       equ   tmp2
:src_bank           equ   tmp3
:exit_offset        equ   tmp4
:entry_offset       equ   tmp5
:exit_bra           equ   tmp6
:exit_address       equ   tmp7
:base_address       equ   tmp8
:opcode             equ   tmp9
:odd_entry_offset   equ   tmp10

                    lda   StartYMod208               ; This is the base line of the virtual screen
                    asl
                    sta   :virt_line_x2              ; Keep track of it

                    lda   ScreenHeight
                    asl
                    clc
                    adc   :virt_line_x2
                    sta   :last_line_x2

                    phb
                    phb
                    pla
                    and   #$FF00
                    sta   :src_bank

:loop
                    ldx   :virt_line_x2

                    lda   StartXMod164Arr,x          ; Get the offset for this line
                    dec                              ; The exit point is one byte sooner
                    bpl   *+5
                    lda   #163

                    bit   #$0001                     ; if odd, then original number was even
                    beq   :odd_exit                  ; if even, the original number was odd

                    ; This is the even code path
                    and   #$FFFE
                    tay
                    lda   CodeFieldEvenBRA,y
                    sta   :exit_bra
                    lda   Col2CodeOffset,y
                    sta   :exit_offset
                    sta   LastPatchOffsetArr,x       ; Cache afor later
                    bra   :do_entry

; This is the odd code path
:odd_exit           tay
                    lda   CodeFieldOddBRA,y
                    sta   :exit_bra
                    lda   Col2CodeOffset,y
                    sta   :exit_offset
                    sta   LastPatchOffsetArr,x

; Handle the entry point calculations
:do_entry
                    lda   StartXMod164Arr,x
                    clc
                    adc   ScreenWidth                ; move to the right edge and back up a byte
                    dec                              ; to get the index of the first on-screen byte

                    cmp   #164                       ; Keep the value in range
                    bcc   *+5
                    sbc   #164

; Same logic as before

                    bit   #$0001
                    beq   :odd_entry

                    and   #$FFFE
                    tay
                    lda   Col2CodeOffset,y
                    sta   :entry_offset
                    lda   #$004C                     ; set the entry_jmp opcode to JMP
                    sta   :opcode
                    stz   :odd_entry_offset          ; mark as an even case
                    bra   :prep_complete

:odd_entry
                    tay
                    lda   Col2CodeOffset,y
                    sta   :entry_offset              ; Will be used to load the data
                    lda   Col2CodeOffset-2,y
                    sta   :odd_entry_offset          ; will the the actual location to jump to
                    lda   #$00AF                     ; set the entry_jmp opcode to LDAL
                    sta   :opcode
:prep_complete

; Now patch in the code field line

                    ldy   BTableLow,x                ; Get the address of the first code field line
                    clc
                    adc   :exit_offset               ; Add some offsets to get the base address in the code field line
                    sta   :exit_address
                    sty   :base_address

                    lda   BTableHigh,x
                    ora   :src_bank
                    pha
                    plb

; First step is to set the BRA instruction to exit the code field at the proper location.  There
; are two sub-steps to do here; we need to save the 16-bit value that exists at the location and
; then overwrite it with the branch instruction.

; SaveOpcode
                                                     ; y is already set to :base_address
                    ldx   :exit_address              ; Save from this location
                    lda:  $0000,x
                    sta:  OPCODE_SAVE+$0000,y

;SetConst
;                    txy                              ; ldy :exit_address -- starting at this address
                    lda   :exit_bra                  ; Copy this value into all of the lines
                    sta:  $0000,x

; Next, patch in the CODE_ENTRY value, which is the low byte of a JMP instruction. This is an
; 8-bit operation and, since the PEA code is bank aligned, we use the entry_offset value directly

                    sep   #$20

; SetCodeEntry
                    lda   :entry_offset
;                    ldy   :base_address
                    sta:  CODE_ENTRY+$0000,y

; SetCodeEntryOpcode

                    lda   :opcode
                    sta:  CODE_ENTRY_OPCODE+$0000,y

; If this is an odd entry, also set the odd_entry low byte and save the operand high byte

                    lda   :odd_entry_offset
                    beq   :not_odd

; SetOddCodeEntry
                    sta:  ODD_ENTRY+$0000,y
; SaveHighOperand
;                    ldx   :exit_address
                    lda:  $0002,x
                    sta:  OPCODE_HIGH_SAVE+$0000,y
:not_odd
                    rep   #$20                       ; clear the carry

; Do the end of the loop -- update the virtual line counter and reduce the number
; of lines left to render

                    plb                              ; restore the bank

                    lda   :virt_line_x2
                    inc
                    inc
                    sta   :virt_line_x2
                    cmp   :last_line_x2
                    jne   :loop

                    rts


_RestoreScanlineBG0Opcodes

:virt_line_x2       equ   tmp1
:lines_left_x2      equ   tmp2
:src_bank           equ   tmp6

                    asl
                    sta   :virt_line_x2              ; Keep track of it

                    phb
                    phb
                    pla
                    and   #$FF00
                    sta   :src_bank

                    txa
                    asl
                    sta   :lines_left_x2

:loop
                    ldx   :virt_line_x2

                    lda   BTableHigh,x
                    ora   :src_bank
                    pha

                    lda   BTableLow,x                ; Get the address of the first code field line
                    clc
                    adc   LastPatchOffsetArr,x
                    tax

                    plb
                    lda:  OPCODE_SAVE+$0000,y
                    sta:  $0000,x

; Do the end of the loop -- update the virtual line counter and reduce the number
; of lines left to render

                    plb                              ; restore the bank

                    lda   :virt_line_x2
                    inc
                    inc
                    sta   :virt_line_x2
                    cmp   :last_line_x2
                    jne   :loop

                    stz   LastPatchOffset            ; Clear the value once completed
                    rts

; Unrolled copy routine to move BankTable entries into BNK_ADDR position.  This is a bit different than the
; other routines, because we don't need to put values into the code fields, but just copy one-byte values
; into an internal array in bank 00 space.  The reason for this is because the code sequence
;
; lda #ADDR
; tcs
; plb
;
; Take only 9 cycles, but the alternative is slower
;
; pea #$BBBB
; plb
; plb         = 13 cycles
;
; If for some reason it becomes important to preserve the accumulator, or save the 208 bytes of
; bank 00 memory, then we can change it.  The advantage right now is that updating the array can
; be done 16-bits at a time and without having to chunk up the writes across multiple banks.  This
; is quite a bit faster than the other routines.
CopyTableToBankBytes

                     tsx                             ; save the stack
                     sei
                     jmp   $0000

                     lda:  2,y
                     pha
                     lda:  0,y
                     pha
bottom
                     txs                             ; restore the stack
                     cli                             ; turn interrupts back on
                     rts
