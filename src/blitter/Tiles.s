; Collection of functions that deal with tiles.  Primarily rendering tile data into
; the code fields.
;
; Tile data can be done faily often, so these routines are performance-sensitive.
;
; CopyTileConst -- the first 16 tile numbers are reserved and can be used
;                  to draw a solid tile block
; CopyTileLinear -- copies the tile data from the tile bank in linear order, e.g.
;                   32 consecutive bytes are copied

; CopyTile
;
; A low-level function that copies 8x8 tiles directly into the code field space.
;
; A = Tile ID (0 - 1023)
; X = Tile row (0 - 25)
; Y = Tile columns (0 - 40)
CopyTile
                phb                     ; save the current bank
                pha                     ; save the tile ID

                tya                     ; lookup the address of the virtual line (y * 8)
                asl
                asl
                asl
                tay

                sep   #$20              ; set the bank register
                lda   BTableHigh,y
                pha                     ; save for a few instruction
                rep   #$20

                txa                     ; there are two columns per tile, so multiple by 4
                asl
                asl                     ; asl will clear the carry bit
                tax
                lda   Col2CodeOffset,x
                adc   BTableLow,y
                tay
                iny                     ; +1 to move past to opcode to the operand

                plb                     ; set the bank
                pla                     ; pop the tile ID
                jsr   _CopyTile

                plb                     ; restore the data bank and return
                rts

; _CopyTile
;
; Copy a solid tile into one of the code banks
;
; B = bank of the code field
; A = Tile ID (0 - 1023)
; Y = Base Adddress in the code field

_CopyTile       cmp   #$0010
                bcc   :FillWord
                cmp   #$0400
                bcc   :CopyTileMem
                rts                     ; Tile number is too large

:TilePatterns   dw    $0000,$1111,$2222,$3333
                dw    $4444,$5555,$6666,$7777
                dw    $8888,$9999,$AAAA,$BBBB
                dw    $CCCC,$DDDD,$EEEE,$FFFF

:FillWord       asl
                tax
                ldal  :TilePatterns,x

CopyTileConst   sta:  $0000,y
                sta:  $0003,y
                sta   $1000,y
                sta   $1003,y
                sta   $2000,y
                sta   $2003,y
                sta   $3000,y
                sta   $3003,y
                sta   $4000,y
                sta   $4003,y
                sta   $5000,y
                sta   $5003,y
                sta   $6000,y
                sta   $6003,y
                sta   $7000,y
                sta   $7003,y
                rts

:CopyTileMem    asl
                asl
                asl
                asl
                asl
                tax

CopyTileLinear  ldal  tiledata+0,x
                sta:  $0000,y
                ldal  tiledata+2,x
                sta:  $0003,y
                ldal  tiledata+4,x
                sta   $1000,y
                ldal  tiledata+6,x
                sta   $1003,y
                ldal  tiledata+8,x
                sta   $2000,y
                ldal  tiledata+10,x
                sta   $2003,y
                ldal  tiledata+12,x
                sta   $3000,y
                ldal  tiledata+14,x
                sta   $3003,y
                ldal  tiledata+16,x
                sta   $4000,y
                ldal  tiledata+18,x
                sta   $4003,y
                ldal  tiledata+20,x
                sta   $5000,y
                ldal  tiledata+22,x
                sta   $5003,y
                ldal  tiledata+24,x
                sta   $6000,y
                ldal  tiledata+26,x
                sta   $6003,y
                ldal  tiledata+28,x
                sta   $7000,y
                ldal  tiledata+30,x
                sta   $7003,y
                rts

















