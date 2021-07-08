; This is the method that is most useful from the high-level code.  We want the
; freedom to blit a range of lines.  This subroutine can assume that all of the
; data in the code fields is set up properly.
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (inclusive), valid range >X up to 199
;
; The lines are based on the appearance of lines in the play field, so blitting lines 0 through
; 19 will draw the first 20 lines on the play field, regardless of where the playfield is physically
; on the SHR screen or the current value of StartY
BltRange
            clc`

            tya                  ; Get the address of the line that we want to return from
            adc   StartY         ; and create a pointer to it
            asl
            tay
            lda   BTableLow,y
            sta   exit_ptr
            lda   BTableHigh,y
            sta   exit_ptr+2

            txa                  ; get the first line (0 - 199)
            adc   StartY         ; add in the virtual offset (0, 207) -- max value of 406
            asl
            tax                  ; this is the offset into the blitter table

            sep   #$20           ; 8-bit Acc
            lda   BTableHigh,x   ; patch in the bank
            sta   blt_entry+3

            lda   BTableLow+1,x  ; patch in the page
            sta   blt_entry+2

; The way we patch the exit code is subtle, but very fast.  The CODE_EXIT offset points to
; an JMP/JML instruction that transitions to the next line after all of the code has been
; executed.  Since every code field line is bank-aligned, we know that the low-byte of the
; operand is always $00.
;
; The trick we use is to patch the low byte to force the code to jump to a special return
; function (jml blt_return) in the *next* code field line.  When it's time to restore the
; code, we can unconditionally store a $00 value to set things back to normal.
;
; This is the ideal situation -- patch/restore in a single 8-bit lda #imm / sta instruction
; pair with no need to preserve the data

            ldy   #CODE_EXIT+1   ; this is a JMP or JML instruction that points to the next line.
            lda   #FULL_RETURN   ; this is the offset of the return code
            sta   [exit_ptr],y   ; patch out the low byte of the JMP/JML
            rep   #$20

; Now we need to set up the Bank, Stack Pointer and Direct Page registers for calling into 
; the code field

            pei   BG1DataBank-1  ; Set the data bank for BG1 data
            plb
            plb

            phd                  ; Save the application direct page
            lda   BlitterDP      ; Set the direct page to the blitter data
            tcd

            sei                  ; disable interrupts
            _R0W1
            tsc                  ; save the stack pointer
            stal  stk_save+1

blt_entry   jml   $000000        ; Jump into the blitter code $XX/YYZZ

blt_return  _R0W0
stk_save    lda   #0000          ; load the stack
            tcs
            cli                  ; re-enable interrupts
            pld                  ; restore the direct page

            sep   #$20
            ldy   #CODE_EXIT+1
            lda   #00
            sta   [exit_ptr],y
            rep   #$20

            rts

; This subroutine is used to set up the BltDispatch code based on the current state of
; the machine and/or the state of the engine.  The tasks it performs are
;
; 1. Set the blt_entry low byte based on the graphics engine configuration
BltSetup
            sep   #$20           ; Only need 8-bits for this
            lda   EngineMode
            bit   #$01           ; Are both background layers enabled?
            beq   :oneLyr
            lda   #entry_2-base
            bra   :twoLyr
:oneLyr     lda   #entry_3-base
:twoLyr     sta   blt_entry+1    ; set the low byte of the JML
            rep   #$20
            rts
























