; Template and equates for GTE blitter
blt_return_lite    EXT

                   use   ../Defs.s      ; this causes merlin32 to terminate early with no error output

                   mx    %00

LITE_STK_ADDR      equ   lite_entry_1-lite_base+1             ; offset to patch in the stack (SHR) right edge address
LITE_LYR_ENTRY     equ   lite_entry_1-lite_base

LITE_CODE_ENTRY_OPCODE  equ   lite_entry_jmp-lite_base
LITE_CODE_ENTRY         equ   lite_entry_jmp-lite_base+1      ; low byte of the page-aligned jump address
LITE_ODD_ENTRY          equ   lite_odd_entry-lite_base+1
LITE_CODE_LEN           equ   lite_top-lite_base
LITE_CODE_EXIT          equ   lite_even_exit-lite_base
LITE_OPCODE_SAVE        equ   lite_odd_low_save-lite_base          ; spot to save the code field opcode when patching exit BRA
LITE_OPCODE_HIGH_SAVE   equ   lite_odd_high_save-lite_base         ; save the third byte only

LITE_ENABLE_INT         equ   lite_enable_int-lite_base            ; offset that re-enable interrupts and continues

; Return to caller -- this is the target address to patch in the JMP instruction on the last rendered line. We
; put it at the beginning so the rest of the bank can be replicated line templates.
lite_full_return   ENT
                   jml   blt_return_lite            ; Full exit

; Start of the template code.  This code is replicated 208 times in the code field
; bank, which is what is required to render 26 tiles to cover the full screen vertical
; scrolling. The lite blitter is crafted to allow the accumulator to be in 8-bit
; mode and avoid any need for rep/sep instructions to handle the odd-aligned case
lite_base          ENT
lite_entry_1       ldx   #0000                      ; Sets screen address (right edge)
                   txs

lite_entry_jmp     brl   $0000                      ; If the screen is odd-aligned, then the opcode is set to 
                                                    ; $A2 to convert to a LDX #imm instruction.  This puts the
                                                    ; relative offset of the instruction field in the register
                                                    ; and falls through to the next instruction.

                   lda:  $0001,x                    ; Get the low byte and push onto the stack
                   pha
lite_odd_entry     brl   $0000                      ; unconditionally jump into the "next" instruction in the 
                                                    ; code field.  This is OK, even if the entry point was the
                                                    ; last instruction, because there is a JMP at the end of
                                                    ; the code field, so the code will simply jump to that
                                                    ; instruction directly.
                                                    ;
                                                    ; As with the original entry point, because all of the
                                                    ; code field is page-aligned, only the low byte needs to
                                                    ; be updated when the scroll position changes



; Re-enable interrupts and continue -- the even_exit JMP from the previous line will jump here every
; 8 or 16 lines in order to give the system time to handle interrupts.
lite_enable_int    tyx
                   txs                              ; restore the stack. No 2-layer support, so B and D are set to GTE data bank
                   lda   STATE_REG_OFF              ; we are in 8-bit mode the whole time...
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT             ; External values 
                   stal  STATE_REG
                   bra   lite_entry_1

lite_loop_exit_1   jmp   lite_odd_exit              ; +0   Alternate exit point depending on whether the left edge is 
lite_loop_exit_2   jmp   lite_even_exit             ; +3   odd-aligned

lite_loop          lup   82                         ; +6   Set up 82 PEA instructions, which is 328 pixels and consumes 246 bytes
                   pea   $0000                      ;      This is 41 8x8 tiles in width.  Need to have N+1 tiles for screen overlap
                   --^
lite_loop_back     jmp   lite_loop                  ; +252 Ensure execution continues to loop around
lite_loop_exit_3   jmp   lite_even_exit             ; +255

                   mx    %10
lite_odd_exit      lda   #0                         ; get the high byte of the saved PEA operand (odd-case is already in 8-bit mode)
                   pha
lite_even_exit     jmp   $0000                      ; Jump to the next line.
                   dfb   $F4,$00                    ; low-word of the saved PEA instruction

; Now repeat the code above 207 more times. Loop 206 times and then manually do the last one
]line              equ   1                          ; start at line 1 (line zero was just done above)
                   lup   206
                   ldx   #0000
                   txs
                   dfb   $82,$00,$00
                   lda:  1,x
                   pha
                   dfb   $82,$00,$00

                   tyx
                   txs
                   lda   STATE_REG_OFF
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG
;                   bra   *-34
                   dfb   $80,$E0

                   jmp   _LINE_BASE+{_LINE_SIZE*]line}+_EXIT_EVEN
                   jmp   _LINE_BASE+{_LINE_SIZE*]line}+_EXIT_ODD

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000
                   pea   $0000

                   pea   $0000
                   pea   $0000

                   jmp   _LINE_BASE+{_LINE_SIZE*]line}+_LOOP
                   jmp   _LINE_BASE+{_LINE_SIZE*]line}+_EXIT_EVEN

                   mx    %10
                   lda   #0
                   pha
                   jmp   $0000
                   dfb   $F4,$00
]line              equ   ]line+1
                   --^

:entry_207         ldx   #0000
                   txs
                   dfb   $82,$00,$00         ; brl $0000 starts at the next instruction
                   lda:  1,x
                   sep   #$20
                   pha
                   dfb   $82,$00,$00

                   tyx
                   txs
                   lda   STATE_REG_OFF
                   stal  STATE_REG
                   cli
                   sei
                   lda   STATE_REG_BLIT
                   stal  STATE_REG
                   bra   :entry_207

                   jmp   :odd_out_207
                   jmp   :exit_207
:loop_207
                   lup   82
                   pea   $0000
                   --^
                   jmp   :loop_207
                   jmp   :exit_207

                   mx    %10
:odd_out_207       lda   #0
                   pha
:exit_207          jmp   lite_entry_1
                   dfb   $F4,$00

                   ds    3546              ; pad to the end of the bank to make sure we start at address $0000
