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




