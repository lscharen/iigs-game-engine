; Collection of functions that deal with tiles.  Primarily rendering tile data into
; the code fields.
;
; Tile data can be done faily often, so these routines are performance-sensitive.
;
; CopyTileConst -- the first 16 tile numbers are reserved and can be used
;                  to draw a solid tile block
; CopyTileLinear -- copies the tile data from the tile bank in linear order, e.g.
;                   32 consecutive bytes are copied

; _RenderTile
;
; A high-level function that takes a 16-bit tile descriptor and dispatched to the
; appropriate tile copy routine based on the descriptor flags
;
; Bit  15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
;     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
;     |xx|xx|FF|MM|DD|VV|HH|  |  |  |  |  |  |  |  |  |
;     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
;      \____/ |  |  |  |  | \________________________/
;        |    |  |  |  |  |      Tile ID (0 to 511)
;        |    |  |  |  |  |
;        |    |  |  |  |  +-- H : Flip tile horizontally
;        |    |  |  |  +----- V : Flip tile vertically
;        |    |  |  +-------- D : Render as a Dynamic Tile (Tile ID < 32, V and H have no effect)
;        |    |  +----------- M : Apply tile mask
;        |    +-------------- F : Overlay a fringe tile
;        +------------------- Reserved (must be zero)
;
; Each logical tile (corresponding to each Tile ID) actually takes up 128 bytes of memory in the
; tile bank
;
; +0  : 32 bytes of tile data
; +32 : 32 bytes of tile mask
; +64 : 32 bytes of horizontally flipped tile data
; +96 : 32 bytes of horizontally flipped tile mask
;
; It is simply too slow to try to horizontally reverse the pixel data on the fly.  This still allows
; for up to 512 tiles to be stored in a single bank, which should be sufficient.

TILE_CTRL_MASK    equ             $FE00
TILE_PROC_MASK    equ             $F800                  ; Select tile proc for rendering

; Low-level function to take a tile descriptor and return the address in the tiledata
; bank.  This is not too useful in the fast-path because the fast-path does more
; incremental calculations, but it is handy for other utility functions
;
; A = tile descriptor
;
; The address is the TileID * 128 + (HFLIP * 64)
GetTileAddr      ENT
                 jsr             _GetTileAddr
                 rtl
_GetTileAddr
                 asl                                               ; Multiply by 2
                 bit             #2*TILE_HFLIP_BIT                 ; Check if the horizontal flip bit is set
                 beq             :no_flip
                 inc                                               ; Set the LSB
:no_flip         asl                                               ; x4
                 asl                                               ; x8
                 asl                                               ; x16
                 asl                                               ; x32
                 asl                                               ; x64
                 asl                                               ; x128
                 rts

; Ignore the horizontal flip bit
_GetBaseTileAddr
                 asl                                               ; Multiply by 2
                 asl                                               ; x4
                 asl                                               ; x8
                 asl                                               ; x16
                 asl                                               ; x32
                 asl                                               ; x64
                 asl                                               ; x128
                 rts
                 
; On entry
;
; B is set to the correct BG1 data bank
; A is set to the the tile descriptor
; Y is set to the top-left address of the tile in the BG1 data bank
;
; tmp0/tmp1 is reserved 
_RenderTileBG1
                 pha                                               ; Save the tile descriptor

                 and             #TILE_VFLIP_BIT+TILE_HFLIP_BIT    ; Only horizontal and vertical flips are supported for BG1
                 xba
                 tax
                 ldal            :actions,x
                 stal            :tiledisp+1

                 pla
                 and             #TILE_ID_MASK                     ; Mask out the ID and save just that
                 _Mul128                                           ; multiplied by 128
                 tax
:tiledisp        jmp             $0000

:actions         dw              _TBSolidBG1_00,_TBSolidBG1_0H,_TBSolidBG1_V0,_TBSolidBG1_VH

; Given an address to a Tile Store record, dispatch to the appropriate tile renderer.  The Tile
; Store record contains all of the low-level information that's needed to call the renderer.
;
; There are two execution paths that are handled here.  First, if there is no sprite, then
; the tile data is read directly and written into the code field in a single pass. If there
; are sprites that overlap the tile, then the sprite data is combined with the tile data
; and written to a temporary direct page buffer.  If 
;
; This routine sets the direct page register to the second page since we use that space to 
; build and cache tile and sprite data, when necessary

_RenderTile2
                 lda   TileStore+TS_SPRITE_FLAG,x     ; This is a bitfield of all the sprites that intersect this tile, only care if non-zero or not
                 bne   do_dirty_sprite

; Handle the non-sprite tile blit

                 sep   #$20
                 lda   TileStore+TS_CODE_ADDR_HIGH,x  ; load the bank of the target code field line
                 pha                                  ; and put on the stack for later

                 lda   TileStore+TS_BASE_ADDR+1,x     ; load the base address of the code field ($0000 or $8000)
                 sta   _BASE_ADDR+1                   ; so we can get by just copying the high byte
                 rep   #$20

                 lda   TileStore+TS_BASE_TILE_DISP,x  ; Get the address of the renderer for this tile
                 stal  :tiledisp+1

                 lda   TileStore+TS_TILE_ID,x
                 sta   _TILE_ID                       ; Some tile blitters need to get the tile descriptor

                 ldy   TileStore+TS_CODE_ADDR_LOW,x   ; load the address of the code field
                 lda   TileStore+TS_TILE_ADDR,x       ; load the address of this tile's data (pre-calculated)
                 pha

                 lda   TileStore+TS_WORD_OFFSET,x
                 plx
                 plb                                  ; set the bank to the code field that will be updated

; B is set to the correct code field bank
; A is set to the tile word offset (0 through 80 in steps of 4)
; Y is set to the top-left address of the tile in the code field
; X is set to the address of the tile data

:tiledisp        jmp   $0000                          ; render the tile

; Let's make a macro helper for the bit test tree
;                dobit   src_offset,dest,next_target,end_target
dobit            MAC
                 beq   last_bit
                 ldx:  ]1,y
                 stx   ]2
                 jmp   ]3
last_bit         ldx:  ]1,y
                 stx   ]2
                 jmp   ]4
                 EOM

; The sprite code is just responsible for quickly copying all of the sprite data
; into the direct page temp area.

do_dirty_sprite
                 pei   TileStoreBankAndTileDataBank   ; Special value that has the TileStore bank in LSB and TileData bank in MSB
                 plb

; Cache a couple of values into the direct page that are used across all copy routines

                 lda   TileStore+TS_TILE_ADDR,y       ; load the address of this tile's data (pre-calculated)
                 sta   tileAddr

                 ldx   TileStore+TS_VBUFF_ADDR_COUNT,y
                 jmp   (dirty_sprite_dispatch,x)
dirty_sprite_dispatch
                 da    CopyNoSprites
                 da    CopyOneSprite
                 da    CopyTwoSprites
                 da    CopyThreeSprites
                 da    CopyFourSprites                     ; MAX, don't bother with more than 4 sprites per tile

; This is very similar to the code in the dirty tile renderer, but we can't reuse 
; because that code draws directly to the graphics screen, and this code draws
; to a temporary budder that has a different stride.

                 ldy   TileStore+TS_VBUFF_ARRAY_ADDR,x     ; base address of the VBUFF sprite address array for this tile

                 lsr
                 bcc   :loop_0_bit_1
                 dobit $0000;sprite_ptr0;:loop_1_bit_1;CopyOneSprite

:loop_0_bit_1    lsr
                 bcc   :loop_0_bit_2
                 dobit $0002;sprite_ptr0;:loop_1_bit_2;CopyOneSprite

:loop_0_bit_2    lsr
                 bcc   :loop_0_bit_3
                 dobit $0004;sprite_ptr0;:loop_1_bit_3;CopyOneSprite

:loop_0_bit_3    lsr
                 bcc   :loop_0_bit_4
                 dobit $0006;sprite_ptr0;:loop_1_bit_4;CopyOneSprite

:loop_0_bit_4    lsr
                 bcc   :loop_0_bit_5
                 dobit $0008;sprite_ptr0;:loop_1_bit_5;CopyOneSprite

:loop_0_bit_5    lsr
                 bcc   :loop_0_bit_6
                 dobit $000A;sprite_ptr0;:loop_1_bit_6;CopyOneSprite

:loop_0_bit_6    lsr
                 bcc   :loop_0_bit_7
                 dobit $000C;sprite_ptr0;:loop_1_bit_7;CopyOneSprite

:loop_0_bit_7    lsr
                 bcc   :loop_0_bit_8
                 dobit $000E;sprite_ptr0;:loop_1_bit_8;CopyOneSprite

:loop_0_bit_8    lsr
                 bcc   :loop_0_bit_9
                 dobit $0010;sprite_ptr0;:loop_1_bit_9;CopyOneSprite

:loop_0_bit_9    lsr
                 bcc   :loop_0_bit_10
                 ldx:  $0012,y
                 stx   spriteIdx
                 cmp   #0
                 jne   :loop_1_bit_10
                 jmp   CopyOneSprite

:loop_0_bit_10   lsr
                 bcc   :loop_0_bit_11
                 dobit $0014;sprite_ptr0;:loop_1_bit_11;CopyOneSprite

:loop_0_bit_11   lsr
                 bcc   :loop_0_bit_12
                 dobit $0016;sprite_ptr0;:loop_1_bit_12;CopyOneSprite

:loop_0_bit_12   lsr
                 bcc   :loop_0_bit_13
                 dobit $0018;sprite_ptr0;:loop_1_bit_13;CopyOneSprite

:loop_0_bit_13   lsr
                 bcc   :loop_0_bit_14
                 dobit $001A;sprite_ptr0;:loop_1_bit_14;CopyOneSprite

:loop_0_bit_14   lsr
                 bcc   :loop_0_bit_15
                 dobit $001C;sprite_ptr0;:loop_1_bit_15;CopyOneSprite

:loop_0_bit_15   ldx:  $001E,y
                 stx   spriteIdx
                 jmp   CopyOneSprite

; We can optimize later, for now just copy the sprite data and mask into its own
; direct page buffer and combine with the tile data later

; We set up direct page pointers to the mask bank and use the bank register for the
; data.
CopyFourSprites
                 lda   TileStore+TS_VBUFF_ADDR_0,y
                 sta   spriteIdx
                 lda   TileStore+TS_VBUFF_ADDR_1,y
                 sta   spriteIdx+4
                 lda   TileStore+TS_VBUFF_ADDR_2,y
                 sta   spriteIdx+8
                 lda   TileStore+TS_VBUFF_ADDR_3,y
                 sta   spriteIdx+12

; Copy three sprites into a temporary direct page buffer
LDA_IL           equ   $A7    ; lda [dp]
LDA_ILY          equ   $B7    ; lda [dp],y
AND_IL           equ   $27    ; and [dp]
AND_ILY          equ   $37    ; and [dp],y

CopyThreeSprites
                 lda   TileStore+TS_VBUFF_ADDR_0,y
                 sta   spriteIdx
                 lda   TileStore+TS_VBUFF_ADDR_1,y
                 sta   spriteIdx+4
                 lda   TileStore+TS_VBUFF_ADDR_2,y
                 sta   spriteIdx+8

]line            equ   0
                 lup   8
                 ldy   #]line*SPRITE_PLANE_SPAN
                 lda   (spriteIdx+8),y
                 db    AND_ILY,spriteIdx+4            ; Can't use long indirect inside LUP because of ']'
                 ora   (spriteIdx+4),y
                 db    AND_ILY,spriteIdx+0
                 ora   (spriteIdx+0),y
                 sta   tmp_sprite_data+{]line*4}

                 db    LDA_ILY,spriteIdx+8
                 db    AND_ILY,spriteIdx+4
                 db    AND_ILY,spriteIdx+0
                 sta   tmp_sprite_mask+{]line*4}

                 ldy   #]line*SPRITE_PLANE_SPAN+2
                 lda   (spriteIdx+8),y
                 db    AND_ILY,spriteIdx+4 
                 ora   (spriteIdx+4),y
                 db    AND_ILY,spriteIdx+0
                 ora   (spriteIdx+0),y
                 sta   tmp_sprite_data+{]line*4}+2

                 db    LDA_ILY,spriteIdx+8
                 db    AND_ILY,spriteIdx+4
                 db    AND_ILY,spriteIdx+0
                 sta   tmp_sprite_mask+{]line*4}+2
]line            equ   ]line+1
                 --^
;                 jmp   FinishTile

; Copy two sprites into a temporary direct page buffer
CopyTwoSprites
                 lda   TileStore+TS_VBUFF_ADDR_0,y
                 sta   spriteIdx
                 lda   TileStore+TS_VBUFF_ADDR_1,y
                 sta   spriteIdx+4

]line            equ   0
                 lup   8
                 ldy   #]line*SPRITE_PLANE_SPAN
                 lda   (spriteIdx+4),y
                 db    AND_ILY,spriteIdx+0
                 ora   (spriteIdx+0),y
                 sta   tmp_sprite_data+{]line*4}

                 db    LDA_ILY,spriteIdx+4
                 db    AND_ILY,spriteIdx+0
                 sta   tmp_sprite_mask+{]line*4}

                 ldy   #]line*SPRITE_PLANE_SPAN+2
                 lda   (spriteIdx+4),y
                 db    AND_ILY,spriteIdx+0
                 ora   (spriteIdx+0),y
                 sta   tmp_sprite_data+{]line*4}+2

                 db    LDA_ILY,spriteIdx+4
                 db    AND_ILY,spriteIdx+0
                 sta   tmp_sprite_mask+{]line*4}+2
]line            equ   ]line+1
                 --^
;                 jmp   FinishTile

; Copy a single piece of sprite data into a temporary direct page . X = spriteIdx
;
; X register is the offset of the underlying tile data
; Y register is the line offset into the sprite data and mask buffers
; There is a pointer for each sprite on the direct page that can be used
; to access both the data and mask components of a sprite
; The Data Bank reigster points to the sprite data
;
;    ldal   tiledata,x
;    and    [spriteIdx],y
;    ora    (spriteIdx),y
;    sta    tmp_sprite_data
;
; For multiple sprites, we can chain together the and/ora instructions to stack the sprites
;
;    ldal   tiledata,x
;    and    [spriteIdx],y
;    ora    (spriteIdx),y
;    and    [spriteIdx+4],y
;    ora    (spriteIdx+4),y
;    and    [spriteIdx+8],y
;    ora    (spriteIdx+8),y
;    sta    tmp_sprite_data
;
; When the sprites need to be drawn on top of the background, then change the order of operations
;
;    lda    (spriteIdx),y
;    and    [spriteIdx+4],y
;    ora    (spriteIdx+4),y
;    and    [spriteIdx+8],y
;    ora    (spriteIdx+8),y
;    sta    tmp_sprite_data
;    andl   tiledata+32,x
;    oral   tiledata,x
;
CopyOneSprite
                 clc
                 lda   TileStore+TS_VBUFF_ADDR_0,y
                 sta   spriteIdx
                 adc   #2
                 sta   spriteIdx+4

]line            equ   0
                 lup   8
                 ldal  tiledata,x
                 and   [spriteIdx]
                 ora   (spriteIdx)
                 sta   tmp_sprite_data+{]line*4}



                 ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
                 sta   tmp_sprite_data+{]line*4}
                 ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta   tmp_sprite_data+{]line*4}+2

                 ldal  spritemask+{]line*SPRITE_PLANE_SPAN},x
                 sta   tmp_sprite_mask+{]line*4}
                 ldal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
                 sta   tmp_sprite_mask+{]line*4}+2
]line            equ   ]line+1
                 --^

;                 jmp   FinishTile

; Reference all of the tile rendering subroutines defined in the TileXXXXX files.  Each file defines
; 8 entry points:
;
; One set for normal, horizontally flipped, vertically flipped and hors & vert flipped.
; A second set that are optimized for when EngineMode has BG1 disabled.
TileProcs        dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 00000 : normal tiles
                 dw     _TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00  ; 00001 : dynamic tiles
                 dw     _TBMaskedTile_00,_TBMaskedTile_0H,_TBMaskedTile_V0,_TBMaskedTile_VH      ; 00010 : masked normal tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00                              ; 00011 : masked dynamic tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00

; Fringe tiles not supported yet, so just repeat the block from above
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 00100 : fringed normal tiles
                 dw     _TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00  ; 00101 : fringed dynamic tiles
                 dw     _TBMaskedTile_00,_TBMaskedTile_0H,_TBMaskedTile_V0,_TBMaskedTile_VH      ; 00110 : fringed masked normal tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00                              ; 00111 : fringed masked dynamic tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00

; High-priority tiles without a sprite in front of them are just normal tiles.  Repeat the top half
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 01000 : high-priority normal tiles
                 dw     _TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00  ; 01001 : high-priority dynamic tiles
                 dw     _TBMaskedTile_00,_TBMaskedTile_0H,_TBMaskedTile_V0,_TBMaskedTile_VH      ; 01010 : high-priority masked normal tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00                              ; 01011 : high-priority masked dynamic tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00

                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 01100 : high-priority fringed normal tiles
                 dw     _TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00,_TBDynamicTile_00  ; 01101 : high-priority fringed dynamic tiles
                 dw     _TBMaskedTile_00,_TBMaskedTile_0H,_TBMaskedTile_V0,_TBMaskedTile_VH      ; 01110 : high-priority fringed masked normal tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00                              ; 01111 : high-priority fringed masked dynamic tiles
                 dw     _TBDynamicMaskTile_00,_TBDynamicMaskTile_00

; Here are all the sprite variants of the tiles
                 dw     _TBSolidSpriteTile_00,_TBSolidSpriteTile_0H
                 dw     _TBSolidSpriteTile_V0,_TBSolidSpriteTile_VH                              ; 10000 : normal tiles w/sprite
                 dw     _TBDynamicSpriteTile_00,_TBDynamicSpriteTile_00
                 dw     _TBDynamicSpriteTile_00,_TBDynamicSpriteTile_00                          ; 10001 : dynamic tiles w/sprite
                 dw     _TBMaskedSpriteTile_00,_TBMaskedSpriteTile_0H
                 dw     _TBMaskedSpriteTile_V0,_TBMaskedSpriteTile_VH                            ; 10010 : masked normal tiles w/sprite
                 dw     _TBDynamicMaskedSpriteTile_00,_TBDynamicMaskedSpriteTile_00
                 dw     _TBDynamicMaskedSpriteTile_00,_TBDynamicMaskedSpriteTile_00              ; 10011 : masked dynamic tiles w/sprite

                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 10100 : fringed normal tiles w/sprite
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 10101 : fringed dynamic tiles w/sprite
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 10110 : fringed masked normal tiles w/sprite
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 10111 : fringed masked dynamic tiles w/sprite

                 dw     _TBSolidPrioritySpriteTile_00,_TBSolidPrioritySpriteTile_0H,
                 dw     _TBSolidPrioritySpriteTile_V0,_TBSolidPrioritySpriteTile_VH              ; 11000 : high-priority normal tiles w/sprite
                 dw     _TBDynamicPrioritySpriteTile_00,_TBDynamicPrioritySpriteTile_00
                 dw     _TBDynamicPrioritySpriteTile_00,_TBDynamicPrioritySpriteTile_00          ; 11001 : high-priority dynamic tiles w/sprite
                 dw     _TBMaskedPrioritySpriteTile_00,_TBMaskedPrioritySpriteTile_0H
                 dw     _TBMaskedPrioritySpriteTile_V0,_TBMaskedPrioritySpriteTile_VH            ; 11010 : high-priority masked normal tiles w/sprite
                 dw     _TBDynamicMaskedPrioritySpriteTile_00,_TBDynamicMaskedPrioritySpriteTile_00
                 dw     _TBDynamicMaskedPrioritySpriteTile_00,_TBDynamicMaskedPrioritySpriteTile_00 ; 11011 : high-priority masked dynamic tiles w/sprite

                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 11100 : high-priority fringed normal tiles w/sprite
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 11101 : high-priority fringed dynamic tiles w/sprite
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 11110 : high-priority fringed masked normal tiles w/sprite
                 dw     _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH          ; 11111 : high-priority fringed masked dynamic tiles w/sprite

; _TBConstTile
;
; A specialized routine that fills in a tile with a single constant value.  It's intended to be used to
; fill in solid colors, so there are no specialized horizontal or verical flipped variants
_TBConstTile
                 sta:            $0001,y
                 sta:            $0004,y
                 sta             $1001,y
                 sta             $1004,y
                 sta             $2001,y
                 sta             $2004,y
                 sta             $3001,y
                 sta             $3004,y
                 sta             $4001,y
                 sta             $4004,y
                 sta             $5001,y
                 sta             $5004,y
                 sta             $6001,y
                 sta             $6004,y
                 sta             $7001,y
                 sta             $7004,y
                 jmp             _TBFillPEAOpcode

ClearTile
                 and             #$00FF
                 ora             #$4800
                 sta:            $0004,y
                 sta             $1004,y
                 sta             $2004,y
                 sta             $3004,y
                 sta             $4004,y
                 sta             $5004,y
                 sta             $6004,y
                 sta             $7004,y
                 inc
                 inc
                 sta:            $0001,y
                 sta             $1001,y
                 sta             $2001,y
                 sta             $3001,y
                 sta             $4001,y
                 sta             $5001,y
                 sta             $6001,y
                 sta             $7001,y

                 sep             #$20
                 lda             #$B1                              ; This is a special case where we can set all the words to LDA (DP),y
                 sta:            $0000,y
                 sta:            $0003,y
                 sta             $1000,y
                 sta             $1003,y
                 sta             $2000,y
                 sta             $2003,y
                 sta             $3000,y
                 sta             $3003,y
                 sta             $4000,y
                 sta             $4003,y
                 sta             $5000,y
                 sta             $5003,y
                 sta             $6000,y
                 sta             $6003,y
                 sta             $7000,y
                 sta             $7003,y
                 rep             #$20
                 rts

; Helper functions to copy tile data to the appropriate location in Bank 0
;  X = tile ID
;  Y = dynamic tile ID
CopyTileToDyn    ENT
                 txa
                 jsr             _GetTileAddr
                 tax

                 tya
                 and             #$001F                            ; Maximum of 32 dynamic tiles
                 asl
                 asl                                               ; 4 bytes per page
                 adc             BlitterDP                         ; Add to the bank 00 base address
                 adc             #$0100                            ; Go to the next page
                 tay
                 jsr             CopyTileDToDyn                    ; Copy the tile data
                 jsr             CopyTileMToDyn                    ; Copy the tile mask
                 rtl

;  X = address of tile
;  Y = tile address in bank 0
CopyTileDToDyn
                 phb
                 pea             $0000
                 plb
                 plb

                 ldal            tiledata+0,x
                 sta:            $0000,y
                 ldal            tiledata+2,x
                 sta:            $0002,y
                 ldal            tiledata+4,x
                 sta             $0100,y
                 ldal            tiledata+6,x
                 sta             $0102,y
                 ldal            tiledata+8,x
                 sta             $0200,y
                 ldal            tiledata+10,x
                 sta             $0202,y
                 ldal            tiledata+12,x
                 sta             $0300,y
                 ldal            tiledata+14,x
                 sta             $0302,y
                 ldal            tiledata+16,x
                 sta             $0400,y
                 ldal            tiledata+18,x
                 sta             $0402,y
                 ldal            tiledata+20,x
                 sta             $0500,y
                 ldal            tiledata+22,x
                 sta             $0502,y
                 ldal            tiledata+24,x
                 sta             $0600,y
                 ldal            tiledata+26,x
                 sta             $0602,y
                 ldal            tiledata+28,x
                 sta             $0700,y
                 ldal            tiledata+30,x
                 sta             $0702,y

                 plb
                 rts

; Helper function to copy tile mask to the appropriate location in Bank 0
;
;  X = address of tile
;  Y = tile address in bank 0
;
; Argument are the same as CopyTileDToDyn, the code takes care of adjust offsets.
; This make is possible to call the two functions back-to-back
;
;   ldx tileAddr
;   ldy dynTileAddr
;   jsr CopyTileDToDyn
;   jsr CopyTileMToDyn
CopyTileMToDyn
                 phb
                 pea             $0000
                 plb
                 plb

                 ldal            tiledata+32+0,x
                 sta:            $0080,y
                 ldal            tiledata+32+2,x
                 sta:            $0082,y
                 ldal            tiledata+32+4,x
                 sta             $0180,y
                 ldal            tiledata+32+6,x
                 sta             $0182,y
                 ldal            tiledata+32+8,x
                 sta             $0280,y
                 ldal            tiledata+32+10,x
                 sta             $0282,y
                 ldal            tiledata+32+12,x
                 sta             $0380,y
                 ldal            tiledata+32+14,x
                 sta             $0382,y
                 ldal            tiledata+32+16,x
                 sta             $0480,y
                 ldal            tiledata+32+18,x
                 sta             $0482,y
                 ldal            tiledata+32+20,x
                 sta             $0580,y
                 ldal            tiledata+32+22,x
                 sta             $0582,y
                 ldal            tiledata+32+24,x
                 sta             $0680,y
                 ldal            tiledata+32+26,x
                 sta             $0682,y
                 ldal            tiledata+32+28,x
                 sta             $0780,y
                 ldal            tiledata+32+30,x
                 sta             $0782,y

                 plb
                 rts

; CopyBG0Tile
;
; A low-level function that copies 8x8 tiles directly into the code field space.
;
; A = Tile ID (0 - 511)
; X = Tile column (0 - 40)
; Y = Tile row (0 - 25)
CopyBG0Tile      ENT
                 phb
                 phk
                 plb
                 jsr             _CopyBG0Tile
                 plb
                 rtl

_CopyBG0Tile
                 phb                                               ; save the current bank
                 phx                                               ; save the original x-value
                 pha                                               ; save the tile ID

                 tya                                               ; lookup the address of the virtual line (y * 8)
                 asl
                 asl
                 asl
                 asl                                               ; x2 because the table contains words, not
                 tay

                 sep             #$20                              ; set the bank register
                 lda             BTableHigh,y
                 pha                                               ; save for a few instruction
                 rep             #$20

                 txa
                 asl                                               ; there are two columns per tile, so multiple by 4
                 asl                                               ; asl will clear the carry bit
                 tax

                 lda             BTableLow,y
                 sta             _BASE_ADDR                        ; Used in masked tile renderer
                 clc
                 adc             Col2CodeOffset+2,x                ; Get the right edge (which is the lower physical address)
                 tay

                 plb                                               ; set the bank
                 pla                                               ; pop the tile ID
;                 jsr             _RenderTile

:exit
                 plx                                               ; pop the x-register
                 plb                                               ; restore the data bank and return
                 rts


; CopyBG1Tile
;
; A low-level function that copies 8x8 tiles directly into the BG1 data buffer.
;
; A = Tile ID (0 - 511)
; X = Tile column (0 - 40)
; Y = Tile row (0 - 25)
CopyBG1Tile
                 phb
                 phk
                 plb
                 jsr             _CopyBG1Tile
                 plb
                 rtl

_CopyBG1Tile
                 phb                                               ; save the current bank
                 phx                                               ; save the original x-value
                 pha                                               ; save the tile ID

                 tya                                               ; lookup the address of the virtual line (y * 8)
                 asl
                 asl
                 asl
                 asl
                 tay

                 txa
                 asl
                 asl                                               ; 4 bytes per tile column
                 clc
                 adc             BG1YTable,y
                 tay

                 sep             #$20
                 lda             BG1DataBank
                 pha
                 plb                                               ; set the bank
                 rep             #$20

                 pla                                               ; pop the tile ID
                 jsr             _RenderTileBG1

                 plx                                               ; pop the x-register
                 plb                                               ; restore the data bank and return
                 rts

; Tile Store that holds tile records which contain all the essential information for rendering 
; a tile.
;
; TileStore+TS_TILE_ID        : Tile descriptor
; TileStore+TS_DIRTY          : $0000 is clean, any other value indicated a dirty tile
; TileStore+TS_TILE_ADDR      : Address of the tile in the tile data buffer
; TileStore+TS_CODE_ADDR_LOW  : Low word of the address in the code field that receives the tile
; TileStore+TS_CODE_ADDR_HIGH : High word of the address in the code field that receives the tile
; TileStore+TS_WORD_OFFSET    : Logical number of word for this location
; TileStore+TS_BASE_ADDR      : Copy of BTableAddrLow
; TileStore+TS_SCREEN_ADDR    : Address on the physical screen corresponding to this tile (for direct rendering)
; TileStore+TS_SPRITE_FLAG    : A bit field of all sprites that intersect this tile
; TileStore+TS_SPRITE_ADDR_1  ; Address of the sprite data that aligns with this tile.  These
; TileStore+TS_SPRITE_ADDR_2  ; values are 1:1 with the TS_SPRITE_FLAG bits and are not contiguous.
; TileStore+TS_SPRITE_ADDR_3  ; If the bit position in TS_SPRITE_FLAG is not set, then the value in 
; TileStore+TS_SPRITE_ADDR_4  ; the TS_SPRITE_ADDR_* field is undefined.
; TileStore+TS_SPRITE_ADDR_5
; TileStore+TS_SPRITE_ADDR_6
; TileStore+TS_SPRITE_ADDR_7
; TileStore+TS_SPRITE_ADDR_8
; TileStore+TS_SPRITE_ADDR_9
; TileStore+TS_SPRITE_ADDR_10
; TileStore+TS_SPRITE_ADDR_11
; TileStore+TS_SPRITE_ADDR_12
; TileStore+TS_SPRITE_ADDR_13
; TileStore+TS_SPRITE_ADDR_14
; TileStore+TS_SPRITE_ADDR_15
; TileStore+TS_SPRITE_ADDR_16


; TileStore+
;TileStore        ENT
;                 ds   TILE_STORE_SIZE*11

; A list of dirty tiles that need to be updated in a given frame
DirtyTileCount   ds   2
DirtyTiles       ds   TILE_STORE_SIZE    ; At most this many tiles can possibly be update at once

; Initialize the tile storage data structures.  This takes care of populating the tile records with the
; appropriate constant values.
InitTiles
:col             equ  tmp0
:row             equ  tmp1
:vbuff           equ  tmp2

; Fill in the TileStoreYTable.  This is just a table of offsets into the Tile Store for each row.  There
; are 26 rows with a stride of 41
                 ldy  #0
                 lda  #0
:yloop
                 sta  TileStoreYTable,y
                 clc
                 adc  #41*2
                 iny
                 iny
                 cpy  #26*2
                 bcc  :yloop

; Next, initialize the Tile Store itself

                 ldx  #TILE_STORE_SIZE-2
                 lda  #25
                 sta  :row
                 lda  #40
                 sta  :col
                 lda  #$8000
                 sta  :vbuff

:loop 

; The first set of values in the Tile Store are changed during each frame based on the actions
; that are happening

                 lda  #0
                 stal TileStore+TS_TILE_ID,x            ; clear the tile store with the special zero tile
                 stal TileStore+TS_TILE_ADDR,x
                 stal TileStore+TS_SPRITE_FLAG,x        ; no sprites are set at the beginning
                 stal TileStore+TS_DIRTY,x              ; none of the tiles are dirty

                 lda  DirtyTileProcs                    ; Fill in with the first dispatch address
                 stal TileStore+TS_DIRTY_TILE_DISP,x

                 lda  TileProcs                         ; Same for non-dirty, non-sprite base case
                 stal TileStore+TS_BASE_TILE_DISP,x     

                 lda  :vbuff                            ; array of sprite vbuff addresses per tile
                 stal TileStore+TS_VBUFF_ARRAY_ADDR,x
                 clc
                 adc  #32
                 sta  :vbuff

; The next set of values are constants that are simply used as cached parameters to avoid needing to
; calculate any of these values during tile rendering

                 lda  :row                              ; Set the long address of where this tile
                 asl                                    ; exists in the code fields
                 tay
                 lda  BRowTableHigh,y
                 stal TileStore+TS_CODE_ADDR_HIGH,x     ; High word of the tile address (just the bank)
                 lda  BRowTableLow,y
                 stal TileStore+TS_BASE_ADDR,x          ; May not be needed later if we can figure out the right constant...

                 lda  :col                              ; Set the offset values based on the column
                 asl                                    ; of this tile
                 asl
                 stal TileStore+TS_WORD_OFFSET,x        ; This is the offset from 0 to 82, used in LDA (dp),y instruction
                 
                 tay
                 lda  Col2CodeOffset+2,y
                 clc
                 adcl TileStore+TS_BASE_ADDR,x
                 stal TileStore+TS_CODE_ADDR_LOW,x      ; Low word of the tile address in the code field

                 dec  :col
                 bpl  :hop
                 dec  :row
                 lda  #40
                 sta  :col
:hop

                 dex
                 dex
                 bpl  :loop
                 rts

_ClearDirtyTiles
                 bra  :hop
:loop
                 jsr  _PopDirtyTile
:hop
                 lda  DirtyTileCount
                 bne  :loop
                 rts

; Helper function to get the address offset into the tile cachce / tile backing store
; X = tile column [0, 40] (41 columns)
; Y = tile row    [0, 25] (26 rows)
GetTileStoreOffset ENT
                 phb
                 phk
                 plb
                 jsr  _GetTileStoreOffset
                 plb
                 rtl


_GetTileStoreOffset
                 phx                        ; preserve the registers
                 phy

                 jsr  _GetTileStoreOffset0

                 ply
                 plx
                 rts

_GetTileStoreOffset0
                 tya
                 asl
                 tay
                 txa
                 asl
                 clc
                 adc  TileStoreYTable,y
                 rts

; Set a tile value in the tile backing store.  Mark dirty if the value changes
;
; A = tile id
; X = tile column [0, 40] (41 columns)
; Y = tile row    [0, 25] (26 rows)
;
; Registers are not preserved
_SetTile
                 pha
                 jsr  _GetTileStoreOffset0          ; Get the address of the X,Y tile position
                 tax
                 pla
                 
                 cmpl TileStore+TS_TILE_ID,x        ; Only set to dirty if the value changed
                 beq  :nochange

                 stal TileStore+TS_TILE_ID,x        ; Value is different, store it.
                 jsr  _GetTileAddr
                 stal TileStore+TS_TILE_ADDR,x      ; Committed to drawing this tile, so get the address of the tile in the tiledata bank for later

                 ldal TileStore+TS_TILE_ID,x
                 and  #TILE_VFLIP_BIT+TILE_HFLIP_BIT ; get the lookup value
                 xba
                 tay
                 lda  DirtyTileProcs,y
                 stal TileStore+TS_DIRTY_TILE_DISP,x

                 ldal TileStore+TS_TILE_ID,x        ; Get the non-sprite dispatch address
                 and  #TILE_CTRL_MASK
                 xba
                 tay
                 lda  TileProcs,y
                 stal TileStore+TS_BASE_TILE_DISP,x

;                txa                                ; Add this tile to the list of dirty tiles to refresh
                 jmp  _PushDirtyTileX               ; on the next call to _ApplyTiles

:nochange        rts
           

; Append a new dirty tile record 
;
;  A = result of _GetTileStoreOffset for X, Y
;
; The main purpose of this function is to
;
;  1. Avoid marking the same tile dirty multiple times, and
;  2. Pre-calculating all of the information necessary to render the tile
PushDirtyTile    ENT
                 phb
                 phk
                 plb
                 jsr  _PushDirtyTile
                 plb
                 rtl

; alternate version that is very slightly slower, but preserves the y-register
_PushDirtyTile
                 tax

; alternate entry point if the x-register is already set
_PushDirtyTileX
                 ldal TileStore+TS_DIRTY,x
                 bne  :occupied2

                 inc                                  ; any non-zero value will work
                 stal TileStore+TS_DIRTY,x            ; and is 1 cycle faster than loading a constant value

                 txa
                 ldx  DirtyTileCount ; 4
                 sta  DirtyTiles,x   ; 6
                 inx                 ; 2
                 inx                 ; 2
                 stx  DirtyTileCount ; 4 = 18
                 rts
:occupied2
                 txa                                ; Make sure TileStore offset is returned in the accumulator
                 rts

; Remove a dirty tile from the list and return it in state ready to be rendered.  It is important
; that the core rendering functions *only* use _PopDirtyTile to get a list of tiles to update,
; because this routine merges the tile IDs stored in the Tile Store with the Sprite
; information to set the TILE_SPRITE_BIT.  This is the *only* place in the entire code base that
; applies this bit to a tile descriptor.
PopDirtyTile     ENT
                 phb
                 phk
                 plb
                 jsr  _PopDirtyTile
                 plb
                 rtl

_PopDirtyTile
                 ldy  DirtyTileCount
                 bne  _PopDirtyTile2
                 rts

_PopDirtyTile2                                       ; alternate entry point
                 dey
                 dey
                 sty  DirtyTileCount                 ; remove last item from the list

                 ldx  DirtyTiles,y                   ; load the offset into the Tile Store
                 lda  #$FFFF
                 stal TileStore+TS_DIRTY,x           ; clear the occupied backlink
                 rts

; Run through the dirty tile list and render them into the code field
ApplyTiles       ENT
                 phb
                 phk
                 plb
                 jsr  _ApplyTiles
                 plb
                 rtl

; The _ApplyTiles function is responsible for rendering all of the dirty tiles into the code
; field.  In this function we switch to the second direct page which holds the temporary
; working buffers for tile rendering.
_ApplyTiles
                 tdc
                 clc
                 adc  #$100                  ; move to the next page
                 tcd

                 bra  :begin

:loop
; Retrieve the offset of the next dirty Tile Store items in the X-register

                 jsr  _PopDirtyTile2

; Call the generic dispatch with the Tile Store record pointer at by the X-register.

                 phb
                 jsr  _RenderTile2
                 plb

; Loop again until the list of dirty tiles is empty

:begin           ldy  DirtyTileCount
                 bne  :loop

                 tdc                         ; Move back to the original direct page
                 sec
                 sbc  #$100
                 tcd
                 rts

; To make processing the tile faster, we do them in chunks of eight.  This allows the loop to be
; unrolled, which means we don't have to keep track of the register value and makes it faster to
; clear the dirty tile flag after being processed.

                 tdc                       ; Move to the dedicated direct page for tile rendering
                 clc
                 adc  #$100
                 tcd

                 phb                       ; Save the current bank
                 tsc
                 sta   tmp0                ; Save it on the direct page
                 bra   at_loop

; The DirtyTiles array and the TileStore information is in the Tile Store bank.  Because we
; process up to 8 tiles as a time and the tile code sets the bank register to the target
; code field bank, we need to restore the bank register each time.  So, we pre-push
; 8 copies of the TileStore bank onto the stack.


at_exit
                 tdc                             ; Move back to the original direct page
                 sec
                 sbc  #$100
                 tcd

                 plb                             ; Restore the original data bank and return
                 rts
dt_base          equ   $FE                        ; top of second direct page space

at_loop
                 lda   tmp0
                 tcs

                 lda  DirtyTileCount              ; This is pre-multiplied by 2
                 beq  at_exit                     ; If there are no items, exit

                 ldx   TileStoreBankDoubled
                 phx
                 phx
                 phx

                 cmp  #16                         ; If there are >= 8 elements, then
                 bcs  at_chunk                    ; do a full chunk

                 stz  DirtyTileCount              ; Otherwise, this pass will handle them all
                 tax
                 jmp  (at_table,x)
at_table         da   at_exit,at_one,at_two,at_three
                 da   at_four,at_five,at_six,at_seven

at_chunk         sec
                 sbc  #16
                 sta  DirtyTileCount              ; Fall through

; Because all of the registers get used in the _RenderTile2 subroutine, we
; push the values from the DirtyTiles array onto the stack and then pop off
; the values as we go

                 ldy   dt_base                    ; Reload the base index
                 ldx   DirtyTiles+14,y            ; Load the TileStore offset
                 stz   TileStore+TS_DIRTY,x       ; Clear this tile's dirty flag
                 jsr  _RenderTile2                ; Draw the tile
                 plb                              ; Reset the data bank to the TileStore bank

at_seven
                 ldy   dt_base
                 ldx   DirtyTiles+12,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTile2
                 plb

at_six
                 ldy   dt_base
                 ldx   DirtyTiles+10,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTile2
                 plb

at_five
                 ldy   dt_base
                 ldx   DirtyTiles+8,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTile2
                 plb

at_four
                 ldy   dt_base
                 ldx   DirtyTiles+6,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTile2
                 plb

at_three
                 ldy   dt_base
                 ldx   DirtyTiles+4,y
                 jsr   _RenderTile2
                 plb

at_two
                 ldy   dt_base
                 ldx   DirtyTiles+2,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTile2
                 plb

at_one
                 ldy   dt_base
                 ldx   DirtyTiles+0,y
                 stz   TileStore+TS_DIRTY,x
                 jsr   _RenderTile2
                 plb

                 jmp   at_loop
