; Special routines for the dirty tile renderer that draws directly to the graphics screen

; A = tile address
; Y = screen address
DirtyTileZero
            lda    TileStore+TS_SCREEN_ADDR,x       ; Get the on-screen address of this tile
            tax
            pei    DP2_BANK01_AND_TILESTORE_BANKS
            plb

]line       equ    0
            lup    8
            stz:   {]line*SHR_LINE_WIDTH}+0,x
            stz:   {]line*SHR_LINE_WIDTH}+2,x
]line       equ    ]line+1

            plb
            rts

DirtyTileA
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

            plb
            rts

DirtyTileV
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
DirtySpriteLine mac
            lda   tiledata+{]1*TILE_DATA_SPAN}+]4,y
            andl  spritemask+{]2*SPRITE_PLANE_SPAN}+]4,x
            oral  spritedata+{]2*SPRITE_PLANE_SPAN}+]4,x
            sta   ]3+]4
            <<<

; Special routine for a single sprite
OneSpriteDirtyA
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

            DirtySpriteLine 0,0,$00,0
            DirtySpriteLine 0,0,$00,2
            DirtySpriteLine 1,1,$A0,0
            DirtySpriteLine 1,1,$A0,2

            tdc
            adc   #320
            tcd

            DirtySpriteLine 2,2,$00,0
            DirtySpriteLine 2,2,$00,2
            DirtySpriteLine 3,3,$A0,0
            DirtySpriteLine 3,3,$A0,2

            tdc
            adc   #320
            tcd

            DirtySpriteLine 4,4,$00,0
            DirtySpriteLine 4,4,$00,2
            DirtySpriteLine 5,5,$A0,0
            DirtySpriteLine 5,5,$A0,2

            tdc
            adc   #320
            tcd

            DirtySpriteLine 6,6,$00,0
            DirtySpriteLine 6,6,$00,2
            DirtySpriteLine 7,7,$A0,0
            DirtySpriteLine 7,7,$A0,2

            _R0W0

            cli
            plb
            pld
            rts

OneSpriteDirtyV
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

            DirtySpriteLine 7,0,$00,0
            DirtySpriteLine 7,0,$00,2
            DirtySpriteLine 6,1,$A0,0
            DirtySpriteLine 6,1,$A0,2

            tdc
            adc   #320
            tcd

            DirtySpriteLine 5,2,$00,0
            DirtySpriteLine 5,2,$00,2
            DirtySpriteLine 4,3,$A0,0
            DirtySpriteLine 4,3,$A0,2

            tdc
            adc   #320
            tcd

            DirtySpriteLine 3,4,$00,0
            DirtySpriteLine 3,4,$00,2
            DirtySpriteLine 2,5,$A0,0
            DirtySpriteLine 2,5,$A0,2

            tdc
            adc   #320
            tcd

            DirtySpriteLine 1,6,$00,0
            DirtySpriteLine 1,6,$00,2
            DirtySpriteLine 0,7,$A0,0
            DirtySpriteLine 0,7,$A0,2

            _R0W0

            cli
            plb
            pld
            rts

; Generic routine for multiple sprites -- expect sprites to be in tmp_sprite_data and tmp_sprite_mask
SpriteDirtyA
            ldy   TileStore+TS_SCREEN_ADDR,x
            lda   TileStore+TS_TILE_ADDR,x
            tax

            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb

]line       equ   0
            lup   8
            ldal  tiledata+{]line*TILE_DATA_SPAN}+0,x
            andl  tmp_sprite_mask+{]line*4}+0
            oral  tmp_sprite_data+{]line*4}+0
            sta:  {]line*SHR_LINE_WIDTH}+0,y

            ldal  tiledata+{]line*TILE_DATA_SPAN}+2,x
            andl  tmp_sprite_mask+{]line*4}+2
            oral  tmp_sprite_data+{]line*4}+2
            sta:  {]line*SHR_LINE_WIDTH}+2,y
]line       equ   ]line+1
            --^

            plb
            rts

SpriteDirtyV
            ldy   TileStore+TS_SCREEN_ADDR,x
            lda   TileStore+TS_TILE_ADDR,x
            tax

            pei   DP2_TILEDATA_AND_TILESTORE_BANKS
            plb

]src        equ   7
]dest       equ   0
            lup   8
            ldal  tiledata+{]src*TILE_DATA_SPAN}+0,x
            andl  tmp_sprite_mask+{]dest*4}+0
            oral  tmp_sprite_data+{]dest*4}+0
            sta:  {]dest*SHR_LINE_WIDTH}+0,y

            ldal  tiledata+{]src*TILE_DATA_SPAN}+2,x
            andl  tmp_sprite_mask+{]dest*4}+2
            oral  tmp_sprite_data+{]dest*4}+2
            sta:  {]dest*SHR_LINE_WIDTH}+2,y
]src        equ   ]src-1
]dest       equ   ]dest+1
            --^

            plb
            rts