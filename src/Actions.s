MoveLeft
                     clc
                     adc       StartX               ; Increment the virtual X-position
                     jsr       SetBG0XPos

                     lda       StartX
                     lsr
                     jsr       SetBG1XPos

                     jsr       DoFrame
                     rts

MoveRight
                     pha
                     lda       StartX
                     sec
                     sbc       1,s
                     bpl       *+5
                     lda       #0
                     jsr       SetBG0XPos

                     lda       StartX
                     lsr
                     jsr       SetBG1XPos

                     jsr       DoFrame
                     pla
                     rts

MoveUp
                     clc
                     adc       StartY               ; Increment the virtual Y-position
                     jsr       SetBG0YPos

                     lda       StartY
                     lsr
                     jsr       SetBG1YPos

                     jsr       DoFrame
                     rts

MoveDown
                     pha
                     lda       StartY
                     sec
                     sbc       1,s
                     bpl       *+5
                     lda       #0
                     jsr       SetBG0YPos

                     lda       StartY
                     lsr
                     jsr       SetBG1YPos

                     jsr       DoFrame
                     pla
                     rts

; Very simple, scroll as fast as possible
oldOneSecondCounter  ds        2
frameCount           ds        2
lastTick             ds        2
Demo
                     lda       OneSecondCounter
                     sta       oldOneSecondCounter
                     stz       frameCount

; Set a timer to fire every 16 ticks

                     lda       #6
                     sta       Timers
                     sta       Timers+2
                     lda       #UpdateBG1Offset
                     sta       Timers+4

; Every 3 ticks (20 fps) cycle some colors

                     lda       #3
                     sta       Timers+8
                     sta       Timers+10
                     lda       #DoColorCycle
                     sta       Timers+12
:loop
                     PushLong  #0
                     _GetTick
                     pla
                     plx

                     cmp       lastTick             ; Throttle to 60 fps
                     beq       :loop
                     tax                            ; Calculate the increment
                     sec
                     sbc       lastTick
                     stx       lastTick
                     jsr       _DoTimers

;                     lda       #1
;                     jsr       MoveLeft
                     jsr       DoFrame

                     inc       frameCount

                     ldal      KBD_STROBE_REG
                     bit       #$0080
                     beq       :nokey
                     and       #$007F
                     cmp       #'s'
                     bne       :nokey

                     rts

:nokey
                     lda       OneSecondCounter
                     cmp       oldOneSecondCounter
                     beq       :loop

                     sta       oldOneSecondCounter
                     lda       ScreenWidth
                     cmp       #150
                     bcs       :loop

                     lda       #FPSStr
                     ldx       #0                   ; top-left corner
                     ldy       #$7777
                     jsr       DrawString

                     lda       frameCount
                     ldx       #4*4
                     jsr       DrawWord

                     stz       frameCount
                     bra       :loop

FPSStr               str       'FPS'

; Move some colors around
DoColorCycle
                     ldal      $E19E00
                     tax
                     ldal      $E19E02
                     stal      $E19E00
                     txa
                     stal      $E19E02
                     rts

; Triggered timer to sway the background
UpdateBG1Offset
                     lda       BG1OffsetIndex
                     inc
                     inc
                     cmp       #32                  ; 16 entries x 2 for indexing
                     bcc       *+5
                     sbc       #32
                     sta       BG1OffsetIndex
                     rts

; A collection of 8 timers that are triggered when their countdown
; goes below zero.  Each time taks up 8 bytes
;
; +0 counter         decremented by the number of ticks since last run
; +2 reset           copied into counter when triggered. 0 turns off the timer.
; +4 addr            address of time routine
; +6 reserved
MAX_TIMERS           equ       4
Timers               ds        8*MAX_TIMERS

; Countdown the timers
;
; A = number of elapsed ticks
_DoTimers
                     pha
                     ldx       #0
:loop
                     lda       Timers,x
                     beq       :skip

                     sec
                     sbc       1,s                  ; subtract the number of ticks
                     sta       Timers,x

                     beq       :fire                ; getting to zero triggers
                     bpl       :skip

:fire                lda       Timers+2,x           ; Reset the timer
                     sta       Timers,x

                     phx                            ; Save our index
                     jsr       (Timers+4,x)
                     plx

:skip                txa
                     clc
                     adc       #8
                     tax
                     cpx       #8*MAX_TIMERS
                     bcc       :loop

                     pla
                     rts

































































