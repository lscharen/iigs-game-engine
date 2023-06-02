; Compile a stamp into a compilation cache
;
; A = vbuff address
; X = width (in bytes)
; Y = height (in scanlines)

_CompileStamp
:lines       equ    tmp0
:sprwidth    equ    tmp1
:cntwidth    equ    tmp2
:baseAddr    equ    tmp3
:destAddr    equ    tmp4
:vbuffAddr   equ    tmp5
:rtnval      equ    tmp6

LDA_IND_LONG_IDX equ $B7
LDA_IMM_OPCODE   equ $A9
LDA_ABS_X_OPCODE equ $BD
AND_IMM_OPCODE   equ $29
ORA_IMM_OPCODE   equ $09
STA_ABS_X_OPCODE equ $9D
STZ_ABS_X_OPCODE equ $9E
RTL_OPCODE       equ $6B

            sta    :vbuffAddr
            sty    :lines
            txa
            lsr
            sta    :sprwidth

; Get ready to build the sprite

            ldy    CompileBankTop                   ; First free byte in the compilation bank
            sty    :rtnval                          ; Save it as the return value

            phb
            pei    CompileBank
            plb                                     ; Set the bank to the compilation cache

            stz    :baseAddr
            stz    :destAddr

:oloop
            lda    :sprwidth
            sta    :cntwidth
            ldx    :vbuffAddr

:iloop
            ldal   spritemask,x
            beq    :no_mask                         ; If Mask == $0000, then it's a solid word
            cmp    #$FFFF
            beq    :next                            ; If Mask == $FFFF, then it's transparent

; Mask with the screen data
            lda    #LDA_ABS_X_OPCODE
            sta:   0,y
            lda    :destAddr
            sta:   1,y
            lda    #AND_IMM_OPCODE
            sta:   3,y
            ldal   spritemask,x
            sta:   4,y
            lda    #ORA_IMM_OPCODE
            sta:   6,y
            ldal   spritedata,x
            sta:   7,y
            lda    #STA_ABS_X_OPCODE
            sta:   9,y
            lda    :destAddr
            sta:   10,y

            tya
            clc
            adc    #12
            tay
            bra    :next

; Just store the data
:no_mask    lda    #LDA_IMM_OPCODE
            sta:   0,y
            ldal   spritedata,x
            beq    :zero
            sta:   1,y

            lda    #STA_ABS_X_OPCODE
            sta:   3,y
            lda    :destAddr
            sta:   4,y

            tya
            clc
            adc    #6
            tay
            bra    :next

:zero       lda    #STZ_ABS_X_OPCODE
            sta:   0,y
            lda    :destAddr
            sta:   1,y

            iny
            iny
            iny

:next
            inx
            inx

            inc    :destAddr                         ; Move to the next word
            inc    :destAddr

            dec    :cntwidth
            bne    :iloop

            lda    :vbuffAddr
            clc
            adc    #SPRITE_PLANE_SPAN
            sta    :vbuffAddr

            lda    :baseAddr                         ; Move to the next line
            clc
            adc    #160
            sta    :baseAddr
            sta    :destAddr

            dec    :lines
            beq    :out
            brl    :oloop

:out
            lda    #RTL_OPCODE                      ; Finish up the subroutine
            sta:   0,y
            iny
            sty    CompileBankTop

            plb
            plb
            lda    :rtnval                          ; Address in the compile memory
            rts

; 4 palettes for the sprite data.  Converts 4 pixels at a time from 0000 0000w wxxy yzz0 -> gggg hhhh iiii jjjj
; each swizzle table is 512 bytes long, 2048 bytes for all four.  They need to be prec

; Draw a tile directly to the graphics screen as a sprite
;
; Y = screen address
; X = tile address
; A = $0001 = ignore mask
;   = $0080 = vflip
;   = $0600 = palette select

_DrawTileToScreenX
            rtl

            phb
            phd                                    ; Save the curren direct page and bank

            ldal  tool_direct_page                 ; Can't assume where we are
            clc
            adc   #$100                            ; Sprite space is on the second page
            tcd

            pei   DP2_TILEDATA_AND_BANK01_BANKS    ; Push the two bank we need
            plb                                    ; Pop off the tile data bank

;            lda   #W11_S0
;            stz   SwizzlePtr
;            lda   #^W11_S0
;            sta   SwizzlePtr+2

]line       equ   0
            lup   8
            ldy   tiledata+{]line*4}+2,x           ; load the 8-bit NES tile data
;            lda   [SwizzlePtr],y                   ; lookup the swizzle value
;            db    LDA_IND_LONG_IDX,SwizzlePtr
;            lda   tiledata+{]line*4}+2,x
            sta   tmp_sprite_data+{]line*4}+2

            ldy   tiledata+{]line*4},x             ; load the 8-bit NES tile data
;            lda   [SwizzlePtr],y                   ; lookup the swizzle value
;            db    LDA_IND_LONG_IDX,SwizzlePtr
;            lda   tiledata+{]line*4},x
            sta   tmp_sprite_data+{]line*4}
]line       equ   ]line+1
            --^

            plb                                    ; Pop off bank 01

]line       equ   0
            lup   8
            ldal  tiledata+{]line*4}+32+2,x
            eor   #$FFFF
            and:  {]line*SHR_LINE_WIDTH}+2,y
            ora   tmp_sprite_data+{]line*4}+2
            sta:  {]line*SHR_LINE_WIDTH}+2,y

            ldal  tiledata+{]line*4}+32,x
            eor   #$FFFF
            and:  {]line*SHR_LINE_WIDTH},y
            ora   tmp_sprite_data+{]line*4}
            sta:  {]line*SHR_LINE_WIDTH},y
]line       equ   ]line+1
            --^

; Restore the direct page and bank

            pld
            plb
            rtl

pal_select  dw    $3333,$6666,$9999,$CCCC

_DrawTileToScreen
:palette    equ    248

            phb
            pea    $0101
            plb
            plb

            bit    #$0040
            beq    :no_prio
            bit    #$0100
            jeq    _DrawPriorityToScreen
            jmp    _DrawPriorityToScreenV

:no_prio
            bit    #$0100
            jne    _DrawTileToScreenV

            phx
            and    #$0006
            tax
            ldal   pal_select,x
            sta    :palette
            plx
            clc

]line       equ   0
            lup   8
            ldal  tiledata+{]line*4}+2,x
            adc   :palette
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            andl  tiledata+{]line*4}+32+2,x
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            sta:  {]line*SHR_LINE_WIDTH}+2,y

            ldal  tiledata+{]line*4},x
            adc   :palette
            eor:  {]line*SHR_LINE_WIDTH},y
            andl  tiledata+{]line*4}+32,x
            eor:  {]line*SHR_LINE_WIDTH},y
            sta:  {]line*SHR_LINE_WIDTH},y
]line       equ   ]line+1
            --^
            plb
            rtl                          ; special exit

_DrawPriorityToScreen
:palette    equ    248
:p_tmp      equ    144

            phx
            and    #$0006
            tax
            ldal   pal_select,x
            sta    :palette
            plx
            clc

]line       equ   0
            lup   8
            ldal  tiledata+{]line*4}+2,x
            adc   :palette
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            sta   :p_tmp

; Convert the screen data to a mask.  Zero in screen = zero in mask, else $F
            lda:  {]line*SHR_LINE_WIDTH}+2,y
            bit   #$F000
            beq   *+5
            ora   #$F000
            bit   #$0F00
            beq   *+5
            ora   #$0F00
            bit   #$00F0
            beq   *+5
            ora   #$00F0
            bit   #$000F
            beq   *+5
            ora   #$000F
            eor   #$FFFF
            and   :p_tmp
            andl  tiledata+{]line*4}+32+2,x
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            sta:  {]line*SHR_LINE_WIDTH}+2,y

            ldal  tiledata+{]line*4},x
            adc   :palette
            eor:  {]line*SHR_LINE_WIDTH},y
            sta   :p_tmp

            lda:  {]line*SHR_LINE_WIDTH},y
            bit   #$F000
            beq   *+5
            ora   #$F000
            bit   #$0F00
            beq   *+5
            ora   #$0F00
            bit   #$00F0
            beq   *+5
            ora   #$00F0
            bit   #$000F
            beq   *+5
            ora   #$000F
            eor   #$FFFF
            and   :p_tmp
            andl  tiledata+{]line*4}+32,x
            eor:  {]line*SHR_LINE_WIDTH},y
            sta:  {]line*SHR_LINE_WIDTH},y
]line       equ   ]line+1
            --^
            plb
            rtl                          ; special exit
            
_DrawTileToScreenV
:palette    equ    248
            phx
            and    #$0006
            tax
            ldal   pal_select,x
            sta    :palette
            plx
            clc

]line       equ   0
            lup   8
            ldal  tiledata+{{7-]line}*4}+2,x
            eor   :palette
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            andl  tiledata+{{7-]line}*4}+32+2,x
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            sta:  {]line*SHR_LINE_WIDTH}+2,y

            ldal  tiledata+{{7-]line}*4},x
            eor   :palette
            eor:  {]line*SHR_LINE_WIDTH},y
            andl  tiledata+{{7-]line}*4}+32,x
            eor:  {]line*SHR_LINE_WIDTH},y
            sta:  {]line*SHR_LINE_WIDTH},y
]line       equ   ]line+1
            --^
            plb
            rtl                          ; special exit

_DrawPriorityToScreenV
:palette    equ    248
:p_tmp      equ    144

            phx
            and    #$0006
            tax
            ldal   pal_select,x
            sta    :palette
            plx
            clc

]line       equ   0
            lup   8
            ldal  tiledata+{{7-]line}*4}+2,x
            adc   :palette
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            sta   :p_tmp

; Convert the screen data to a mask
            lda:  {]line*SHR_LINE_WIDTH}+2,y
            bit   #$F000
            beq   *+5
            ora   #$F000
            bit   #$0F00
            beq   *+5
            ora   #$0F00
            bit   #$00F0
            beq   *+5
            ora   #$00F0
            bit   #$000F
            beq   *+5
            ora   #$000F
            eor   #$FFFF
            and   :p_tmp
            andl  tiledata+{{7-]line}*4}+32+2,x
            eor:  {]line*SHR_LINE_WIDTH}+2,y
            sta:  {]line*SHR_LINE_WIDTH}+2,y

            ldal  tiledata+{{7-]line}*4},x
            adc   :palette
            eor:  {]line*SHR_LINE_WIDTH},y
            sta   :p_tmp

            lda:  {]line*SHR_LINE_WIDTH},y
            bit   #$F000
            beq   *+5
            ora   #$F000
            bit   #$0F00
            beq   *+5
            ora   #$0F00
            bit   #$00F0
            beq   *+5
            ora   #$00F0
            bit   #$000F
            beq   *+5
            ora   #$000F
            eor   #$FFFF
            and   :p_tmp
            andl  tiledata+{{7-]line}*4}+32,x
            eor:  {]line*SHR_LINE_WIDTH},y
            sta:  {]line*SHR_LINE_WIDTH},y
]line       equ   ]line+1
            --^
            plb
            rtl                          ; special exit

; Draw a sprite directly to the graphics screen. If sprite is clipped at all, do not draw.
;
; X = sprite record index
_DSTSOut
             rts

_DrawStampToScreen
             lda    _Sprites+IS_OFF_SCREEN,x        ; If the sprite is off-screen, don't draw it
             bne    _DSTSOut

             lda    _Sprites+SPRITE_ID,x            ; If the sprite is hidden or an overlay, don't draw it
             bit    #SPRITE_OVERLAY+SPRITE_HIDE
             bne    _DSTSOut

             lda    _Sprites+SPRITE_CLIP_WIDTH,x    ; If the sprite is clipped to the playfield, don't draw it
             cmp    _Sprites+SPRITE_WIDTH,x
             bne    _DSTSOut
             lda    _Sprites+SPRITE_CLIP_HEIGHT,x
             cmp    _Sprites+SPRITE_HEIGHT,x
             bne    _DSTSOut

             clc
             lda    _Sprites+SPRITE_Y,x
             adc    ScreenY0
             asl
             asl
             asl
             asl
             asl
             sta    tmp0
             asl
             asl
             clc
             adc    tmp0
             clc
             adc    #$2000
             clc
             adc    ScreenX0
             adc    _Sprites+SPRITE_X,x              ; Move to the horizontal address
             tay                                     ; This is the on-screen address

             lda    _Sprites+SPRITE_ID,x          ; If this is a compiled sprite, call the routine in the compilation bank
             bit    #SPRITE_COMPILED
             beq    *+5
             brl    :compiled

             lda    _Sprites+SPRITE_HEIGHT,x
             sta    tmp0

; Sprite is either 8 or 16 pixels wide, so select the entry point
             lda    _Sprites+SPRITE_WIDTH,x
             cmp    #4
             beq    :skinny

             lda    _Sprites+SPRITE_DISP,x           ; This is the VBUFF address with the correct sprite frame
             tax
             phb
             pea    $0101
             plb
             plb
             bra    :entry16
:loop16
             clc
             txa
             adc    #SPRITE_PLANE_SPAN
             tax
             tya
             adc    #SHR_LINE_WIDTH
             tay
:entry16
             lda:   6,y
             andl   spritemask+6,x
             oral   spritedata+6,x
             sta:   6,y
             lda:   4,y
             andl   spritemask+4,x
             oral   spritedata+4,x
             sta:   4,y
             lda:   2,y
             andl   spritemask+2,x
             oral   spritedata+2,x
             sta:   2,y
             lda:   0,y
             andl   spritemask+0,x
             oral   spritedata+0,x
             sta:   0,y

             dec    tmp0
             bne    :loop16

             plb
             rts

:skinny
             lda    _Sprites+SPRITE_DISP,x           ; This is the VBUFF address with the correct sprite frame
             tax
             phb
             pea    $0101
             plb
             plb
             bra    :entry8
:loop8
             clc
             txa
             adc    #SPRITE_PLANE_SPAN
             tax
             tya
             adc    #SHR_LINE_WIDTH
             tay
:entry8
             lda:   2,y
             andl   spritemask+2,x
             oral   spritedata+2,x
             sta:   2,y
             lda:   0,y
             andl   spritemask+0,x
             oral   spritedata+0,x
             sta:   0,y

             dec    tmp0
             bne    :loop8

             plb
             rts

:compiled
            lda    CompileBank-1                 ; Load the bank into the high byte
            stal   :patch+2                      ; Put it into the 3rd address bytes (2nd byte is garbage)
            lda    _Sprites+SPRITE_DISP,x        ; Address in the compile bank
            stal   :patch+1                      ; Set 1st and 2nd address bytes

            tyx                                  ; Put on-screen address in X-register
            phb                                  ; Compiled sprites assume bank register is $01
            pea    $0101
            plb
            plb
:patch      jsl    $000000                       ; Dispatch
            plb
            rts

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
