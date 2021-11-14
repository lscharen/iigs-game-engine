; SCB binding.  Really just a fast copy from an array in memory to the SCBs for a range of
; physical lines.  Follow the same calling conventions as _BltRange
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
;
; The lines are based on the appearance of lines in the play field, so blitting lines 0 through
; 19 will draw the first 20 lines on the play field, regardless of where the playfield is physically
; on the SHR screen or the current value of StartY
;
; This could be made faster by forcing a SCB array to be copied into PEAs ahead of time, but this
; is a bit more flexible            
BltSCB      ENT
            phb
            phk
            plb
            jsr   _BltSCB
            plb
            rtl

_BltSCBOut
            rts
_BltSCB
            lda   SCBArrayPtr
            ora   SCBArrayPtr+2
            beq   _BltSCBOut

            phb                  ; preserve the bank register
            tsc                  ; save the stack pointer
            stal  :stk_save+1

            sep   #$20           ; Get the offset into the SCB array
            lda   SCBArrayPtr+2
            pha                  ; Stash the bank to set later
            rep   #$20

            lda   SCBArrayPtr+2
            bpl   :bind_to_bg0
            lda   BG1StartY
            bra   :bind_to_bg1
:bind_to_bg0 
            lda   StartY
:bind_to_bg1
            clc
            adc   SCBArrayPtr
            tax

            lda   ScreenHeight  ; Calculate the number of scan lines / entry point
            asl
            asl
            eor   #$FFFF
            inc
            clc
            adc   #:scb_end
            sta   :entry+1

            lda   ScreenY1       ; Get the SCB address to but into the stack register
            dec
            clc
            adc   #SHADOW_SCREEN_SCB

            plb                  ; Pop the bank with the SCB array
            sei                  ; turn off interrupts while we slam SCBs
            tcs                  ; set the stack to teh SCB area in Bank 01
            _R0W1
:entry      jmp   :scb_end

; 100 lda/pha to cover, potentialls, the full screen
]line       equ   198
            lup   100
            lda:  ]line,x
            pha
]line       equ   ]line-2
            --^
:scb_end

            _R0W0
:stk_save   lda   #0000          ; load the stack
            tcs
            cli                  ; re-enable interrupts

            plb                  ; restore the bank
            rts


; Quick helper to set the pointer (X = low word, A = hgih work)
SetSCBArray ENT
        jsr   _SetSCBArray
        rtl

_SetSCBArray
        stx  SCBArrayPtr
        sta  SCBArrayPtr+2
        rts
