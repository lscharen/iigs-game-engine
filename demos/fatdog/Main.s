              REL
              DSK      MAINSEG

              use      EDS.GSOS.MACS.s
              use      Tool222.Macs.s
              use      ../../src/GTE.s
              use      ../../src/Defs.s


              mx       %00

; Space for player position variables
PlayerX       equ      AppSpace
PlayerY       equ      AppSpace+2

; Timer handle
TimerHndl     dw       $FFFF
IntroCounter  ds       2

              phk
              plb

              jsl      EngineStartUp

              stz      PlayerX
              stz      PlayerY

              ldx      #0              ; Use full-screen mode
              jsl      SetScreenMode
              bcs      *+5
              sta      TimerHndl


              stz      IntroCounter
              ldx      #^IntroTask
              lda      #IntroTask
              ldy      #10             ; Play at 6 fps
              jsl      AddTimer
              bcs      *+5
              sta      TimerHndl

:loop
              jsl      DoTimers
              jsl      ReadControl
              and      #$007F          ; Ignore the buttons for now

              cmp      #'q'
              beq      :exit

; Just keep drawing the player.  The timer task will animate the position

              jsr      DrawPlayer
              bra      :loop

:moveup
              lda      PlayerY
              dec
              bpl      *+5
              lda      #0
              sta      PlayerY
              jmp      DrawPlayer

:movedown
              lda      PlayerY
              inc
              cmp      #160
              bcc      *+5
              lda      #160
              sta      PlayerY
              jmp      DrawPlayer

:moveleft
              lda      PlayerX
              dec
              bpl      *+5
              lda      #0
              sta      PlayerX
              jmp      DrawPlayer

:moveright
              lda      PlayerX
              inc
              cmp      #140
              bcc      *+5
              lda      #140
              sta      PlayerX
              jmp      DrawPlayer

; Clean up and do a GS/OS Quit
:exit
              jsl      EngineShutDown

:quit
              _QuitGS  qtRec
              bcs      :fatal
:fatal        brk      $00

qtRec         adrl     $0000
              da       $00

; Play a scripted animation
IntroTask
              phb
              phk
              plb

              lda      IntroCounter
              and      #$0007
              asl
              asl
              tax

              lda      IntroPath,x     ; X coordinate
              sta      PlayerX
              lda      IntroPath+2,x   ; Y coordinate
              sta      PlayerY

              inc      IntroCounter
              plb
              rtl

IntroPath     dw       0,0,10,0,20,0,20,5,20,7,35,15,50,17,80,20

DrawPlayer
              lda      PlayerY
              asl
              tax
              ldal     ScreenAddr,x
              clc
              adc      PlayerX
              tay
              jsl      Spr_001
              rts

; Storage for tiles (not used in this demo)
tiledata      ENT

; Storage for sprites
StackAddress  ds       2
              PUT      sprites/Ships.s
















