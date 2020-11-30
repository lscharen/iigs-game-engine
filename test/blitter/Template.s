; Template and equates for GTE blitter

                   mx    %00

DP_ADDR            equ   entry_1-base+1
BG1_ADDR           equ   entry_2-base+1
STK_ADDR           equ   entry_3-base+1

CODE_ENTRY         equ   entry_jmp-base+1             ; low byte of the page-aligned jump address
CODE_TOP           equ   loop-base
CODE_LEN           equ   top-base
CODE_EXIT          equ   even_exit-base
OPCODE_SAVE        equ   odd_exit-base+1              ; spot to save the code field opcode when patching exit BRA

LINES_PER_BANK     equ   16

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
PagePatchNum       equ   *-PagePatches

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

SetScreenRect      sty   ScreenHeight                 ; Save the screen height and width
                   stx   ScreenWidth

                   tax                                ; Temp save of the accumulator
                   and   #$00FF
                   sta   ScreenY0
                   clc
                   adc   ScreenHeight
                   sta   ScreenY1

                   txa                                ; Restore the accumulator
                   xba
                   and   #$00FF
                   sta   ScreenX0
                   clc
                   adc   ScreenWidth
                   sta   ScreenX1

                   lda   ScreenY0                     ; Calculate the address of the first byte
                   asl                                ; of the right side of the playfield
                   tax
                   lda   ScreenAddr,x
                   clc
                   adc   ScreenX1
                   dec
                   pha                                ; Save for second loop

                   ldx   #0
                   ldy   ScreenHeight
                   clc
:loop1             sta   RTable,x
                   adc   #160
                   inx
                   inx
                   dey
                   bne   :loop1

                   pla                                ; Reset the address and continue filling in the
                   ldy   ScreenHeight                 ; second half of the table
:loop2             sta   RTable,x
                   adc   #160
                   inx
                   inx
                   dey
                   bne   :loop2

                   rts

; Set the starting line of the virtual buffer that will be displayed on the first physical line
; of the screen rect.
;
; A = line number [0, 207]
;
; There are a few things that need to happen with the Y-position of the virtual buffer is changed:
;
;  1. The address of the stack in the code fields needs to be changed
;
; If there is a second background, then the Y-register value in the code field needs to
; change as well, but that is deferred until later because we don't want to duplicate work
; if both the BG0 Y-position and the BG1 Y-position is changed on the same frame.
;
; We have routines that operate on a single blitter bank at time, so we need to break up the loop
; into blocks of code aligned mod 16.  There is some housekeeping because the height of the screen
; could be less that one full bank. 
;
; Each of the within-bank subroutine takes the following arguments
;
;   X = number of lines * 2, 0 to 32
;   Y = starting line * $1000
;   A = value
;
; The pseudo-code for this subroutine is as follows.
;
; pre_line_count  = 0
; curr_bank = StartY / 16
;
; // If the start is not bank aligned, then calculate the pre-work
; start_mod_16 = StartY % 16
; if (start_mod_16 !== 0) {
;   pre_line_count = min(16 - start_mod_16, ScreenHeight)
;   do_action(curr_bank, start_mod_16, pre_line_count)
;   curr_bank = (curr_bank + 1) % 13
; }
;
; line_count = ScreenHeight - pre_line_count
; while (line_count > 16) {
;   do_action(curr_bank, 0, 16)
;   line_count -= 16
;   curr_bank = (curr_bank + 1) % 13
; }
; 
; if (line_count > 0) {
;   do_action(curr_bank, 0, line_count)
; }
;
; One hack we do is to push in *at least* enough bank values (ScreenHeight / 16) + 1 on the
; stack ahead of time and just pop them off in order.  At worst, this only adds about 10 cycles
; of overhead and eliminates an awkward 16-bit <-> 8-bit state switch within the inner loops.
;

bank_count         equ   tmp0
start_mod_16       equ   tmp1
line_x2            equ   tmp2                         ; A physical screen line; used to index into RTable
last_x2            equ   tmp3

SetYPos            sta   StartY                       ; Save the position

                   asl
                   sta   line_x2
                   lsr

; Now we need to calculate two things.  First, we get the code bank index that we are starting on. This
; is easy, it's just the value of floor(Y / 16), but we pre-multiple by 4 for indexing into the table
; of bank addresses.  Next, we need to calculate the number of banks that the current range spans.  This
; will be either floor(ScreenHeight / 16) or floor(ScreenHeight / 16) + 1 depending on the exact value
; of the Y position, so we actually calculate floor((ScreenHeight + Y % 16) / 16) and pre-multiple by 2.

                   lsr                                ; divide by 4 (Y / 18 * 4 => Y / 4) and then truncate
                   lsr                                ; the bottom two bits (and only keep relevant bits)
                   and   #$003C
                   tay



                   lda   StartY
                   and   #$000F
                   sta   start_mod_16                 ; Save for later
                   clc
                   adc   ScreenHeight
                   and   #$00F0                       ; Just keep the relevant nibble
                   lsr
                   lsr
                   lsr
                   tax                                ; Keep the value pre-multiplied by 2
                   lsr
                   sta   bank_count                   ; This is the total number of action calls to make

                   jsr   PushBanks                    ; Push the bank bytes on the stack

; Start of the main body of the function.  First, see if there are any unaligned lines to 
; handle in the first code bank.

                   lda   start_mod_16
                   beq   skip_pre

                   _Mul4096                           ; Save the offset into the code bank of the
                   tay                                ; first line.

                   lda   #16                          ; Now figure out how many lines to execute.  Usually
                   sec                                ; this will just be the lines to the end of the code
                   sbc   start_mod_16                 ; bank, but if the total screen height is smaller than
                   cmp   ScreenHeight                 ; the number of lines in the code bank, we need to clamp
                   bcc   :min_1                       ; the maximum value
                   lda   ScreenHeight
:min_1             asl                                ; multiply the count by two
                   pha                                ; save it for a second

                   clc
                   adc   line_x2
                   sta   line_x2                      ; advance the line counter
                   tax
                   ldal  RTable-2,x                   ; Load the ending address for this block

                   plx                                ; Pop the number of lines * 2 to fill
                   plb                                ; Set the code field bank
                   jsr   SetScreenAddrs

skip_pre           ldy   #0
                   lda   line_x2
                   clc
                   adc   #32
                   cmp


                   sec
                   plb                                ; Set the code field bank
                   ldal  RTable+30,x                  ; Load the highest address for this code field bank
                   jsr   SetScreenAddrsTop            ; to bypass the need to set the X register

                   txa
                   clc
                   adc   #32
                   tax

                   ldy   #0
                   jsr   SetScreenAddrsTop            ; bypass X-register

                   dec   loop_count

                   lda   line_count                   ; with some pre-calc, we can just decrement a 
                   sec                                ; counter because we know the remaining line
                   sbc   #16                          ; count is line_count % 16
                   sta   line_count
                   cmp   #16
                   bcs   core_loop

                   lda   line_count
                   beq   :no_post

:no_post
                   asl                                ; Y is still zero
                   tax

                   plb                                ; Set the code field bank
;               jsr   (action)


:out               phk                                ; Need to restore the current bank
                   plb
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
                   sbc   #$1101000000000000

                   cmp   #%0110100000000000
                   bcc   *+5
                   sbc   #$0110100000000000

                   cmp   #%0011010000000000
                   bcc   *+5
                   sbc   #$0011010000000000

                   cmp   #%0001101000000000
                   bcc   *+5
                   sbc   #$0001101000000000

                   cmp   #%0000110100000000
                   bcc   *+5
                   sbc   #$0000110100000000

                   cmp   #%0000011010000000
                   bcc   *+5
                   sbc   #$0000011010000000

                   cmp   #%0000001101000000
                   bcc   *+5
                   sbc   #$0000001101000000

                   cmp   #%0000000110100000
                   bcc   *+5
                   sbc   #$0000000110100000

                   cmp   #%0000000011010000
                   bcc   *+5
                   sbc   #$0000000011010000
                   rts

; BankYSetup
;
; This is the set of function that have to be done to set up all of the code banks
; for execution when the Y-Origin of the virtual screen changes.  The tasks are:
;
;  

; Copy tile data into code field.  Their are specialized copy routines
;
; CopyTileConst -- the first 16 tile numbers are reserved and can be used
;                  to draw a solid tile block
CopyTile           cmp   #$0010
                   bcs   :invalid
                   asl
                   tax
                   ldal  TilePatterns,x
                   bra   CopyTileConst
:invalid           rts

TilePatterns       dw    $0000,$1111,$2222,$3333
                   dw    $4444,$5555,$6666,$7777
                   dw    $8888,$9999,$AAAA,$BBBB
                   dw    $CCCC,$DDDD,$EEEE,$FFFF

CopyTileConst      sta:  $0000,y
                   sta:  $0003,y
                   sta   $1000,y
                   sta   $1003,y
                   sta   $2000,y
                   sta   $2003,y
                   sta   $3000,y
                   sta   $3003,y
                   sta   $4000,y
                   sta   $4003,y
                   sta   $5000,y
                   sta   $5003,y
                   sta   $6000,y
                   sta   $6003,y
                   sta   $7000,y
                   sta   $7003,y
                   rts

; Patch out the final JMP to jump to the long JML return code
;
; Y = starting line * $1000
SetReturn          lda   #$0280                       ; BRA *+4
                   sta   CODE_EXIT,y
                   rts

ResetReturn        lda   #$004C                       ; JMP $XX00
                   sta   CODE_EXIT,y
                   rts

; Fill in the even_exit JMP instruction to jump to the next line (all but last line)
SetNextLine        lda   #$F000+{entry_3-base}
                   ldy   #CODE_EXIT+1
                   ldx   #15*2
                   jmp   SetAbsAddrs

; Push a series of bank bytes onto the stack that are use to iterate among the
; different code banks.
;
; Y = starting index * 4
; X = number of bank
;
; Bytes are pushed in reverse order, so popping the banks will set the B register
; in acending order, as expected (top to bottom)
;
; This is a bit of an unusual routine, we switch to 8-bit index registers and 16-bit accumulator.
; That way we can cache the return address in the accumulator and use the index registers for
; moving the data.  This is OK, because the arrays are small, so X and Y are much smaller than 256.

PushBanks          pla                                ; Pop off the return address
                   sep   #$10
                   jmp   (:tbl,x)
:tbl               da    :bottom-04,:bottom-08,:bottom-12,:bottom-16
                   da    :bottom-20,:bottom-24,:bottom-28,:bottom-32
                   da    :bottom-36,:bottom-40,:bottom-44,:bottom-48
                   da    :bottom-52
:top               ldx:  BlitBuff+48,y                ; These are all 8-bit loads and pushes
                   phx
                   ldx:  BlitBuff+44,y
                   phx
                   ldx:  BlitBuff+42,y
                   phx
                   ldx:  BlitBuff+38,y
                   phx
                   ldx:  BlitBuff+34,y
                   phx
                   ldx:  BlitBuff+30,y
                   phx
                   ldx:  BlitBuff+26,y
                   phx
                   ldx:  BlitBuff+22,y
                   phx
                   ldx:  BlitBuff+18,y
                   phx
                   ldx:  BlitBuff+14,y
                   phx
                   ldx:  BlitBuff+10,y
                   phx
                   ldx:  BlitBuff+6,y
                   phx
                   ldx:  BlitBuff+2,y
                   phx
:bottom            rep   #$10
                   pha                                ; Push the return address back to the top of the stack
                   rts

; Patch an 8-bit or 16-bit value into the bank.  These are a set up unrolled loops to 
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
SetConst           jmp   (:tbl,x)
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

; SaveOpcode
;
; Save the values to the restore location.  This should only be used to patch the
; code field since the save location is fixed.  
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = store location * $1000
SaveOpcode         pha                                ; save the accumulator
                   ldal  :tbl,x
                   dec
                   plx                                ; put the accumulator into X
                   pha                                ; push the address into the stack
                   rts                                ; and jump

:tbl               da    :bottom-00,:bottom-06,:bottom-12,:bottom-18
                   da    :bottom-24,:bottom-30,:bottom-36,:bottom-42
                   da    :bottom-48,:bottom-54,:bottom-60,:bottom-66
                   da    :bottom-72,:bottom-78,:bottom-84,:bottom-90
                   da    :bottom-96
:top               lda   $F000,y
                   sta   $F000,x
                   lda   $E000,y
                   sta   $E000,x
                   lda   $D000,y
                   sta   $D000,x
                   lda   $C000,y
                   sta   $C000,x
                   lda   $B000,y
                   sta   $B000,x
                   lda   $A000,y
                   sta   $A000,x
                   lda   $9000,y
                   sta   $9000,x
                   lda   $8000,y
                   sta   $8000,x
                   lda   $7000,y
                   sta   $7000,x
                   lda   $6000,y
                   sta   $6000,x
                   lda   $5000,y
                   sta   $5000,x
                   lda   $4000,y
                   sta   $4000,x
                   lda   $3000,y
                   sta   $3000,x
                   lda   $2000,y
                   sta   $2000,x
                   lda   $1000,y
                   sta   $1000,x
                   lda:  $0000,y
                   sta:  $0000,x
:bottom            rts

; RestoreOpcode
;
; Restore the values to the opcode location.  This should only be used to restore the
; code field.
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = store location * $1000
RestoreOpcode      pha                                ; save the accumulator
                   ldal  :tbl,x
                   dec
                   plx                                ; put the accumulator into X
                   pha                                ; push the address into the stack
                   rts                                ; and jump

:tbl               da    :bottom-00,:bottom-06,:bottom-12,:bottom-18
                   da    :bottom-24,:bottom-30,:bottom-36,:bottom-42
                   da    :bottom-48,:bottom-54,:bottom-60,:bottom-66
                   da    :bottom-72,:bottom-78,:bottom-84,:bottom-90
                   da    :bottom-96

:top               lda   $F000,x
                   sta   $F000,y
                   lda   $E000,x
                   sta   $E000,y
                   lda   $D000,x
                   sta   $D000,y
                   lda   $C000,x
                   sta   $C000,y
                   lda   $B000,x
                   sta   $B000,y
                   lda   $A000,x
                   sta   $A000,y
                   lda   $9000,x
                   sta   $9000,y
                   lda   $8000,x
                   sta   $8000,y
                   lda   $7000,x
                   sta   $7000,y
                   lda   $6000,x
                   sta   $6000,y
                   lda   $5000,x
                   sta   $5000,y
                   lda   $4000,x
                   sta   $4000,y
                   lda   $3000,x
                   sta   $3000,y
                   lda   $2000,x
                   sta   $2000,y
                   lda   $1000,x
                   sta   $1000,y
                   lda:  $0000,x
                   sta:  $0000,y
:bottom            rts


; SetScreenAddrs
;
; A = initial screen location (largest)
; Y = starting line * $1000
; X = number of lines
;
; Automatically decrements address by 160 bytes each line
SetScreenAddrs     sec
                   jmp   (:tbl,x)
:tbl               da    :bottom-00,:bottom-03,:bottom-09,:bottom-15
                   da    :bottom-21,:bottom-27,:bottom-33,:bottom-39
                   da    :bottom-45,:bottom-51,:bottom-57,:bottom-63
                   da    :bottom-69,:bottom-75,:bottom-81,:bottom-87
                   da    :bottom-93
SetScreenAddrsTop
:top               sta   STK_ADDR+$F000,y
                   sbc   #160
                   sta   STK_ADDR+$E000,y
                   sbc   #160
                   sta   STK_ADDR+$D000,y
                   sbc   #160
                   sta   STK_ADDR+$C000,y
                   sbc   #160
                   sta   STK_ADDR+$B000,y
                   sbc   #160
                   sta   STK_ADDR+$A000,y
                   sbc   #160
                   sta   STK_ADDR+$9000,y
                   sbc   #160
                   sta   STK_ADDR+$8000,y
                   sbc   #160
                   sta   STK_ADDR+$7000,y
                   sbc   #160
                   sta   STK_ADDR+$6000,y
                   sbc   #160
                   sta   STK_ADDR+$5000,y
                   sbc   #160
                   sta   STK_ADDR+$4000,y
                   sbc   #160
                   sta   STK_ADDR+$3000,y
                   sbc   #160
                   sta   STK_ADDR+$2000,y
                   sbc   #160
                   sta   STK_ADDR+$1000,y
                   sbc   #160
                   sta:  STK_ADDR+$0000,y
:bottom            rts

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

; Full up a full bank with blitter templates.  Currently we can fit 16 lines per bank, so need
; a total of 13 banks to hold the 208 lines to full-screen support
;
; A = high word of bank table
; Y = index * 4 of the bank to initialize
bankArray          equ   tmp0
target             equ   tmp2
nextBank           equ   tmp4
BuildBank
                   stx   bankArray
                   sta   bankArray+2

                   stz   target
                   iny
                   iny
                   lda   [bankArray],y
                   sta   target+2

                   iny                                ; move to the next item
                   iny
                   iny                                ; middle byte
                   cpy   #4*13                        ; if greater than the array length, wrap back to zero
                   bcc   :ok
                   ldy   #1
:ok                lda   [bankArray],y                ; Get the middle and high bytes of the address
                   sta   nextBank

:next
                   jsr   BuildLine2
                   lda   target
                   clc
                   adc   #$1000
                   sta   target
                   bcc   :next

                   phb
                   pei   target+1
                   plb
                   plb

                   lda   #$F000+{entry_3-base}        ; Set the address from each line to the next
                   ldy   #CODE_EXIT+1
                   ldx   #15*2
                   jsr   SetAbsAddrs

                   ldy   #$F000+CODE_EXIT             ; Patch the last line with a JML to go to the next bank
                   lda   #{$005C+{entry_3-base}*256}
                   sta   [target],y
                   ldy   #$F000+CODE_EXIT+2
                   lda   nextBank
                   sta   [target],y

                   plb
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
                   lda   #CODE_LEN                    ; round up to an even number of bytes
                   inc
                   and   #$FFFE
                   beq   :nocopy
                   dec
                   dec
                   tay
:loop              lda   base,y
                   sta   [target],y

                   dey
                   dey
                   bpl   :loop

:nocopy            lda   #0                           ; copy is complete, now patch up the addresses
                   sep   #$20

                   ldx   #0
                   lda   target+2                     ; patch in the bank for the absolute long addressing mode
:dobank            ldy   BankPatches,x
                   sta   [target],y
                   inx
                   inx
                   cpx   #BankPatchNum
                   bcc   :dobank

                   ldx   #0
:dopage            ldy   PagePatches,x                ; patch the page addresses by adding the page offset to each
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
entry_1            ldx   #0000
entry_2            ldy   #0000
entry_3            lda   #0000
                   tcs

long_0
entry_jmp          jmp   $0100
                   dfb   $00                          ; if the screen is odd-aligned, then the opcode is set to 
;                                 ; $AF to convert to a LDA long instruction.  This puts the
;                                 ; first two bytes of the instruction field in the accumulator
;                                 ; and falls through to the next instruction.
;
;                                 ; We structure the line so that the entry point only needs to
;                                 ; update the low-byte of the address, the means it takes only
;                                 ; an amortized 4-cycles per line to set the entry pointbra

right_odd          bit   #$000B                       ; Check the bottom nibble to quickly identify a PEA instruction
                   beq   r_is_pea                     ; This costs 6 cycles in the fast-path

                   bit   #$0040                       ; Check bit 6 to distinguish between JMP and all of the LDA variants
                   bne   r_is_jmp

long_1             stal  *+4-base
                   dfb   $00,$00                      ; this here to avoid needing a BRA instruction back.  So the fast-path
;                                 ; gets a 1-cycle penalty, but we save 3 cycles here.

r_is_pea           xba                                ; fast code for PEA
                   sep   #$30
                   pha
                   rep   #$30
odd_entry          jmp   $0100                        ; unconditionally jump into the "next" instruction in the 
;                                 ; code field.  This is OK, even if the entry point was the
;                                 ; last instruction, because there is a JMP at the end of
;                                 ; the code field, so the code will simply jump to that
;                                 ; instruction directly.
;                                 ;
;                                 ; As with the original entry point, because all of the
;                                 ; code field is page-aligned, only the low byte needs to
;                                 ; be updated when the scroll position changes

r_is_jmp           sep   #$41                         ; Set the C and V flags which tells a snippet to push only the low byte
long_2             ldal  entry_jmp+1-base
long_3             stal  *+5-base
                   dfb   $4C,$00,$00                  ; Jump back to address in entry_jmp (this takes 16 cycles, is there a better way?)

; This is the spot that needs to be page-aligned. In addition to simplifying the entry address
; and only needing to update a byte instad of a word, because the code breaks out of the
; code field with a BRA instruction, we keep everything within a page to avoid the 1-cycle
; page-crossing penalty of the branch.
                   ds    204
loop_exit_1        jmp   odd_exit-base                ; +0   Alternate exit point depending on whether the left edge is 
loop_exit_2        jmp   even_exit-base               ; +3   odd-aligned

loop               lup   82                           ; +6   Set up 82 PEA instructions, which is 328 pixels and consumes 246 bytes
                   pea   $0000                        ;      This is 41 8x8 tiles in width.  Need to have N+1 tiles for screen overlap
                   --^
loop_back          jmp   loop-base                    ; +252 Ensure execution continues to loop around
loop_exit_3        jmp   even_exit-base               ; +255

odd_exit           lda   #0000                        ; This operand field is *always* used to hold the original 2 bytes of the code field
;                                 ; that are replaced by the needed BRA instruction to exit the code field.  When the
;                                 ; left edge is odd-aligned, we are able to immediately load the value and perform
;                                 ; similar logic to the right_odd code path above

left_odd           bit   #$000B
                   beq   l_is_pea

                   bit   #$0040
                   bne   l_is_jmp

long_4             stal  *+4-base
                   dfb   $00,$00
l_is_pea           xba
                   sep   #$30
                   pha
                   rep   #$30
                   bra   even_exit
l_is_jmp           sep   #$01                         ; Set the C flag (V is always cleared at this point) which tells a snippet to push only the high byte
long_5             ldal  entry_jmp+1-base
long_6             stal  *+5-base
                   dfb   $4C,$00,$00                  ; Jump back to address in entry_jmp (this takes 13 cycles, is there a better way?)

; JMP opcode = $4C, JML opcode = $5C
even_exit          jmp   $1000                        ; Jump to the next line.
                   ds    1                            ; space so that the last line in a bank can be patched into a JML
full_return        jml   blt_return                   ; Full exit

; Special epilogue: skip a number of bytes and jump back into the code field. This is useful for
;                   large, floating panels in the attract mode of a game, or to overlay solid
;                   dialog.

epilogue_1         tsc
                   sec
                   sbc   #0
                   tcs
                   jmp   $0000                        ; This jumps back into the code field
:out               jmp   $0000                        ; This jumps to the next epilogue chain element
                   ds    1

; Special epilogue: re-enable interrupts.  Used every 8 or 16 lines to allow music to continue playing
epilogue_2         ldal  stk_save                     ; restore the stack
                   tcs
                   sep   #$20                         ; 8-bit mode
                   ldal  STATE_REG                    ; Read Bank 0 / Write Bank 0
                   and   #$CF
                   stal  STATE_REG
                   cli
                   nop                                ; Give a couple of cycles
                   sei
                   ldal  STATE_REG
                   ora   #$10                         ; Read Bank 0 / Write Bank 1
                   stal  STATE_REG
                   rep   #$20
                   jmp   $0000
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




















































































































































