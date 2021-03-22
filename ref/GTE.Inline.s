; Template and utility function for a single line of the GTE blitter. See the other GTE.Line.s file
; for details on the general structure of this template.
;
; This is a variant that places the snippets inline within the code field.  We give up
; the speed of three-byte code sequences, but eliminate the double JMP and simplify the
; handling of odd-alignment.
;
; This mode is best when the scenes are always complicated.
;
;  Odd:
            MX    %00
entry_1     ldx   #0000       ; patch with the address of the direct page tiles. Fixed.
entry_2     ldy   #0000       ; patch with the address of the line in the second layer. Set when BG1 scroll position changes.
entry_3     lda   #0000       ; patch with the address of the right edge of the line. Set when origin position changes.
            tcs

entry_jmp   jmp   $2000       ; always jump into the same location.  For odd line, the end
;                                 ; of the snippet will be patched to handle the right-edge case.

right_odd   sep   #$20        ; enter here from the code field
            pha
            rep   #$20
            jmp   $2000       ; jump back into the code field


            jmp   odd_exit
            jmp   even_exit

; Code field, each block is N bytes

loop
            lda   #1234       ; PEA $0000 becomes LDA #0000 / BRA / PHA
            bra   l0

            jmp   exit        ; 'normal' exit point
            jmp   left_odd    ; handler for pushing a single byte to the left edge
            jmp   right_odd   ; handler for pushing a single byte to the right edge
l0          pha               ; always end with a PHA, this is the patch point

            lda   (00),y      ; 
            and   #MASK
            ora   #data
            bra   l1

            jmp   exit        ; 'normal' exit point
            jmp   left_odd    ; handler for pushing a single byte to the left edge
            jmp   right_odd   ; handler for pushing a single byte to the right edge
l0          pha               ; always end with a PHA, this is the patch point



            ...
            jmp   loop


            jmp   even_exit


left_odd    sep   #$20
            xba
            pha
            rep   #$20

exit        jmp   $0000       ; Jump to the next line.  We set up the blitter to do 8 or 16 lines at a time
;                                 ; before restoring the machine state and re-enabling interrupts.  This makes
;                                 ; the blitter interrupt friendly to allow things like music player to continue
;                                 ; to function.
;
;                                 ; When it's time to exit, the next_entry address points to an alternate exit point

; These are the special code snippets -- there is a 1:1 relationship between each snippet space
; and a 3-byte entry in the code field. Thus, each snippet has a hard-coded JMP to return to 
; the next code field location
;
; The snippet is required to handle the odd-alignment in-line; there is no facility for
; patching or intercepting these values due to their complexity.  The only requirements
; are:
;
;  1. Carry Clear -> 16-bit write and return to the next code field operand
;  2. Carry Set 
;     a. Overflow set   -> Low 8-bit write and return to the next code field operand
;     b. Overflow clear -> High 8-bit write and exit the line
;     c. Always clear the Carry flags. It's actually OK to leave the overflow bit in 
;        its passed state, because having the carry bit clear prevent evaluation of
;        the V bit.
;
; Snippet Samples:
;
; Standard Two-level Mix (27 bytes)
;
;   Optimal     = 18 cycles (LDA/AND/ORA/PHA)
;  16-bit write = 23 cycles 
;   8-bit low   = 35 cycles
;   8-bit high  = 36 cycles
;
;  start     lda  (00),y
;            and  #MASK
;            ora  #DATA         ; 14 cycles to load the data
;            bcs  8_bit
;            pha
;  out       jmp  next          ; Fast-path completes in 9 additional cycles

;  8_bit     sep  #$30          ; Switch to 8 bit mode
;            bvs  r_edge        ; Need to switch if doing the left edge
;            xba
;  r_edge    pha                ; push the value
;            rep  #$31          ; put back into 16-bit mode and clear the carry bit, as required
;            bvs  out           ; jmp out and continue if this is the right edge
;            jmp  even_exit     ; exit the line otherwise
;                               ;
;                               ; The slow paths have 21 and 22 cycles for the right and left
;                               ; odd-aligned cases respectively.

snippets    ds    32*82


















