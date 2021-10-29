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

; Temporary direct page locatinos used by some of the complex tile renderers

_X_REG           equ             tiletmp
_Y_REG           equ             tiletmp+2
_T_PTR           equ             tiletmp+4                         ; Copy of the tile address pointer
_BASE_ADDR       equ             tiletmp+6                         ; Copy of BTableLow for this tile
_SPR_X_REG       equ             tiletmp+8                         ; Cache address of sprite plane source for a tile

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
:no_flip         and             #TILE_ID_MASK*2                   ; Mask out non-id bits
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
; Y = address of tile
RenderTile       ENT
                 phb
                 phk
                 plb
                 jsr   _RenderTile2
                 plb
                 rtl

_RenderTile2
                 lda   TileStore+TS_TILE_ID,y         ; build the finalized tile descriptor
                 ora   TileStore+TS_SPRITE_FLAG,y
                 bpl   :nosprite                      ; save a few cycles on average -- the sprite flag is $8000, so easy bpl/bmi test
                 ldx   TileStore+TS_SPRITE_ADDR,y
                 stx   _SPR_X_REG

:nosprite
                 and   #TILE_CTRL_MASK
                 xba
                 tax
                 lda   TileProcs,x                    ; load and patch in the appropriate subroutine
                 sta   :tiledisp+1

                 ldx   TileStore+TS_TILE_ADDR,y       ; load the address of this tile's data (pre-calculated)

                 sep   #$20                           ; load the bank of the target code field line
                 lda   TileStore+TS_CODE_ADDR_HIGH,y
                 pha
                 rep   #$20
                 lda   TileStore+TS_CODE_ADDR_LOW,y   ; load the address of the code field
                 pha
                 lda   TileStore+TS_BASE_ADDR,y   ; load the address of the code field
                 sta   _BASE_ADDR

                 lda   TileStore+TS_WORD_OFFSET,y
                 ply
                 plb                                  ; set the bank

; B is set to the correct code field bank
; A is set to the tile word offset (0 through 80 in steps of 4)
; Y is set to the top-left address of the tile in the code field
; X is set to the address of the tile data

:tiledisp        jmp   $0000                          ; render the tile

; Reference all of the tile rendering subroutines defined in the TileXXXXX files.  Each file defines
; 8 entry points:
;
; One set for normal, horizontally flipped, vertically flipped and hors & vert flipped.
; A second set that are optimized for when EngineMode has BG1 disabled.
TileProcs        dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00000 : normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00001 : dynamic tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00010 : masked normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00011 : masked dynamic tiles

                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00100 : fringed normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00101 : fringed dynamic tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00110 : fringed masked normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 00111 : fringed masked dynamic tiles

                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01000 : high-priority normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01001 : high-priority dynamic tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01010 : high-priority masked normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01011 : high-priority masked dynamic tiles

                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01100 : high-priority fringed normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01101 : high-priority fringed dynamic tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01110 : high-priority fringed masked normal tiles
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 01111 : high-priority fringed masked dynamic tiles

                 dw              _TBSolidSpriteTile_00,_TBSolidSpriteTile_0H,_TBSolidSpriteTile_V0,_TBSolidSpriteTile_VH  ; 10000 : normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 10001 : dynamic tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 10010 : masked normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 10011 : masked dynamic tiles w/sprite

                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 10100 : fringed normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 10101 : fringed dynamic tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 10110 : fringed masked normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 10111 : fringed masked dynamic tiles w/sprite

                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11000 : high-priority normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11001 : high-priority dynamic tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11010 : high-priority masked normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11011 : high-priority masked dynamic tiles w/sprite

                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11100 : high-priority fringed normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11101 : high-priority fringed dynamic tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11110 : high-priority fringed masked normal tiles w/sprite
                 dw              _TBSolidTile_00,_TBSolidTile_0H,_TBSolidTile_V0,_TBSolidTile_VH  ; 11111 : high-priority fringed masked dynamic tiles w/sprite

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
; TileStore+TS_DIRTY          : $FFFF is clean, otherwise stores a back-reference to the DirtyTiles array
; TileStore+TS_SPRITE_FLAG    : Set to TILE_SPRITE_BIT is a sprite is present at this tile location
; TileStore+TS_SPRITE_ADDR    ; Address of the tile in the sprite plane
; TileStore+TS_TILE_ADDR      : Address of the tile in the tile data buffer
; TIleStore+TS_CODE_ADDR_LOW  : Low word of the address in the code field that receives the tile
; TileStore+TS_CODE_ADDR_HIGH : High word of the address in the code field that receives the tile
; TileStore+TS_WORD_OFFSET    : Logical number of word for this location
; TileStore+TS_BASE_ADDR      : Copy of BTableAddrLow

TileStore        ENT
                 ds   TILE_STORE_SIZE*9

; A list of dirty tiles that need to be updated in a given frame
DirtyTileCount   ds   2
DirtyTiles       ds   TILE_STORE_SIZE    ; At most this many tiles can possibly be update at once

; Initialize the tile storage data structures.  This takes care of populating the tile records with the
; appropriate constant values.
InitTiles
:col             equ  tmp0
:row             equ  tmp1

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

:loop 

; The first set of values in the Tile Store are changed during each frame based on the actions
; that are happening

                 stz  TileStore+TS_TILE_ID,x            ; clear the tile store with the special zero tile
                 stz  TileStore+TS_TILE_ADDR,x

                 stz  TileStore+TS_SPRITE_FLAG,x        ; no sprites are set at the beginning
                 lda  #$FFFF                            ; none of the tiles are dirty
                 sta  TileStore+TS_DIRTY,x

; The next set of values are constants that are simply used as cached parameters to avoid needing to
; calculate any of these values during tile rendering

                 lda  :row                              ; Set the long address of where this tile
                 asl                                    ; exists in the code fields
                 tay
                 lda  BRowTableHigh,y
                 sta  TileStore+TS_CODE_ADDR_HIGH,x     ; High word of the tile address (just the bank)
                 lda  BRowTableLow,y
                 sta  TileStore+TS_BASE_ADDR,x          ; May not be needed later if we can figure out the right constant...

                 lda  :col                              ; Set the offset values based on the column
                 asl                                    ; of this tile
                 asl
                 sta  TileStore+TS_WORD_OFFSET,x        ; This is the offset from 0 to 82, used in LDA (dp),y instruction
                 
                 tay
                 lda  Col2CodeOffset+2,y
                 clc
                 adc  TileStore+TS_BASE_ADDR,x
                 sta  TileStore+TS_CODE_ADDR_LOW,x      ; Low word of the tile address in the code field

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
_SetTile
                 pha
                 jsr  _GetTileStoreOffset0          ; Get the address of the X,Y tile position
                 tay
                 pla
                 
                 cmp  TileStore+TS_TILE_ID,y        ; Only set to dirty if the value changes
                 beq  :nochange

                 sta  TileStore+TS_TILE_ID,y        ; Value is different, store it.

                 jsr  _GetTileAddr
                 sta  TileStore+TS_TILE_ADDR,y      ; Committed to drawing this tile, so get the address of the tile in the tiledata bank for later

                 tya                                ; Add this tile to the list of dirty tiles to refresh
                 jmp  _PushDirtyTile                ; on the next call to _ApplyTiles

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

_PushDirtyTile
                 tay                                 ; check if this already marked immediately
                 lda  TileStore+TS_DIRTY,y           ; If the lookup === $FFFF (<$8000), it is free.
                 bpl  :occupied

; At this point, keep the Y register value because it is the correct offset to all of the tile
; record fields.
                 ldx  DirtyTileCount

                 txa
                 sta  TileStore+TS_DIRTY,y           ; Store a back-link to this record

                 tya
                 sta  DirtyTiles,x                   ; Store the lookup address in the list

                 inx
                 inx
                 stx  DirtyTileCount                 ; Commit
:occupied
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
                 ldx  DirtyTileCount
                 bne  _PopDirtyTile2
                 rts

_PopDirtyTile2                                       ; alternate entry point
                 dex
                 dex
                 stx  DirtyTileCount                 ; remove last item from the list

                 ldy  DirtyTiles,x                   ; load the offset into the Tile Store
                 lda  #$FFFF
                 sta  TileStore+TS_DIRTY,y           ; clear the occupied backlink
                 rts

; Run through the dirty tile list and render them into the code field
_ApplyTiles
                 bra  :begin

:loop
; Retrieve the offset of the next dirty Tile Store items in the Y-register

                 jsr  _PopDirtyTile2

; Call the generic dispatch with the Tile Store record pointer at by the Y-register.  

                 phb
                 jsr  _RenderTile2
                 plb

; Loop again until the list of dirty tiles is empty

:begin           ldx  DirtyTileCount
                 bne  :loop
                 rts