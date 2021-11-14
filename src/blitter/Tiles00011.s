; _TBDynamicMaskTile
;
; Insert a code sequence to mask the dynamic tile against the background.  This is quite a slow process because
; every word needs to be handled with a JMP exception; but it looks good!
_TBDynamicMaskTile_00
                 jsr             _TBDynamicDataAndMask
                 jmp             _TBFillJMPOpcode

; A = dynamic tile id (must be <32)
_TBDynamicDataAndMask
                 and             #$007F                            ; clamp to < (32 * 4)
                 sta             _T_PTR
                 stx             _X_REG

                 CopyMaskedDWord  $0003
                 CopyMaskedDWord  $1003
                 CopyMaskedDWord  $2003
                 CopyMaskedDWord  $3003
                 CopyMaskedDWord  $4003
                 CopyMaskedDWord  $5003
                 CopyMaskedDWord  $6003
                 CopyMaskedDWord  $7003

                 inc             _T_PTR                            ; Move to the next column
                 inc             _T_PTR
                 inc             _X_REG                            ; Move to the next column
                 inc             _X_REG

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
