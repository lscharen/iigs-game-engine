; IIgs Game Engine

            TYP   $B3         ; S16 file
            DSK   GTETestApp
            XPL

; Segment #1 -- Main execution block

            ASM   App.Main.s
;            SNA   Main

; Segment #2 -- 64KB Tile Memory

            ASM   App.Tile.s















































