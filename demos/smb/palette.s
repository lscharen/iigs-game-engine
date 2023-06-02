; NES Palette (52 entries)
nesPalette
    dw  $0888
    dw  $004A
    dw  $001B
    dw  $0409
    dw  $0A06
    dw  $0C02
    dw  $0C10
    dw  $0910
    dw  $0630
    dw  $0140
    dw  $0050
    dw  $0043
    dw  $0046
    dw  $0000
    dw  $0111
    dw  $0111

    dw  $0CCC
    dw  $007F
    dw  $025F
    dw  $083F
    dw  $0F3B
    dw  $0F35
    dw  $0F20
    dw  $0D30
    dw  $0C60
    dw  $0380
    dw  $0190
    dw  $0095
    dw  $00AD
    dw  $0222
    dw  $0111
    dw  $0111

    dw  $0FFF
    dw  $01DF
    dw  $07AF
    dw  $0D8F
    dw  $0F4F
    dw  $0F69
    dw  $0F93
    dw  $0F91
    dw  $0FC2
    dw  $0AE1
    dw  $03F3
    dw  $01FA
    dw  $00FF
    dw  $0666
    dw  $0111
    dw  $0111

    dw  $0FFF
    dw  $0AFF
    dw  $0BEF
    dw  $0DAF
    dw  $0FBF
    dw  $0FAB
    dw  $0FDB
    dw  $0FEA
    dw  $0FF9
    dw  $0DE9
    dw  $0AEB
    dw  $0AFD
    dw  $09FF
    dw  $0EEE
    dw  $0111
    dw  $0111

; Swizzle tables based on AreaType
;
; IIgs palette index 0 is always the background color: 'BBB'
; IIgs palette index 0 is always the color cycling color 'RRR'
;
; The rest are remapped.
;
; Underground:
;
; T0: $0F $29 $1A $09
; T1: --- $3C $1C $0F
; T2: --- $30 $21 $1C
; T3: --- RRR $17 $1C
; S0: --- $16 $27 $18 --> $37 $27 $16
; S1: --- $1C $36 $17
; S2: --- $16 $30 $27
; S3: --- $1D $3C $1C --> $0F  RR $29 $1A  $09 $36 $1C $30  $21 $16 $27 $18  $17 $3C $1D $37 : 0 free colors
;                     --> $00 $01 $02 $03  $04 $05 $06 $07  $08 $09 $0A $0B  $0C $0D $0E $0F
;
; Mapped palettes
;
; T0: 0 2 3 4
; T1: 0 D 6 0
; T2: 0 7 8 6
; T3: 0 1 C 6
; S0: 0 F A B
; S1: 0 6 5 C
; S2: 0 9 7 A
; S3: 0 E D 6
;
; Above Ground
;
; T0: $22 $29 $1A $0F
; T1: --- $36 $17 $0F
; T2: --- $30 $21 $0F
; T3: --- RRR $17 $0F
; S0: --- $16 $27 $18 --> $37 $27 $16
; S1: --- $1A $30 $17
; S2: --- $16 $30 $27
; S3: --- $0F $36 $17 --> $22  RR $29 $1A  $0F $36 $17 $30  $21 $16 $27 $18  $1A --- --- $16 : 2 free colors
;                     --> $00 $01 $02 $03  $04 $05 $06 $07  $08 $09 $0A $0B  $0C $0D $0E $0F
; Mapped palettes
;
; T0: 0 2 3 4
; T1: 0 5 6 4
; T2: 0 7 8 4
; T3: 0 1 6 4
; S0: 0 F A B
; S1: 0 C 7 A
; S2: 0 9 7 A
; S3: 0 4 5 6