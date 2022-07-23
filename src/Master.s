; IIgs Generic Tile Engine User Toolset

            TYP   $BA                  ; Tool set file
            DSK   Tool160
            XPL

; Main toolbox interface and code

            ASM   Tool.s
            SNA   Main

; 64KB Tile Memory

            ASM   static\TileData.s
            KND   #$1001               ; Type and Attributes ($10=Static,$01=Data)
            ALI   BANK
            SNA   TDATA

; 64KB Sprite Plane Data

            ASM   static\SprData.s
            KND   #$1001               ; Type and Attributes ($11=Static+Bank Relative,$01=Data)
            ALI   BANK
            SNA   SDATA

; 64KB Sprite Mask Data

            ASM   static\SprMask.s
            KND   #$1001               ; Type and Attributes ($11=Static+Bank Relative,$01=Data)
            ALI   BANK
            SNA   SMASK

; 64KB Tile Store

            ASM   static\TileStore.s
            KND   #$1001               ; Type and Attributes ($11=Static+Bank Relative,$01=Data)
            ALI   BANK
            SNA   TSTORE

; 64KB Rotation Data Tables

            ASM   RotData.s
            KND   #$1001               ; Type and Attributes ($11=Static+Bank Relative,$01=Data)
            ALI   BANK
            SNA   ROTDATA
