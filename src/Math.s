; Math-y functions

                   mx    %00

; Special subroutine to divide the accumulator by 164 and return remainder in the Accumulator
;
; 164 = $A4 = 1010_0100
Mod164             cmp   #%1010010000000000
                   bcc   *+5
                   sbc   #%1010010000000000

                   cmp   #%0101001000000000
                   bcc   *+5
                   sbc   #%0101001000000000

                   cmp   #%0010100100000000
                   bcc   *+5
                   sbc   #%0010100100000000

                   cmp   #%0001010010000000
                   bcc   *+5
                   sbc   #%0001010010000000

                   cmp   #%0000101001000000
                   bcc   *+5
                   sbc   #%0000101001000000

                   cmp   #%0000010100100000
                   bcc   *+5
                   sbc   #%0000010100100000

                   cmp   #%0000001010010000
                   bcc   *+5
                   sbc   #%0000001010010000

                   cmp   #%0000000101001000
                   bcc   *+5
                   sbc   #%0000000101001000

                   cmp   #%0000000010100100
                   bcc   *+5
                   sbc   #%0000000010100100
                   rts

; Special subroutine to divide the accumulator by 208 and return remainder in the Accumulator
;
; 208 = $D0 = 1101_0000
;
; There are probably faster hacks to divide a 16-bit unsigned value by 208
;   https://www.drdobbs.com/parallel/optimizing-integer-division-by-a-constan/184408499
;   https://embeddedgurus.com/stack-overflow/2009/06/division-of-integers-by-constants/

Mod208             cmp   #%1101000000000000
                   bcc   *+5
                   sbc   #%1101000000000000

                   cmp   #%0110100000000000
                   bcc   *+5
                   sbc   #%0110100000000000

                   cmp   #%0011010000000000
                   bcc   *+5
                   sbc   #%0011010000000000

                   cmp   #%0001101000000000
                   bcc   *+5
                   sbc   #%0001101000000000

                   cmp   #%0000110100000000
                   bcc   *+5
                   sbc   #%0000110100000000

                   cmp   #%0000011010000000
                   bcc   *+5
                   sbc   #%0000011010000000

                   cmp   #%0000001101000000
                   bcc   *+5
                   sbc   #%0000001101000000

                   cmp   #%0000000110100000
                   bcc   *+5
                   sbc   #%0000000110100000

                   cmp   #%0000000011010000
                   bcc   *+5
                   sbc   #%0000000011010000
                   rts
