; IIgs Game Engine

            TYP   $B3         ; S16 file
            DSK   SuperMarioGS
            XPL

; Segment #1 -- Main execution block

            ASM   Main.s
            KND   #$1100
            SNA   MAIN

; Segment #2 -- ROM

            ASM   rom.s
            KND   #$1100
            SNA   SMBROM
















































