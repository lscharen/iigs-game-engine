; Some sample code / utilities to help integrate compiled sprites int the GTE rendering
; pipeline.
;
; The main point of this file to to establish calling conventions and provide a framework
; for blitting a range of sprite lines, instead of always the full sprite.

; A = address, X = scroll_mask offset, Y = HHLL, LL = first line, HH = last line
draw
    sei
    
    cli
    rts

lines dw line0,line1,line2,line3,line4,line5,line6,line7

line0
    lda 0
    and #$FF00
    ora #$00DD
    sta 0

line1
    lda 0
    and #$FF00
    ora #$00DD
    sta 0

line2
    lda 0
    and #$FF00
    ora #$00DD
    sta 0

line3
    lda 0
    and #$FF00
    ora #$00DD
    sta 0

line4
    lda 0
    and #$FF00
    ora #$00DD
    sta 0

line5
    lda 0
    and #$FF00
    ora #$00DD
    sta 0

line6
    lda 0
    and #$FF00
    ora #$00DD
    sta 0

line7
    lda 0
    and #$FF00
    ora #$00DD
    sta 0
