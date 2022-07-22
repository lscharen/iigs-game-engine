; Alternate entry point that takes arguments in registers instead of using a _Sprite
; record
;
; Y = VBUFF address
; X = Tile Data address
; A = Sprite Flags
DISP_VFLIP   equ    $0004      ; hard code these because they are internal values
DISP_HFLIP   equ    $0002
DISP_MASK    equ    $0018      ; Preserve the size bits

_DrawSpriteStamp
             sty    tmp1
             stx    tmp2
             xba
             and    #DISP_MASK                    ; dispatch to all of the different orientations
             sta    tmp3

             phb
             pea   #^tiledata                     ; Set the bank to the tile data
             plb

; X = sprite ID
; Y = Tile Data
; A = VBUFF address
             ldx    tmp3
             ldy    tmp2
             lda    tmp1
             jsr    _DrawSprite

             lda    tmp3
             ora    #DISP_HFLIP
             tax
             ldy    tmp2
             lda    tmp1
             clc
             adc    #3*4
             jsr    _DrawSprite

             lda    tmp3
             ora    #DISP_VFLIP
             tax
             ldy    tmp2
             lda    tmp1
             clc
             adc    #6*4
             jsr    _DrawSprite

             lda    tmp3
             ora    #DISP_HFLIP+DISP_VFLIP
             tax
             ldy    tmp2
             lda    tmp1
             clc
             adc    #9*4
             jsr    _DrawSprite

; Restore bank
             plb                                  ; pop extra byte
             plb
             rts
; 
; X = _Sprites array offset
_DrawSprite
             jmp   (draw_sprite,x)

draw_sprite  dw    draw_8x8,draw_8x8h,draw_8x8v,draw_8x8hv         ; 8 wide x 8 tall
             dw    draw_8x16,draw_8x16h,draw_8x16v,draw_8x16hv     ; 8 wide x 16 tall
             dw    draw_16x8,draw_16x8h,draw_16x8v,draw_16x8hv     ; 16 wide by 8 tall
             dw    draw_16x16,draw_16x16h,draw_16x16v,draw_16x16hv ; 16 wide by 16 tall

             dw    :rtn,:rtn,:rtn,:rtn           ; hidden bit is set
             dw    :rtn,:rtn,:rtn,:rtn
             dw    :rtn,:rtn,:rtn,:rtn
             dw    :rtn,:rtn,:rtn,:rtn
:rtn         rts

draw_8x8
             tax
             jmp   _DrawTile8x8

draw_8x8h
             tax
             clc
             tya
             adc   #64
             tay
             jmp   _DrawTile8x8

draw_8x8v
             tax
             jmp   _DrawTile8x8V

draw_8x8hv
             tax
             clc
             tya
             adc   #64
             tay
             jmp   _DrawTile8x8V

draw_8x16
             tax
             jsr   _DrawTile8x8
             clc
             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             tya
             adc   #{128*32}                      ; 32 tiles to the next vertical one, each tile is 128 bytes
             tay
             jmp   _DrawTile8x8

draw_8x16h
             tax
             clc
             tya
             adc   #64
             tay
             jsr   _DrawTile8x8
             clc
             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             tya
             adc   #{128*32}                      ; 32 tiles to the next vertical one, each tile is 128 bytes
             tay
             jmp   _DrawTile8x8

draw_8x16v
             clc
             tax
             tya
             pha
             adc   #{128*32}
             tay
             jsr   _DrawTile8x8V
             clc
             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             ply
             jmp   _DrawTile8x8V

draw_8x16hv
             clc
             tax
             tya
             adc   #64
             pha
             adc   #{128*32}
             tay
             jsr   _DrawTile8x8V
             clc
             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             ply
             jmp   _DrawTile8x8V

draw_16x8
             tax
             jsr   _DrawTile8x8
             clc
             txa
             adc   #4
             tax
             tya
             adc   #128                           ; Next tile is 128 bytes away
             tay
             jmp   _DrawTile8x8

draw_16x8h
             clc
             tax
             tya
             adc   #64
             pha
             adc   #128
             tay
             jsr   _DrawTile8x8
             txa
             adc   #4
             tax
             ply
             jmp   _DrawTile8x8

draw_16x8v
             tax
             jsr   _DrawTile8x8V
             clc
             txa
             adc   #4
             tax
             tya
             adc   #128
             tay
             jmp   _DrawTile8x8V

draw_16x8hv
             clc
             tax
             tya
             adc   #64
             pha
             adc   #128
             tay
             jsr   _DrawTile8x8V
             txa
             adc   #4
             tax
             ply
             jmp   _DrawTile8x8V

; X = sprite ID
; Y = Tile Data
; A = VBUFF address
draw_16x16
             clc
             tax
             jsr   _DrawTile8x8
             txa
             adc   #4
             tax
             tya
             adc   #128
             tay
             jsr   _DrawTile8x8
             txa
             adc   #{8*SPRITE_PLANE_SPAN}-4
             tax
             tya
             adc    #{128*{32-1}}
             tay
             jsr   _DrawTile8x8
             txa
             adc   #4
             tax
             tya
             adc   #128
             tay
             jmp   _DrawTile8x8

draw_16x16h
             clc
             tax
             tya
             adc   #64
             pha
             adc   #128
             tay
             jsr   _DrawTile8x8

             txa
             adc   #4
             tax
             ply
             jsr   _DrawTile8x8

             txa
             adc   #{8*SPRITE_PLANE_SPAN}-4
             tax
             tya
             adc    #{128*32}
             pha
             adc    #128
             tay
             jsr   _DrawTile8x8

             txa
             adc   #4
             tax
             ply
             jmp   _DrawTile8x8

draw_16x16v
             clc
             tax
             tya
             pha                                        ; store some copies
             phx
             pha
             adc   #{128*32}
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             ply
             jsr   _DrawTile8x8V

             pla
             adc   #4
             tax
             lda   1,s
             adc   #{128*{32+1}}
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #{8*SPRITE_PLANE_SPAN}
             tax
             pla
             adc   #128
             tay
             jmp   _DrawTile8x8V

draw_16x16hv
             clc
             tax
             tya
             pha
             adc   #{128*{32+1}}+64                        ; Bottom-right source to top-left 
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #4
             tax
             lda   1,s
             adc   #{128*32}+64
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #{8*SPRITE_PLANE_SPAN}-4
             tax
             lda    1,s
             adc    #128+64
             tay
             jsr   _DrawTile8x8V

             txa
             adc   #4
             tax
             pla
             adc   #64
             tay
             jmp   _DrawTile8x8V


; X = sprite vbuff address
; Y = tile data pointer
_DrawTile8x8
_CopyTile8x8
]line       equ   0
            lup   8
            lda:  tiledata+32+{]line*4},y
            stal  spritemask+{]line*SPRITE_PLANE_SPAN},x
            lda:  tiledata+{]line*4},y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN},x

            lda:  tiledata+32+{]line*4}+2,y
            stal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            lda:  tiledata+{]line*4}+2,y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^
            rts

_DrawTile8x8V
_CopyTile8x8V
]line       equ   0
            lup   8
            lda:  tiledata+32+{{7-]line}*4},y
            stal  spritemask+{]line*SPRITE_PLANE_SPAN},x
            lda:  tiledata+{{7-]line}*4},y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN},x

            lda:  tiledata+32+{{7-]line}*4}+2,y
            stal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            lda:  tiledata+{{7-]line}*4}+2,y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^
            rts
