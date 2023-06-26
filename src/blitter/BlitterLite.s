; This is the method that is most useful from the high-level code.  We want the
; freedom to blit a range of lines.  This subroutine can assume that all of the
; data in the code fields is set up properly.
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
;
; The lines are based on the appearance of lines in the play field, so blitting lines 0 through
; 19 will draw the first 20 lines on the play field, regardless of where the playfield is physically
; on the SHR screen or the current value of StartY
lite_base        EXT
lite_full_return EXT

; This should only be called from _Render when it is determined to be safe
_BltRangeLite

:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2

                phb

                clc
                dey
                tya                  ; Get the address of the line that we want to return from
                adc   StartYMod208   ; and create a pointer to it
                asl
                tay
                lda   BTableLow,y
                sta   :exit_ptr
                lda   BTableHigh,y
                sta   :exit_ptr+2

                txa                  ; get the first line (0 - 199)
                adc   StartYMod208   ; add in the virtual offset (0, 207) -- max value of 406
                asl
                tax                  ; this is the offset into the blitter table

                lda   BTableLow,x     ; patch in the address
                sta   blt_entry_lite+1

; The way we patch the exit code is subtle, but very fast.  The CODE_EXIT offset points to
; an JMP/JML instruction that transitions to the next line after all of the code has been
; executed.
;
; The trick we use is to patch the low byte to force the code to jump to a special return
; function (jml blt_return) in the *next* code field line.

                ldy   #_EXIT_EVEN+1       ; this is a JMP instruction that points to the next line.
                lda   [:exit_ptr],y       ; we have to save because not every line points to the same
                sta   :jmp_low_save       ; position in the next code line

                lda   #lite_full_return   ; this is the address of the return code
                sta   [:exit_ptr],y       ; patch out the address of the JMP

                php                       ; save the current processor flags
                sep   #$20                ; run the lite blitter in 8-bit accumulator mode

                lda   :exit_ptr+2         ; set the bank to the code field
                pha
                plb

                sei                       ; disable interrupts
                _R0W1
                tsx                       ; save the stack pointer in Y
                txy
blt_entry_lite  jml   lite_base           ; Jump into the blitter code $ZZ/YYXX (Does not modify Y or X)

blt_return_lite ENT
                _R0W0
                tyx
                txs                       ; restore the stack
                plp                       ; re-enable interrupts (maybe, if interrupts disabled when we are called, they are not re-endabled)

:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2
                mx    %00

                ldy   #_EXIT_EVEN+1
                lda   :jmp_low_save
                sta   [:exit_ptr],y

                plb
                rts
