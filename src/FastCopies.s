; Large, unrolled loops for setting values in the code field that would be used by the Horz.s
; and Vert.s code.
;
; The utility of these functions is that they do not need to do any sort of bank switching and
; can update all of the play field lines in a single call.  The downside is that they take up
; significantly more space, need large auxiliary tables, and must be patched after the code
; field memory is allocated.
;
; Probably still worth it....

BlitBuff    EXT

; Patch the fast copy routines with the allocated memory addresses
InitFastCopies

; Fist, patch the cttc routine

            ldy   #0
            ldx   #0

:loop1
            lda   BlitBuff+2,y              ; Get the bank of each in the accumulatow low byte

            sep   #$20
]line       equ   0
            lup   16
            stal  cttc_start+{]line*7}+4,x
            stal  cttc_start+{{]line+208}*7}+4,x
]line       equ   ]line+1
            --^
            rep   #$20

            txa
            clc
            adc   #7*16
            tax

            tya
            clc
            adc   #4
            tay

            cpy   #13*4
            bcs   *+5
            brl   :loop1

; Next, patch the two store routines

            ldy   #0
            ldx   #0

:loop2
            lda   BlitBuff+2,y              ; Get the bank of each in the accumulatow low byte

            sep   #$20
]line       equ   0
            lup   16
            stal  store_start+{]line*4}+1,x
            stal  store_start+{{]line+208}*4}+1,x
]line       equ   ]line+1
            --^
            rep   #$20

            txa
            clc
            adc   #4*16
            tax

            tya
            clc
            adc   #4
            tay

            cpy   #13*4
            bcs   *+5
            brl   :loop2

            rtl


; Function to load data from an array and store in the code field. Assume that the
; bank register is already set to the bank of the srcAddr data
srcAddr     equ  0
destOffset  equ  2

CopyTblToCode
            ldal  entry_7,x                   ; This is the entry point
            stal  cttc_jump+1

            txa                               ; Set the Y register to srcAddr - 2*start to compensate for the
            eor   #$FFFF                      ; offset in the code.  This does mean that the array we are copying
            sec                               ; cannot by near the beginning of the bank
            adc   srcAddr
            tyx                               ; put the ending offset in X
            tay

            ldal  entry_7,x
            tax
            lda   #$0060
            stal  {cttc_start&$FF0000}+3,x    ; patch at the next STAL instruction because the high byte is always zero

            ldx   destOffset                  ; byte offset within each line
cttc_jump   jsr   $0000

            lda   #$009F                      ; restore the STAL opcode
            stal  {cttc_start&$FF0000}+3,x

            rtl

; Define the 416 addresses for each copy
entry_7
]line       equ   0
            lup   416
            da    cttc_start+{]line*7}
]line       equ   ]line+1
            --^

; Generate the code that performs the copy.
cttc_unit   mac
            lda:  {]1*32}+{]2*2},y
            stal  $000000+{]2*$1000},x
            <<<

cttc_start
]bank       equ   0
            lup   26
            cttc_unit ]bank;0
            cttc_unit ]bank;1
            cttc_unit ]bank;2
            cttc_unit ]bank;3
            cttc_unit ]bank;4
            cttc_unit ]bank;5
            cttc_unit ]bank;6
            cttc_unit ]bank;7
            cttc_unit ]bank;8
            cttc_unit ]bank;9
            cttc_unit ]bank;10
            cttc_unit ]bank;11
            cttc_unit ]bank;12
            cttc_unit ]bank;13
            cttc_unit ]bank;14
            cttc_unit ]bank;15
]bank       equ   ]bank+1
            --^
            rts

Store8Bits
            txa
            asl
            adc   #store_start
            stal  s8b_jump+1

            tya
            asl
            tax
            lda   #$0060
            stal  {store_start&$FF0000},x

            ldx   destOffset                  ; byte offset within each line
            lda   srcAddr
            sep   #$20
s8b_jump    jsr   $0000

            lda   #$9F                        ; restore the STAL opcode
            stal  {store_start&$FF0000},x
            rep   #$20

            rtl

Store16Bits
            txa
            asl
            adc   #store_start
            stal  s16b_jump+1

            tya
            asl
            tax
            lda   #$0060
            stal  {store_start&$FF0000},x

            ldx   destOffset                  ; byte offset within each line
            lda   srcAddr
s16b_jump   jsr   $0000

            lda   #$009F                        ; restore the STAL opcode
            stal  {store_start&$FF0000},x
            rtl

store_start
            lup   26
            stal  $000000,x
            stal  $001000,x
            stal  $002000,x
            stal  $003000,x
            stal  $004000,x
            stal  $005000,x
            stal  $006000,x
            stal  $007000,x
            stal  $008000,x
            stal  $009000,x
            stal  $00A000,x
            stal  $00B000,x
            stal  $00C000,x
            stal  $00D000,x
            stal  $00E000,x
            stal  $00F000,x
            --^
            rts


CodeCopy8
            txa
            asl
            adc   #store_start
            stal  cc8_jump+1

            tya
            asl
            tax
            lda   #$0060
            stal  {store8_start&$FF0000},x

            ldx   destOffset                  ; byte offset within each line
            lda   srcAddr
cc8_jump   jsr   $0000

            lda   #$009F                        ; restore the STAL opcode
            stal  {store8_start&$FF0000},x
            rtl

store8_start
            lup   26
            pea   $0000
            plb
            plb

            lda   $0000,y
            stal  $000000,x
            lda   $0000,y
            stal  $001000,x
            lda   $0000,y
            stal  $002000,x
            lda   $0000,y
            stal  $003000,x
            lda   $0000,y
            stal  $004000,x
            lda   $0000,y
            stal  $005000,x
            lda   $0000,y
            stal  $006000,x
            lda   $0000,y
            stal  $007000,x
            lda   $0000,y
            stal  $008000,x
            lda   $0000,y
            stal  $009000,x
            lda   $0000,y
            stal  $00A000,x
            lda   $0000,y
            stal  $00B000,x
            lda   $0000,y
            stal  $00C000,x
            lda   $C000,y
            stal  $00D000,x
            lda   $E000,y
            stal  $00E000,x
            lda   $F000,y
            stal  $00F000,x
            --^
            rts