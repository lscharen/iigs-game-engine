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

SHADOW_REG      equ   $E0C035
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
            jsr   DrawStaticUI
            jsr   APUStartUp

            sep   #$30
            lda   #$f
            jsl   APU_STATUS_WRITE              ; turn on the first four channels by default
            rep   #$30


:update
            jsr   DrawUI
:evtloop
;            jsr   DrawDynUI             ; Always update to see changing internal APU values
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
            bne   :not_spc
            jsr   Toggle
            brl   :update

:not_spc    cmp   #'a'
            bne   :not_a
            lda   show_border
            eor   #1
            sta   show_border
:not_a

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
:toggle1    da    Toggle4000,Toggle4001,Toggle4002,Toggle4003
            da    Toggle4008,Toggle400A,Toggle400B,ToggleNoop
            da    Toggle4004,Toggle4005,Toggle4006,Toggle4007
            da    Toggle400C,Toggle400E,Toggle400F,Toggle4015
ToggleNoop
            brl   ToggleExit

Toggle4000
            lda   APU_PULSE1_REG1
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG1_WRITE
            brl   ToggleExit
Toggle4001
            lda   APU_PULSE1_REG2
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG2_WRITE
            brl   ToggleExit
Toggle4002
            lda   APU_PULSE1_REG3
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG3_WRITE
            brl   ToggleExit
Toggle4003
            lda   APU_PULSE1_REG4
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE1_REG4_WRITE
            brl   ToggleExit

Toggle4004
            lda   APU_PULSE2_REG1
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE2_REG1_WRITE
            brl   ToggleExit
Toggle4005
            lda   APU_PULSE2_REG2
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE2_REG2_WRITE
            brl   ToggleExit
Toggle4006
            lda   APU_PULSE2_REG3
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE2_REG3_WRITE
            brl   ToggleExit
Toggle4007
            lda   APU_PULSE2_REG4
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_PULSE2_REG4_WRITE
            brl   ToggleExit

Toggle4008
            lda   APU_TRIANGLE_REG1
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_TRIANGLE_REG1_WRITE
            brl   ToggleExit
Toggle400A
            lda   APU_TRIANGLE_REG3
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_TRIANGLE_REG3_WRITE
            brl   ToggleExit
Toggle400B
            lda   APU_TRIANGLE_REG4
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_TRIANGLE_REG4_WRITE
            brl   ToggleExit

Toggle400C
            lda   APU_NOISE_REG1
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_NOISE_REG1_WRITE
            brl   ToggleExit
Toggle400E
            lda   APU_NOISE_REG3
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_NOISE_REG3_WRITE
            brl   ToggleExit
Toggle400F
            lda   APU_NOISE_REG4
            ldx   CursorCol
            eor   ToggleTable,x
            jsl   APU_NOISE_REG4_WRITE
            brl   ToggleExit

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
            bne   :not_0
            lda   #6
            sta   CursorRow
            rts
:not_0
            cmp   #8
            bne   :not_8
            lda   #15
            sta   CursorRow
            rts
:not_8
            dec
            sta   CursorRow
            rts

MoveDown
            lda   CursorRow
            cmp   #6
            bne   :not_6
            stz   CursorRow
            rts
:not_6
            cmp   #15
            bne   :not_15
            lda   #8
            sta   CursorRow
            rts
:not_15
            inc
            sta   CursorRow
            rts

MoveLeft
            lda   CursorCol
            dec
            bpl   :store
            lda   CursorRow
            cmp   #15
            beq   :skip
            eor   #8
            sta   CursorRow
:skip
            lda   #7
:store      sta   CursorCol
            rts

MoveRight
            lda   CursorCol
            inc
            cmp   #8
            bcc   :store

            lda   CursorRow
            cmp   #15
            beq   :skip
            eor   #8
            sta   CursorRow
:skip
            lda   #0
:store      sta   CursorCol
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
                  ldal      KBD_REG
                  rep       #$20
                  pla
                  rts

                 mx  %00
InitGraphics
                 sep   #$20
                 lda   #$C1
                 stal  $E0C029         ; screen on

                 ldal  SHADOW_REG      ; shadow on
                 and   #$F7
                 stal  SHADOW_REG
                 rep   #$20

                 lda   #0
                 ldx   #0
:scbloop         stal  $012000,x
                 inx
                 inx
                 cpx   #$7E00
                 bcc   :scbloop

                 ldx    #0
:palloop         lda    DefaultPalette,x
                 stal  $019E00,x
                 inx
                 inx
                 cpx   #$20
                 bcc   :palloop
                 rts

DefaultPalette   ENT
                 dw    $0000,$0777,$0841,$072C
                 dw    $000F,$0080,$0F70,$0D00
                 dw    $0FA9,$0FF0,$00E0,$04DF
                 dw    $0DAF,$078F,$0CCC,$0FFF

; UI string templates
PULSE1_TITLE     str   'PULSE1'
PULSE2_TITLE     str   'PULSE2'
TRIANGLE_TITLE   str   'TRIANGLE'
NOISE_TITLE      str   'NOISE'
CONTROL_TITLE    str   'CONTROL'

PULSE_REG1_STR   str   'DDLCVVVV'
PULSE_REG2_STR   str   'EPPPNSSS'
PULSE_REG3_STR   str   'TTTTTTTT'
PULSE_REG4_STR   str   'LLLLLTTT'

TRIANGLE_REG1_STR   str   'CRRRRRRR'
TRIANGLE_REG3_STR   str   'TTTTTTTT'
TRIANGLE_REG4_STR   str   'LLLLLTTT'

NOISE_REG1_STR   str   '--LCVVVV'
NOISE_REG3_STR   str   'L---PPPP'
NOISE_REG4_STR   str   'LLLLL---'

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

; Draw stuff that will never be updated
DrawStaticUI
            ldx  #{6*4}+{ROW_SPAN*3}
            ldy  #$1111
            lda  #PULSE1_TITLE
            jsr  DrawString

            ldx  #{22*4}+{ROW_SPAN*3}
            ldy  #$1111
            lda  #PULSE2_TITLE
            jsr  DrawString

            ldx  #{6*4}+{ROW_SPAN*10}
            ldy  #$1111
            lda  #TRIANGLE_TITLE
            jsr  DrawString

            ldx  #{22*4}+{ROW_SPAN*10}
            ldy  #$1111
            lda  #NOISE_TITLE
            jsr  DrawString

            ldx  #{22*4}+{ROW_SPAN*16}
            ldy  #$1111
            lda  #CONTROL_TITLE
            jsr  DrawString

DrawUI
            jsr  DrawPulse1
            jsr  DrawPulse2
            jsr  DrawTriangle
            jsr  DrawNoise
            jsr  DrawControl

            jsr  DrawCursor
            rts

PULSE1_X   equ  1
PULSE1_Y   equ  5
DrawPulse1
            ldx  #{PULSE1_X*4}+{ROW_SPAN*PULSE1_Y}
            ldy  #$4444
            lda  #$4000
            jsr  DrawWord

            ldy  #PULSE_REG1_STR
            lda  APU_PULSE1_REG1
            ldx  #{{PULSE1_X+5}*4}+{ROW_SPAN*PULSE1_Y}
            jsr  DrawBitsHL


            ldx  #{PULSE1_X*4}+{ROW_SPAN*{PULSE1_Y+1}}
            ldy  #$4444
            lda  #$4001
            jsr  DrawWord

            ldy  #PULSE_REG2_STR
            lda  APU_PULSE1_REG2
            ldx  #{{PULSE1_X+5}*4}+{ROW_SPAN*{PULSE1_Y+1}}
            jsr  DrawBitsHL


            ldx  #{PULSE1_X*4}+{ROW_SPAN*{PULSE1_Y+2}}
            ldy  #$4444
            lda  #$4002
            jsr  DrawWord

            ldy  #PULSE_REG3_STR
            lda  APU_PULSE1_REG3
            ldx  #{{PULSE1_X+5}*4}+{ROW_SPAN*{PULSE1_Y+2}}
            jsr  DrawBitsHL


            ldx  #{PULSE1_X*4}+{ROW_SPAN*{PULSE1_Y+3}}
            ldy  #$4444
            lda  #$4003
            jsr  DrawWord

            ldy  #PULSE_REG4_STR
            lda  APU_PULSE1_REG4
            ldx  #{{PULSE1_X+5}*4}+{ROW_SPAN*{PULSE1_Y+3}}
            jsr  DrawBitsHL
            rts

PULSE2_X   equ  17
PULSE2_Y   equ  5
DrawPulse2
            ldx  #{PULSE2_X*4}+{ROW_SPAN*PULSE2_Y}
            ldy  #$4444
            lda  #$4004
            jsr  DrawWord

            ldy  #PULSE_REG1_STR
            lda  APU_PULSE2_REG1
            ldx  #{{PULSE2_X+5}*4}+{ROW_SPAN*PULSE2_Y}
            jsr  DrawBitsHL

            ldx  #{PULSE2_X*4}+{ROW_SPAN*{PULSE2_Y+1}}
            ldy  #$4444
            lda  #$4005
            jsr  DrawWord

            ldy  #PULSE_REG2_STR
            lda  APU_PULSE2_REG2
            ldx  #{{PULSE2_X+5}*4}+{ROW_SPAN*{PULSE2_Y+1}}
            jsr  DrawBitsHL

            ldx  #{PULSE2_X*4}+{ROW_SPAN*{PULSE2_Y+2}}
            ldy  #$4444
            lda  #$4006
            jsr  DrawWord

            ldy  #PULSE_REG3_STR
            lda  APU_PULSE2_REG3
            ldx  #{{PULSE2_X+5}*4}+{ROW_SPAN*{PULSE2_Y+2}}
            jsr  DrawBitsHL

            ldx  #{PULSE2_X*4}+{ROW_SPAN*{PULSE2_Y+3}}
            ldy  #$4444
            lda  #$4007
            jsr  DrawWord

            ldy  #PULSE_REG4_STR
            lda  APU_PULSE2_REG4
            ldx  #{{PULSE2_X+5}*4}+{ROW_SPAN*{PULSE2_Y+3}}
            jsr  DrawBitsHL

            rts


TRIANGLE_X  equ  1
TRIANGLE_Y  equ  12
DrawTriangle
            ldx  #{TRIANGLE_X*4}+{ROW_SPAN*TRIANGLE_Y}
            ldy  #$4444
            lda  #$4008
            jsr  DrawWord

            ldy  #TRIANGLE_REG1_STR
            lda  APU_TRIANGLE_REG1
            ldx  #{{TRIANGLE_X+5}*4}+{ROW_SPAN*TRIANGLE_Y}
            jsr  DrawBitsHL


            ldx  #{TRIANGLE_X*4}+{ROW_SPAN*{TRIANGLE_Y+1}}
            ldy  #$4444
            lda  #$400A
            jsr  DrawWord

            ldy  #TRIANGLE_REG3_STR
            lda  APU_TRIANGLE_REG3
            ldx  #{{TRIANGLE_X+5}*4}+{ROW_SPAN*{TRIANGLE_Y+1}}
            jsr  DrawBitsHL


            ldx  #{TRIANGLE_X*4}+{ROW_SPAN*{TRIANGLE_Y+2}}
            ldy  #$4444
            lda  #$400B
            jsr  DrawWord

            ldy  #TRIANGLE_REG4_STR
            lda  APU_TRIANGLE_REG4
            ldx  #{{TRIANGLE_X+5}*4}+{ROW_SPAN*{TRIANGLE_Y+2}}
            jsr  DrawBitsHL

            rts

NOISE_X  equ  17
NOISE_Y  equ  12
DrawNoise
            ldx  #{NOISE_X*4}+{ROW_SPAN*NOISE_Y}
            ldy  #$4444
            lda  #$400C
            jsr  DrawWord

            ldy  #NOISE_REG1_STR
            lda  APU_NOISE_REG1
            ldx  #{{NOISE_X+5}*4}+{ROW_SPAN*NOISE_Y}
            jsr  DrawBitsHL


            ldx  #{NOISE_X*4}+{ROW_SPAN*{NOISE_Y+1}}
            ldy  #$4444
            lda  #$400E
            jsr  DrawWord

            ldy  #NOISE_REG3_STR
            lda  APU_NOISE_REG3
            ldx  #{{NOISE_X+5}*4}+{ROW_SPAN*{NOISE_Y+1}}
            jsr  DrawBitsHL


            ldx  #{NOISE_X*4}+{ROW_SPAN*{NOISE_Y+2}}
            ldy  #$4444
            lda  #$400F
            jsr  DrawWord

            ldy  #NOISE_REG4_STR
            lda  APU_NOISE_REG4
            ldx  #{{NOISE_X+5}*4}+{ROW_SPAN*{NOISE_Y+2}}
            jsr  DrawBitsHL

            rts

; Draw the APU Status byte
CONTROL_X   equ  17
CONTROL_Y   equ  18
DrawControl
            ldx  #{CONTROL_X*4}+{ROW_SPAN*CONTROL_Y}
            ldy  #$4444
            lda  #$4015
            jsr  DrawWord

            ldy  #APU_STATUS_STR
            lda  APU_STATUS
            ldx  #{{CONTROL_X+5}*4}+{ROW_SPAN*CONTROL_Y}
            jsr  DrawBitsHL

            rts

DrawCursor
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
            adc  col2screen,x
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

row2screen  dw   5,6,7,8,12,13,14,0,5,6,7,8,12,13,14,18     ; 16 logical rows, 0-7 are column 1, 8-15 column 2
col2screen  dw   6,6,6,6,6, 6, 6, 0,22,22,22,22,22,22,22,22 ; 
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

setborder
        php
        sep  #$20
        eorl $E0C034
        and  #$0F
        eorl $E0C034
        stal $E0C034
        plp
        rts
        
            put   App.Msg.s
            put   font.s

            put   apu.s
