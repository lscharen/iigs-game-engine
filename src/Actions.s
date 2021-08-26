MoveLeft
                     clc
                     adc       StartX               ; Increment the virtual X-position
                     jsl       SetBG0XPos

                     lda       StartX
                     lsr
                     jsl       SetBG1XPos

                     jsl       Render
                     rts

MoveRight
                     pha
                     lda       StartX
                     sec
                     sbc       1,s
                     bpl       *+5
                     lda       #0
                     jsl       SetBG0XPos

                     lda       StartX
                     lsr
                     jsl       SetBG1XPos

                     jsl       Render
                     pla
                     rts

MoveUp
                     clc
                     adc       StartY               ; Increment the virtual Y-position
                     pha

                     lda       #240                 ; virtual play field height
                     sec
                     sbc       ScreenHeight
                     tax
                     cmp       1,s
                     bcc       *+4
                     lda       1,s
                     jsl       SetBG0YPos
                     pla

;                     lda       StartY
;                     lsr
;                     jsl       SetBG1YPos

                     jsl       Render
                     rts

MoveDown
                     pha
                     lda       StartY
                     sec
                     sbc       1,s
                     bpl       *+5
                     lda       #0
                     jsl       SetBG0YPos

;                     lda       StartY
;                     lsr
;                     jsl       SetBG1YPos

                     jsl       Render
                     pla
                     rts

; Very simple, scroll as fast as possible
oldOneSecondCounter  ds        2
frameCount           ds        2
lastTick             ds        2
Demo
                     ldal      OneSecondCounter
                     sta       oldOneSecondCounter
                     stz       frameCount

; Every 3 ticks (20 fps) cycle some colors

                     lda       #DoColorCycle
                     ldx       #^DoColorCycle
                     ldy       #3
                     jsl       AddTimer

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
;                     jsr       _DoTimers

;                     lda       #1
;                     jsr       MoveLeft
                     jsr       UpdateBG1Rotation
;                     jsr       DoColorCycle
                     jsl       Render

                     inc       frameCount

                     ldal      KBD_STROBE_REG
                     bit       #$0080
                     beq       :nokey
                     and       #$007F
                     cmp       #'s'
                     bne       :nokey

                     rts

:nokey
                     ldal      OneSecondCounter
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

; Move some colors around color (6 - 11) address 12 - 22
DoColorCycle
                     ldal      $E19E0C
                     pha
                     ldal      $E19E0E
                     pha
                     ldal      $E19E10
                     pha
                     ldal      $E19E12
                     pha
                     ldal      $E19E14
                     pha
                     ldal      $E19E16
                     stal      $E19E0C
                     pla
                     stal      $E19E16
                     pla
                     stal      $E19E14
                     pla
                     stal      $E19E12
                     pla
                     stal      $E19E10
                     pla
                     stal      $E19E0E
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

AngleUp
                     lda       angle
                     inc
                     cmp       #64
                     bcc       *+5
                     sbc       #64
                     sta       angle
                     jsr       _ApplyAngle
                     jsl       Render
                     rts

AngleDown
                     lda       angle
                     dec
                     bpl       *+6
                     clc
                     adc       #64
                     sta       angle
                     jsr       _ApplyAngle
                     jsl       Render
                     rts

angle                dw        0
UpdateBG1Rotation
                     jsr       _ApplyAngle
; Increment the angle
                     lda       angle
                     inc
                     cmp       #64
                     bcc       *+5
                     lda       #0
                     sta       angle
                     rts

x_angles             EXT
y_angles             EXT
_ApplyAngle
                     lda       angle                ; debug with angle = 0
                     asl
                     tax
                     ldal      x_angles,x           ; load the address of addressed for this angle
                     tay
                     phx
                     jsl       ApplyBG1XPosAngle
                     plx

                     ldal      y_angles,x           ; load the address of addresses for this angle
                     tay
                     jsl       ApplyBG1YPosAngle

                     rts


