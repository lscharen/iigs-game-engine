; IIgs Game Engine

            TYP   $B3                  ; S16 file
            DSK   GTEShooter
            XPL

; Segment #1 -- Main execution block

            ASM   Main.s

; Segment #2 -- Core GTE Code

            ASM   ..\..\src\Core.s

; Segment #3 -- GTE Rotation Table Data

            ASM   ..\..\src\RotData.s
            DS    0
            KND   #$1001               ; Type and Attributes ($11=Static+Bank Relative,$01=Data)
            ALI   BANK
            SNA   RotData

