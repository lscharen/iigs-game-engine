; Implementation of a PEI Slammer that updates a rectangular screen area.  The only tweak that
; this implementation does is that it does break up the slam into chunks of scan lines to allow
; time for interrupts to be serviced in a timely manner.
;
; A = base address of top-left edge of the screen
; Y = number of scanlines to blit
; X = width of the screen in bytes
PEISlam
               stx   :screen_width  ; save the width

               phd                  ; save the current direct page and assign the base
               tcd                  ; creen address to the direct page register

               tsc
               sta   :stk_save      ; save the stack pointer to restore later

               lda   #:pei_end      ; patch the PEI entry address
               sec
               sbc   :screen_width
               sta   :inner+1

               clc                  ; clear before the loop -- nothing in the loop affect the carry bit
               bra   :outer         ; hop into the entry point.  The loop control logic is next because 
                                    ; the size of the PEI instruction is too large to use short branches
                                    ; in the code after pei_end

:control
               tdc                  ; Move to the next line
               adc   #160
               tcd
               adc   :screen_width
               tcs

               dey                  ; decrement the total counter, if zero then we're done
               beq   :exit

               dex                  ; decrement the inner counter
               bne   :inner         ; if not zero, no break; go to the next line

               _R0W0                ; restore the execution environment and
               lda   :stk_save      ; give a few cycles to catch some interrupts
               tcs
               cli                  ; fall through here -- saves a BRA instruction

:outer
               ldx   #8             ; Enable interrupts at least once every 8 lines
               sei
               _R1W1
:inner         jmp   $0000

:exit
               _R0W0
               lda   :stk_save
               tcs
               cli

               pld
               rts

]dp            equ   158
               lup   80             ; A full width screen is 160 bytes / 80 words
               pei   ]dp
]dp            equ   ]dp-2
               --^
:pei_end
               jmp   :control

:stk_save      ds    2
:screen_width  ds    2















































