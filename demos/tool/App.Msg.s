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

; Convert a word (Acc) into a hexadecimal string and store at (Y)
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
DrawWord       phx                  ; Save register value
               phy
               ldy   #WordBuff+1
               jsr   WordToString
               ply
               plx
               lda   #WordBuff
               jsr   DrawString
               rts

WordBuff       str   '0000'
Addr3Buff      str   '000000'       ; str adds leading length byte

















































