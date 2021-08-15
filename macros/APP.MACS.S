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


; MAcros to use in the Masked Tile renderer
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
                lda   #$004C          ; JMP instruction
                sta:  ]3,y

                ldx   _X_REG          ; Get the addressing offset
                ldal  JTableOffset,x  ; Get the address offset and add to the base address
                adc   _BASE_ADDR      ; of the current code field line (could be an ORA, too)
                sta:  ]3+1,y

                tay                   ; This becomes the new address that we use to patch in
                txa                   ; Get the offset and render a LDA (dp),y instruction
                xba
                ora   #$00B1
                sta:  $0000,y

                ldx   _T_PTR          ; restore the original x-register value
                ldal  ]1,x            ; insert the tile mask and data into the exception
                sta:  $0003,y         ; handler.
                ldal  ]2,x
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































