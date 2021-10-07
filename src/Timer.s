; Timer implementation
;
; The engire provides four timer slot that can be used by one-shot or 
; recurring timers.  Each timer is given an initial tick count, a 
; reset tick count (0 = one-shot), and an action to perform.
;
; The timers handle overflow, so if a recurring timer has a tick count of 3
; and 7 VBL ticks have passed, then the timer will be fired twice and
; a tick count of 2 will be set.
;
; As such, the timers are appropriate to drive physical and other game
; behaviors at a frame-independent rate.
;
; A collection of 4 timers that are triggered when their countdown
; goes below zero.  Each timer takes up 16 bytes
;
; A timer can fire multiple times during a singular evaluation.  For example, if the
; timer delay is set to 1 and 3 VBL ticks happen, then the timer delta is -2, will fire,
; have the delay added and get -1, fire again, increment to zero, first again and then
; finally reset to 1.
;
; +0 counter         decremented by the number of ticks since last run
; +2 reset           copied into counter when triggered. 0 turns off the timer.
; +4 addr            long address of timer routine
; +8 user            8 bytes of user data space for timer state
MAX_TIMERS      equ       4
TIMER_REC_SIZE  equ       16

lastTick        ds        2
Timers          ds        TIMER_REC_SIZE*MAX_TIMERS

GetVBLTicks     ENT
                jsr       _GetVBLTicks
                rtl
_GetVBLTicks
                PushLong  #0
                _GetTick
                pla
                plx
                rts

; Initialize the timers
InitTimers
                jsr       _GetVBLTicks
                sta       lastTick

                lda       #0
                ldx       #{TIMER_REC_SIZE*MAX_TIMERS}-2
:loop           sta       Timers,x
                dex
                dex
                bne       :loop
                rts

; Add a new timer
;
; Input
;  A = low word of timer callback function
;  X = high word of timer callback function
;  Y = number of ticks for the timer to delay
;  C = set to 1 if the timer is a one-shot timer
;
; Return
;  C = 0 if success, 1 if no timer slots are available
;  A = timer slot ID if C = 0
AddTimer        ENT
                phb

                php                                           ; Save the input parameters
                phx
                pha
                phy

                phk
                plb

                ldx       #0
:loop           lda       Timers,x                            ; If the counter is zero, timer is free
                beq       :freeslot

                txa                                           ; Advance to the next timer record
                clc
                adc       #TIMER_REC_SIZE
                tax

                cpx       #{TIMER_REC_SIZE*MAX_TIMERS}
                bcc       :loop
                bra       :notimers

:freeslot       pla
                sta       Timers+0,x                          ; set the counter and 
                stz       Timers+2,x                          ; default to a zero reset value
                pla
                sta       Timers+4,x                          ; set the callback address
                pla
                sta       Timers+6,x

                stz       Timers+8,x                          ; Clear the user data space
                stz       Timers+10,x                         ; Clear the user data space
                stz       Timers+12,x                         ; Clear the user data space
                stz       Timers+14,x                         ; Clear the user data space

                plp
                bcs       :oneshot
                lda       Timers+0,x                          ; if not a one-shot, put the counter
                sta       Timers+2,x                          ; value into the reset field

:oneshot        plb
                txa                                           ; return the slot ID and a success status
                clc
                rtl

:notimers       ply
                pla
                plx
                plp
                plb

                sec                                           ; Return an error status
                lda       #0
                rtl

; Small function to remove a timer
;
; A = Timer ID
RemoveTimer     ENT
                phb
                phk
                plb
                cmp       #{TIMER_REC_SIZE*{MAX_TIMERS-1}}+1
                bcs       :exit

                tax
                stz       Timers,x
                stz       Timers+2,x
                stz       Timers+4,x
                stz       Timers+6,x

:exit
                plb
                rtl

; Execute the timer functions
DoTimers        ENT
                phb
                phk
                plb

                jsr       _GetVBLTicks

                cmp       lastTick                            ; Throttle to 60 fps
                beq       :exit
                tax                                           ; Calculate the increment
                sec
                sbc       lastTick
                stx       lastTick

; We don't want times to fire excessively.  If the timer has nt been evaluated for over 
; one second, then just skip processing and wait for the next call.
                cmp       #60
                bcs       :exit

                jsr       _DoTimers

:exit           plb
                rtl

; Countdown the timers
;
; A = number of elapsed ticks
_DoTimers
                pha
                ldx       #0
:loop
                lda       Timers,x                            ; A zero means do not fire
                beq       :skip

                sec
                sbc       1,s                                 ; subtract the number of ticks
                sta       Timers,x

:retry          beq       :fire                               ; getting <= zero triggers
                bpl       :skip

:fire           pha                                           ; Save the counter
                phx                                           ; Save our index

                lda       Timers+4,x                          ; execute the timer callback
                sta       :dispatch+1
                lda       Timers+5,x
                sta       :dispatch+2
:dispatch       jsl       $000000

                plx
                pla

                lda       Timers+2,x                          ; Load the reset value, if it's zero
                beq       :oneshot                            ; then this was a one-shot timer

                clc
                adc       Timers,x                            ; Add to the current count and store
                sta       Timers,x
                bra       :retry                              ; See if we have >0 ticks to wait until the next trigger

:oneshot        stz       Timers,x

:skip           txa
                clc
                adc       #TIMER_REC_SIZE
                tax
                cpx       #{TIMER_REC_SIZE*MAX_TIMERS}
                bcc       :loop

                pla
                rts
