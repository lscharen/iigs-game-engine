; _TBDynamicPrioritySpriteTile
;
; Variant of _TBDynamicSpriteTile (Tile10001), but draw the sprite data behind the dynamic tile 
_TBDynamicPrioritySpriteTile_00
                jsr      _TBDynamicPriorityDataAndMask
                jmp      _TBFillJMPOpcode

_TBDynamicPriorityDataAndMask
                 sty             _Y_REG               ; This is restored in the macro

                 sta             _X_REG               ; Cache some column values derived from _X_REG
                 tax
                 clc
                 ldal            JTableOffset,x       ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

                 lda             _TILE_ID             ; Get the original tile descriptor
                 and             #$007F               ; clamp to < (32 * 4)
                 ora             #$3580               ; Pre-calc the AND $80,x opcode + operand
                 xba
                 sta             _OP_CACHE            ; This is an op to load the dynamic tile data

                 ldx             _SPR_X_REG

                 CopyDynPriSpriteWord  {0*SPRITE_PLANE_SPAN};$0003
                 CopyDynPriSpriteWord  {1*SPRITE_PLANE_SPAN};$1003
                 CopyDynPriSpriteWord  {2*SPRITE_PLANE_SPAN};$2003
                 CopyDynPriSpriteWord  {3*SPRITE_PLANE_SPAN};$3003
                 CopyDynPriSpriteWord  {4*SPRITE_PLANE_SPAN};$4003
                 CopyDynPriSpriteWord  {5*SPRITE_PLANE_SPAN};$5003
                 CopyDynPriSpriteWord  {6*SPRITE_PLANE_SPAN};$6003
                 CopyDynPriSpriteWord  {7*SPRITE_PLANE_SPAN};$7003

                 ldx             _X_REG
                 clc
                 ldal            JTableOffset+2,x     ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

                 lda             _OP_CACHE
                 adc             #$0200
                 sta             _OP_CACHE

                 ldx             _SPR_X_REG

                 CopyDynPriSpriteWord  {0*SPRITE_PLANE_SPAN}+2;$0000
                 CopyDynPriSpriteWord  {1*SPRITE_PLANE_SPAN}+2;$1000
                 CopyDynPriSpriteWord  {2*SPRITE_PLANE_SPAN}+2;$2000
                 CopyDynPriSpriteWord  {3*SPRITE_PLANE_SPAN}+2;$3000
                 CopyDynPriSpriteWord  {4*SPRITE_PLANE_SPAN}+2;$4000
                 CopyDynPriSpriteWord  {5*SPRITE_PLANE_SPAN}+2;$5000
                 CopyDynPriSpriteWord  {6*SPRITE_PLANE_SPAN}+2;$6000
                 CopyDynPriSpriteWord  {7*SPRITE_PLANE_SPAN}+2;$7000

                 rts


; Masked renderer for a dynamic tile with sprite data overlaid.
;
; ]1 : sprite plane offset
; ]2 : code field offset
CopyDynPriSpriteWord MAC

; Need to fill in the first 9 bytes of the JMP handler with the following code sequence where
; the data and mask from from the sprite plane
;
;            lda  #DATA
;            and  $80,x
;            ora  $00,x
;            bra  *+16

                lda   _JTBL_CACHE     ; Get the offset to the exception handler for this column
                ora   #{]2&$F000}     ; adjust for the current row offset
                sta:  ]2+1,y
                tay                   ; This becomes the new address that we use to patch in

                lda   #$00A9          ; LDA #DATA
                sta:  $0000,y
                ldal  spritedata+{]1},x
                sta:  $0001,y

                lda   _OP_CACHE
                sta:  $0003,y         ; AND $80,x
                eor   #$8020          ; Switch the opcode to an ORA and remove the high bit of the operand
                sta:  $0005,y         ; ORA $00,x

                lda   #$0E80          ; branch to the prologue (BRA *+16)
                sta:  $0007,y

                ldy   _Y_REG          ; restore original y-register value and move on
                eom