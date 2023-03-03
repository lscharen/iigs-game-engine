; Template and equates for GTE blitter

                   mx    %00

DP_ADDR            equ   entry_1-base+1             ; offset to patch in the direct page for dynamic tiles
BG1_ADDR           equ   entry_2-base+1             ; offset to patch in the Y-reg for BG1 (dp),y addressing
STK_ADDR           equ   entry_3-base+1             ; offset to patch in the stack (SHR) right edge address
; BNK_ADDR           equ   entry_0-base+1             ; offset to patch in the address of a Bank 0 memory location to load the bank register

DP_ENTRY           equ   entry_1-base
TWO_LYR_ENTRY      equ   entry_2-base
ONE_LYR_ENTRY      equ   entry_3-base
; BANK_ENTRY         equ   entry_0-base

CODE_ENTRY_OPCODE  equ   entry_jmp-base
CODE_ENTRY         equ   entry_jmp-base+1           ; low byte of the page-aligned jump address
ODD_ENTRY          equ   odd_entry-base+1
CODE_TOP           equ   loop-base
CODE_LEN           equ   top-base
CODE_EXIT          equ   even_exit-base
OPCODE_SAVE        equ   odd_save-base              ; spot to save the code field opcode when patching exit BRA
OPCODE_HIGH_SAVE   equ   odd_save-base+2            ; save the third byte
FULL_RETURN        equ   full_return-base           ; offset that returns from the blitter
ENABLE_INT         equ   enable_int-base            ; offset that re-enable interrupts and continues
LINES_PER_BANK     equ   16
SNIPPET_BASE       equ   snippets-base

; offsets from each snippet base address for the different entry points

SNIPPET_ENTRY_1    equ   0                          ; two layer + dynamic tile + sprite
SNIPPET_ENTRY_2    equ   4                          ; (two layer | dynamic tile) + sprite
SNIPPET_ENTRY_3    equ   18                         ; two layer + dynamic tile (no sprite)

; Locations that need the page offset added
PagePatches        da    {long_0-base+2}
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
                   da    {even_exit-base+2}
                   da    {jmp_rtn_1-base+2}
;                   da    {jmp_rtn_2-base+2}

]index             equ   0
                   lup   82                                 ; Patch anything that needs updating within the snippets
                   da    {snippets-base+{]index*32}+17}
                   da    {snippets-base+{]index*32}+28}
]index             equ   ]index+1
                   --^
PagePatchNum       equ   *-PagePatches

; Location that need a bank byte set for long addressing modes
BankPatches        da    {long_0-base+3}
                   da    {long_1-base+3}
                   da    {long_2-base+3}
                   da    {long_3-base+3}
                   da    {long_4-base+3}
                   da    {long_5-base+3}
                   da    {long_6-base+3}
BankPatchNum       equ   *-BankPatches

; Start of the template code.  This code is replicated 16 times per bank and spans
; 13 banks for a total of 208 lines, which is what is required to render 26 tiles
; to cover the full screen vertical scrolling.
;
; The 'base' location is always assumed to be on a 4kb ($1000) boundary.  We make sure that
; the code is assembled on a page boundary to help with alignment
                   ds    \,$00                      ; pad to the next page boundary
base
;entry_0            lda   #0000                      ; Used to set per-scanline bank register
;                   tcs
;                   plb
entry_1            ldx   #0000                      ; Used for LDA 00,x addressing (Dynamic Tiles)
entry_2            ldy   #0000                      ; Used for LDA (00),y addressing (Second Layer; BG1)
entry_3            lda   #0000                      ; Sets screen address (right edge)
                   tcs

long_0
entry_jmp          jmp   $0100
                   dfb   $00                        ; if the screen is odd-aligned, then the opcode is set to 
                                                    ; $AF to convert to a LDA long instruction.  This puts the
                                                    ; first two bytes of the instruction field in the accumulator
                                                    ; and falls through to the next instruction.

                                                    ; We structure the line so that the entry point only needs to
                                                    ; update the low-byte of the address, the means it takes only
                                                    ; an amortized 4-cycles per line to set the entry point break

right_odd          bit   #$000B                     ; Check the bottom nibble to quickly identify a PEA instruction
                   bne   r_is_not_pea               ; This costs 5 cycles in the fast-path

                   xba                              ; fast code for PEA
r_jmp_rtn          sep   #$20                       ; shared return code path by all methods
two_byte_rtn       pha
                   rep   #$61                       ; Clear Carry, Overflow and M bits #$20
odd_entry          jmp   $0100                      ; unconditionally jump into the "next" instruction in the 
                                                    ; code field.  This is OK, even if the entry point was the
                                                    ; last instruction, because there is a JMP at the end of
                                                    ; the code field, so the code will simply jump to that
                                                    ; instruction directly.
                                                    ;
                                                    ; As with the original entry point, because all of the
                                                    ; code field is page-aligned, only the low byte needs to
                                                    ; be updated when the scroll position changes

r_is_not_pea       bit   #$0040                     ; Check bit 6 to distinguish between JMP and all of the LDA variants
                   bne   r_is_jmp

long_1             stal  *+6-base                   ; Everything else is a two-byte LDA opcode + PHA
                   sep   #$20                       ; Lift 8-bit mode here to save a cycle in the LDA
                   dfb   $00,$00
                   bra   two_byte_rtn

r_is_jmp           sep   #$41                       ; Set the C and V flags which tells a snippet to push only the low byte
long_2             ldal  entry_jmp+1-base
long_3             stal  *+5-base
                   jmp   $0000                      ; Jumps into the exception code, which returns to r_jmp_rtn

; The next labels are special, in that they are entry points into special subroutines.  They are special
; because they are within the first 256 bytes of each code field, which allows them to be selectable
; by patching the low byte of the JMP instructions.

; Return to caller -- the even_exit JMP from the previous line will jump here when a render is complete
full_return        jml   blt_return                 ; Full exit


; The even/odd branch of this line's exception handler will return here.  This is mostly
; a space-saving measure to allow for more code in the exeption handers themselves, but
; also simplifies the relocation process since we only have to update a single address
; in each exception handler, rather than two.
;
; Once working, this code should be able to be interleaved with the r_jmp_rtn code
; above to eliminate a couple of branches
jmp_rtn
                   bvs   r_jmp_rtn
jmp_rtn_1          jmp   l_jmp_rtn-base             ; Could inline the code and save 3 cycles / line
                                                    ; If we switch even/odd exit points, could fall through
                                                    ; to the even_exit JMP at the head of the PEA field to
                                                    ; save 6 cycles.

; Re-enable interrupts and continue -- the even_exit JMP from the previous line will jump here every
; 8 or 16 lines in order to give the system time to handle interrupts.
enable_int         ldal  stk_save+1                 ; restore the stack
                   tcs
                   sep   #$20                       ; 8-bit mode
                   ldal  STATE_REG                  ; Read Bank 0 / Write Bank 0
                   and   #$CF
                   stal  STATE_REG
                   cli
                   nop                              ; Give a couple of cycles
                   sei
                   ldal  STATE_REG
                   ora   #$10                       ; Read Bank 0 / Write Bank 1
                   stal  STATE_REG
                   rep   #$20
                   bra   entry_1

; This is the spot that needs to be page-aligned. In addition to simplifying the entry address
; and only needing to update a byte instad of a word, because the code breaks out of the
; code field with a BRA instruction, we keep everything within a page to avoid the 1-cycle
; page-crossing penalty of the branch.

                   ds    \,$00                      ; pad to the next page boundary
loop_exit_1        jmp   odd_exit-base              ; +0   Alternate exit point depending on whether the left edge is 
loop_exit_2        jmp   even_exit-base             ; +3   odd-aligned

loop               lup   82                         ; +6   Set up 82 PEA instructions, which is 328 pixels and consumes 246 bytes
                   pea   $0000                      ;      This is 41 8x8 tiles in width.  Need to have N+1 tiles for screen overlap
                   --^
loop_back          jmp   loop-base                  ; +252 Ensure execution continues to loop around
loop_exit_3        jmp   even_exit-base             ; +255

long_5
odd_exit           ldal  l_is_jmp+1-base
                   bit   #$000B
                   bne   :chk_jmp

                   sep   #$20
long_6             ldal  l_is_jmp+3-base            ; get the high byte of the PEA operand

; Fall-through when we have to push a byte on the left edge. Must be 8-bit on entry.  Optimized
; for the PEA $0000 case -- only 19 cycles to handle the edge, so pretty good
:left_byte
                   pha
                   rep   #$20

; JMP opcode = $4C, JML opcode = $5C
even_exit          jmp   $1000                      ; Jump to the next line.
                   ds    1                          ; space so that the last line in a bank can be patched into a JML

:chk_jmp
                   bit   #$0040
                   bne   l_is_jmp

long_4             stal  *+4-base
                   dfb   $00,$00
l_jmp_rtn          xba
                   sep   #$20
                   pha
                   rep   #$61                       ; Clear everything C, V and M
                   bra   even_exit

l_is_jmp           sec                              ; Set the C flag (V is always cleared at this point) which tells a snippet to push only the high byte
odd_save           dfb   $00,$00,$00                ; The odd exit 3-byte sequence is always stashed here

; Special epilogue: skip a number of bytes and jump back into the code field. This is useful for
;                   large, floating panels in the attract mode of a game, or to overlay solid
;                   dialog while still animating the play field

epilogue_1         tsc
                   sec
                   sbc   #0
                   tcs
                   jmp   $0000                      ; This jumps back into the code field
:out               jmp   $0000                      ; This jumps to the next epilogue chain element
                   ds    1

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
;        its passed state, because having the carry bit clear prevents evaluation of
;        the V bit.
;
; Version 2: In order to improve performance, especially for two-layer tiles + sprites, the
;            snippet code was revised to have a fixed structure so that the constant DATA and
;            MASK values always exist in the same location, regarless of the tile type.  The
;            tradeoff is that there is a different entry point into the snippet based on the 
;            tile type, but that is significantly cheaper to lookup and patch into the code
;            field JMP instruction than it is to rebuild 20+ bytes of code each time.
;
;            There are different snippet templates + offset tables based on the EngineMode
;
; EngineMode 
;
;  ENGINE_MODE_TWO_LAYER  NO
;  ENGINE_MODE_DYN_TILES  NO
;
;  Snippet Template
;      None.
;
;  ENGINE_MODE_TWO_LAYER  YES
;  ENGINE_MODE_DYN_TILES  NO
;
;  Snippet Template
;
;           ds   4
;           lda  (00),y   <-- Single Entry Point
;           and  #MASK    <-- Mask is always at byte 8
;           ora  #DATA    <-- Data is always at byte 11
;           bcs  _alt
;           pha
;           jmp  NEXT
; _alt      jmp  RTN
;
;  ENGINE_MODE_TWO_LAYER  NO
;  ENGINE_MODE_DYN_TILES  YES
;
;  Snippet Template
;
;           ds   4
;           lda  00,x     <-- Single Entry Point
;           and  #MASK
;           ora  #DATA
;           bcs  _alt
;           pha
;           jmp  NEXT
; _alt      jmp  RTN
;
;  ENGINE_MODE_TWO_LAYER  YES
;  ENGINE_MODE_DYN_TILES  YES
;
;  Snippet Template
;
;           lda  (00),y     <-- Entry Point 1
;           and  $80,x
;           ora  $00,x      <-- Entry Point 2 (Change this word to "lda (00),y" or "lda 00,x", or "ora 00,x" depending on combination)
;           and  #MASK
;           ora  #DATA
;           bcs  _alt
; _16bit    pha
;           jmp  NEXT
;           lda  (00),y     <--- Entry Point 3 (sneak this in here to avoid extra branch)
;           and  $80,x
;           ora  $00,x
;           bcc  _16bit
; _alt      jmp  RTN (29 bytes)
;
; Note that the code that's assembled in these snippets is just a template.  Every routine that utilizes
; an exception handler *MUST* patch up the routines.  There are different routines based on the Engine Mode.
;
; The LDA (00),y opcodes have a fixed operand, but the dynamic tile instructions are determined by the
; dynamic tile id and must be set each time.

                   ds    \,$00                      ; pad to the next page boundary
]index             equ   0
snippets           lup   82
                   lda   ({{81-]index}*2}),y        ; 0:  Pre-set the LDA (XX),y instructions
                   and   $80,x                      ; 2:  The direct page instructions are placeholders and get overwritten
                   ora   $00,x                      ; 4:  This gets patched out often
                   and   #$0000                     ; 6:  the mask operand will be set when the tile is drawn
                   ora   #$0000                     ; 9:  the data operand will be set when the tile is drawn
                   bcs   :byte                      ; 12: if C = 0, just push the data and return
:word              pha                              ; 14:
                   jmp   loop+3+{3*]index}-base     ; 15: Return address offset within the code field
                   lda   ({{81-]index}*2}),y        ; 18: Pre-set the LDA (XX),y instructions
                   and   $80,x                      ; 20:
                   ora   $00,x                      ; 22:
                   bcc   :word                      ; 24:
:byte              jmp   jmp_rtn-base               ; 26:
                   ds    3                          ; 29: Padding to make a full 32 bytes
]index             equ   ]index+1
                   --^
top