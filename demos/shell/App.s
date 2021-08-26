; IIgs Game Engine

            TYP   $B3            ; S16 file
            DSK   GTETestApp
            XPL

; Segment #1 -- Main execution block

            ASM   App.Main.s
            DS    0              ;   Number of bytes of 0's to add at the end of the Segment
            KND   #$1100         ;   Type and Attributes ($11=Static+Bank Relative,$00=Code)
            ALI   None           ;   Boundary Alignment (None)
            SNA   Main

; Segment #2 -- Core GTE Code

            ASM   Core.s
            SNA   Core

; Segment #3 -- 64KB Tile Memory

            ASM   App.TileSet.s
            DS    0
            KND   #$1001         ; Type and Attributes ($11=Static+Bank Relative,$01=Data)
;            ALI   BANK
            SNA   Tiles

; Segment #4 -- Rotation table data

            ASM   RotData.s
            DS    0
            KND   #$1001         ; Type and Attributes ($11=Static+Bank Relative,$01=Data)
            ALI   BANK
            SNA   RotData

