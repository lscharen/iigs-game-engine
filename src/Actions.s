MoveLeft
                     clc
                     adc   StartX               ; Increment the virtual X-position
                     jsr   SetBG0XPos

                     lda   StartX
                     lsr
                     jsr   SetBG1XPos

                     jsr   DoFrame
                     rts

MoveRight
                     pha
                     lda   StartX
                     sec
                     sbc   1,s
                     bpl   *+5
                     lda   #0
                     jsr   SetBG0XPos

                     lda   StartX
                     lsr
                     jsr   SetBG1XPos

                     jsr   DoFrame
                     pla
                     rts

MoveUp
                     clc
                     adc   StartY               ; Increment the virtual Y-position
                     jsr   SetBG0YPos

                     lda   StartY
                     lsr
                     jsr   SetBG1YPos

                     jsr   DoFrame
                     rts

MoveDown
                     pha
                     lda   StartY
                     sec
                     sbc   1,s
                     bpl   *+5
                     lda   #0
                     jsr   SetBG0YPos

                     lda   StartY
                     lsr
                     jsr   SetBG1YPos

                     jsr   DoFrame
                     pla
                     rts

; Very simple, scroll as fast as possible
oldOneSecondCounter  ds    2
frameCount           ds    2
Demo
                     lda   OneSecondCounter
                     sta   oldOneSecondCounter
                     stz   frameCount
:loop
                     lda   #1
                     jsr   MoveLeft
                     inc   frameCount

                     ldal  KBD_STROBE_REG
                     bit   #$0080
                     beq   :nokey
                     and   #$007F
                     cmp   #'s'
                     bne   :nokey
                     rts

:nokey
                     lda   OneSecondCounter
                     cmp   oldOneSecondCounter
                     beq   :loop

                     sta   oldOneSecondCounter

                     lda   #FPSStr
                     ldx   #0                   ; top-left corner
                     ldy   #$7777
                     jsr   DrawString

                     lda   frameCount
                     ldx   #4*4
                     jsr   DrawWord

                     stz   frameCount
                     bra   :loop

FPSStr               str   'FPS'









