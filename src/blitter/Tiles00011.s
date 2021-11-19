; _TBDynamicMaskTile
;
; Insert a code sequence to mask the dynamic tile against the background.  This is quite a slow process because
; every word needs to be handled with a JMP exception; but it looks good!
_TBDynamicMaskTile_00
                 jsr             _TBDynamicDataAndMask
                 jmp             _TBFillJMPOpcode

; A = dynamic tile id (must be <32)
_TBDynamicDataAndMask
                 sta             _X_REG               ; Cache some column values derived from _X_REG
                 tax
                 ora             #$B100               ; Pre-calc the LDA (dp),y opcode + operand
                 xba
                 sta             _OP_CACHE

                 clc
                 ldal            JTableOffset,x       ; Get the address offset and add to the base address
                 adc             _BASE_ADDR           ; of the current code field line
                 sta             _JTBL_CACHE

; We need to do an AND dp|$80,x / ORA dp,x.  The opcode values are $35 and $15, respectively.
; We pre-calculate the AND opcode with the high bit of the operand set and then, in the macro
; perform and EOR #$2080 to covert the opcode and operand in one instruction

                 lda             _TILE_ID             ; Get the original tile descriptor
                 and             #$007F               ; clamp to < (32 * 4)
                 ora             #$3580               ; Pre-calc the AND $80,x opcode + operand
                 xba
                 sta             _T_PTR               ; This is an op to load the dynamic tile data

                 CopyMaskedDWord  $0003
                 CopyMaskedDWord  $1003
                 CopyMaskedDWord  $2003
                 CopyMaskedDWord  $3003
                 CopyMaskedDWord  $4003
                 CopyMaskedDWord  $5003
                 CopyMaskedDWord  $6003
                 CopyMaskedDWord  $7003

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

                 CopyMaskedDWord  $0000
                 CopyMaskedDWord  $1000
                 CopyMaskedDWord  $2000
                 CopyMaskedDWord  $3000
                 CopyMaskedDWord  $4000
                 CopyMaskedDWord  $5000
                 CopyMaskedDWord  $6000
                 CopyMaskedDWord  $7000

                 rts

; A simple helper function that fill in all of the opcodes of a tile with the JMP opcode.
_TBFillJMPOpcode
                 sep             #$20
                 lda             #$4C
                 sta:            $0000,y
                 sta:            $0003,y
                 sta             $1000,y
                 sta             $1003,y
                 sta             $2000,y
                 sta             $2003,y
                 sta             $3000,y
                 sta             $3003,y
                 sta             $4000,y
                 sta             $4003,y
                 sta             $5000,y
                 sta             $5003,y
                 sta             $6000,y
                 sta             $6003,y
                 sta             $7000,y
                 sta             $7003,y
                 rep             #$20
                 rts


; Masked renderer for a dynamic tile. What's interesting about this renderer is that the mask
; value is not used directly, but simply indicates if we can use a LDA 0,x / PHA sequence,
; a LDA (00),y / PHA, or a JMP to a blended render
;
; If a dynamic tile is animated, there is the possibility to create a special mask that marks
; words of the tile that a front / back / mixed across all frames.
;
; ]1 : code field offset
;
; This macro does not set the opcode since they will all be JMP instructions, they can be 
; filled more efficiently in a separate routine.
CopyMaskedDWord MAC

; Need to fill in the first 6 bytes of the JMP handler with the following code sequence
;
;            lda  (00),y
;            and  $80,x
;            ora  $00,x
;            bra  *+17

                lda   _JTBL_CACHE
                ora   #{]1&$F000}     ; adjust for the current row offset
                sta:  ]1+1,y

                tax                   ; This becomes the new address that we use to patch in
                lda   _OP_CACHE
                sta:  $0000,x         ; LDA (00),y
                lda   _T_PTR
                sta:  $0002,x         ; AND $80,x
                eor   #$8020          ; Switch the opcode to an ORA and remove the high bit of the operand
                sta:  $0004,x         ; ORA $00,x
                lda   #$0F80          ; branch to the prologue (BRA *+17)
                sta:  $0006,x
                eom