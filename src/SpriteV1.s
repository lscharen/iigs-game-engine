; Old code the was in Version 1, but is not needed.  May be adapted for Verions 2.

; Y = _Sprites array offset
_EraseSpriteY
             lda   _Sprites+OLD_VBUFF_ADDR,y
             beq   :noerase
             ldx   _Sprites+SPRITE_DISP,y              ; get the dispatch index for this sprite (32 values)
             jmp   (:do_erase,x)
:noerase     rts
:do_erase    dw    _EraseTileSprite8x8,_EraseTileSprite8x8,_EraseTileSprite8x8,_EraseTileSprite8x8
             dw    _EraseTileSprite8x16,_EraseTileSprite8x16,_EraseTileSprite8x16,_EraseTileSprite8x16
             dw    _EraseTileSprite16x8,_EraseTileSprite16x8,_EraseTileSprite16x8,_EraseTileSprite16x8
             dw    _EraseTileSprite16x16,_EraseTileSprite16x16,_EraseTileSprite16x16,_EraseTileSprite16x16
             dw    _EraseTileSprite8x8,_EraseTileSprite8x8,_EraseTileSprite8x8,_EraseTileSprite8x8
             dw    _EraseTileSprite8x16,_EraseTileSprite8x16,_EraseTileSprite8x16,_EraseTileSprite8x16
             dw    _EraseTileSprite16x8,_EraseTileSprite16x8,_EraseTileSprite16x8,_EraseTileSprite16x8
             dw    _EraseTileSprite16x16,_EraseTileSprite16x16,_EraseTileSprite16x16,_EraseTileSprite16x16

; A = bank address
_EraseTileSprite8x8
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    8
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)
            lda    #$FFFF
]line       equ    0
            lup    8
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb
            rts

_EraseTileSprite8x16
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    16
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)
            lda    #$FFFF
]line       equ    0
            lup    16
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb
            rts

_EraseTileSprite16x8
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    8
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
            stz:   {]line*SPRITE_PLANE_SPAN}+4,x
            stz:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)
            lda    #$FFFF
]line       equ    0
            lup    8
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
            sta:   {]line*SPRITE_PLANE_SPAN}+4,x
            sta:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb
            rts

_EraseTileSprite16x16
            tax
            phb                                   ; Save the bank to switch to the sprite plane

            pei    SpriteBanks
            plb                                   ; pop the data bank (low byte)

]line       equ    0
            lup    16
            stz:   {]line*SPRITE_PLANE_SPAN}+0,x
            stz:   {]line*SPRITE_PLANE_SPAN}+2,x
            stz:   {]line*SPRITE_PLANE_SPAN}+4,x
            stz:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb                                  ; pop the mask bank (high byte)

            lda    #$FFFF
]line       equ    0
            lup    16
            sta:   {]line*SPRITE_PLANE_SPAN}+0,x
            sta:   {]line*SPRITE_PLANE_SPAN}+2,x
            sta:   {]line*SPRITE_PLANE_SPAN}+4,x
            sta:   {]line*SPRITE_PLANE_SPAN}+6,x
]line       equ   ]line+1
            --^

            plb
            rts

            
; First, if there is only one sprite, then we can skip any overhead and do a single lda/and/ora/sta to put the
; sprite data on the screen.
;
; Second, if there are 4 or less, then we "stack" the sprite data using an unrolled loop that allows each
; sprite to just be a single and/ora pair and the final result is not written to any intermediate memory buffer.
;
; Third, if there are 5 or more sprites, then we assume that the sprites are "dense" and that there will be a
; non-trivial amount of overdraw.  In this case we do a series of optimized copies of the sprite data *and*
; masks into a direct page buffer in *reverse order*.  Once a mask value becomes zero, then nothing else can
; show through and that value can be skipped.  Once all of the mask values are zero, then the render is terminated
; and the data buffer copied to the final destination.
;
; Note that these rendering algorithms impose a priority ordering on the sprites where lower sprite IDs are drawn
; underneath higher sprite IDs.
RenderActiveSpriteTiles
                 cmp   #0       ; Is there only one active sprite? If so optimise
                 bne   :many

                 ldx   vbuff    ; load the address to the (adjusted) sprite tile
                 lda   TileStore+TS_SCREEN_ADDR,y
                 tay

                 lda   tiledata+0,y
                 andl  spritemask,x
                 oral  spritedata,x
                 sta   00,s

                 lda   tiledata+2,y
                 andl  spritemask+2,x
                 oral  spritedata+2,x
                 sta   02,s

                 ...
                 tsc
                 adc   #320
                 tcs
                 ...

                 lda   tiledata+{line*4},y
                 andl  spritemask+{line*SPAN},x
                 oral  spritedata+{line*SPAN},x
                 sta   160,s

                 lda   tiledata+{line*4}+2,y
                 andl  spritemask+{line*SPAN}+2,x
                 oral  spritedata+{line*SPAN}+2,x
                 sta   162,s

                 rts


:many
                 lda   TileStore+TS_SCREEN_ADDR,y
                 tcs
                 lda   TileStore+TS_TILE_ADDR,y
                 tay

                 ldx   count
                 jmp   (:arr,x)
                 lda   tiledata+0,y
                 ldx   vbuff
                 andl  spritemask,x
                 oral  spritedata,x
                 ldx   vbuff+2
                 andl  spritemask,x
                 oral  spritedata,x
                 ldx   vbuff+4
                 andl  spritemask,x
                 oral  spritedata,x
                 ...
                 sta   00,s

                 ldx   count
                 jmp   (:arr,x)
                 lda   tiledata+0,y
                 ldx   vbuff
                 andl  spritemask,x
                 oral  spritedata,x
                 ldx   vbuff+2
                 andl  spritemask,x
                 oral  spritedata,x
                 ldx   vbuff+4
                 andl  spritemask,x
                 oral  spritedata,x
                 ...
                 sta   02,s

                 sta   160,s

                 sta   162,s

                 tsc
                 adc   #320