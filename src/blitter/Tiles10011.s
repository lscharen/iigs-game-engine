; _TBDynamicMaskedSpriteTile
;
; This tile type does not explicitly support horizontal or vertical flipping.  An appropriate tile
; descriptor should be passed into CopyTileToDyn to put the horizontally or vertically flipped source
; data into the dynamic tile buffer
;
; When rendering, the background, via lda (dp),y, is shown behind the animate sprite
_TBDynamicMaskedSpriteTile_00
                 sty             _Y_REG               ; This is restored in the macro

                 sta             _X_REG               ; Cache some column values derived from _X_REG
                 tax
                 ora             #$B100               ; Pre-calc the LDA (dp),y opcode + operand
                 xba
                 sta             _OP_CACHE

                 clc
                 ldal            JTableOffset,x       ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

                 lda             _TILE_ID             ; Get the original tile descriptor
                 and             #$007F               ; clamp to < (32 * 4)
                 ora             #$3580               ; Pre-calc the AND $80,x opcode + operand
                 xba
                 sta             _T_PTR               ; This is an op to load the dynamic tile data

                 ldx             _SPR_X_REG

                 CopyDynMaskedSpriteWord  {0*SPRITE_PLANE_SPAN};$0003
                 CopyDynMaskedSpriteWord  {1*SPRITE_PLANE_SPAN};$1003
                 CopyDynMaskedSpriteWord  {2*SPRITE_PLANE_SPAN};$2003
                 CopyDynMaskedSpriteWord  {3*SPRITE_PLANE_SPAN};$3003
                 CopyDynMaskedSpriteWord  {4*SPRITE_PLANE_SPAN};$4003
                 CopyDynMaskedSpriteWord  {5*SPRITE_PLANE_SPAN};$5003
                 CopyDynMaskedSpriteWord  {6*SPRITE_PLANE_SPAN};$6003
                 CopyDynMaskedSpriteWord  {7*SPRITE_PLANE_SPAN};$7003

                 ldx             _X_REG
                 clc
                 ldal            JTableOffset+2,x     ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

                 lda             _OP_CACHE
                 adc             #$0200
                 sta             _OP_CACHE
                 lda             _T_PTR
                 adc             #$0200
                 sta             _T_PTR

                 ldx             _SPR_X_REG

                 CopyDynMaskedSpriteWord  {0*SPRITE_PLANE_SPAN}+2;$0000
                 CopyDynMaskedSpriteWord  {1*SPRITE_PLANE_SPAN}+2;$1000
                 CopyDynMaskedSpriteWord  {2*SPRITE_PLANE_SPAN}+2;$2000
                 CopyDynMaskedSpriteWord  {3*SPRITE_PLANE_SPAN}+2;$3000
                 CopyDynMaskedSpriteWord  {4*SPRITE_PLANE_SPAN}+2;$4000
                 CopyDynMaskedSpriteWord  {5*SPRITE_PLANE_SPAN}+2;$5000
                 CopyDynMaskedSpriteWord  {6*SPRITE_PLANE_SPAN}+2;$6000
                 CopyDynMaskedSpriteWord  {7*SPRITE_PLANE_SPAN}+2;$7000

                 rts


; Masked renderer for a masked dynamic tile with sprite data overlaid.
;
; ]1 : sprite plane offset
; ]2 : code field offset
CopyDynMaskedSpriteWord MAC

; Need to fill in the first 14 bytes of the JMP handler with the following code sequence where
; the data and mask from from the sprite plane
;
;            lda  ($00),y
;            and  $80,x
;            ora  $00,x
;            and  #MASK
;            ora  #DATA
;            bra  *+15
;
; If MASK == 0, then we can do a PEA.  If MASK == $FFFF, then fall back to the simple Dynamic Tile
; code and eliminate the constanct AND/ORA instructions.

                ldal  spritemask+]1,x            ; load the mask value
                bne   mixed                      ; a non-zero value may be mixed

; This is a solid word
                lda   #$00F4          ; PEA instruction
                sta:  ]2,y
                ldal  spritedata+]1,x ; load the sprite data
                sta:  ]2+1,y          ; PEA operand
                bra   next

; We will always do a JMP to the eception handler, so set that up, then check for sprite
; transparency
mixed
                lda   #$004C          ; JMP to handler
                sta:  ]2,y
                lda   _JTBL_CACHE     ; Get the offset to the exception handler for this column
                ora   #{]2&$F000}     ; adjust for the current row offset
                sta:  ]2+1,y
                tay                   ; This becomes the new address that we use to patch in

                lda   _OP_CACHE
                sta:  $0000,y         ; LDA (00),y
                lda   _T_PTR
                sta:  $0002,y         ; AND $80,x
                eor   #$8020          ; Switch the opcode to an ORA and remove the high bit of the operand
                sta:  $0004,y         ; ORA $00,x

                lda   #$0029          ; AND #SPRITE_MASK
                sta:  $0006,y
                ldal  spritemask+]1,x 
                cmp   #$FFFF          ; All 1's in the mask is a fully transparent sprite word
                beq   transparent     ; so we can use the Tile00011 method
                sta:  $0007,y

                lda   #$0009          ; ORA #SPRITE_DATA
                sta:  $0009,y
                ldal  spritedata+]1,x
                sta:  $000A,y

                lda   #$0980          ; branch to the prologue (BRA *+11)
                sta:  $000C,y
                bra   next

; This is a transparent word, so just show the dynamic data
transparent
                lda   #$0F80          ; branch to the epilogue (BRA *+17)
                sta:  $0006,y
next
                ldy   _Y_REG          ; restore original y-register value and move on
                eom