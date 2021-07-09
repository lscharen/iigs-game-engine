;
; Dereference a handle that is on the top of the stack
;
_Deref      MAC
            phb               ; save caller's data bank register
            pha               ; push high word of handle on stack
            plb               ; sets B to the bank byte of the pointer
            lda   |$0002,x    ; load the high word of the master pointer
            pha               ; and save it on the stack
            lda   |$0000,x    ; load the low word of the master pointer
            tax               ; and return it in X
            pla               ; restore the high word in A
            plb               ; pull the handle's high word high byte off the
                              ; stack
            plb               ; restore the caller's data bank register    
            <<<

_Mul4096    mac
            xba
            asl
            asl
            asl
            asl
            <<<

_Div16      mac
            lsr
            lsr
            lsr
            lsr
            <<<

_R0W0       mac               ; Read Bank 0 / Write Bank 0
            ldal  STATE_REG
            and   #$FFCF
            stal  STATE_REG
            <<<

_R0W1       mac               ; Read Bank 0 / Write Bank 1
            ldal  STATE_REG
            ora   #$0010
            stal  STATE_REG
            <<<

_R1W1       mac               ; Read Bank 0 / Write Bank 1
            ldal  STATE_REG
            ora   #$0030
            stal  STATE_REG
            <<<

_PushReg    mac               ; Used to save/restore registers when calling subroutines.
            pha
            phx
            phy
            <<<

_PullReg    mac
            ply
            plx
            pla
            <<<

_PushReg2   mac               ; Variation to also save the P-register to preserve m/x
            pha
            phx
            phy
            php
            <<<

_PullReg2   mac
            plp
            ply
            plx
            pla
            <<<

jne         mac
            beq   *+5
            jmp   ]1
            <<<

jeq         mac
            bne   *+5
            jmp   ]1
            <<<

jcc         mac
            bcs   *+5
            jmp   ]1
            <<<

jcs         mac
            bcc   *+5
            jmp   ]1
            <<<

min         mac
            cmp   ]1
            bcc   mout
            lda   ]1
mout        <<<
****************************************
* Basic Error Macro                    *
****************************************
_Err        mac
            bcc   NoErr
            do    ]0          ; (DO if true) 
            jsr   PgmDeath    ;  this is conditionally compiled if
            str   ]1          ;  we pass in an error statement
            else              ; (ELSE) 
            jmp   PgmDeath0   ;  we just call the simpler error handler
            fin               ; (FIN) 
NoErr       eom


















