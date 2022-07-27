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


; Call _NewHandle, but track the allocation
_TrackHandle   mac
               _NewHandle
               bcs       err
               ldx       NumHandles
               lda       1,s
               sta       Handles,x
               lda       3,s
               sta       Handles+2,x
               txa
               adc       #4
               sta       NumHandles
err
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
                lda   ]1              ; load the tile data
                sta:  ]2+1,y          ; PEA operand
                bra   next

mixed           cmp   #$FFFF          ; All 1's in the mask is fully transparent
                beq   transparent

; This is the slowest path because there is a *lot* of work to do.  So much that it's
; worth it to change up the environment to optimize things a bit more.
;
; Need to fill in the first 10 bytes of the JMP handler with the following code sequence
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

                lda   #$0D80          ; branch to the prologue (BRA *+15)
                sta:  $0008,y

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
                ora   _BASE_ADDR      ; of the current code field row (2 rows per bank) $0000 or $8000
                ora   #{]3&$7000}     ; adjust for the current line offset within the row
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

; Copy the top 9 bytes down. We have 23 bytes of space and are only using 8.  Since 9 + 8 = 17 < 23, we
; can save 3 cycles per word by eliminating the BRA instruction

;                lda   #$0D80          ; branch to the prologue (BRA *+15)
;                sta:  $0008,y

                lda:   $0017,y
                sta:   $0008,y
                lda:   $0019,y
                sta:   $000A,y
                lda:   $001B,y
                sta:   $000C,y
                lda:   $001D,y
                sta:   $000E,y
                lda:   $001E,y
                sta:   $000F,y

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

; Large code blocks that can be used in sprite blitters
; ]1: line number
OneSpriteToCodeField mac
            lda   blttmp+{]1*4}
            andl  spritemask+{]1*SPRITE_PLANE_SPAN},x
            oral  spritedata+{]1*SPRITE_PLANE_SPAN},x
            sta:  $0004+{]1*$1000},y

            lda   blttmp+{]1*4}+2
            andl  spritemask+{]1*SPRITE_PLANE_SPAN}+2,x
            oral  spritedata+{]1*SPRITE_PLANE_SPAN}+2,x
            sta:  $0001+{]1*$1000},y
            eom

TwoSpritesToCodeField mac
            ldy   #{]1*SPRITE_PLANE_SPAN}
            lda   blttmp+{]1*4}
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0004+{]1*$1000},x

            ldy   #{]1*SPRITE_PLANE_SPAN}+2
            lda   blttmp+{]1*4}+2
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0001+{]1*$1000},x
            eom

ThreeSpritesToCodeField mac
            ldy   #{]1*SPRITE_PLANE_SPAN}
            lda   blttmp+{]1*4}
            andl  [spritemask_2],y
            oral  [spritedata_2],y
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0004+{]1*$1000},x

            ldy   #{]1*SPRITE_PLANE_SPAN}+2
            lda   blttmp+{]1*4}+2
            andl  [spritemask_2],y
            oral  [spritedata_2],y
            andl  [spritemask_1],y
            oral  [spritedata_1],y
            andl  [spritemask_0],y
            oral  [spritedata_0],y
            sta:  $0001+{]1*$1000},x
            eom
