; Template and equates for GTE blitter

              mx    %00

DP_ADDR       equ   entry_1-base+1
BG1_ADDR      equ   entry_2-base+1
STK_ADDR      equ   entry_3-base+1

CODE_TOP      equ   loop-base
CODE_LEN      equ   top-base

; Locations that need the page offset added
PagePatches   da    {long_0-base+2}
              da    {long_1-base+2}
              da    {long_2-base+2}
              da    {long_3-base+2}
              da    {long_4-base+2}
              da    {long_5-base+2}
              da    {long_6-base+2}
              da    {odd_entry-base+2}
              da    {loop_exit_1-base+2}
              da    {loop_exit_2-base+2}
              da    {loop_back-base+2}
              da    {loop_exit_3-base+2}
PagePatchNum  equ   *-PagePatches

BankPatches   da    {long_0-base+3}
              da    {long_1-base+3}
              da    {long_2-base+3}
              da    {long_3-base+3}
              da    {long_4-base+3}
              da    {long_5-base+3}
              da    {long_6-base+3}
BankPatchNum  equ   *-BankPatches

target        equ   0
BuildBank
              stz   target
              sta   target+2
:next
              jsr   BuildLine2
              lda   target
              clc
              adc   #$1000
              sta   target
              bcc   :next

              rts

; this is a relocation subroutine, it is responsible for copying the template to a
; memory location and patching up the necessary instructions.
;
; X = low word of address (must be a multiple of $1000)
; A = high word of address (bank)
BuildLine
              stx   target
              sta   target+2

BuildLine2
              lda   #CODE_LEN         ; round up to an even number of bytes
              inc
              and   #$FFFE
              beq   :nocopy
              dec
              dec
              tay
:loop         lda   base,y
              sta   [target],y

              dey
              dey
              bpl   :loop

:nocopy       lda   #0                ; copy is complete, now patch up the addresses
              sep   #$20

              ldx   #0
              lda   target+2          ; patch in the bank for the absolute long addressing mode
:dobank       ldy   BankPatches,x
              sta   [target],y
              inx
              inx
              cpx   #BankPatchNum
              bcc   :dobank

              ldx   #0
:dopage       ldy   PagePatches,x     ; patch the page addresses by adding the page offset to each
              lda   [target],y
              clc
              adc   target+1
              sta   [target],y
              inx
              inx
              cpx   #PagePatchNum
              bcc   :dopage

:out
              rep   #$20
              rts

; start of the template code
base
entry_1       ldx   #0000
entry_2       ldy   #0000
entry_3       lda   #0000
              tcs

long_0
entry_jmp     jmp   $0100
              dfb   $00               ; if the screen is odd-aligned, then the opcode is set to 
;                                 ; $AF to convert to a LDA long instruction.  This puts the
;                                 ; first two bytes of the instruction field in the accumulator
;                                 ; and falls through to the next instruction.
;
;                                 ; We structure the line so that the entry point only needs to
;                                 ; update the low-byte of the address, the means it takes only
;                                 ; an amortized 4-cycles per line to set the entry pointbra

right_odd     bit   #$000B            ; Check the bottom nibble to quickly identify a PEA instruction
              beq   r_is_pea          ; This costs 6 cycles in the fast-path

              bit   #$0040            ; Check bit 6 to distinguish between JMP and all of the LDA variants
              bne   r_is_jmp

long_1        stal  *+4-base
              dfb   $00,$00           ; this here to avoid needing a BRA instruction back.  So the fast-path
;                                 ; gets a 1-cycle penalty, but we save 3 cycles here.

r_is_pea      xba                     ; fast code for PEA
              sep   #$30
              pha
              rep   #$30
odd_entry     jmp   $0100             ; unconditionally jump into the "next" instruction in the 
;                                 ; code field.  This is OK, even if the entry point was the
;                                 ; last instruction, because there is a JMP at the end of
;                                 ; the code field, so the code will simply jump to that
;                                 ; instruction directly.
;                                 ;
;                                 ; As with the original entry point, because all of the
;                                 ; code field is page-aligned, only the low byte needs to
;                                 ; be updated when the scroll position changes

r_is_jmp      sep   #$41              ; Set the C and V flags which tells a snippet to push only the low byte
long_2        ldal  entry_jmp+1-base
long_3        stal  *+5-base
              dfb   $4C,$00,$00       ; Jump back to address in entry_jmp (this takes 16 cycles, is there a better way?)

; This is the spot that needs to be page-aligned. In addition to simplifying the entry address
; and only needing to update a byte instad of a word, because the code breaks out of the
; code field with a BRA instruction, we keep everything within a page to avoid the 1-cycle
; page-crossing penalty of the branch.
              ds    204
loop_exit_1   jmp   odd_exit-base     ; +0   Alternate exit point depending on whether the left edge is 
loop_exit_2   jmp   even_exit-base    ; +3   odd-aligned

loop          lup   82                ; +6   Set up 82 PEA instructions, which is 328 pixels and consumes 246 bytes
              pea   $0000             ;      This is 41 8x8 tiles in width.  Need to have N+1 tiles for screen overlap
              --^
loop_back     jmp   loop-base         ; +252 Ensure execution continues to loop around
loop_exit_3   jmp   even_exit-base    ; +255

odd_exit      lda   #0000             ; This operand field is *always* used to hold the original 2 bytes of the code field
;                                 ; that are replaced by the needed BRA instruction to exit the code field.  When the
;                                 ; left edge is odd-aligned, we are able to immediately load the value and perform
;                                 ; similar logic to the right_odd code path above

left_odd      bit   #$000B
              beq   l_is_pea

              bit   #$0040
              bne   l_is_jmp

long_4        stal  *+4-base
              dfb   $00,$00
l_is_pea      xba
              sep   #$30
              pha
              rep   #$30
              bra   even_exit
l_is_jmp      sep   #$01              ; Set the C flag (V is always cleared at this point) which tells a snippet to push only the high byte
long_5        ldal  entry_jmp+1-base
long_6        stal  *+5-base
              dfb   $4C,$00,$00       ; Jump back to address in entry_jmp (this takes 13 cycles, is there a better way?)

even_exit     jmp   $1000             ; Jump to the next line.  We set up the blitter to do 8 or 16 lines at a time
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

; snippets      ds    32*82
top











































