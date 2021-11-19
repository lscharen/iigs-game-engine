; _TBDynamicSpriteTile
;
; This tile type does not explicitly support horizontal or vertical flipping.  An appropriate tile
; descriptor should be passed into CopyTileToDyn to put the horizontally or vertically flipped source
; data into the dynamic tile buffer
_TBDynamicSpriteTile_00
                 sty             _Y_REG               ; This is restored in the macro

                 sta             _X_REG               ; Cache some column values derived from _X_REG
                 tax
                 clc
                 ldal            JTableOffset,x       ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

                 lda             _TILE_ID             ; Get the original tile descriptor
                 and             #$007F               ; clamp to < (32 * 4)
                 ora             #$B500
                 xba
                 sta             _OP_CACHE            ; This is the 2-byte opcode for to load the data

                 CopyDynSpriteWord  {0*SPRITE_PLANE_SPAN};$0003
                 CopyDynSpriteWord  {1*SPRITE_PLANE_SPAN};$1003
                 CopyDynSpriteWord  {2*SPRITE_PLANE_SPAN};$2003
                 CopyDynSpriteWord  {3*SPRITE_PLANE_SPAN};$3003
                 CopyDynSpriteWord  {4*SPRITE_PLANE_SPAN};$4003
                 CopyDynSpriteWord  {5*SPRITE_PLANE_SPAN};$5003
                 CopyDynSpriteWord  {6*SPRITE_PLANE_SPAN};$6003
                 CopyDynSpriteWord  {7*SPRITE_PLANE_SPAN};$7003

                 ldx             _X_REG
                 inx
                 inx
                 clc
                 ldal            JTableOffset,x       ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

                 lda             _OP_CACHE
                 adc             #$0200
                 sta             _OP_CACHE

                 CopyDynSpriteWord  {0*SPRITE_PLANE_SPAN}+2;$0000
                 CopyDynSpriteWord  {1*SPRITE_PLANE_SPAN}+2;$1000
                 CopyDynSpriteWord  {2*SPRITE_PLANE_SPAN}+2;$2000
                 CopyDynSpriteWord  {3*SPRITE_PLANE_SPAN}+2;$3000
                 CopyDynSpriteWord  {4*SPRITE_PLANE_SPAN}+2;$4000
                 CopyDynSpriteWord  {5*SPRITE_PLANE_SPAN}+2;$5000
                 CopyDynSpriteWord  {6*SPRITE_PLANE_SPAN}+2;$6000
                 CopyDynSpriteWord  {7*SPRITE_PLANE_SPAN}+2;$7000

                 rts
