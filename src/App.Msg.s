HexToChar      dfb   '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'

; Convert a byte (Acc) into a string and store at (Y)
ByteToString   and   #$00FF
               sep   #$20
               pha
               lsr
               lsr
               lsr
               lsr
               and   #$0F
               tax
               ldal  HexToChar,x
               sta:  $0000,y

               pla
               and   #$0F
               tax
               ldal  HexToChar,x
               sta:  $0001,y

               rep   #$20
               rts

; Convert a word (Acc) into a string and store at (Y)
WordToString   pha
               bra   Addr2ToString

; Pass in Acc = High, X = low
Addr3ToString  phx
               jsr   ByteToString
               iny
               iny
               lda   1,s
Addr2ToString  xba
               jsr   ByteToString
               iny
               iny
               pla
               jsr   ByteToString
               rts

; A=Value
; X=Screen offset
WordBuff       dfb   4
               ds    4
DrawWord       phx                  ; Save register value
               ldy   #WordBuff+1
               jsr   WordToString
               plx
               lda   #WordBuff
               ldy   #$7777
               jsr   DrawString
               rts

; Rendout out the bank addresses of all the blitter fields
:count         =     tmp0
:ptr           =     tmp1
:addr          =     tmp3
DumpBanks      stz   :addr
               lda   #13
               sta   :count
               lda   #BlitBuff
               sta   :ptr
               lda   #^BlitBuff
               sta   :ptr+2

:loop          lda   [:ptr]
               tax
               ldy   #2
               lda   [:ptr],y

               ldy   #Hello+1
               jsr   Addr3ToString

               lda   #Hello
               ldx   :addr
               ldy   #$7777
               jsr   DrawString

               lda   :addr
               clc
               adc   #160*8
               sta   :addr

               inc   :ptr
               inc   :ptr
               inc   :ptr
               inc   :ptr

               dec   :count
               lda   :count
               bne   :loop

               rts





























