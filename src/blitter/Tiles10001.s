; _TBDynamicSpriteTile
;
; This tile type does not explicitly support horizontal or vertical flipping.  An appropriate tile
; descriptor should be passed into CopyTileToDyn to put the horizontally or vertically flipped source
; data into the dynamic tile buffer
_TBDynamicSpriteTile
                 sta     _X_REG
                 ldal    TileStore+TS_JMP_ADDR,x      ; Get the address of the exception handler
                 sta     _JTBL_CACHE

                 ldal    TileStore+TS_TILE_ID,x       ; Get the original tile descriptor
                 and     #$007F                       ; clamp to < (32 * 4)
                 ora     #$B500
                 xba
                 sta     _OP_CACHE                    ; This is the 2-byte opcode for to load the data

                 CopyDynWord  0;$0003
                 CopyDynWord  4;$1003
                 CopyDynWord  8;$2003
                 CopyDynWord  12;$3003
                 CopyDynWord  16;$4003
                 CopyDynWord  20;$5003
                 CopyDynWord  24;$6003
                 CopyDynWord  28;$7003

                 clc
                 lda     _JTBL_CACHE
                 adc     #32                          ; All the snippets are 32 bytes wide and, since we're
                 sta     _JTBL_CACHE                  ; within one tile, the second column is consecutive

                 lda     _OP_CACHE
                 adc     #$0200                       ; Advance to the next word
                 sta     _OP_CACHE

                 CopyDynWord  2;$0000
                 CopyDynWord  6;$1000
                 CopyDynWord  10;$2000
                 CopyDynWord  14;$3000
                 CopyDynWord  18;$4000
                 CopyDynWord  22;$5000
                 CopyDynWord  26;$6000
                 CopyDynWord  30;$7000

                 plb
                 rts


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

                 ldx             _SPR_X_REG

                 CopyDynSpriteWord  {0*SPRITE_PLANE_SPAN};$0003
                 CopyDynSpriteWord  {1*SPRITE_PLANE_SPAN};$1003
                 CopyDynSpriteWord  {2*SPRITE_PLANE_SPAN};$2003
                 CopyDynSpriteWord  {3*SPRITE_PLANE_SPAN};$3003
                 CopyDynSpriteWord  {4*SPRITE_PLANE_SPAN};$4003
                 CopyDynSpriteWord  {5*SPRITE_PLANE_SPAN};$5003
                 CopyDynSpriteWord  {6*SPRITE_PLANE_SPAN};$6003
                 CopyDynSpriteWord  {7*SPRITE_PLANE_SPAN};$7003

                 ldx             _X_REG
                 clc
                 ldal            JTableOffset+2,x     ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

                 lda             _OP_CACHE
                 adc             #$0200
                 sta             _OP_CACHE

                 ldx             _SPR_X_REG

                 CopyDynSpriteWord  {0*SPRITE_PLANE_SPAN}+2;$0000
                 CopyDynSpriteWord  {1*SPRITE_PLANE_SPAN}+2;$1000
                 CopyDynSpriteWord  {2*SPRITE_PLANE_SPAN}+2;$2000
                 CopyDynSpriteWord  {3*SPRITE_PLANE_SPAN}+2;$3000
                 CopyDynSpriteWord  {4*SPRITE_PLANE_SPAN}+2;$4000
                 CopyDynSpriteWord  {5*SPRITE_PLANE_SPAN}+2;$5000
                 CopyDynSpriteWord  {6*SPRITE_PLANE_SPAN}+2;$6000
                 CopyDynSpriteWord  {7*SPRITE_PLANE_SPAN}+2;$7000

                 rts

; Create a masked render based on data in the direct page temporary buffer
; 
; ]1 : sprite buffer offset
; ]2 : code field offset
CopyDynWord     mac
                lda   tmp_sprite_mask+{]1}     ; load the mask value
                bne   mixed                    ; a non-zero value may be mixed

; This is a solid word
                lda   #$00F4                   ; PEA instruction
                sta:  ]2,y
                lda   tmp_sprite_data+{]1}     ; load the sprite data
                sta:  ]2+1,y                   ; PEA operand
                bra   next

mixed           cmp   #$FFFF                   ; All 1's in the mask is a fully transparent sprite word
                beq   transparent

                lda   #$004C                   ; JMP to handler
                sta:  {]2},y
                lda   _JTBL_CACHE              ; Get the offset to the exception handler for this column
                ora   #{]2&$F000}              ; adjust for the current row offset
                sta:  {]2}+1,y
                tax                            ; This becomes the new address that we use to patch in

                lda   _OP_CACHE       ; Get the LDA dp,x instruction for this column
                sta:  $0000,x

                lda   #$0029          ; AND #SPRITE_MASK
                sta:  $0002,x
                lda   tmp_sprite_mask+{]1}
                sta:  $0003,x

                lda   #$0009          ; ORA #SPRITE_DATA
                sta:  $0005,x
                lda   tmp_sprite_data+{]1}
                sta:  $0006,x

                lda   #$0D80          ; branch to the prologue (BRA *+15)
                sta:  $0008,x
                bra   next

; This is a transparent word, so just show the dynamic data
transparent
                lda   #$4800          ; Put the PHA in the third byte
                sta:  {]2}+1,y
                lda   _OP_CACHE       ; Store the LDA dp,x instruction with operand
                sta:  {]2},y
next
                 <<<

; Masked renderer for a dynamic tile with sprite data overlaid.
;
; ]1 : sprite plane offset
; ]2 : code field offset
CopyDynSpriteWord MAC

; Need to fill in the first 10 bytes of the JMP handler with the following code sequence where
; the data and mask from from the sprite plane
;
;            lda  $00,x
;            and  #MASK
;            ora  #DATA
;            bra  *+15
;
; If MASK == 0, then we can do a PEA.  If MASK == $FFFF, then fall back to the simple Dynamic Tile
; code.
                ldal  spritemask+{]1},x            ; load the mask value
                bne   mixed                        ; a non-zero value may be mixed

; This is a solid word
                lda   #$00F4          ; PEA instruction
                sta:  ]2,y
                ldal  spritedata+{]1},x ; load the sprite data
                sta:  ]2+1,y          ; PEA operand
                bra   next

mixed           cmp   #$FFFF          ; All 1's in the mask is a fully transparent sprite word
                beq   transparent

                lda   #$004C          ; JMP to handler
                sta:  ]2,y
                lda   _JTBL_CACHE     ; Get the offset to the exception handler for this column
                ora   #{]2&$F000}     ; adjust for the current row offset
                sta:  ]2+1,y
                tay                   ; This becomes the new address that we use to patch in

                lda   _OP_CACHE       ; Get the LDA dp,x instruction for this column
                sta:  $0000,y

                lda   #$0029          ; AND #SPRITE_MASK
                sta:  $0002,y
                ldal  spritemask+{]1},x 
                sta:  $0003,y

                lda   #$0009          ; ORA #SPRITE_DATA
                sta:  $0005,y
                ldal  spritedata+{]1},x
                sta:  $0006,y

                lda   #$0D80          ; branch to the prologue (BRA *+15)
                sta:  $0008,y

                ldy   _Y_REG          ; restore original y-register value and move on
                bra   next

; This is a transparent word, so just show the dynamic data
transparent
                lda   #$4800          ; Put the PHA in the third byte
                sta:  ]2+1,y
                lda   _OP_CACHE       ; Store the LDA dp,x instruction with operand
                sta:  ]2,y
next
                eom