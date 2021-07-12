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
               ldy   #WordBuff+1
               jsr   WordToString
               plx
               lda   #WordBuff
               ldy   #$7777
               jsr   DrawString
               rts

; Render out the bank addresses of all the blitter fields
DumpBanks

:addr          =     1
:count         =     3
:ptr           =     5

               pea   #^BlitBuff     ; pointer to address table
               pea   #BlitBuff
               pea   #13            ; count = 13
               pea   $0000          ; addr = 0

               tsc
               phd                  ; save the direct page
               tcd                  ; set the direct page

:loop          lda   [:ptr]
               tax
               ldy   #2
               lda   [:ptr],y

               ldy   #Addr3Buff+1
               jsr   Addr3ToString

               lda   #Addr3Buff
               ldx   :addr
               ldy   #$7777
               jsr   DrawString

               lda   :addr
               clc
               adc   #160*8
               sta   :addr

               lda   #4
               adc   :ptr
               sta   :ptr

               dec   :count
               bne   :loop

               pld                  ; restore the direct page
               tsc                  ; restore the stack pointer
               clc
               adc   #8
               tcs
               rts

WordBuff       str   '0000'
Addr3Buff      str   '000000'       ; str adds leading length byte















































