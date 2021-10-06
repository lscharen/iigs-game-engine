; Collection of functions that deal with tiles.  Primarily rendering tile data into
; the code fields.
;
; Tile data can be done faily often, so these routines are performance-sensitive.
;
; CopyTileConst -- the first 16 tile numbers are reserved and can be used
;                  to draw a solid tile block
; CopyTileLinear -- copies the tile data from the tile bank in linear order, e.g.
;                   32 consecutive bytes are copied

; RenderTile
;
; A high-level function that takes a 16-bit tile descriptor and dispatched to the
; appropriate tile copy courinte based on the descritor flags
;
; Bit  15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
;     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
;     |xx|xx|FF|MM|DD|VV|HH|  |  |  |  |  |  |  |  |  |
;     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
;      \____/ |  |  |  |  | \________________________/
;        |    |  |  |  |  |      Tile ID (0 to 511)
;          |  |  |  |  |  |
;          |  |  |  |  |  +-- H : Flip tile horizontally
;          |  |  |  |  +----- V : Flip tile vertically
;          |  |  |  +-------- D : Render as a Dynamic Tile (Tile ID < 32, V and H have no effect)
;          |  |  +----------- M : Apply tile mask
;          |  +-------------- F : Overlay a fringe tile
;          +----------------- Reserved
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

TILE_ID_MASK     equ             $01FF
TILE_FRINGE_BIT  equ             $2000
TILE_MASK_BIT    equ             $1000
TILE_DYN_BIT     equ             $0800
TILE_VFLIP_BIT   equ             $0400
TILE_HFLIP_BIT   equ             $0200
TILE_CTRL_MASK   equ             $1E00                             ; Deliberately ignore the Fringe bit in the dispatch

; Low-level function to take a tile descriptor and return the address in the tiledata
; bank.  This is not too useful in the fast-path because the fast-path does more
; incremental calculations, but it is handy for other utility functions
;
; A = tile descriptor
;
; The address is the TileID * 128 + (HFLIP * 64)
_GetTileAddr
                 asl                                               ; Multiply by 2
                 bit             #2*TILE_HFLIP_BIT                 ; Check if the horizontal flip bit is set
                 beq             :no_flip
                 inc                                               ; Set the LSB
:no_flip         and             #TILE_ID_MASK                     ; Mask out non-id bits
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
RenderTileBG1
                 tax                                               ; Save the tile descriptor
                 and             #TILE_ID_MASK                     ; Mask out the ID and save just that
                 _Mul128                                           ; multiplied by 128
                 pha

                 txa
                 and             #TILE_VFLIP_BIT+TILE_HFLIP_BIT    ; Only horizontal and vertical flips are supported for BG1
                 xba
                 tax
                 jmp             (:actions,x)

:actions         dw              bg1_noflip,bg1_hflip,bg1_vflip,bg1_hvflip

bg1_noflip
                 pla
                 brl             _CopyTileBG1

bg1_hflip
                 pla
                 clc
                 adc             #64                               ; Advance to the flipped version
                 brl             _CopyTileBG1

bg1_vflip
                 pla
                 brl             _CopyTileBG1V

bg1_hvflip
                 pla
                 clc
                 adc             #64                               ; Advance to the flipped version
                 brl             _CopyTileBG1V

_CopyTileBG1     tax

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
                 rts

_CopyTileBG1V    tax

                 ldal            tiledata+0,x
                 sta:            $0700,y
                 ldal            tiledata+2,x
                 sta:            $0702,y
                 ldal            tiledata+4,x
                 sta             $0600,y
                 ldal            tiledata+6,x
                 sta             $0602,y
                 ldal            tiledata+8,x
                 sta             $0500,y
                 ldal            tiledata+10,x
                 sta             $0502,y
                 ldal            tiledata+12,x
                 sta             $0400,y
                 ldal            tiledata+14,x
                 sta             $0402,y
                 ldal            tiledata+16,x
                 sta             $0300,y
                 ldal            tiledata+18,x
                 sta             $0302,y
                 ldal            tiledata+20,x
                 sta             $0200,y
                 ldal            tiledata+22,x
                 sta             $0202,y
                 ldal            tiledata+24,x
                 sta             $0100,y
                 ldal            tiledata+26,x
                 sta             $0102,y
                 ldal            tiledata+28,x
                 sta             $0000,y
                 ldal            tiledata+30,x
                 sta             $0002,y
                 rts

; On entry
;
; B is set to the correct code field bank
; A is set to the the tile descriptor
; Y is set to the top-left address of the tile in the code field
; X is set to the tile word offset (0 through 80 in steps of 4)
;
; tmp0/tmp1 is reserved 
RenderTile
                 bit             #TILE_CTRL_MASK                   ; Fast path for "normal" tiles
                 beq             _CopyTile
                 cmp             #TILE_MASK_BIT                    ; Tile 0 w/mask bit set is special, too
                 bne             *+5
                 brl             ClearTile

                 phx                                               ; Save the tile offset

                 tax
                 and             #TILE_ID_MASK                     ; Mask out the ID and save just that
                 _Mul128                                           ; multiplied by 128
                 pha

                 txa
                 and             #TILE_CTRL_MASK                   ; Mask out the different modifiers
                 xba
                 tax
                 jmp             (:actions,x)

:actions         dw              solid,solid_hflip,solid_vflip,solid_hvflip
                 dw              dynamic,dynamic,dynamic,dynamic
                 dw              masked,masked_hflip,masked_vflip,masked_hvflip
                 dw              dyn_masked,dyn_masked,dyn_masked,dyn_masked

FillWord0
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
                 bra             FillPEAOpcode

; _CopyTile
;
; Copy a solid tile into one of the code banks
;
; B = bank of the code field
; A = Tile ID (0 - 1023)
; Y = Base Adddress in the code field


_CopyTile        cmp             #$0000                            ; Fast-path the special zero tile
                 beq             FillWord0

CopyTileMem
                 _Mul128                                           ; Take care of getting the right tile address

CopyTileMem0
                 tax

                 ldal            tiledata+0,x                      ; The low word goes in the *next* instruction
                 sta:            $0004,y
                 ldal            tiledata+2,x
                 sta:            $0001,y
                 ldal            tiledata+4,x
                 sta             $1004,y
                 ldal            tiledata+6,x
                 sta             $1001,y
                 ldal            tiledata+8,x
                 sta             $2004,y
                 ldal            tiledata+10,x
                 sta             $2001,y
                 ldal            tiledata+12,x
                 sta             $3004,y
                 ldal            tiledata+14,x
                 sta             $3001,y
                 ldal            tiledata+16,x
                 sta             $4004,y
                 ldal            tiledata+18,x
                 sta             $4001,y
                 ldal            tiledata+20,x
                 sta             $5004,y
                 ldal            tiledata+22,x
                 sta             $5001,y
                 ldal            tiledata+24,x
                 sta             $6004,y
                 ldal            tiledata+26,x
                 sta             $6001,y
                 ldal            tiledata+28,x
                 sta             $7004,y
                 ldal            tiledata+30,x
                 sta             $7001,y                           ; Fall through

; For solid tiles
FillPEAOpcode
                 sep             #$20
                 lda             #$F4
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

; Masked tiles
;
; Can result in one or three different code sequences
;
; If mask === $0000, then insert PEA $DATA
; If mask === $FFFF, then insert LDA (DP),y / PHA
; Else               then insert JMP and patch exception handler
;
; Because every word of the tile can lead to different opcodes, we
; do the entire setup for each word rather than breaking them up into
; 16-bit and 8-bit operations.

; Macro to make the loop simpler.  Takes three arguments
;
; ]1 = address of tile data
; ]2 = address of tile mask
; ]3 = address of target in code field

_X_REG           equ             tiletmp
_Y_REG           equ             tiletmp+2
_T_PTR           equ             tiletmp+4                         ; Copy of the tile address pointer
_BASE_ADDR       equ             tiletmp+6                         ; Copy of BTableLow for this tile

CopyTileMemM

                 stx             _X_REG                            ; Save these values as we will need to reload them
                 sty             _Y_REG                            ; at certain points
                 sta             _T_PTR
                 tax

; Do the left column first

                 CopyMaskedWord  tiledata+0;tiledata+32+0;$0003
                 CopyMaskedWord  tiledata+4;tiledata+32+4;$1003
                 CopyMaskedWord  tiledata+8;tiledata+32+8;$2003
                 CopyMaskedWord  tiledata+12;tiledata+32+12;$3003
                 CopyMaskedWord  tiledata+16;tiledata+32+16;$4003
                 CopyMaskedWord  tiledata+20;tiledata+32+20;$5003
                 CopyMaskedWord  tiledata+24;tiledata+32+24;$6003
                 CopyMaskedWord  tiledata+28;tiledata+32+28;$7003

; Move the index for the JTableOffset array.  This is the same index used for transparent words,
; so, if _X_REG is zero, then we would be patching out the last word in the code field with LDA (0),y
; and then increment _X_REG by two to patch the next-to-last word in the code field with LDA (2),y

                 inc             _X_REG
                 inc             _X_REG

; Do the right column

                 CopyMaskedWord  tiledata+2;tiledata+32+2;$0000
                 CopyMaskedWord  tiledata+6;tiledata+32+6;$1000
                 CopyMaskedWord  tiledata+10;tiledata+32+10;$2000
                 CopyMaskedWord  tiledata+14;tiledata+32+14;$3000
                 CopyMaskedWord  tiledata+18;tiledata+32+18;$4000
                 CopyMaskedWord  tiledata+22;tiledata+32+22;$5000
                 CopyMaskedWord  tiledata+26;tiledata+32+26;$6000
                 CopyMaskedWord  tiledata+30;tiledata+32+30;$7000

                 rts

CopyTileMemMV

                 stx             _X_REG                            ; Save these values as we will need to reload them
                 sty             _Y_REG                            ; at certain points
                 sta             _T_PTR
                 tax

                 CopyMaskedWord  tiledata+0;tiledata+32+0;$7003
                 CopyMaskedWord  tiledata+2;tiledata+32+2;$7000
                 CopyMaskedWord  tiledata+4;tiledata+32+4;$6003
                 CopyMaskedWord  tiledata+6;tiledata+32+6;$6000
                 CopyMaskedWord  tiledata+8;tiledata+32+8;$5003
                 CopyMaskedWord  tiledata+10;tiledata+32+10;$5000
                 CopyMaskedWord  tiledata+12;tiledata+32+12;$4003
                 CopyMaskedWord  tiledata+14;tiledata+32+14;$4000
                 CopyMaskedWord  tiledata+16;tiledata+32+16;$3003
                 CopyMaskedWord  tiledata+18;tiledata+32+18;$3000
                 CopyMaskedWord  tiledata+20;tiledata+32+20;$2003
                 CopyMaskedWord  tiledata+22;tiledata+32+22;$2000
                 CopyMaskedWord  tiledata+24;tiledata+32+24;$1003
                 CopyMaskedWord  tiledata+28;tiledata+32+26;$1000
                 CopyMaskedWord  tiledata+30;tiledata+32+28;$0003
                 CopyMaskedWord  tiledata+32;tiledata+32+30;$0000

                 rts

TilePatterns     dw              $0000,$1111,$2222,$3333
                 dw              $4444,$5555,$6666,$7777
                 dw              $8888,$9999,$AAAA,$BBBB
                 dw              $CCCC,$DDDD,$EEEE,$FFFF

ClearTile        sep             #$20
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

                 txa
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
                 rts

; Copy a tile, but vertically flip the data
CopyTileMemV
                 tax

                 ldal            tiledata+0,x                      ; The low word goes in the *next* instruction
                 sta             $7004,y
                 ldal            tiledata+2,x
                 sta             $7001,y
                 ldal            tiledata+4,x
                 sta             $6004,y
                 ldal            tiledata+6,x
                 sta             $6001,y
                 ldal            tiledata+8,x
                 sta             $5004,y
                 ldal            tiledata+10,x
                 sta             $5001,y
                 ldal            tiledata+12,x
                 sta             $4004,y
                 ldal            tiledata+14,x
                 sta             $4001,y
                 ldal            tiledata+16,x
                 sta             $3004,y
                 ldal            tiledata+18,x
                 sta             $3001,y
                 ldal            tiledata+20,x
                 sta             $2004,y
                 ldal            tiledata+22,x
                 sta             $2001,y
                 ldal            tiledata+24,x
                 sta             $1004,y
                 ldal            tiledata+26,x
                 sta             $1001,y
                 ldal            tiledata+28,x
                 sta:            $0004,y
                 ldal            tiledata+30,x
                 sta:            $0001,y
                 rts

; Primitives to render a dynamic tile
;
; LDA 00,x / PHA where the operand is fixed when the tile is rendered
; $B5 $00 $48
;
; A = dynamic tile id (must be <32)

DynamicTile
                 and             #$007F                            ; clamp to < (32 * 4)
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
                 lda             #$B5
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

; This should never be called, because empty control value should be fast-pathed
solid
                 pla
                 plx
                 brl             CopyTileMem

solid_hflip
                 pla
                 clc
                 adc             #64                               ; Advance to the flipped version
                 plx
                 brl             CopyTileMem

solid_vflip
                 pla
                 plx
                 brl             CopyTileMemV

solid_hvflip
                 pla
                 clc
                 adc             #64                               ; Advance to the flipped version
                 plx
                 brl             CopyTileMemV

masked
                 pla
                 plx
                 brl             CopyTileMemM

masked_hflip
                 pla
                 clc
                 adc             #64                               ; Advance to the flipped version
                 plx
                 brl             CopyTileMemM

masked_vflip
                 pla
                 plx
                 brl             CopyTileMemMV

masked_hvflip
                 pla
                 clc
                 adc             #64                               ; Advance to the flipped version
                 plx
                 brl             CopyTileMemMV

dynamic
                 pla
                 asl
                 asl
                 asl
                 xba                                               ; Undo the x128 we just need x4
                 plx
                 brl             DynamicTile

dyn_masked
                 pla
                 plx
                 rts

; Merge
;
; For fringe support -- takes a pointer to two tiles and composites them into
; some scratch space.
;
; X = primary tile address
; Y = fringe tile address

tilescratch      equ             $FF80
_MergeTiles
; Merge the tile data
]step            equ             0
                 lup             16
                 lda:            tiledata+]step,x
                 and:            tiledata+32+]step,y
                 ora:            tiledata+]step,y
                 sta:            tilescratch+]step
]step            equ             ]step+2
                 --^

; Merge the tile masks
]step            equ             0
                 lup             16
                 lda:            tiledata+32+]step,x
                 and:            tiledata+32+]step,y
                 sta:            tilescratch+32+]step
]step            equ             ]step+2
                 --^

                 lda             #tilescratch/128
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
                 asl
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

; Optimization note: We could make a Tile2CodeOffset table that is pre-reversed, which should simplify
; the code starting after the 'rep #$20' to just be this.  Saves around 16 cycles / tile...
;
; There would need to be a similar modification made to the JTable as well.

                 plb                                               ; set the bank
                 pla                                               ; pop the tile ID
                 jsr             RenderTile

                 plx                                               ; pop the x-register
                 plb                                               ; restore the data bank and return
                 rts

; CopyTileBG1
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
                 jsr             RenderTileBG1

                 plx                                               ; pop the x-register
                 plb                                               ; restore the data bank and return
                 rts


















