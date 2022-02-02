; Template and equates for GTE blitter

                   mx    %00

DP_ADDR            equ   entry_1-base+1             ; offset to patch in the direct page for dynamic tiles
BG1_ADDR           equ   entry_2-base+1             ; offset to patch in the Y-reg for BG1 (dp),y addressing
STK_ADDR           equ   entry_3-base+1             ; offset to patch in the stack (SHR) right edge address

DP_ENTRY           equ   entry_1-base
TWO_LYR_ENTRY      equ   entry_2-base
ONE_LYR_ENTRY      equ   entry_3-base

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
                   lup   82                                 ; All the snippet addresses. The two JMP
                   da    {snippets-base+{]index*32}+31}     ; instructino are at the end of each of
                   da    {snippets-base+{]index*32}+28}     ; the 32-byte buffers
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

; Set the physical location of the virtual screen on the physical screen. The
; screen size must by a multiple of 8
;
; A = XXYY where XX is the left edge [0, 159] and YY is the top edge [0, 199]
; X = width (in bytes)
; Y = height (in lines)
;
; This subroutine stores the screen positions in the direct page space and fills
; in the double-length ScreenAddrR table that holds the address of the right edge
; of the playfield.  This table is used to set addresses in the code banks when the
; virtual origin is changed.
;
; We are not concerned about the raw performance of this function because it should
; usually only be executed once during app initialization.  It doesn't get called
; with any significant frequency.

SetScreenRect      sty   ScreenHeight               ; Save the screen height and width
                   stx   ScreenWidth

                   tax                              ; Temp save of the accumulator
                   and   #$00FF
                   sta   ScreenY0
                   clc
                   adc   ScreenHeight
                   sta   ScreenY1

                   txa                              ; Restore the accumulator
                   xba
                   and   #$00FF
                   sta   ScreenX0
                   clc
                   adc   ScreenWidth
                   sta   ScreenX1

                   lda   ScreenHeight               ; Divide the height in scanlines by 8 to get the number tiles
                   lsr
                   lsr
                   lsr
                   sta   ScreenTileHeight

                   lda   ScreenWidth                ; Divide width in bytes by 4 to get the number of tiles
                   lsr
                   lsr
                   sta   ScreenTileWidth

                   lda   ScreenY0                   ; Calculate the address of the first byte
                   asl                              ; of the right side of the playfield
                   tax
                   lda   ScreenAddr,x               ; This is the address for the left edge of the physical screen
                   clc
                   adc   ScreenX1
                   dec
                   pha                              ; Save for second loop

                   ldx   #0
                   ldy   ScreenHeight
                   jsr   :loop
                   pla                              ; Reset the address and continue filling in the
                   ldy   ScreenHeight               ; second half of the table
:loop              clc
                   sta   RTable,x
                   adc   #160
                   inx
                   inx
                   dey
                   bne   :loop

; Calculate the screen locations for each tile cornder

                   lda   ScreenY0                   ; Calculate the address of the first byte
                   asl                              ; of the right side of the playfield
                   tax
                   lda   ScreenAddr,x               ; This is the address for the left edge of the physical screen
                   clc
                   adc   ScreenX0

                   ldx   #0
                   ldy   #0
:tsloop
                   sta   TileStore+TS_SCREEN_ADDR,X

                   clc
                   adc   #4                         ; Go to the next tile

                   iny
                   cpy   #41                        ; If we've done 41 columns, move to the next line
                   bcc   :nohop
                   ldy   #0
                   clc
                   adc   #{8*160}-{4*41}
:nohop

                   inx
                   inx
                   cpx   #TILE_STORE_SIZE-2
                   bcc   :tsloop

; Return
                   rts

; Clear the SHR screen and then infill the defined field
FillScreen         lda   #0
                   jsr   _ClearToColor

                   ldy   ScreenY0
:yloop
                   tya
                   asl   a
                   tax
                   lda   ScreenAddr,x
                   clc
                   adc   ScreenX0
                   tax
                   phy

                   lda   ScreenWidth
                   lsr
                   tay
                   lda   #$FFFF
:xloop             stal  $E10000,x                  ; X is the absolute address
                   inx
                   inx
                   dey
                   bne   :xloop

                   ply
                   iny
                   cpy   ScreenY1
                   bcc   :yloop
                   rts

; Special subroutine to divide the accumulator by 164 and return remainder in the Accumulator
;
; 164 = $A4 = 1010_0100
Mod164             cmp   #%1010010000000000
                   bcc   *+5
                   sbc   #%1010010000000000

                   cmp   #%0101001000000000
                   bcc   *+5
                   sbc   #%0101001000000000

                   cmp   #%0010100100000000
                   bcc   *+5
                   sbc   #%0010100100000000

                   cmp   #%0001010010000000
                   bcc   *+5
                   sbc   #%0001010010000000

                   cmp   #%0000101001000000
                   bcc   *+5
                   sbc   #%0000101001000000

                   cmp   #%0000010100100000
                   bcc   *+5
                   sbc   #%0000010100100000

                   cmp   #%0000001010010000
                   bcc   *+5
                   sbc   #%0000001010010000

                   cmp   #%0000000101001000
                   bcc   *+5
                   sbc   #%0000000101001000

                   cmp   #%0000000010100100
                   bcc   *+5
                   sbc   #%0000000010100100
                   rts

; Special subroutine to divide the accumulator by 208 and return remainder in the Accumulator
;
; 208 = $D0 = 1101_0000
;
; There are probably faster hacks to divide a 16-bit unsigned value by 208
;   https://www.drdobbs.com/parallel/optimizing-integer-division-by-a-constan/184408499
;   https://embeddedgurus.com/stack-overflow/2009/06/division-of-integers-by-constants/

Mod208             cmp   #%1101000000000000
                   bcc   *+5
                   sbc   #%1101000000000000

                   cmp   #%0110100000000000
                   bcc   *+5
                   sbc   #%0110100000000000

                   cmp   #%0011010000000000
                   bcc   *+5
                   sbc   #%0011010000000000

                   cmp   #%0001101000000000
                   bcc   *+5
                   sbc   #%0001101000000000

                   cmp   #%0000110100000000
                   bcc   *+5
                   sbc   #%0000110100000000

                   cmp   #%0000011010000000
                   bcc   *+5
                   sbc   #%0000011010000000

                   cmp   #%0000001101000000
                   bcc   *+5
                   sbc   #%0000001101000000

                   cmp   #%0000000110100000
                   bcc   *+5
                   sbc   #%0000000110100000

                   cmp   #%0000000011010000
                   bcc   *+5
                   sbc   #%0000000011010000
                   rts

; Patch an 8-bit or 16-bit valueS into the bank.  These are a set up unrolled loops to 
; quickly patch in a constanct value, or a value from an array into a given set of 
; templates.
;
; Because we have structured everything as parallel code blocks, most updates to the blitter
; reduce to storing a constant value and have an amortized cost of just a single store.
;
; The utility of these routines is that they also handle setting just a range of lines
; within a single bank.
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = value
;
; Set M to 0 or 1
SetConst                                            ; Need a blank line here, otherwise the :tbl local variable resolveds backwards
                   jmp   (:tbl,x)
:tbl               da    :bottom-00,:bottom-03,:bottom-06,:bottom-09
                   da    :bottom-12,:bottom-15,:bottom-18,:bottom-21
                   da    :bottom-24,:bottom-27,:bottom-30,:bottom-33
                   da    :bottom-36,:bottom-39,:bottom-42,:bottom-45
                   da    :bottom-48
:top               sta   $F000,y
                   sta   $E000,y
                   sta   $D000,y
                   sta   $C000,y
                   sta   $B000,y
                   sta   $A000,y
                   sta   $9000,y
                   sta   $8000,y
                   sta   $7000,y
                   sta   $6000,y
                   sta   $5000,y
                   sta   $4000,y
                   sta   $3000,y
                   sta   $2000,y
                   sta   $1000,y
                   sta:  $0000,y
:bottom            rts

; SetDPAddrs
;
; A = absolute address (largest)
; Y = offset
;
; Initializes a bank of direct page offsets
SetDPAddrs
                   lda   #$0800
                   sta   $F000,y
                   lda   #$0700
                   sta   $E000,y
                   lda   #$0600
                   sta   $D000,y
                   lda   #$0500
                   sta   $C000,y
                   lda   #$0400
                   sta   $B000,y
                   lda   #$0300
                   sta   $A000,y
                   lda   #$0200
                   sta   $9000,y
                   lda   #$0100
                   sta:  $8000,y

                   lda   #$0800
                   sta   $7000,y
                   lda   #$0700
                   sta   $6000,y
                   lda   #$0600
                   sta   $5000,y
                   lda   #$0500
                   sta   $4000,y
                   lda   #$0400
                   sta   $3000,y
                   lda   #$0300
                   sta   $2000,y
                   lda   #$0200
                   sta   $1000,y
                   lda   #$0100
                   sta:  $0000,y
                   rts

; SetAbsAddrs
;
; A = absolute address (largest)
; Y = offset
; X = number of lines
;
; Stores a value and decrements by $1000 for each line
SetAbsAddrs        sec
                   jmp   (:tbl,x)
:tbl               da    :bottom-00,:bottom-03,:bottom-09,:bottom-15
                   da    :bottom-21,:bottom-27,:bottom-33,:bottom-39
                   da    :bottom-45,:bottom-51,:bottom-57,:bottom-63
                   da    :bottom-69,:bottom-75,:bottom-81,:bottom-87
                   da    :bottom-93
:top               sta   $F000,y
                   sbc   #$1000
                   sta   $E000,y
                   sbc   #$1000
                   sta   $D000,y
                   sbc   #$1000
                   sta   $C000,y
                   sbc   #$1000
                   sta   $B000,y
                   sbc   #$1000
                   sta   $A000,y
                   sbc   #$1000
                   sta   $9000,y
                   sbc   #$1000
                   sta   $8000,y
                   sbc   #$1000
                   sta   $7000,y
                   sbc   #$1000
                   sta   $6000,y
                   sbc   #$1000
                   sta   $5000,y
                   sbc   #$1000
                   sta   $4000,y
                   sbc   #$1000
                   sta   $3000,y
                   sbc   #$1000
                   sta   $2000,y
                   sbc   #$1000
                   sta   $1000,y
                   sbc   #$1000
                   sta:  $0000,y
:bottom            rts

; Fill up a full bank with blitter templates.  Currently we can fit 16 lines per bank, so need
; a total of 13 banks to hold the 208 lines for full-screen support
;
; A = high word of bank table
; Y = index * 4 of the bank to initialize
BuildBank

:bankArray         equ   tmp0
:target            equ   tmp2
:nextBank          equ   tmp4

                   stx   :bankArray
                   sta   :bankArray+2

                   stz   :target
                   iny
                   iny
                   lda   [:bankArray],y
                   sta   :target+2

                   iny                              ; move to the next item
                   iny
                   iny                              ; middle byte
                   cpy   #4*13                      ; if greater than the array length, wrap back to zero
                   bcc   :ok
                   ldy   #1
:ok                lda   [:bankArray],y             ; Get the middle and high bytes of the address
                   sta   :nextBank

:next
                   jsr   :BuildLine2
                   lda   :target
                   clc
                   adc   #$1000
                   sta   :target
                   bcc   :next

                   phb
                   pei   :target+1
                   plb
                   plb

; Change the patched value to one of DP_ENTRY, TWO_LYR_ENTRY or ONE_LYR_ENTRY based on the capabilities
; that the engine needs.

                   lda   #$F000+{DP_ENTRY}          ; Set the address from each line to the next
                   ldy   #CODE_EXIT+1
                   ldx   #15*2
                   jsr   SetAbsAddrs

                   ldy   #DP_ADDR
                   jsr   SetDPAddrs

                   ldy   #$F000+CODE_EXIT           ; Patch the last line with a JML to go to the next bank
                   lda   #{$005C+{DP_ENTRY}*256}
                   sta   [:target],y
                   ldy   #$F000+CODE_EXIT+2
                   lda   :nextBank
                   sta   [:target],y

                   ldy   #$8000+CODE_EXIT           ; Patch one line per bank to enable interrupts
                   lda   #{$004C+{ENABLE_INT}*256}
                   sta   [:target],y

                   plb
                   rts

; This is the relocation subroutine, it is responsible for copying the template to a
; memory location and patching up the necessary instructions.
;
; X = low word of address (must be a multiple of $1000)
; A = high word of address (bank)
:BuildLine
                   stx   :target
                   sta   :target+2

:BuildLine2
                   lda   #CODE_LEN                  ; round up to an even number of bytes
                   inc
                   and   #$FFFE
                   beq   :nocopy
                   dec
                   dec
                   tay
:loop              lda   base,y
                   sta   [:target],y

                   dey
                   dey
                   bpl   :loop

:nocopy            lda   #0                         ; copy is complete, now patch up the addresses
                   sep   #$20

                   ldx   #0
                   lda   :target+2                  ; patch in the bank for the absolute long addressing mode
:dobank            ldy   BankPatches,x
                   sta   [:target],y
                   inx
                   inx
                   cpx   #BankPatchNum
                   bcc   :dobank

                   ldx   #0
:dopage            ldy   PagePatches,x              ; patch the page addresses by adding the page offset to each
                   lda   [:target],y
                   clc
                   adc   :target+1
                   sta   [:target],y
                   inx
                   inx
                   cpx   #PagePatchNum
                   bcc   :dopage

:out
                   rep   #$20
                   rts

; Start of the template code.  This code is replicated 16 times per bank and spans
; 13 banks for a total of 208 lines, which is what is required to render 26 tiles
; to cover the full screen vertical scrolling.
;
; The 'base' location is always assumed to be on a 4kb ($1000) boundary.  We make sure that
; the code is assembled on a page boundary to help will alignment
                   ds    \,$00                      ; pad to the next page boundary
base
entry_1            ldx   #0000                      ; Used for LDA 00,x addressing
entry_2            ldy   #0000                      ; Used for LDA (00),y addressing
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
; Snippet Samples:
;
; Standard Two-level Mix (23 bytes)
;
;   Optimal     = 18 cycles (LDA/AND/ORA/PHA/JMP)
;  16-bit write = 21 cycles 
;   8-bit low   = 30 cycles
;   8-bit high  = 29 cycles
;
;  start     lda  (00),y        ; 6
;            and  #MASK         ; 3
;            ora  #DATA         ; 3 = 12 cycles to load the data
;            bcs  alt_exit      ; 2/3
;            pha                ; 4
;  out       brl  next          ; 4 Fast-path completes in 5 additional cycles
;
;  alt_exit  bvs  r_edge        ; 2/3 
;            clc                ; 2
;            brl  l_jmp_rtn     ; 3
;  r_edge    rep   #$41
;            brl  r_jmp_rtn     ; 3
;
;
; For dynamic masked tiles, we re-write bytes 2 - 8 as this, which mostly
; avoids an execution speed pentaly for having to fill in the two extra bytes
; with an instruction
;
;  start     lda  (00),y        ; 6
;            and  $80,x         ; 5
;            ora  $00,x         ; 5 = 16 cycles to load the data
;            bcc  *+4           ; 
;            bcs  alt_exit      ; 2/3
;            pha
;            ...
;
; A theoretical exception handler that performed a full 3-level blend would be
;
;  start     lda  0,s
;            and  [00],y
;            ora  (00),y
;            and  $80,x
;            ora  $00,x
;            and  #MASK
;            ora  #DATA
;            bcs  alt_exit
;            pha                ; 4
;  out       brl  next          ; 4 Fast-path completes in 5 additional cycles
;
;  alt_exit  bvs  r_edge        ; 2/3 
;            clc                ; 2
;            brl  l_jmp_rtn     ; 3
;  r_edge    rep   #$41
;            brl  r_jmp_rtn     ; 3

; Each snippet is provided 32 bytes of space.  The constant code is filled in from the end and
; it is the responsibility of the code that fills in the hander to create valid program in the
; first 23 bytes are available to be manipulated.
;
; Note that the code that's assembled in the first bytes of these snippets is just an example.  Every
; routine that created an exception handler *MUST* write a full set of instructions since there is
; no guarantee of what was written previously.
                   ds    \,$00                      ; pad to the next page boundary
]index             equ   0
snippets           lup   82
                   ds    2                          ; space for all exception handlers
                   and   #$0000                     ; the mask operand will be set when the tile is drawn
                   ora   #$0000                     ; the data operand will be set when the tile is drawn
                   ds    15                         ; extra padding

                   bcs   :byte                      ; if C = 0, just push the data and return
                   pha                              ; 1 byte 
                   jmp   loop+3+{3*]index}-base     ; 3 bytes
:byte              jmp   jmp_rtn-base               ; 3 bytes
]index             equ   ]index+1
                   --^
top