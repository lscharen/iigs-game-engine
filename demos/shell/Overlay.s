; Put a single-line overlay to display status information
Overlay
:top         equ   16
             ldy   #$2222

             lda   #TopLabel
             ldx   #{160*:top+4}
             jsr   DrawString
             ldx   #{160*:top+12}
;             lda   LastTop
;             jsr   DrawWord

             lda   #BottomLabel
             ldx   #{160*:top+32}
             jsr   DrawString
             ldx   #{160*:top+40}
;             lda   LastBottom
;             jsr   DrawWord

             lda   #LeftLabel
             ldx   #{160*:top+60}
             jsr   DrawString
             ldx   #{160*:top+68}
;             lda   LastLeft
;             jsr   DrawWord

             lda   #RightLabel
             ldx   #{160*:top+88}
             jsr   DrawString
             ldx   #{160*:top+96}
;             lda   LastRight
;             jsr   DrawWord


             lda   #XLabel
             ldx   #{160*{:top+8}+4}
             jsr   DrawString
             ldx   #{160*{:top+8}+12}
             lda   StartX
             jsr   DrawWord

             lda   #XModLabel
             ldx   #{160*{:top+8}+32}
             jsr   DrawString
             ldx   #{160*{:top+8}+40}
             lda   StartXMod164
             jsr   DrawWord

             lda   #YLabel
             ldx   #{160*{:top+8}+60}
             jsr   DrawString
             ldx   #{160*{:top+8}+68}
             lda   StartY
             jsr   DrawWord

             lda   #YModLabel
             ldx   #{160*{:top+8}+88}
             jsr   DrawString
             ldx   #{160*{:top+8}+96}
             lda   StartYMod208
             jsr   DrawWord


             lda   #DirtyLabel
             ldx   #{160*{:top+16}+4}
             jsr   DrawString
             ldx   #{160*{:top+16}+12}
             lda   DirtyBits
             jsr   DrawWord

             lda   #STWLabel
             ldx   #{160*{:top+16}+32}
             jsr   DrawString
             ldx   #{160*{:top+16}+48}
             lda   ScreenTileWidth
             jsr   DrawWord

             lda   #STHLabel
             ldx   #{160*{:top+16}+68}
             jsr   DrawString
             ldx   #{160*{:top+16}+84}
             lda   ScreenTileHeight
             jsr   DrawWord

             rts

TopLabel     str   'T:'
BottomLabel  str   'B:'
RightLabel   str   'R:'
LeftLabel    str   'L:'

XLabel       str   'X:'
YLabel       str   'Y:'
XModLabel    str   'X*'
YModLabel    str   'Y*'

DirtyLabel   str   'D:'
STWLabel     str   'STW:'
STHLabel     str   'STH:'



