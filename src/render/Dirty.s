; Special routines for the dirty tile renderer that draws directly to the graphics screen

; A = tile address
; Y = screen address
SpriteUnder0Dirty
ConstTile0Dirty
            lda    TileStore+TS_SCREEN_ADDR,x       ; Get the on-screen address of this tile
            tax
            pei    DP2_BANK01_AND_TILESTORE_BANKS
            plb

]line       equ    0
            lup    8
            stz:   {]line*SHR_LINE_WIDTH}+0,x
            stz:   {]line*SHR_LINE_WIDTH}+2,x
]line       equ    ]line+1
            --^

            plb
            rts

; Sprite over a zero tile
OneSpriteDirtyOver0
            ldy   TileStore+TS_SCREEN_ADDR,x
            tax

            pei   DP2_BANK01_AND_TILESTORE_BANKS
            plb

]line       equ   0
            lup   8
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+0,x
            sta:  {]line*SHR_LINE_WIDTH}+0,y
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            sta:  {]line*SHR_LINE_WIDTH}+2,y
]line       equ   ]line+1
            --^

            plb
            rts

; Multiple sprites (copied to direct page temp space)
SpriteOver0Dirty
            ldy   TileStore+TS_SCREEN_ADDR,x
            pei   DP2_BANK01_AND_TILESTORE_BANKS
            plb

]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}+0
            sta:  {]line*SHR_LINE_WIDTH}+0,y
            lda   tmp_sprite_data+{]line*4}+2
            sta:  {]line*SHR_LINE_WIDTH}+2,y
]line       equ   ]line+1
            --^

            plb
            rts

CopyTileADirty
            ldy    TileStore+TS_SCREEN_ADDR,x       ; Get the on-screen address of this tile
            lda    TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            tax

            pei    DP2_BANK01_AND_TILESTORE_BANKS
            plb

]line       equ    0
            lup    8
            ldal   tiledata+{]line*4}+0,x
            sta:   {]line*SHR_LINE_WIDTH}+0,y
            ldal   tiledata+{]line*4}+2,x
            sta:   {]line*SHR_LINE_WIDTH}+2,y
]line       equ    ]line+1
            --^

            plb
            rts

CopyTileVDirty
            ldy    TileStore+TS_SCREEN_ADDR,x       ; Get the on-screen address of this tile
            lda    TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            tax

            pei    DP2_BANK01_AND_TILESTORE_BANKS
            plb

]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*4}+0,x
            sta:   {]line*SHR_LINE_WIDTH}+0,y
            ldal  tiledata+{]src*4}+2,x
            sta:   {]line*SHR_LINE_WIDTH}+2,y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^

            plb
            rts

; DirtySpriteLine srcLine,destLine,dpAddr,offset
DirtySpriteOver mac
            lda:  tiledata+{]1*TILE_DATA_SPAN}+]4,y
            andl  spritemask+{]2*SPRITE_PLANE_SPAN}+]4,x
            oral  spritedata+{]2*SPRITE_PLANE_SPAN}+]4,x
            sta   ]3+]4
            <<<

DirtySpriteUnder mac
            ldal  spritedata+{]2*SPRITE_PLANE_SPAN}+]4,x
            and   tiledata+{]1*TILE_DATA_SPAN}+32+]4,y
            ora   tiledata+{]1*TILE_DATA_SPAN}+]4,y
            sta   ]3+]4
            <<<

; Special routine for a single sprite
OneSpriteDirtyOverA

            ldy   TileStore+TS_TILE_ADDR,x
            lda   TileStore+TS_SCREEN_ADDR,x
            ldx   sprite_ptr0

            phd
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb
            sei
            clc
            tcd

            _R0W1

            DirtySpriteOver 0;0;$00;0
            DirtySpriteOver 0;0;$00;2
            DirtySpriteOver 1;1;$A0;0
            DirtySpriteOver 1;1;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteOver 2;2;$00;0
            DirtySpriteOver 2;2;$00;2
            DirtySpriteOver 3;3;$A0;0
            DirtySpriteOver 3;3;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteOver 4;4;$00;0
            DirtySpriteOver 4;4;$00;2
            DirtySpriteOver 5;5;$A0;0
            DirtySpriteOver 5;5;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteOver 6;6;$00;0
            DirtySpriteOver 6;6;$00;2
            DirtySpriteOver 7;7;$A0;0
            DirtySpriteOver 7;7;$A0;2

            _R0W0

            cli
            plb
            pld
            rts

OneSpriteDirtyUnderA
            ldy   TileStore+TS_TILE_ADDR,x
            lda   TileStore+TS_SCREEN_ADDR,x
            ldx   sprite_ptr0

            phd
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb
            sei
            clc
            tcd

            _R0W1

            DirtySpriteUnder 0;0;$00;0
            DirtySpriteUnder 0;0;$00;2
            DirtySpriteUnder 1;1;$A0;0
            DirtySpriteUnder 1;1;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteUnder 2;2;$00;0
            DirtySpriteUnder 2;2;$00;2
            DirtySpriteUnder 3;3;$A0;0
            DirtySpriteUnder 3;3;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteUnder 4;4;$00;0
            DirtySpriteUnder 4;4;$00;2
            DirtySpriteUnder 5;5;$A0;0
            DirtySpriteUnder 5;5;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteUnder 6;6;$00;0
            DirtySpriteUnder 6;6;$00;2
            DirtySpriteUnder 7;7;$A0;0
            DirtySpriteUnder 7;7;$A0;2

            _R0W0

            cli
            plb
            pld
            rts

OneSpriteDirtyOverV
            ldy   TileStore+TS_TILE_ADDR,x
            lda   TileStore+TS_SCREEN_ADDR,x
            ldx   sprite_ptr0

            phd
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb
            sei
            clc
            tcd

            _R0W1

            DirtySpriteOver 7;0;$00;0
            DirtySpriteOver 7;0;$00;2
            DirtySpriteOver 6;1;$A0;0
            DirtySpriteOver 6;1;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteOver 5;2;$00;0
            DirtySpriteOver 5;2;$00;2
            DirtySpriteOver 4;3;$A0;0
            DirtySpriteOver 4;3;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteOver 3;4;$00;0
            DirtySpriteOver 3;4;$00;2
            DirtySpriteOver 2;5;$A0;0
            DirtySpriteOver 2;5;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteOver 1;6;$00;0
            DirtySpriteOver 1;6;$00;2
            DirtySpriteOver 0;7;$A0;0
            DirtySpriteOver 0;7;$A0;2

            _R0W0

            cli
            plb
            pld
            rts


OneSpriteDirtyUnderV
            ldy   TileStore+TS_TILE_ADDR,x
            lda   TileStore+TS_SCREEN_ADDR,x
            ldx   sprite_ptr0

            phd
            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb
            sei
            clc
            tcd

            _R0W1

            DirtySpriteUnder 7;0;$00;0
            DirtySpriteUnder 7;0;$00;2
            DirtySpriteUnder 6;1;$A0;0
            DirtySpriteUnder 6;1;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteUnder 5;2;$00;0
            DirtySpriteUnder 5;2;$00;2
            DirtySpriteUnder 4;3;$A0;0
            DirtySpriteUnder 4;3;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteUnder 3;4;$00;0
            DirtySpriteUnder 3;4;$00;2
            DirtySpriteUnder 2;5;$A0;0
            DirtySpriteUnder 2;5;$A0;2

            tdc
            adc   #320
            tcd

            DirtySpriteUnder 1;6;$00;0
            DirtySpriteUnder 1;6;$00;2
            DirtySpriteUnder 0;7;$A0;0
            DirtySpriteUnder 0;7;$A0;2

            _R0W0

            cli
            plb
            pld
            rts

; Generic routine for multiple sprites -- expect sprites to be in tmp_sprite_data and tmp_sprite_mask
SpriteOverADirty
            ldy   TileStore+TS_SCREEN_ADDR,x
            lda   TileStore+TS_TILE_ADDR,x
            tax

            pei   DP2_BANK01_AND_TILESTORE_BANKS
            plb

]line       equ   0
            lup   8
            ldal  tiledata+{]line*TILE_DATA_SPAN}+0,x
            and   tmp_sprite_mask+{]line*4}+0
            ora   tmp_sprite_data+{]line*4}+0
            sta:  {]line*SHR_LINE_WIDTH}+0,y
;            brk   $00

            ldal  tiledata+{]line*TILE_DATA_SPAN}+2,x
            and   tmp_sprite_mask+{]line*4}+2
            ora   tmp_sprite_data+{]line*4}+2
            sta:  {]line*SHR_LINE_WIDTH}+2,y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteUnderADirty
            ldy   TileStore+TS_SCREEN_ADDR,x
            lda   TileStore+TS_TILE_ADDR,x
            tax

            pei   DP2_BANK01_AND_TILESTORE_BANKS
            plb

]line       equ   0
            lup   8
            lda   tmp_sprite_data+{]line*4}+0
            andl  tiledata+{]line*TILE_DATA_SPAN}+32,x
            oral  tiledata+{]line*TILE_DATA_SPAN}+0,x
            sta:  {]line*SHR_LINE_WIDTH}+0,y

            lda   tmp_sprite_data+{]line*4}+2
            andl  tiledata+{]line*TILE_DATA_SPAN}+32+2,x
            oral  tiledata+{]line*TILE_DATA_SPAN}+2,x
            sta:  {]line*SHR_LINE_WIDTH}+2,y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteOverVDirty
            ldy   TileStore+TS_SCREEN_ADDR,x
            lda   TileStore+TS_TILE_ADDR,x
            tax

            pei   DP2_BANK01_AND_TILESTORE_BANKS
            plb

]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*TILE_DATA_SPAN}+0,x
            and   tmp_sprite_mask+{]dest*4}+0
            ora   tmp_sprite_data+{]dest*4}+0
            sta:  {]dest*SHR_LINE_WIDTH}+0,y

            ldal  tiledata+{]src*TILE_DATA_SPAN}+2,x
            and   tmp_sprite_mask+{]dest*4}+2
            ora   tmp_sprite_data+{]dest*4}+2
            sta:  {]dest*SHR_LINE_WIDTH}+2,y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^

            plb
            rts

SpriteUnderVDirty
            ldy   TileStore+TS_SCREEN_ADDR,x
            lda   TileStore+TS_TILE_ADDR,x
            tax

            pei   DP2_BANK01_AND_TILESTORE_BANKS
            plb

]src        equ   7
]dest       equ   0
            lup   8

            lda   tmp_sprite_data+{]dest*4}+0
            andl  tiledata+{]src*TILE_DATA_SPAN}+32,x
            oral  tiledata+{]src*TILE_DATA_SPAN}+0,x
            sta:  {]dest*SHR_LINE_WIDTH}+0,y

            lda   tmp_sprite_data+{]dest*4}+2
            andl  tiledata+{]src*TILE_DATA_SPAN}+32+2,x
            oral  tiledata+{]src*TILE_DATA_SPAN}+2,x
            sta:  {]dest*SHR_LINE_WIDTH}+2,y

]src        equ   ]src-1
]dest       equ   ]dest+1
            --^

            plb
            rts