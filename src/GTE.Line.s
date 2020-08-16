; Template and utility function for a single line of the GTE blitter. This is a memory
; hog. Because, potentially, all of the registers (X, Y, D, SP, B) are in use, we only
; have the P-register and PC for flow control. A lot of the code is replicated so that
; different piece of code run at different address so that JMP instruction can be used
; for flow control.
;
; Any JMP instruction with an address of $20XX will have its low byte set when the 
; scroll position of screen is set.  If the scroll position is set, repeately calling
; the blitter will refresh the screen each time without re-applying all of the patches
; that depend on the scroll position.
;
; When called
;  * Interrupts are off
;  * Bank address is set to background 1
;  * Direct Page is set to the data field
;    + First 256 bytes are pointers to background 1 mask data
;    + Next 2048 bytes are dynamic tile data
;  * Bank 00 read
;  * Bank 01 write
;
; Each line takes up 8kb and is aligned to a multiple of $2000
;  NOTE: Each line may only need 4kb -- space requirements driven by snippet complexity
;
; Each 3-byte sequence in the code field is one of
;
;  PEA $0000         => F4 00 00 = %1111 0100
;  LDA 00     / PHA  => A5 00 48 = %1010 0101
;  LDA 00,x   / PHA  => B5 00 48 = %1011 0101
;  LDA (00),y / PHA  => B1 00 48 = %1011 0001
;  LDA 00,s   / PHA  => A3 00 48 = %1010 0011
;  JMP 0000          => 4C 00 00 = %0100 1100
;
; Only the JMP opcode is less than $80 and all of the others perform their work inline,
; so this gives us a fast test to help extract only the high or low byte of each word
;
; So, before diving into the code, just how fast is it? The architecture of GTE allows simple 
; things to be fast and complex things to not be slow.  That is, the developer has a lot
; of control over the time taken to render the full screen based on how complex it can be.
;
; That said, I'll cover three cases, ranging from the simple (a single background) and
; complex (2 backgrounds, 50% mixed).  The even- and odd-aligned cases are also broken out.
;
; Simple case; all elements of the code field are PEA instructions
;
;  Even:
;    - Start at entry_3, 8 cycles to jump into the code field
;    - 80 PEA instructions + one JMP = 403 cycles
;    - BRA and JMP = 6 cycles
;    - Final JMP to next line = 3 cycles
;      -- total of 420 cycles / line of which 400 were spent doing necessary instructions
;      -- theoretically almost 30 fps
;
;  Odd:
;    - Start at entry_3, 17 cycles to get to r_is_pea. If a second background is never used,
;      this template could be specialized and reduce this overhead to 11 cycles.
;    - 15 cycles to push the 8-bit right edge
;    - 78 PEA instructions + one JMP = 393 cycles
;    - 50% JMP to odd_exit = 1.5 cycles, amortized
;    - 24 cycles to push the 8-bit left edge
;    - Final JMP to next line = 3 cycles
;      -- total 453.5 cycles / line
;      -- theoretically 27.5 fps
;
; Complex; 25% of code-field is PEA, 25% is LDA (00),y / PHA, and 50% is mixed
;
;  Even:
;    - Start at entry_3, 8 cycles to jump into the code field
;    - Code Field
;      - 20 PEA instruction  =  100 cycles
;      - 20 LDA (00),y / PHA =  240 cycles
;      - 20 JMP / Fast Path  = 1040 cycles
;      - JMP loop            =    3 cycles
;    - BRA and JMP = 6 cycles
;    - Final JMP to next line = 3 cycles
;      -- total of 1,517 cycles / line of which 700 were spent doing necessary instructions
;      -- theoretically about 8 fps

entry_1      ldx   #0000          ; patch with the address of the direct page tiles. Fixed.
entry_2      ldy   #0000          ; patch with the address of the line in the second layer. Set when BG1 scroll position changes.
entry_3      lda   #0000          ; patch with the address of the right edge of the line. Set when origin position changes.
             tcs

entry_jmp    jmp   $2000
             dfb   00             ; of the screen is odd-aligned, then the opcode is set to 
;                                 ; $AF to convert to a LDA long instruction.  This puts the
;                                 ; first two bytes of the instruction field in the accumulator
;                                 ; and falls through to the next instruction.
;
;                                 ; We structure the line so that the entry point only needs to
;                                 ; update the low-byte of the address, the means it takes only
;                                 ; an amortized 4-cycles per line to set the entry pointbra

right_odd    bit   #$000B         ; Check the bottom nibble to quickly identify a PEA instruction
             beq   r_is_pea       ; This costs 6 cycles in the fast-path

             bit   #$0040         ; Check bit 6 to distinguish between JMP and all of the LDA variants
             bne   r_is_jmp

             stal  r_lda_patch+1  ; Original word is still in the accumulator.  Execute it. We inline 
r_lda_patch  dfb   00,00          ; this here to avoid needing a BRA instruction back.  So the fast-path
;                                 ; gets a 1-cycle penalty, but we save 3 cycles here.

r_is_pea     xba                  ; fast code for PEA
             sep   #$30
             pha
             rep   #$30
             jmp   $2003          ; unconditionally jump into the "next" instruction in the 
;                                 ; code field.  This is OK, even if the entry point was the
;                                 ; last instruction, because there is a JMP at the end of
;                                 ; the code field, so the code will simply jump to that
;                                 ; instruction directly.
;                                 ;
;                                 ; As with the original entry point, because all of the
;                                 ; code field is page-aligned, only the low byte needs to
;                                 ; be updated when the scroll position changes

r_is_jmp     sep   #$41           ; Set the C and V flags which tells a snippet to push only the low byte
             ldal  entry_jmp+1
             stal  r_jmp_patch+1
r_jmp_patch  dfb   $4C,$00,$00    ; Jump back to address in entry_jmp (this takes 13 cycles, is there a better way?)

; This is the spot that needs to be page-aligned. In addition to simplifying the entry address
; and only needing to update a byte instad of a word, because the code breaks out of the
; code field with a BRA instruction, we keep everything within a page to avoid the 1-cycle
; page-crossing penalty of the branch.
             jmp   odd_exit       ; +0   Alternate exit point depending on whether the left edge is 
             jmp   even_exit      ; +3   odd-aligned

loop         lup   82             ; +6   Set up 82 PEA instructions, which is 328 pixels and consumes 246 bytes
             pea   $0000          ;      This is 41 8x8 tiles in width.  Need to have N+1 tiles for screen overlap
             --^
             jmp   loop           ; +252 Ensure execution continues to loop around
             jmp   even_exit      ; +255

odd_exit     lda   #patch         ; This operabd field is *always* used to hold the original 2 bytes of the code field
;                                 ; that are replaced by the needed BRA instruction to exit the code field.  When the
;                                 ; left edge is odd-aligned, we are able to immediately load the value and perform
;                                 ; similar logic to the right_odd code path above

left_odd     bit   #$000B
             beq   l_is_pea

             bit   #$0040
             bne   l_is_jmp

             stal  l_lda_patch+1
l_lda_patch  dfb   00,00
l_is_pea     xba
             sep   #$30
             pha
             rep   #$30
             bra   even_exit
r_is_jmp     sep   #$01           ; Set the C flag (V is always cleared at this point) which tells a snippet to push only the high byte
             ldal  entry_jmp+1
             stal  r_jmp_patch+1
r_jmp_patch  dfb   $4C,$00,$00    ; Jump back to address in entry_jmp (this takes 13 cycles, is there a better way?)

even_exit    jmp   next_entry     ; Jump to the next line.  We set up the blitter to do 8 or 16 lines at a time
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


