; APU Sim
;
; Interactive driver for the APU emulation. Inspired by the liveNES ROM (https://github.com/plgDavid/livenes)

           REL

           use   EDS.GSOS.Macs

; Keycodes
LEFT_ARROW      equ   $08
RIGHT_ARROW     equ   $15
UP_ARROW        equ   $0B
DOWN_ARROW      equ   $0A

KBD_REG         equ   $E0C000
KBD_STROBE_REG  equ   $E0C010
VBL_STATE_REG   equ   $E0C019
MOD_REG         equ   $E0C025
COMMAND_KEY_REG equ   $E0C061
OPTION_KEY_REG  equ   $E0C062

; ReadControl return value bits
PAD_BUTTON_B    equ   $0100
PAD_BUTTON_A    equ   $0200
PAD_KEY_DOWN    equ   $0400

; Direct page space
MyUserId    equ   0
LastKey     equ   2

CursorRow   equ   4
CursorCol   equ   6

Tmp0        equ   128
Tmp1        equ   130

            mx  %00

            phk
            plb
            sta   MyUserId

            stz   CursorCol
            stz   CursorRow

            jsr   InitGraphics
            jsr   APUStartUp

            sep   #$30
            lda   #1
            jsl   APU_STATUS_WRITE              ; turn on the first pulse channel by default
            rep   #$30


:update
            jsr   DrawUI
:evtloop
            jsr   DrawDynUI             ; Always update to see changing internal APU values
            jsr   _ReadControl
            bit   #PAD_KEY_DOWN      ; Only response to actual key presses
            beq   :evtloop
 
            and   #$007F
            cmp   #'q'
            beq   :done

            cmp   #UP_ARROW
            bne   *+8
            jsr   MoveUp
            brl   :update

            cmp   #DOWN_ARROW
            bne   *+8
            jsr   MoveDown
            brl   :update

            cmp   #LEFT_ARROW
            bne   *+8
            jsr   MoveLeft
            brl   :update

            cmp   #RIGHT_ARROW
            bne   *+8
            jsr   MoveRight
            brl   :update

            cmp   #' '
            bne   :next
            jsr   Toggle
            brl   :update

:next
            brl   :evtloop
:done
            jsr   APUShutDown
Quit
            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

; Toggle an APU bit
Toggle
            mx    %11
            sep   #$30

            lda   CursorRow
            asl
            tax
            jmp   (:toggle1,x)
:toggle1    da    Toggle4000,Toggle4001,Toggle4002,Toggle4003,Toggle4015
Toggle4000
            lda   APU_PULSE1_REG1
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG1_WRITE
            bra   ToggleExit
Toggle4001
            lda   APU_PULSE1_REG2
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG2_WRITE
            bra   ToggleExit
Toggle4002
            lda   APU_PULSE1_REG3
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG3_WRITE
            bra   ToggleExit
Toggle4003
            lda   APU_PULSE1_REG4
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG4_WRITE
            bra   ToggleExit

Toggle4015
            lda   APU_STATUS
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_STATUS_WRITE
            bra   ToggleExit

TogglePulse2
ToggleExit
            rep   #$30
            rts

ToggleTable dfb  $80,$40,$20,$10,$08,$04,$02,$01
; Cursor navigation
            mx  %00
MoveUp 
            lda   CursorRow
            dec
            bpl   *+5
            lda   #4
            sta   CursorRow
            rts

MoveDown
            lda   CursorRow
            inc
            cmp   #5
            bcc   *+5
            lda   #0
            sta   CursorRow
            rts

MoveLeft
            lda   CursorCol
            dec
            bpl   *+5
            lda   #7
            sta   CursorCol
            rts

MoveRight
            lda   CursorCol
            inc
            cmp   #8
            bcc   *+5
            lda   #0
            sta   CursorCol
            rts

; Read the keyboard and paddle controls and return in a game-controller-like format
                 mx  %00
_ReadControl      pea       $0000               ; low byte = key code, high byte = %------AB 

                  sep       #$20
                  ldal      OPTION_KEY_REG      ; 'B' button
                  and       #$80
                  beq       :BNotDown

                  lda       #>PAD_BUTTON_B
                  ora       2,s
                  sta       2,s

:BNotDown
                  ldal      COMMAND_KEY_REG
                  and       #$80
                  beq       :ANotDown

                  lda       #>PAD_BUTTON_A
                  ora       2,s
                  sta       2,s

:ANotDown
                  ldal      KBD_STROBE_REG      ; read the keyboard
                  bit       #$80
                  beq       :KbdNotDwn          ; check the key-down status
                  and       #$7f
                  ora       1,s
                  sta       1,s

                  cmp       LastKey
                  beq       :KbdDown
                  sta       LastKey

                  lda       #>PAD_KEY_DOWN       ; set the keydown flag
                  ora       2,s
                  sta       2,s
                  bra       :KbdDown

:KbdNotDwn
                  stz       LastKey
:KbdDown
                  rep       #$20
                  pla
                  rts

                 mx  %00
InitGraphics
                 lda   #0
                 ldx   #0
:scbloop         stal  $E12000,x
                 inx
                 inx
                 cpx   #$7E00
                 bcc   :scbloop

                 ldx    #0
:palloop         lda    DefaultPalette,x
                 stal  $E19E00,x
                 inx
                 inx
                 cpx   #$20
                 bcc   :palloop

                 sep   #$20
                 lda   #$C1
                 stal  $E0C029
                 rep   #$20
                 rts

DefaultPalette   ENT
                 dw    $0000,$0777,$0841,$072C
                 dw    $000F,$0080,$0F70,$0D00
                 dw    $0FA9,$0FF0,$00E0,$04DF
                 dw    $0DAF,$078F,$0CCC,$0FFF

; UI string templates
PULSE1_TITLE     str   'PULSE1'
PULSE_REG1_STR   str   'DDLCVVVV'
PULSE_REG2_STR   str   'EPPPNSSS'
PULSE_REG3_STR   str   'TTTTTTTT'
PULSE_REG4_STR   str   'LLLLLTTT'
APU_STATUS_STR   str   '---DNT21'

ROW_SPAN    equ  {8*160}

DrawDynUI
            ldx  #{18*4}+{ROW_SPAN*5}
            ldy  #$3333
            lda  APU_PULSE1_LENGTH_COUNTER
            jsr  DrawByte

            ldx  #{18*4}+{ROW_SPAN*6}
            ldy  #$3333
            lda  APU_PULSE1_MUTE
            jsr  DrawByte

            ldx  #{18*4}+{ROW_SPAN*7}
            ldy  #$3333
            lda  APU_PULSE1_ENVELOPE
            jsr  DrawByte

            ldx  #{18*4}+{ROW_SPAN*8}
            ldy  #$3333
            lda  APU_PULSE1_CURRENT_PERIOD
            jsr  DrawWord


DrawUI
            ldx  #{1*4}+{ROW_SPAN*5}
            ldy  #$4444
            lda  #$4000
            jsr  DrawWord

            ldy  #PULSE_REG1_STR
            lda  APU_PULSE1_REG1
            ldx  #{6*4}+{ROW_SPAN*5}
            jsr  DrawBitsHL

            ldx  #{15*4}+{ROW_SPAN*5}
            ldy  #$5555
            lda  APU_PULSE1_REG1
            jsr  DrawByte



            ldx  #{1*4}+{ROW_SPAN*6}
            ldy  #$4444
            lda  #$4001
            jsr  DrawWord

            ldy  #PULSE_REG2_STR
            lda  APU_PULSE1_REG2
            ldx  #{6*4}+{ROW_SPAN*6}
            jsr  DrawBitsHL

            ldx  #{15*4}+{ROW_SPAN*6}
            ldy  #$5555
            lda  APU_PULSE1_REG2
            jsr  DrawByte



            ldx  #{1*4}+{ROW_SPAN*7}
            ldy  #$4444
            lda  #$4002
            jsr  DrawWord

            ldy  #PULSE_REG3_STR
            lda  APU_PULSE1_REG3
            ldx  #{6*4}+{ROW_SPAN*7}
            jsr  DrawBitsHL

            ldx  #{15*4}+{ROW_SPAN*7}
            ldy  #$5555
            lda  APU_PULSE1_REG3
            jsr  DrawByte



            ldx  #{1*4}+{ROW_SPAN*8}
            ldy  #$4444
            lda  #$4003
            jsr  DrawWord

            ldy  #PULSE_REG4_STR
            lda  APU_PULSE1_REG4
            ldx  #{6*4}+{ROW_SPAN*8}
            jsr  DrawBitsHL

            ldx  #{15*4}+{ROW_SPAN*8}
            ldy  #$5555
            lda  APU_PULSE1_REG4
            jsr  DrawByte


; Draw the APU Status byte

            ldx  #{1*4}+{ROW_SPAN*10}
            ldy  #$4444
            lda  #$4015
            jsr  DrawWord

            ldy  #APU_STATUS_STR
            lda  APU_STATUS
            ldx  #{6*4}+{ROW_SPAN*10}
            jsr  DrawBitsHL

            ldx  #{15*4}+{ROW_SPAN*10}
            ldy  #$5555
            lda  APU_STATUS
            jsr  DrawByte

            lda  CursorRow
            asl
            tax
            lda  row2screen,x             ; Get the physical position of each logical row
            asl
            asl
            asl
            asl
            asl
            pha
            asl
            asl
            clc
            adc  1,s
            asl
            asl
            asl
            sta  1,s
            lda  CursorCol
            clc
            adc  #6
            asl
            asl
            clc
            adc  1,s
            tax
            pla

            lda  #'_'
            ldy  #$FFFF
            jsr  DrawBottom

            rts

row2screen  dw   5,6,7,8,10
; Draw a byte as a series of bits using the template strings and
; the bit values to set the color
;
; x = screen coordinates
; y = string template
; a = byte value
DrawBitsHL
            and   #$00FF
            xba
            sta   Tmp0
            iny                      ; advance past string length byte
            sty   Tmp1

            ldy   #0
:loop
            phy

            lda   (Tmp1),y
            and   #$00FF

            ldy   #$1111     ; dk. grey
            asl   Tmp0
            bcc   *+5
            ldy   #$FFFF     ; white

            jsr   DrawChar

            txa
            clc
            adc   #4
            tax

            ply
            iny
            cpy   #8
            bcc   :loop
            rts

            put   App.Msg.s
            put   font.s

            put   apu.s
