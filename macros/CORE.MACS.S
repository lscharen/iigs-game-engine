****************************************
* Basic Error Macro                    *
****************************************
_Err            mac
                bcc   NoErr
                do    ]0              ; (DO if true) 
                jsr   PgmDeath        ;  this is conditionally compiled if
                str   ]1              ;  we pass in an error statement
                else                  ; (ELSE) 
                jmp   PgmDeath0       ;  we just call the simpler error handler
                fin                   ; (FIN) 
NoErr           eom

;
; Dereference a handle that is on the top of the stack
;
_Deref          MAC
                phb                   ; save caller's data bank register
                pha                   ; push high word of handle on stack
                plb                   ; sets B to the bank byte of the pointer
                lda   |$0002,x        ; load the high word of the master pointer
                pha                   ; and save it on the stack
                lda   |$0000,x        ; load the low word of the master pointer
                tax                   ; and return it in X
                pla                   ; restore the high word in A
                plb                   ; pull the handle's high word high byte off the
                                      ; stack
                plb                   ; restore the caller's data bank register    
                <<<

_Mul128         mac
                asl
                asl
                asl
                asl
                asl
                asl
                asl
                <<<
; Possible optimization (assumes accumulator is <512). 8 cycles/5 bytes vs 14 cycles/7 bytes
;                cmp  #$0100
;                xba
;                ror

_Div16          mac
                lsr
                lsr
                lsr
                lsr
                <<<

_R0W0           mac                   ; Read Bank 0 / Write Bank 0
                ldal  STATE_REG
                and   #$FFCF
                stal  STATE_REG
                <<<

_R0W1           mac                   ; Read Bank 0 / Write Bank 1
                ldal  STATE_REG
                ora   #$0010
                stal  STATE_REG
                <<<

_R1W1           mac                   ; Read Bank 0 / Write Bank 1
                ldal  STATE_REG
                ora   #$0030
                stal  STATE_REG
                <<<

_PushReg        mac                   ; Used to save/restore registers when calling subroutines.
                pha
                phx
                phy
                <<<

_PullReg        mac
                ply
                plx
                pla
                <<<

_PushReg2       mac                   ; Variation to also save the P-register to preserve m/x
                pha
                phx
                phy
                php
                <<<

_PullReg2       mac
                plp
                ply
                plx
                pla
                <<<

jne             mac
                beq   *+5
                jmp   ]1
                <<<

jeq             mac
                bne   *+5
                jmp   ]1
                <<<

jcc             mac
                bcs   *+5
                jmp   ]1
                <<<

jcs             mac
                bcc   *+5
                jmp   ]1
                <<<

min             mac
                cmp   ]1
                bcc   mout
                lda   ]1
mout            <<<

; Increment a value mod some number.  
incmod          mac
                inc
                cmp   ]1
                bcc   out
                lda   #0
out             <<<

decmod          mac
                dec
                bpl   out
                lda   ]1
                dec
out             <<<

adcmod          mac
                adc   ]1
                cmp   ]2
                bcc   out
                sbc   ]2
out             <<<

sbcmod          mac
                sbc   ]1
                bpl   out
                clc
                adc   ]2
out             <<<

asr16           mac
                cmp   #$8000
                ror
                <<<

asr8            mac
                cmp   #$80
                ror
                <<<

; Inline macros for fast calculation of some internal values
_TileStoreOffset mac
                lda   ]2
                asl
                tay
                lda   ]1
                asl                            ; Assume in range, so asl puts a 0 bit into the carry
                adc  TileStoreYTable,y
                <<<

_TileStoreOffsetX mac
                lda   ]2
                asl
                tax
                lda   ]1
                asl                            ; Assume in range, so asl puts a 0 bit into the carry
                adc  TileStoreYTable,x
                <<<

_; Macro variant to calculate inline from any source
_SpriteVBuffAddr mac
                lda   ]2
                clc
                adc   #NUM_BUFF_LINES
                xba
                adc   ]1
                <<<

; Macro to define script steps
ScriptStep      MAC
                IF    #=]5
                dw    {]1+{{]5&#$000F}<<8}},]2,]3,]4
                ELSE
                dw    ]1,]2,]3,]4
                FIN
                <<<

; A specialized CopyMaskedWord macro that draws a tile from a direct page workspace. Used
; to render fringe tiles and sprite tiles when BG1 is active.  If there is no second background,
; then one should use the optimized functions which assumes a PEA opcode and only
; needs to copy data words
;
; ]1 : tiledata direct page address , the tilemask direct page address is tiledata + 32
; ]2 : code field offset
CopyMaskedWordD MAC
                lda   ]1+32           ; load the mask value
                bne   mixed           ; a non-zero value may be mixed

; This is a solid word
                lda   #$00F4          ; PEA instruction
                sta:  ]2,y
                ldal  ]1              ; load the tile data
                sta:  ]2+1,y          ; PEA operand
                bra   next

mixed           cmp   #$FFFF          ; All 1's in the mask is fully transparent
                beq   transparent

; This is the slowest path because there is a *lot* of work to do.  So much that it's
; worth it to change up the environment to optimize things a bit more.
;
; Need to fill in the first 8 bytes of the JMP handler with the following code sequence
;
;            lda  (00),y
;            and  #MASK
;            ora  #DATA

                lda   #$004C          ; JMP instruction
                sta:  ]2,y

                ldx   _X_REG          ; Get the addressing offset
                ldal  JTableOffset,x  ; Get the address offset and add to the base address
                adc   _BASE_ADDR      ; of the current code field line
                adc   #{]2&$F000}     ; adjust for the current row offset
                sta:  ]2+1,y

                tay                   ; This becomes the new address that we use to patch in
                txa                   ; Get the offset and render a LDA (dp),y instruction

                sep   #$20
                sta:  $0001,y         ; LDA (00),y operand
                lda   #$B1
                sta:  $0000,y         ; LDA (00),y opcode
                lda   #$29
                sta:  $0002,y         ; AND #$0000 opcode
                lda   #$09
                sta:  $0005,y         ; ORA #$0000 opcode
                rep   #$20

                lda   ]1+32           ; insert the tile mask and data into the exception
                sta:  $0003,y         ; handler.
                lda   ]1
                sta:  $0006,y

                ldy   _Y_REG          ; restore original y-register value and move on
                bra   next

; This is a transparent word, so just show the second background layer
transparent
                lda   #$00B1          ; LDA (dp),y instruction
                sta:  ]2,y
                lda   _X_REG          ; X is the logical tile offset (0, 2, 4, ... 82) left-to-right
                ora   #$4800          ; put a PHA after the offset
                sta:  ]2+1,y
next
                eom

; Macros to use in the Masked Tile renderer
;
; ]1 : tiledata offset
; ]2 : tilemask offset
; ]3 : code field offset
CopyMaskedWord  MAC
                ldal  ]2,x            ; load the mask value
                bne   mixed           ; a non-zero value may be mixed

; This is a solid word
                lda   #$00F4          ; PEA instruction
                sta:  ]3,y
                ldal  ]1,x            ; load the tile data
                sta:  ]3+1,y          ; PEA operand
                bra   next

mixed           cmp   #$FFFF          ; All 1's in the mask is fully transparent
                beq   transparent

; This is the slowest path because there is a *lot* of work to do.  So much that it's
; worth it to change up the environment to optimize things a bit more.
;
; Need to fill in the first 8 bytes of the JMP handler with the following code sequence
;
;            lda  (00),y
;            and  #MASK
;            ora  #DATA

                lda   #$004C          ; JMP instruction
                sta:  ]3,y

                ldx   _X_REG          ; Get the addressing offset
                ldal  JTableOffset,x  ; Get the address offset and add to the base address
                adc   _BASE_ADDR      ; of the current code field line
                adc   #{]3&$F000}     ; adjust for the current row offset
                sta:  ]3+1,y

                tay                   ; This becomes the new address that we use to patch in
                txa                   ; Get the offset and render a LDA (dp),y instruction

                sep   #$20
                sta:  $0001,y         ; LDA (00),y operand
                lda   #$B1
                sta:  $0000,y         ; LDA (00),y opcode
                lda   #$29
                sta:  $0002,y         ; AND #$0000 opcode
                lda   #$09
                sta:  $0005,y         ; ORA #$0000 opcode
                rep   #$20

                ldx   _T_PTR          ; restore the original x-register value
                ldal  ]2,x            ; insert the tile mask and data into the exception
                sta:  $0003,y         ; handler.
                ldal  ]1,x
                sta:  $0006,y

                ldy   _Y_REG          ; restore original y-register value and move on
                bra   next

; This is a transparent word, so just show the second background layer
transparent
                lda   #$00B1          ; LDA (dp),y instruction
                sta:  ]3,y
                lda   _X_REG          ; X is the logical tile offset (0, 2, 4, ... 82) left-to-right
                ora   #$4800          ; put a PHA after the offset
                sta:  ]3+1,y
next
                eom

; Masked renderer for a dynamic tile. What's interesting about this renderer is that the mask
; value is not used directly, but simply indicates if we can use a LDA 0,x / PHA sequence,
; a LDA (00),y / PHA, or a JMP to a blended render
;
; If a dynamic tile is animated, there is the possibility to create a special mask that marks
; words of the tile that a front / back / mixed across all frames.
;
; ]1 : tiledata offset
; ]2 : tilemask offset
; ]3 : code field offset
CopyMaskedDWord MAC

; Need to fill in the first 8 bytes of the JMP handler with the following code sequence
;
;            lda  (00),y
;            and  $80,x
;            ora  $00,x
;            bcc  *+4

                ldx   _X_REG          ; Get the addressing offset
                ldal  JTableOffset,x  ; Get the address offset and add to the base address
                adc   _BASE_ADDR      ; of the current code field line
                adc   #{]1&$F000}     ; adjust for the current row offset
                sta:  ]1+1,y

                tax                   ; This becomes the new address that we use to patch in
                lda   _X_REG          ; Get the offset and render a LDA (dp),y instruction

                sep   #$20            ; Easier to do 8-bit operations
                sta:  $0001,x         ; Set the LDA (00),y operand
                lda   #$B1
                sta:  $0000,x         ; Set the LDA (00),y opcode

                lda   _T_PTR
                sta:  $0005,x         ; Set ORA 00,x operand
                ora   #$80
                sta:  $0003,x         ; Set AND 00,x operand
                lda   #$35
                sta:  $0002,x         ; Set AND 00,x operand
                lda   #$15
                sta:  $0004,x         ; Set ORA 00,x operand
                rep   #$30

                lda   #$0290          ; BCC *+4
                sta:  $0006,x
                eom


; Masked renderer for a dynamic tile with sprite data overlaid. What's interesting about this renderer is that the mask
; value is not used directly, but simply indicates if we can use a LDA 0,x / PHA sequence,
; a LDA (00),y / PHA, or a JMP to a blended render
;
; If a dynamic tile is animated, there is the possibility to create a special mask that marks
; words of the tile that a front / back / mixed across all frames.
;
; ]1 : tiledata offset
; ]2 : tilemask offset
; ]3 : code field offset
CopyMaskedDynSpriteWord MAC

; Need to fill in the first 12(!!) bytes of the JMP handler with the following code sequence
;
;            lda  (00),y
;            and  $80,x
;            ora  $00,x
;            and  #MASK
;            ora  #DATA
;
; If MASK == 0, then we can do a PEA.  If MASK == $FFFF, then fall back to the simple Dynamic Masked
; code.


                ldx   _X_REG          ; Get the addressing offset
                ldal  JTableOffset,x  ; Get the address offset and add to the base address
                adc   _BASE_ADDR      ; of the current code field line
                adc   #{]1&$F000}     ; adjust for the current row offset
                sta:  ]1+1,y

                tax                   ; This becomes the new address that we use to patch in
                lda   _X_REG          ; Get the offset and render a LDA (dp),y instruction

                sep   #$20            ; Easier to do 8-bit operations
                sta:  $0001,x         ; Set the LDA (00),y operand
                lda   #$B1
                sta:  $0000,x         ; Set the LDA (00),y opcode

                lda   _T_PTR
                sta:  $0005,x         ; Set ORA 00,x operand
                ora   #$80
                sta:  $0003,x         ; Set AND 00,x operand
                lda   #$35
                sta:  $0002,x         ; Set AND 00,x operand
                lda   #$15
                sta:  $0004,x         ; Set ORA 00,x operand
                rep   #$30

                lda   #$0290          ; BCC *+4
                sta:  $0006,x
                eom
