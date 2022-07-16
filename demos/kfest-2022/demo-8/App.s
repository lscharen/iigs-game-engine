; KFest 2022: Demo #8

            TYP   $B3                  ; S16 file
            DSK   GTEDemo8
            XPL

; Segment #1 -- Main execution block

            ASM   App.Main.s
            SNA   Main

; Segment #2 -- Tileset

            ASM   gen\App.TileSet.s
            SNA   TSET