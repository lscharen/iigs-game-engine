; Implementation of a PEI Slammer that updates a rectangular screen area.  The only tweak that
; this implementation does is that it does break up the slam into chunks of scan lines to allow
; time for interrupts to be serviced in a timely manner.
;
; This is a fairly basic slam in that it does not try to align the direct page.  To enhance the
; slammer, note that page-aligned addresses repeat every 8 scan lines and some lines would need
; to be split into two slams to keep the direct page aligned.
;
; At best, this saves 1 cycles per word, or 80 cycles for a full screen -- which is only about
; 12 additional instructions, so this is an optimization that is unlikely to lead to a net
; improvement.
;
; A = base address of top-left edge of the screen
; Y = number of scanlines to blit
; X = width of the screen in bytes
PEISlam
               stx   :screen_width  ; save the width

               phd                  ; save the current direct page and assign the base
               tcd                  ; screen address to the direct page register
               clc
               adc   :screen_width  ; screen address of the right edge (will go in stack)
               tax                  ; but cache in x register for a bit....

               tsc
               sta   :stk_save      ; save the stack pointer to restore later

               lda   #:pei_end      ; patch the PEI entry address
               sec
               sbc   :screen_width
               sta   :inner+1

               clc                  ; clear before the loop -- nothing in the loop affect the carry bit
               brl   :outer         ; hop into the entry point.

]dp            equ   158
               lup   80             ; A full width screen is 160 bytes / 80 words
               pei   ]dp
]dp            equ   ]dp-2
               --^
:pei_end
               tdc                  ; Move to the next line
               adc   #160
               tcd
               adc   :screen_width
               tcs

               dey                  ; decrement the total counter, if zero then we're done
               beq   :exit

               dex                  ; decrement the inner counter.  Both counters are set
               beq   :restore       ; up so that they fall-through by default to save a cycle
                                    ; per loop iteration.

:inner         jmp   $0000          ; 25 cycles of overhead per line. A full width slam executes all
                                    ; 80 of the PEI instructions which we expect to take 7 cycles
                                    ; since the direct page is not aligned.  So total overhead is
                                    ; 25 / (25 + 7 * 80) = 4.27% of execution
                                    ;
                                    ; Without the interrupt breaks, we could remove the dex/beq test
                                    ; and save 4 cycles per loop which takes the overhead down to
                                    ; only 3.6%

:restore
               tsx                  ; save the current stack
               _R0W0                ; restore the execution environment and
               lda   :stk_save      ; give a few cycles to catch some interrupts
               tcs
               cli                  ; fall through here -- saves a BRA instruction

:outer
               sei
               txs                  ; set the stack address to the right edge
               ldx   #8             ; Enable interrupts at least once every 8 lines
               _R1W1
               bra   :inner

:exit
               _R0W0
               lda   :stk_save
               tcs
               cli

               pld
               rts

:stk_save      ds    2
:screen_width  ds    2































































