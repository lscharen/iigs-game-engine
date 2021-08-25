Spr_000     CLC                 ; 36x10, 295 bytes, 490 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$4444        ; Pattern #1 : 9
            LDY   #$8888        ; Pattern #2 : 6
            LDA   #$0020        ; Pattern #3 : 5
            TCD
*--		
            LDA   $04,S         ; Line 0
            AND   #$00F0
            ORA   #$5505
            STA   $04,S
            LDA   $0A,S
            AND   #$0F00
            ORA   #$A0AA
            STA   $0A,S
            TSC
            ADC   #$0009
            TCS
            PEA   $AA88
            PHY
            TSC                 ; Line 1
            ADC   #$00A7
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$A0AA
            STA   $A1,S
            SEP   #$20
            LDA   $98,S
            AND   #$F0
            STA   $98,S
            REP   #$30
            PEA   $AAAA
            PEA   $AA88
            PEA   $5844
            PEA   $4400
            TSC                 ; Line 2
            ADC   #$00A8
            TCS
            SEP   #$20
            LDA   #$9A
            STA   $96,S
            LDA   $94,S
            AND   #$0F
            ORA   #$A0
            STA   $94,S
            REP   #$30
            PEA   $AAAA
            PEA   $8858
            PEA   $2402
            PHD
            TSC                 ; Line 3
            ADC   #$00AB
            TCS
            SEP   #$20
            LDA   $A1,S
            AND   #$0F
            ORA   #$50
            STA   $A1,S
            REP   #$30
            PEA   $8288
            PHY
            PEA   $8858
            PEA   $2440
            PEA   $4404
            PEA   $0209
            TSC                 ; Line 4
            ADC   #$00AC
            TCS
            LDA   $9F,S
            AND   #$0F00
            ORA   #$2022
            STA   $9F,S
            SEP   #$20
            LDA   #$9A
            STA   $93,S
            LDA   $91,S
            AND   #$0F
            ORA   #$A0
            STA   $91,S
            REP   #$30
            PHX
            PHX
            PEA   $4424
            PEA   $5044
            PHX
            PEA   $2000
            TSC                 ; Line 5
            ADC   #$00AA
            TCS
            SEP   #$20
            LDA   $97,S
            AND   #$F0
            STA   $97,S
            REP   #$30
            PEA   $2222
            PEA   $2282
            PEA   $8855
            PHX
            PEA   $0409
            TSC                 ; Line 6
            ADC   #$00A9
            TCS
            LDA   $98,S
            AND   #$00F0
            ORA   #$4400
            STA   $98,S
            PEA   $0000
            PEA   $2088
            PEA   $8855
            PHX
            TSC                 ; Line 7
            ADC   #$00A5
            TCS
            PHD
            PEA   $8855
            TSC                 ; Line 8
            ADC   #$00A2
            TCS
            TDC
            STA   $9D,S
            PHD
            PEA   $5525
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_001     CLC                 ; 48x11, 427 bytes, 707 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$4444        ; Pattern #1 : 8
            LDY   #$0000        ; Pattern #2 : 7
            LDA   #$8888        ; Pattern #3 : 6
            TCD
*--		
            LDA   $0B,S         ; Line 0
            AND   #$00F0
            STA   $0B,S
            LDA   $11,S
            AND   #$0F00
            ORA   #$2022
            STA   $11,S
            LDA   $A4,S
            AND   #$000F
            ORA   #$AAA0
            STA   $A4,S
            SEP   #$20
            LDA   #$05
            STA   $AB,S
            LDA   $A0,S
            AND   #$F0
            ORA   #$0A
            STA   $A0,S
            REP   #$30
            TSC
            ADC   #$0010
            TCS
            PEA   $2202
            PHY
            TSC                 ; Line 1
            ADC   #$00A7
            TCS
            LDA   $8F,S
            AND   #$F00F
            ORA   #$0AA0
            STA   $8F,S
            LDA   $98,S
            AND   #$00F0
            STA   $98,S
            SEP   #$20
            LDA   $93,S
            AND   #$F0
            ORA   #$0A
            STA   $93,S
            LDA   $A2,S
            AND   #$0F
            ORA   #$20
            STA   $A2,S
            REP   #$30
            PEA   $22A2
            PEA   $AAAA
            PHD
            PEA   $8855
            TSC                 ; Line 2
            ADC   #$00A9
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$20A2
            STA   $A1,S
            SEP   #$20
            LDA   $93,S
            AND   #$0F
            ORA   #$A0
            STA   $93,S
            LDA   $95,S
            AND   #$0F
            ORA   #$A0
            STA   $95,S
            REP   #$30
            PEA   $22AA
            PEA   $AAAA
            PEA   $8858
            PHX
            TSC                 ; Line 3
            ADC   #$00A8
            TCS
            LDA   $92,S
            AND   #$F00F
            ORA   #$0AA0
            STA   $92,S
            SEP   #$20
            LDA   #$82
            STA   $A2,S
            LDA   $8F,S
            AND   #$0F
            ORA   #$A0
            STA   $8F,S
            REP   #$30
            PEA   $AAAA
            PEA   $AA88
            PEA   $5824
            PEA   $0200
            PEA   $2202
            TSC                 ; Line 4
            ADC   #$00AB
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$5044
            STA   $A1,S
            SEP   #$20
            LDA   $90,S
            AND   #$F0
            ORA   #$0A
            STA   $90,S
            LDA   $93,S
            AND   #$F0
            ORA   #$0A
            STA   $93,S
            REP   #$30
            PHD
            PHD
            PEA   $5824
            PEA   $4044
            PEA   $0420
            PEA   $44A0
            TSC                 ; Line 5
            ADC   #$00AC
            TCS
            LDA   $8B,S
            AND   #$F00F
            ORA   #$0AA0
            STA   $8B,S
            LDA   $8F,S
            AND   #$0F0F
            ORA   #$A0A0
            STA   $8F,S
            SEP   #$20
            LDA   $95,S
            AND   #$F0
            STA   $95,S
            REP   #$30
            PHX
            PHX
            PEA   $2450
            PHX
            PEA   $4400
            PEA   $2202
            TSC                 ; Line 6
            ADC   #$00AD
            TCS
            SEP   #$20
            LDA   $95,S
            AND   #$F0
            STA   $95,S
            REP   #$30
            PEA   $0200
            PEA   $0022
            PEA   $0280
            PEA   $8855
            PHX
            PEA   $0400
            TSC                 ; Line 7
            ADC   #$00A9
            TCS
            PHY
            PEA   $0088
            PEA   $8855
            PHX
            TSC                 ; Line 8
            ADC   #$00A5
            TCS
            SEP   #$20
            LDA   $9A,S
            AND   #$F0
            STA   $9A,S
            REP   #$30
            PHY
            PEA   $8855
            PEA   $4404
            TSC                 ; Line 9
            ADC   #$00A4
            TCS
            TYA
            STA   $9D,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PHY
            PEA   $5555
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_002     CLC                 ; 20x8, 218 bytes, 357 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$8888        ; Pattern #1 : 3
            LDY   #$0000        ; Pattern #2 : 3
            LDA   #$22AA        ; Pattern #3 : 2
            TCD
*--		
            SEP   #$20          ; Line 0
            LDA   #$22
            STA   $05,S
            LDA   $A0,S
            AND   #$F0
            STA   $A0,S
            REP   #$30
            TSC
            ADC   #$0004
            TCS
            PEA   $2202
            PHY
            TSC                 ; Line 1
            ADC   #$00A6
            TCS
            LDA   $9A,S
            AND   #$00F0
            ORA   #$4200
            STA   $9A,S
            SEP   #$20
            LDA   $A2,S
            AND   #$0F
            ORA   #$20
            STA   $A2,S
            REP   #$30
            PHD
            PEA   $AA88
            PEA   $8855
            TSC                 ; Line 2
            ADC   #$00A7
            TCS
            SEP   #$20
            LDA   #$85
            STA   $A1,S
            REP   #$30
            PHD
            PEA   $8A58
            PEA   $2400
            TSC                 ; Line 3
            ADC   #$00A6
            TCS
            SEP   #$20
            LDA   #$42
            STA   $A1,S
            REP   #$30
            PHX
            PEA   $8824
            PEA   $4004
            PEA   $2004
            TSC                 ; Line 4
            ADC   #$00A8
            TCS
            LDA   $A0,S
            AND   #$0F00
            STA   $A0,S
            PEA   $4422
            PEA   $4488
            PEA   $4544
            PEA   $0400
            TSC                 ; Line 5
            ADC   #$00A7
            TCS
            SEP   #$20
            LDA   $9A,S
            AND   #$F0
            STA   $9A,S
            REP   #$30
            PHY
            PEA   $8858
            PEA   $4544
            TSC                 ; Line 6
            ADC   #$00A4
            TCS
            TYA
            STA   $9C,S
            LDA   $9E,S
            AND   #$0F00
            ORA   #$2022
            STA   $9E,S
            PEA   $0080
            PEA   $5844
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_003     CLC                 ; 36x11, 316 bytes, 531 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$AAAA        ; Pattern #1 : 7
            LDY   #$0000        ; Pattern #2 : 6
            LDA   #$8888        ; Pattern #3 : 4
            TCD
*--		
            LDA   $AC,S         ; Line 0
            AND   #$0F00
            ORA   #$2022
            STA   $AC,S
            SEP   #$20
            LDA   $A5,S
            AND   #$F0
            STA   $A5,S
            REP   #$30
            TSC
            ADC   #$000B
            TCS
            PEA   $2222
            PEA   $2222
            PEA   $0200
            TSC                 ; Line 1
            ADC   #$00A6
            TCS
            LDA   $A2,S
            AND   #$0F00
            ORA   #$20A2
            STA   $A2,S
            PEA   $AA99
            PEA   $4544
            PEA   $2422
            TSC                 ; Line 2
            ADC   #$00A7
            TCS
            LDA   $A2,S
            AND   #$0F00
            ORA   #$20A2
            STA   $A2,S
            PEA   $AA99
            PEA   $5555
            PEA   $2400
            PEA   $00AA
            PHX
            PHX
            TSC                 ; Line 3
            ADC   #$00AD
            TCS
            LDA   $A3,S
            AND   #$0F00
            ORA   #$2022
            STA   $A3,S
            SEP   #$20
            LDA   $94,S
            AND   #$F0
            ORA   #$0A
            STA   $94,S
            REP   #$30
            PEA   $9A99
            PEA   $55AA
            PEA   $0A00
            PEA   $2000
            PEA   $9A99
            PEA   $9999
            PHX
            TSC                 ; Line 4
            ADC   #$00B0
            TCS
            SEP   #$20
            LDA   $94,S
            AND   #$F0
            ORA   #$0A
            STA   $94,S
            REP   #$30
            PEA   $5255
            PEA   $5555
            PEA   $AA0A
            PEA   $5045
            PEA   $0402
            PEA   $A09A
            PEA   $99AA
            TSC                 ; Line 5
            ADC   #$00B0
            TCS
            SEP   #$20
            LDA   $A0,S
            AND   #$0F
            STA   $A0,S
            REP   #$30
            PEA   $8288
            PHD
            PHD
            PEA   $0680
            PEA   $5555
            PEA   $4420
            PEA   $00AA
            TSC                 ; Line 6
            ADC   #$00AD
            TCS
            LDA   $9D,S
            AND   #$0F00
            STA   $9D,S
            PHY
            PEA   $A0AA
            PEA   $AAA0
            PEA   $AA88
            PEA   $5545
            PEA   $0402
            TSC                 ; Line 7
            ADC   #$00A8
            TCS
            PHY
            PHX
            PEA   $8855
            PEA   $4400
            TSC                 ; Line 8
            ADC   #$00A6
            TCS
            PHY
            PEA   $AA88
            PEA   $4504
            TSC                 ; Line 9
            ADC   #$00A4
            TCS
            TYA
            STA   $9D,S
            PHY
            PEA   $8808
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_004     CLC                 ; 36x11, 312 bytes, 534 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$0000        ; Pattern #1 : 14
            LDY   #$5555        ; Pattern #2 : 9
            LDA   #$9999        ; Pattern #3 : 6
            TCD
*--		
            LDA   $06,S         ; Line 0
            AND   #$00F0
            ORA   #$2202
            STA   $06,S
            LDA   $AC,S
            AND   #$0F00
            ORA   #$4044
            STA   $AC,S
            SEP   #$20
            LDA   $A5,S
            AND   #$F0
            ORA   #$02
            STA   $A5,S
            REP   #$30
            TSC
            ADC   #$000B
            TCS
            PEA   $4444
            PEA   $4444
            TSC                 ; Line 1
            ADC   #$00A4
            TCS
            LDA   $A2,S
            AND   #$0F00
            ORA   #$4094
            STA   $A2,S
            PHD
            PEA   $2222
            PEA   $2222
            TSC                 ; Line 2
            ADC   #$00A7
            TCS
            SEP   #$20
            LDA   #$94
            STA   $A2,S
            REP   #$30
            PHD
            PHY
            PHY
            PEA   $0099
            PEA   $99AA
            PEA   $AAAA
            TSC                 ; Line 3
            ADC   #$00AD
            TCS
            LDA   $94,S
            AND   #$00F0
            ORA   #$AA0A
            STA   $94,S
            LDA   $A2,S
            AND   #$0F00
            ORA   #$4044
            STA   $A2,S
            PHD
            PEA   $55AA
            PEA   $0A00
            PHX
            PEA   $9099
            PHD
            PEA   $AAAA
            TSC                 ; Line 4
            ADC   #$00AF
            TCS
            SEP   #$20
            LDA   $95,S
            AND   #$F0
            ORA   #$0A
            STA   $95,S
            REP   #$30
            PHY
            PEA   $55AA
            PEA   $0A50
            PEA   $5505
            PHX
            PEA   $9A99
            TSC                 ; Line 5
            ADC   #$00AF
            TCS
            SEP   #$20
            LDA   #$00
            STA   $94,S
            REP   #$30
            PEA   $8088
            PEA   $8888
            PEA   $8888
            PEA   $0880
            PHY
            PEA   $5500
            PEA   $00AA
            TSC                 ; Line 6
            ADC   #$00AE
            TCS
            SEP   #$20
            LDA   $94,S
            AND   #$F0
            STA   $94,S
            REP   #$30
            PHX
            PHX
            PHX
            PEA   $A0AA
            PEA   $8855
            PEA   $5505
            TSC                 ; Line 7
            ADC   #$00A8
            TCS
            LDA   $98,S
            AND   #$00F0
            ORA   #$5500
            STA   $98,S
            PHX
            PEA   $00AA
            PEA   $AA88
            PHY
            TSC                 ; Line 8
            ADC   #$00A5
            TCS
            PHX
            PEA   $AA88
            TSC                 ; Line 9
            ADC   #$00A2
            TCS
            TXA
            STA   $9D,S
            PHX
            PEA   $8808
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_005     CLC                 ; 24x9, 263 bytes, 431 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$4444        ; Pattern #1 : 5
            LDY   #$8888        ; Pattern #2 : 4
            LDA   #$0000        ; Pattern #3 : 2
            TCD
*--		
            LDA   $01,S         ; Line 0
            AND   #$00F0
            STA   $01,S
            SEP   #$20
            LDA   #$22
            STA   $A7,S
            REP   #$30
            TSC
            ADC   #$0006
            TCS
            PEA   $2222
            PEA   $0200
            TSC                 ; Line 1
            ADC   #$00A4
            TCS
            PEA   $AAAA
            PHY
            PEA   $5805
            TSC                 ; Line 2
            ADC   #$00A8
            TCS
            LDA   $98,S
            AND   #$00F0
            ORA   #$4200
            STA   $98,S
            SEP   #$20
            LDA   $A2,S
            AND   #$0F
            ORA   #$20
            STA   $A2,S
            REP   #$30
            PEA   $22AA
            PEA   $AA88
            PEA   $2544
            PEA   $0400
            TSC                 ; Line 3
            ADC   #$00A9
            TCS
            SEP   #$20
            LDA   #$45
            STA   $A1,S
            REP   #$30
            PHY
            PHY
            PEA   $2540
            PEA   $4400
            TSC                 ; Line 4
            ADC   #$00A8
            TCS
            SEP   #$20
            LDA   $97,S
            AND   #$F0
            STA   $97,S
            REP   #$30
            PHX
            PHX
            PEA   $5244
            PEA   $4404
            PEA   $2004
            TSC                 ; Line 5
            ADC   #$00AB
            TCS
            SEP   #$20
            LDA   $97,S
            AND   #$F0
            ORA   #$04
            STA   $97,S
            REP   #$30
            PEA   $2200
            PEA   $0022
            PEA   $0088
            PEA   $5544
            PEA   $4400
            TSC                 ; Line 6
            ADC   #$00A7
            TCS
            LDA   #$0050
            STA   $9B,S
            LDA   $99,S
            AND   #$00F0
            ORA   #$5500
            STA   $99,S
            LDA   $9D,S
            AND   #$0F00
            ORA   #$2022
            STA   $9D,S
            PHD
            PEA   $8088
            PEA   $4544
            TSC                 ; Line 8
            ADC   #$013F
            TCS
            LDA   $00,S
            AND   #$00F0
            STA   $00,S
            SEP   #$20
            LDA   $02,S
            AND   #$0F
            STA   $02,S
            REP   #$30
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_006     CLC                 ; 24x33, 731 bytes, 1214 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$0000        ; Pattern #1 : 31
            LDY   #$4024        ; Pattern #2 : 4
            LDA   #$0224        ; Pattern #3 : 3
            TCD
*--		
            LDA   #$0500        ; Line 0
            STA   $07,S
            LDA   #$5000
            STA   $A8,S
            LDA   $A6,S
            AND   #$00F0
            ORA   #$8000
            STA   $A6,S
            SEP   #$20
            LDA   $09,S
            AND   #$0F
            STA   $09,S
            REP   #$30
            TSC                 ; Line 2
            ADC   #$0149
            TCS
            LDA   $9C,S
            AND   #$00F0
            ORA   #$4400
            STA   $9C,S
            SEP   #$20
            LDA   $01,S
            AND   #$0F
            STA   $01,S
            REP   #$30
            PEA   $0500
            PEA   $8004
            TSC                 ; Line 3
            ADC   #$00A5
            TCS
            LDA   $A0,S
            AND   #$0F00
            ORA   #$0005
            STA   $A0,S
            SEP   #$20
            LDA   $9B,S
            AND   #$F0
            STA   $9B,S
            REP   #$30
            PEA   $5080
            PEA   $0664
            TSC                 ; Line 4
            ADC   #$00A3
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$0088
            STA   $A1,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PEA   $4008
            PEA   $4495
            TSC                 ; Line 5
            ADC   #$00A4
            TCS
            SEP   #$20
            LDA   $A2,S
            AND   #$0F
            ORA   #$80
            STA   $A2,S
            REP   #$30
            PEA   $8005
            PEA   $4244
            TSC                 ; Line 6
            ADC   #$00A5
            TCS
            LDA   $9A,S
            AND   #$00F0
            ORA   #$6800
            STA   $9A,S
            LDA   $A0,S
            AND   #$0F00
            ORA   #$8006
            STA   $A0,S
            PEA   $6880
            PEA   $6606
            PEA   $4200
            TSC                 ; Line 7
            ADC   #$00A5
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$00A0
            STA   $A1,S
            PEA   $0088
            PEA   $8888
            TSC                 ; Line 8
            ADC   #$00A4
            TCS
            SEP   #$20
            LDA   $9A,S
            AND   #$F0
            STA   $9A,S
            REP   #$30
            PEA   $5560
            PEA   $0888
            PEA   $0806
            TSC                 ; Line 9
            ADC   #$00A8
            TCS
            SEP   #$20
            LDA   #$A0
            STA   $A0,S
            REP   #$30
            PEA   $A05A
            PEA   $5560
            PEA   $0808
            PEA   $0606
            TSC                 ; Line 10
            ADC   #$00A7
            TCS
            LDA   $96,S
            AND   #$00F0
            ORA   #$5400
            STA   $96,S
            PEA   $5455
            PEA   $6066
            PEA   $0686
            PEA   $A800
            PHX
            TSC                 ; Line 11
            ADC   #$00AB
            TCS
            PEA   $5055
            PEA   $005A
            PEA   $5585
            PEA   $A550
            PEA   $0A42
            TSC                 ; Line 12
            ADC   #$00AA
            TCS
            PHX
            PEA   $00A0
            PEA   $5555
            PEA   $A550
            PEA   $0542
            PEA   $6428
            TSC                 ; Line 13
            ADC   #$00AC
            TCS
            PHY
            PHX
            PEA   $5A82
            PEA   $A200
            PEA   $0522
            PEA   $8428
            TSC                 ; Line 14
            ADC   #$00AC
            TCS
            PHY
            PEA   $0066
            PEA   $6608
            PEA   $6600
            PHX
            PHX
            TSC                 ; Line 15
            ADC   #$00AC
            TCS
            PEA   $4022
            PEA   $0060
            PEA   $4288
            PEA   $4802
            TSC                 ; Line 16
            ADC   #$00A8
            TCS
            PEA   $8056
            PEA   $0060
            PEA   $8858
            PEA   $6806
            TSC                 ; Line 17
            ADC   #$00A8
            TCS
            PEA   $8006
            PHX
            PHX
            PHX
            TSC                 ; Line 18
            ADC   #$00A8
            TCS
            LDA   $9D,S
            AND   #$0F00
            ORA   #$005A
            STA   $9D,S
            PHX
            PEA   $00AA
            PEA   $5550
            PEA   $550A
            TSC                 ; Line 19
            ADC   #$00A4
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$005A
            STA   $A1,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PEA   $5500
            PEA   $050A
            TSC                 ; Line 20
            ADC   #$00A4
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$005A
            STA   $A1,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PEA   $5500
            PEA   $05A5
            TSC                 ; Line 21
            ADC   #$00A4
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$005A
            STA   $A1,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PEA   $5502
            PEA   $55A5
            TSC                 ; Line 22
            ADC   #$00A4
            TCS
            PEA   $5502
            PHX
            TSC                 ; Line 23
            ADC   #$00A5
            TCS
            PHX
            PHD
            PEA   $4402
            TSC                 ; Line 24
            ADC   #$00A6
            TCS
            SEP   #$20
            LDA   $9A,S
            AND   #$F0
            STA   $9A,S
            REP   #$30
            PHY
            PHD
            PEA   $4202
            TSC                 ; Line 25
            ADC   #$00A6
            TCS
            LDA   $9A,S
            AND   #$00F0
            ORA   #$5400
            STA   $9A,S
            SEP   #$20
            LDA   $A0,S
            AND   #$0F
            STA   $A0,S
            REP   #$30
            PEA   $4044
            PHD
            PHY
            TSC                 ; Line 26
            ADC   #$00A5
            TCS
            LDA   #$2040
            STA   $9D,S
            LDA   $9B,S
            AND   #$00F0
            ORA   #$4400
            STA   $9B,S
            PHX
            PEA   $2040
            TSC                 ; Line 28
            ADC   #$0142
            TCS
            LDA   #$4404
            STA   $9D,S
            LDA   $9F,S
            AND   #$0F00
            ORA   #$0044
            STA   $9F,S
            PEA   $4044
            PEA   $5402
            TSC                 ; Line 30
            ADC   #$0146
            TCS
            SEP   #$20
            LDA   #$00
            STA   $A1,S
            REP   #$30
            PHX
            PEA   $0044
            PEA   $4404
            TSC                 ; Line 31
            ADC   #$00A6
            TCS
            SEP   #$20
            LDA   $9B,S
            AND   #$F0
            STA   $9B,S
            REP   #$30
            PHX
            PHX
            PHX
            TSC                 ; Line 32
            ADC   #$00A7
            TCS
            PHX
            PHX
            PHX
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_007     CLC                 ; 28x5, 120 bytes, 244 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$0000        ; Pattern #1 : 35
*--		
            LDA   $A9,S         ; Line 0
            AND   #$0F00
            STA   $A9,S
            SEP   #$20
            LDA   $01,S
            AND   #$F0
            STA   $01,S
            REP   #$30
            TSC
            ADC   #$0005
            TCS
            PHX
            PHX
            TSC                 ; Line 1
            ADC   #$00A7
            TCS
            SEP   #$20
            LDA   $98,S
            AND   #$F0
            STA   $98,S
            REP   #$30
            PHX
            PHX
            PHX
            PHX
            TSC                 ; Line 2
            ADC   #$00AC
            TCS
            PHX
            PHX
            PHX
            PHX
            PHX
            PHX
            TSC                 ; Line 3
            ADC   #$00AB
            TCS
            LDA   $99,S
            AND   #$0F00
            STA   $99,S
            PHX
            PHX
            PHX
            PHX
            PHX
            PHX
            TSC                 ; Line 4
            ADC   #$00A4
            TCS
            PHX
            PHX
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_008     CLC                 ; 24x9, 264 bytes, 441 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$4444        ; Pattern #1 : 5
            LDY   #$AAAA        ; Pattern #2 : 4
            LDA   #$0000        ; Pattern #3 : 3
            TCD
*--		
            SEP   #$20          ; Line 0
            LDA   #$22
            STA   $A9,S
            LDA   $01,S
            AND   #$F0
            STA   $01,S
            REP   #$30
            TSC
            ADC   #$0007
            TCS
            PEA   $2222
            PEA   $2202
            PHD
            TSC                 ; Line 1
            ADC   #$00A7
            TCS
            PEA   $22AA
            PHY
            PEA   $8888
            PEA   $5805
            TSC                 ; Line 2
            ADC   #$00AA
            TCS
            LDA   $96,S
            AND   #$00F0
            ORA   #$4200
            STA   $96,S
            LDA   $A0,S
            AND   #$0F00
            ORA   #$2088
            STA   $A0,S
            PEA   $22AA
            PHY
            PEA   $8A58
            PEA   $2200
            PEA   $2004
            TSC                 ; Line 3
            ADC   #$00A9
            TCS
            LDA   $A1,S
            AND   #$0F00
            ORA   #$5044
            STA   $A1,S
            PEA   $8888
            PEA   $8858
            PEA   $2444
            PEA   $4400
            TSC                 ; Line 4
            ADC   #$00A8
            TCS
            LDA   $97,S
            AND   #$00F0
            STA   $97,S
            LDA   $A1,S
            AND   #$0F00
            ORA   #$2000
            STA   $A1,S
            PHX
            PEA   $4424
            PEA   $5044
            PEA   $4404
            PEA   $2004
            TSC                 ; Line 5
            ADC   #$00AA
            TCS
            LDA   $9C,S
            AND   #$0F00
            STA   $9C,S
            PHD
            PEA   $0080
            PEA   $8845
            PHX
            TSC                 ; Line 6
            ADC   #$00A3
            TCS
            LDA   #$5055
            STA   $9D,S
            LDA   $9F,S
            AND   #$0F00
            STA   $9F,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PEA   $8058
            PEA   $4504
            TSC                 ; Line 8
            ADC   #$0140
            TCS
            LDA   $00,S
            AND   #$00F0
            STA   $00,S
            SEP   #$20
            LDA   $02,S
            AND   #$0F
            STA   $02,S
            REP   #$30
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_009     CLC                 ; 28x10, 285 bytes, 482 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$4444        ; Pattern #1 : 7
            LDY   #$0000        ; Pattern #2 : 7
            LDA   #$8888        ; Pattern #3 : 4
            TCD
*--		
            SEP   #$20          ; Line 0
            LDA   $01,S
            AND   #$F0
            STA   $01,S
            LDA   $A9,S
            AND   #$0F
            ORA   #$20
            STA   $A9,S
            REP   #$30
            TSC
            ADC   #$0007
            TCS
            PEA   $2222
            PEA   $2200
            PHY
            TSC                 ; Line 1
            ADC   #$00A7
            TCS
            PEA   $22AA
            PEA   $AA8A
            PHD
            PEA   $5805
            TSC                 ; Line 2
            ADC   #$00AA
            TCS
            LDA   $96,S
            AND   #$00F0
            ORA   #$4200
            STA   $96,S
            PEA   $22A2
            PEA   $AAAA
            PEA   $8A88
            PHX
            PHY
            TSC                 ; Line 3
            ADC   #$00AB
            TCS
            SEP   #$20
            LDA   $A1,S
            AND   #$0F
            ORA   #$50
            STA   $A1,S
            REP   #$30
            PEA   $8288
            PHD
            PEA   $8845
            PEA   $0244
            PEA   $0420
            TSC                 ; Line 4
            ADC   #$00AA
            TCS
            LDA   $95,S
            AND   #$00F0
            STA   $95,S
            SEP   #$20
            LDA   $A1,S
            AND   #$0F
            STA   $A1,S
            REP   #$30
            PHX
            PHX
            PEA   $4402
            PEA   $4544
            PEA   $4400
            PEA   $2204
            TSC                 ; Line 5
            ADC   #$00AC
            TCS
            LDA   $96,S
            AND   #$00F0
            ORA   #$4400
            STA   $96,S
            SEP   #$20
            LDA   $9E,S
            AND   #$0F
            STA   $9E,S
            REP   #$30
            PHY
            PEA   $2022
            PEA   $0088
            PEA   $5844
            PEA   $4404
            TSC                 ; Line 6
            ADC   #$00A7
            TCS
            LDA   $9D,S
            AND   #$0F00
            STA   $9D,S
            PHY
            PEA   $8088
            PEA   $5544
            TSC                 ; Line 7
            ADC   #$00A2
            TCS
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PEA   $8855
            PEA   $4404
            TSC                 ; Line 8
            ADC   #$00A4
            TCS
            TYA
            STA   $9D,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PHY
            PEA   $5555
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_010     CLC                 ; 32x12, 379 bytes, 643 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$4444        ; Pattern #1 : 10
            LDY   #$8888        ; Pattern #2 : 8
            LDA   #$0000        ; Pattern #3 : 6
            TCD
*--		
            LDA   $01,S         ; Line 0
            AND   #$00F0
            STA   $01,S
            LDA   $A9,S
            AND   #$0F00
            ORA   #$2022
            STA   $A9,S
            TSC
            ADC   #$0008
            TCS
            PEA   $2222
            PEA   $2200
            PHD
            TSC                 ; Line 1
            ADC   #$00A6
            TCS
            SEP   #$20
            LDA   $99,S
            AND   #$F0
            STA   $99,S
            REP   #$30
            PEA   $AAAA
            PEA   $8A88
            PHY
            PEA   $5805
            TSC                 ; Line 2
            ADC   #$00AB
            TCS
            SEP   #$20
            LDA   $A2,S
            AND   #$0F
            ORA   #$20
            STA   $A2,S
            REP   #$30
            PEA   $22A2
            PEA   $AAAA
            PEA   $8A88
            PEA   $5544
            PEA   $4400
            TSC                 ; Line 3
            ADC   #$00AB
            TCS
            LDA   $94,S
            AND   #$00F0
            ORA   #$0400
            STA   $94,S
            PEA   $22AA
            PEA   $AAAA
            PEA   $8A88
            PEA   $4522
            PEA   $0200
            PEA   $4204
            TSC                 ; Line 4
            ADC   #$00AD
            TCS
            LDA   $93,S
            AND   #$00F0
            ORA   #$4200
            STA   $93,S
            SEP   #$20
            LDA   $A1,S
            AND   #$0F
            ORA   #$20
            STA   $A1,S
            REP   #$30
            PEA   $A2AA
            PEA   $AA8A
            PHY
            PEA   $4502
            PEA   $4044
            PEA   $0020
            TSC                 ; Line 5
            ADC   #$00AC
            TCS
            SEP   #$20
            LDA   $A1,S
            AND   #$0F
            ORA   #$50
            STA   $A1,S
            REP   #$30
            PHY
            PHY
            PEA   $8858
            PEA   $4440
            PHX
            PEA   $0400
            TSC                 ; Line 6
            ADC   #$00AC
            TCS
            LDA   $A0,S
            AND   #$0F00
            ORA   #$2002
            STA   $A0,S
            SEP   #$20
            LDA   $93,S
            AND   #$F0
            STA   $93,S
            REP   #$30
            PHX
            PHX
            PHX
            PEA   $0245
            PHX
            PEA   $4400
            PEA   $2004
            TSC                 ; Line 7
            ADC   #$00AD
            TCS
            LDA   $95,S
            AND   #$00F0
            ORA   #$4400
            STA   $95,S
            LDA   $9D,S
            AND   #$0F00
            STA   $9D,S
            PHD
            PEA   $2022
            PEA   $0088
            PEA   $5855
            PHX
            PEA   $0400
            TSC                 ; Line 8
            ADC   #$00A8
            TCS
            SEP   #$20
            LDA   $9F,S
            AND   #$0F
            STA   $9F,S
            REP   #$30
            PEA   $0080
            PHY
            PEA   $5544
            TSC                 ; Line 9
            ADC   #$00A4
            TCS
            SEP   #$20
            LDA   $9A,S
            AND   #$F0
            STA   $9A,S
            REP   #$30
            PHD
            PEA   $8855
            PEA   $4404
            TSC                 ; Line 10
            ADC   #$00A4
            TCS
            TDC
            STA   $9D,S
            SEP   #$20
            LDA   $9C,S
            AND   #$F0
            STA   $9C,S
            REP   #$30
            PHD
            PEA   $5555
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_011     CLC                 ; 32x16, 484 bytes, 800 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$0000        ; Pattern #1 : 5
            LDY   #$4444        ; Pattern #2 : 4
            LDA   #$5555        ; Pattern #3 : 4
            TCD
*--		
            LDA   #$4224        ; Line 0
            STA   $0D,S
            LDA   #$3924
            STA   $AC,S
            LDA   $AE,S
            AND   #$0F00
            ORA   #$209A
            STA   $AE,S
            TSC                 ; Line 2
            ADC   #$0140
            TCS
            LDA   #$A3AA
            STA   $AB,S
            LDA   $05,S
            AND   #$0F00
            ORA   #$2022
            STA   $05,S
            LDA   $A9,S
            AND   #$00F0
            ORA   #$2202
            STA   $A9,S
            LDA   $AD,S
            AND   #$0F00
            ORA   #$0039
            STA   $AD,S
            SEP   #$20
            LDA   $A3,S
            AND   #$F0
            ORA   #$02
            STA   $A3,S
            REP   #$30
            TSC
            ADC   #$000E
            TCS
            PEA   $A2A3
            PEA   $AA24
            TSC                 ; Line 3
            ADC   #$009D
            TCS
            LDA   $9B,S
            AND   #$00F0
            ORA   #$2902
            STA   $9B,S
            PEA   $2292
            PEA   $9922
            TSC                 ; Line 4
            ADC   #$00AA
            TCS
            LDA   $9F,S
            AND   #$0F00
            ORA   #$0044
            STA   $9F,S
            SEP   #$20
            LDA   $94,S
            AND   #$F0
            ORA   #$02
            STA   $94,S
            REP   #$30
            PEA   $4034
            PEA   $13AA
            PEA   $2A22
            PEA   $9999
            PEA   $9999
            TSC                 ; Line 5
            ADC   #$00A8
            TCS
            SEP   #$20
            LDA   $A2,S
            AND   #$0F
            STA   $A2,S
            REP   #$30
            PEA   $5155
            PEA   $A54A
            PEA   $9449
            PEA   $4499
            PEA   $9929
            TSC                 ; Line 6
            ADC   #$00AB
            TCS
            LDA   $94,S
            AND   #$00F0
            ORA   #$4400
            STA   $94,S
            PEA   $0055
            PEA   $4524
            PEA   $A54A
            PEA   $A488
            PHY
            PEA   $9429
            TSC                 ; Line 7
            ADC   #$00AD
            TCS
            LDA   $93,S
            AND   #$00F0
            STA   $93,S
            PEA   $8008
            PEA   $5594
            PEA   $4952
            PEA   $A54A
            PEA   $5488
            PEA   $8808
            TSC                 ; Line 8
            ADC   #$00AC
            TCS
            PEA   $9020
            PEA   $4599
            PEA   $AA24
            PHD
            PEA   $4555
            PEA   $5585
            TSC                 ; Line 9
            ADC   #$00AC
            TCS
            PEA   $9020
            PEA   $55A4
            PEA   $9A49
            PHY
            PEA   $4522
            PEA   $4244
            PEA   $8808
            TSC                 ; Line 10
            ADC   #$00AE
            TCS
            PEA   $9008
            PEA   $5245
            PEA   $9924
            PHD
            PEA   $5440
            PEA   $2242
            PEA   $4502
            TSC                 ; Line 11
            ADC   #$00AE
            TCS
            LDA   $93,S
            AND   #$00F0
            STA   $93,S
            LDA   $9F,S
            AND   #$0F00
            STA   $9F,S
            PEA   $8040
            PEA   $2055
            PHY
            PEA   $2244
            PEA   $4400
            PEA   $0040
            PEA   $2402
            TSC                 ; Line 12
            ADC   #$00AC
            TCS
            LDA   $A0,S
            AND   #$0F00
            STA   $A0,S
            SEP   #$20
            LDA   $97,S
            AND   #$F0
            STA   $97,S
            REP   #$30
            PEA   $0452
            PEA   $4544
            PEA   $0200
            PEA   $0040
            PEA   $990A
            TSC                 ; Line 13
            ADC   #$00A9
            TCS
            LDA   $9A,S
            AND   #$00F0
            ORA   #$4400
            STA   $9A,S
            SEP   #$20
            LDA   $A0,S
            AND   #$0F
            STA   $A0,S
            REP   #$30
            PEA   $2022
            PEA   $2220
            PHD
            PHX
            TSC                 ; Line 14
            ADC   #$00A7
            TCS
            TXA
            STA   $9C,S
            SEP   #$20
            LDA   $9E,S
            AND   #$0F
            STA   $9E,S
            REP   #$30
            PHX
            PEA   $2042
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_012     CLC                 ; 20x7, 183 bytes, 306 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$2222        ; Pattern #1 : 4
            LDY   #$6022        ; Pattern #2 : 2
            LDA   #$9A86        ; Pattern #3 : 2
            TCD
*--		
            LDA   #$84A9        ; Line 0
            STA   $01,S
            LDA   $A1,S
            AND   #$00F0
            ORA   #$6204
            STA   $A1,S
            SEP   #$20
            LDA   $03,S
            AND   #$0F
            STA   $03,S
            REP   #$30
            TSC                 ; Line 1
            ADC   #$00A6
            TCS
            LDA   $9A,S
            AND   #$00F0
            ORA   #$4202
            STA   $9A,S
            PHY
            PHX
            TSC                 ; Line 2
            ADC   #$00A5
            TCS
            SEP   #$20
            LDA   $A1,S
            AND   #$0F
            STA   $A1,S
            REP   #$30
            PEA   $8029
            PEA   $A9AA
            PHD
            TSC                 ; Line 3
            ADC   #$00A6
            TCS
            LDA   $99,S
            AND   #$00F0
            ORA   #$4202
            STA   $99,S
            PEA   $6682
            PEA   $4855
            PEA   $6498
            PEA   $4A86
            TSC                 ; Line 4
            ADC   #$00A8
            TCS
            LDA   $9A,S
            AND   #$00F0
            ORA   #$6204
            STA   $9A,S
            PEA   $6029
            PEA   $A9AA
            PHD
            TSC                 ; Line 5
            ADC   #$00A5
            TCS
            LDA   #$84A9
            STA   $9B,S
            SEP   #$20
            LDA   $9D,S
            AND   #$0F
            STA   $9D,S
            REP   #$30
            PHY
            PHX
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_013     CLC                 ; 32x13, 399 bytes, 683 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$4444        ; Pattern #1 : 12
            LDY   #$0000        ; Pattern #2 : 11
            LDA   #$AAAA        ; Pattern #3 : 8
            TCD
*--		
            LDA   $08,S         ; Line 0
            AND   #$0F00
            ORA   #$2022
            STA   $08,S
            SEP   #$20
            LDA   $01,S
            AND   #$F0
            STA   $01,S
            LDA   $AB,S
            AND   #$0F
            ORA   #$20
            STA   $AB,S
            REP   #$30
            TSC
            ADC   #$0007
            TCS
            PEA   $2222
            PHY
            PHY
            TSC                 ; Line 1
            ADC   #$00A9
            TCS
            SEP   #$20
            LDA   #$A2
            STA   $A1,S
            REP   #$30
            PEA   $22A2
            PHD
            PEA   $8A88
            PEA   $8888
            PEA   $5805
            TSC                 ; Line 2
            ADC   #$00AA
            TCS
            LDA   $97,S
            AND   #$00F0
            STA   $97,S
            PHD
            PEA   $AA8A
            PEA   $8845
            PHX
            PHY
            TSC                 ; Line 3
            ADC   #$00AC
            TCS
            SEP   #$20
            LDA   #$22
            STA   $A1,S
            REP   #$30
            PEA   $22A2
            PHD
            PEA   $AA88
            PEA   $5844
            PEA   $4404
            TSC                 ; Line 4
            ADC   #$00AA
            TCS
            LDA   $94,S
            AND   #$00F0
            ORA   #$4200
            STA   $94,S
            SEP   #$20
            LDA   $A2,S
            AND   #$0F
            ORA   #$20
            STA   $A2,S
            REP   #$30
            PHD
            PHD
            PEA   $8858
            PEA   $4420
            PHY
            PEA   $2204
            TSC                 ; Line 5
            ADC   #$00AD
            TCS
            SEP   #$20
            LDA   #$45
            STA   $A1,S
            REP   #$30
            PEA   $8888
            PEA   $8888
            PEA   $8858
            PEA   $2400
            PHX
            PEA   $0020
            TSC                 ; Line 6
            ADC   #$00AC
            TCS
            SEP   #$20
            LDA   $93,S
            AND   #$F0
            STA   $93,S
            REP   #$30
            PHX
            PHX
            PEA   $4424
            PEA   $5044
            PHX
            PEA   $0400
            PEA   $2204
            TSC                 ; Line 7
            ADC   #$00AF
            TCS
            SEP   #$20
            LDA   $93,S
            AND   #$F0
            STA   $93,S
            REP   #$30
            PEA   $0020
            PEA   $2222
            PEA   $2202
            PEA   $8088
            PEA   $5544
            PHX
            PHY
            TSC                 ; Line 8
            ADC   #$00AD
            TCS
            LDA   $94,S
            AND   #$00F0
            ORA   #$4400
            STA   $94,S
            LDA   $9A,S
            AND   #$0F00
            STA   $9A,S
            PHY
            PHY
            PHY
            PEA   $8888
            PEA   $4544
            PEA   $4404
            TSC                 ; Line 9
            ADC   #$00A5
            TCS
            SEP   #$20
            LDA   $A1,S
            AND   #$0F
            STA   $A1,S
            REP   #$30
            PEA   $8858
            PEA   $4544
            TSC                 ; Line 10
            ADC   #$00A4
            TCS
            LDA   #$5055
            STA   $9C,S
            LDA   $9A,S
            AND   #$00F0
            ORA   #$5500
            STA   $9A,S
            LDA   $9E,S
            AND   #$0F00
            STA   $9E,S
            PEA   $0080
            PEA   $5845
            PEA   $4404
            TSC                 ; Line 12
            ADC   #$0140
            TCS
            LDA   $00,S
            AND   #$00F0
            STA   $00,S
            LDA   $02,S
            AND   #$0F00
            STA   $02,S
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		
Spr_014     CLC                 ; 16x3, 91 bytes, 170 cycles
            SEI                 ; Disable Interrupts
            PHD                 ; Backup Direct Page
            TSC                 ; Backup Stack
            STA   StackAddress
            LDAL  $E1C068       ; Direct Page and Stack in Bank 01/
            ORA   #$0030
            STAL  $E1C068
            TYA                 ; Y = Sprite Target Screen Address (upper left corner)
            TCS                 ; New Stack address
            LDX   #$0000        ; Pattern #1 : 15
*--		
            SEP   #$20          ; Line 0
            LDA   $06,S
            AND   #$0F
            STA   $06,S
            LDA   $A0,S
            AND   #$F0
            STA   $A0,S
            REP   #$30
            TSC
            ADC   #$0005
            TCS
            PHX
            PHX
            PHX
            TSC                 ; Line 1
            ADC   #$00A7
            TCS
            SEP   #$20
            LDA   $A0,S
            AND   #$0F
            STA   $A0,S
            REP   #$30
            PHX
            PHX
            PHX
            TSC                 ; Line 2
            ADC   #$00A5
            TCS
            PHX
            PHX
            PHX
*--		
            LDAL  $E1C068       ; Direct Page and Stack in Bank 00/
            AND   #$FFCF
            STAL  $E1C068
            LDA   StackAddress  ; Restore Stack
            TCS
            PLD                 ; Restore Direct Page
            CLI                 ; Enable Interrupts
            RTL

*-------------------------------		


