              REL
              DSK      MAINSEG

              use      EDS.GSOS.MACS.s
              use      ../../src/GTE.s
              use      ../../src/Defs.s


              mx       %00

; Space for player position variables
PlayerX       equ      AppSpace
PlayerY       equ      AppSpace+2

              phk
              plb

              jsl      EngineStartUp

              stz      PlayerX
              stz      PlayerY

              ldx      #0              ; Use full-screen mode
              jsl      SetScreenMode

:loop
              jsl      ReadControl
              and      #$007F          ; Ignore the buttons for now

              cmp      #'q'
              beq      :exit

; WASD for player movement

              cmp      #'w'
              bne      :not_w
              jsr      :moveup
              brl      :loop
:not_w

              cmp      #'a'
              bne      :not_a
              jsr      :moveleft
              brl      :loop
:not_a

              cmp      #'s'
              bne      :not_s
              jsr      :movedown
              brl      :loop
:not_s

              cmp      #'d'
              bne      :not_d
              jsr      :moveright
:not_d
              brl      :loop

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






















































