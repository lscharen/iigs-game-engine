; KFest 2022: Demo #5

            TYP   $B3                  ; S16 file
            DSK   GTEDemo5
            XPL

; Segment #1 -- Main execution block

            ASM   App.Main.s
            SNA   Main

; Segment #2 -- Tileset

            ASM   gen\App.TileSet.s
            SNA   TSET