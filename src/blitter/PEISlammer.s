; Implementation of a PEI Slammer that updates a rectangular screen area.  The only tweak that
; this implementation does is that it does break up the slam into chunks of scan lines to allow
; time for interrupts to be serviced in a timely manner.
;
; This is a fairly basic slam in that it does not try to align the direct page.  To enhance the
; slammer, note that page-aligned addresses repeat every 8 scan lines and some lines would need
; to be split into two slams to keep the direct page aligned.
;
; At best, this saves 1 cycles per word, or 80 cycles for a full scanline -- which is only about
; 12 additional instructions, so this is an optimization that is unlikely to lead to a net
; improvement.
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
_PEISlam
                 cpx   #200
                 bcc   *+4
                 brk   $14
;                 rts
                 cpy   #201
                 bcc   *+4
                 brk   $15
;                 rts

                 tya                    ; x must be less than y
                 stal  :screen_width_1
                 txa
                 cmpl  :screen_width_1
                 bcc   *+3
                 rts


                 lda   ScreenWidth
                 dec
                 stal  :screen_width_1  ; save the width-1 outside of the direct page

                 lda   #:pei_end        ; patch the PEI entry address
                 sec
                 sbc   ScreenWidth
                 stal  :inner+1

                 phx
                 tya
                 sec
                 sbc   1,s
                 ply
                 tay                    ; get the number of lines in the y register

                 txa
                 asl
                 tax
                 lda   RTable,x         ; This is the right visible byte, so add one to get the 
                 tax                    ; left visible byte (cache in x-reg)
                 sec
                 sbc   ScreenWidth
                 inc

                 phd                    ; save the current direct page and assign the base
                 tcd                    ; screen address to the direct page register

                 tsc
                 stal  :stk_save        ; save the stack pointer to restore later

                 clc                    ; clear before the loop -- nothing in the loop affect the carry bit
                 brl   :outer           ; hop into the entry point.

]dp              equ   158
                 lup   80               ; A full width screen is 160 bytes / 80 words
                 pei   ]dp
]dp              equ   ]dp-2
                 --^
:pei_end
                 tdc                    ; Move to the next line
                 adc   #160
                 tcd
                 adcl  :screen_width_1
                 tcs

                 cmp   #$9D00
                 bcc   *+4
                 beq   :exit
;                 brk   $85              ; Kill if stack is out of range

                 dey                    ; decrement the total counter, if zero then we're done
                 beq   :exit

                 dex                    ; decrement the inner counter.  Both counters are set
                 beq   :restore         ; up so that they fall-through by default to save a cycle
                                        ; per loop iteration.

:inner           jmp   $0000            ; 25 cycles of overhead per line. A full width slam executes all
                                        ; 80 of the PEI instructions which we expect to take 7 cycles
                                        ; since the direct page is not aligned.  So total overhead is
                                        ; 25 / (25 + 7 * 80) = 4.27% of execution
                                        ;
                                        ; Without the interrupt breaks, we could remove the dex/beq test
                                        ; and save 4 cycles per loop which takes the overhead down to
                                        ; only 3.6%

:restore
                 tsx                    ; save the current stack
                 _R0W0                  ; restore the execution environment and
                 ldal  :stk_save        ; give a few cycles to catch some interrupts
                 tcs
                 cli                    ; fall through here -- saves a BRA instruction

:outer
                 sei
                 txs                    ; set the stack address to the right edge
                 ldx   #8               ; Enable interrupts at least once every 8 lines
                 _R1W1
                 bra   :inner

:exit
                 _R0W0
                 ldal  :stk_save
                 tcs
                 cli

                 pld
                 rts

:stk_save        ds    2
:screen_width_1  ds    2

; A stashed memory location just in case we need it.  This is filled in the GTEStartUp()
tool_direct_page ds    2

; External entry point.  Can be called directly from another bank
PEISlam
                phd
                phb

                ldal   tool_direct_page
                tcd
                jsr    _SetDataBank             ; only affects accumulator
                jsr    _PEISlam
                plb
                pld
                rtl


