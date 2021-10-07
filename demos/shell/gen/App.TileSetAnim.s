
TileAnimInit  ENT

              ldx   #168
              ldy   #0
              jsl   CopyTileToDyn
              ldx   #169
              ldy   #1
              jsl   CopyTileToDyn
              ldx   #208
              ldy   #2
              jsl   CopyTileToDyn
              ldx   #209
              ldy   #3
              jsl   CopyTileToDyn

              lda   #TileAnim_168   ; low word of handler
              ldx   #^TileAnim_168  ; high word of handler
              ldy   #15             ; number of ticks
              jsl   StartScript

              lda   #TileAnim_169
              ldx   #^TileAnim_169
              ldy   #15
              clc
              jsl   StartScript

              lda   #TileAnim_208
              ldx   #^TileAnim_208
              ldy   #15
              clc
              jsl   StartScript

              lda   #TileAnim_209
              ldx   #^TileAnim_209
              ldy   #15
              clc
              jsl   StartScript
              rts
TileAnim_168
              dw    $8006,169,0,0
              dw    $8006,171,0,0
              dw    $8006,173,0,0
              dw    $cd06,175,0,0
TileAnim_169
              dw    $8006,170,1,0
              dw    $8006,172,1,0
              dw    $8006,174,1,0
              dw    $cd06,176,1,0
TileAnim_208
              dw    $8006,209,2,0
              dw    $8006,211,2,0
              dw    $8006,213,2,0
              dw    $cd06,215,2,0
TileAnim_209
              dw    $8006,210,3,0
              dw    $8006,212,3,0
              dw    $8006,214,3,0
              dw    $cd06,216,3,0






