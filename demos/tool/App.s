; IIgs Sprite Testbed

            TYP   $B3                  ; S16 file
            DSK   GTEToolDemo
            XPL

; Segment #1 -- Main execution block

            ASM   App.Main.s
            SNA   Main

; Segment #2 -- Tileset

            ASM   Zelda.TileSet.s
            SNA   TSET
