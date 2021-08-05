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
; X = Tile column (0 - 40)
; Y = Tile row (0 - 25)
CopyTile
               phb                     ; save the current bank
               phx                     ; save the original x-value
               pha                     ; save the tile ID

               tya                     ; lookup the address of the virtual line (y * 8)
               asl
               asl
               asl
               asl
               tay

               sep   #$20              ; set the bank register
               lda   BTableHigh,y
               pha                     ; save for a few instruction
               rep   #$20

               phx                     ; Reverse the tile index since x = 0 is at the end
               lda   #40
               sec
               sbc   1,s
               plx

               asl                     ; there are two columns per tile, so multiple by 4
               asl                     ; asl will clear the carry bit
               tax
               lda   Col2CodeOffset,x
               adc   BTableLow,y
               tay

               plb                     ; set the bank
               pla                     ; pop the tile ID
               jsr   :ClearTile        ; :_CopyTile

               plx                     ; pop the x-register
               plb                     ; restore the data bank and return
               rts

; _CopyTile
;
; Copy a solid tile into one of the code banks
;
; B = bank of the code field
; A = Tile ID (0 - 1023)
; Y = Base Adddress in the code field

:_CopyTile     cmp   #$0010
               bcs   *+5
               brl   :FillWord
               cmp   #$0400
               bcs   *+5
               brl   :CopyTileMem
               rts                     ; Tile number is too large

:TilePatterns  dw    $0000,$1111,$2222,$3333
               dw    $4444,$5555,$6666,$7777
               dw    $8888,$9999,$AAAA,$BBBB
               dw    $CCCC,$DDDD,$EEEE,$FFFF

:ClearTile     sep   #$20
               lda   #$B1
               sta:  $0000,y
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
               rep   #$20

               lda   3,s
               asl
               asl
               and   #$00FF
               ora   #$4800
               sta:  $0004,y
               sta   $1004,y
               sta   $2004,y
               sta   $3004,y
               sta   $4004,y
               sta   $5004,y
               sta   $6004,y
               sta   $7004,y
               inc
               inc
               sta:  $0001,y
               sta   $1001,y
               sta   $2001,y
               sta   $3001,y
               sta   $4001,y
               sta   $5001,y
               sta   $6001,y
               sta   $7001,y
               rts


:FillWord      asl
               tax
               ldal  :TilePatterns,x

               sta:  $0001,y
               sta:  $0004,y
               sta   $1001,y
               sta   $1004,y
               sta   $2001,y
               sta   $2004,y
               sta   $3001,y
               sta   $3004,y
               sta   $4001,y
               sta   $4004,y
               sta   $5001,y
               sta   $5004,y
               sta   $6001,y
               sta   $6004,y
               sta   $7001,y
               sta   $7004,y
               rts

:CopyTileMem   sec
               sbc   #$0010

               asl
               asl
               asl
               asl
               asl
               tax

               ldal  tiledata+0,x      ; The low word goes in the *next* instruction
               sta:  $0004,y
               ldal  tiledata+2,x
               sta:  $0001,y
               ldal  tiledata+4,x
               sta   $1004,y
               ldal  tiledata+6,x
               sta   $1001,y
               ldal  tiledata+8,x
               sta   $2004,y
               ldal  tiledata+10,x
               sta   $2001,y
               ldal  tiledata+12,x
               sta   $3004,y
               ldal  tiledata+14,x
               sta   $3001,y
               ldal  tiledata+16,x
               sta   $4004,y
               ldal  tiledata+18,x
               sta   $4001,y
               ldal  tiledata+20,x
               sta   $5004,y
               ldal  tiledata+22,x
               sta   $5001,y
               ldal  tiledata+24,x
               sta   $6004,y
               ldal  tiledata+26,x
               sta   $6001,y
               ldal  tiledata+28,x
               sta   $7004,y
               ldal  tiledata+30,x
               sta   $7001,y
               rts

; Primitives to render a dynamic tile
;
; LDA 00,x / PHA where the operand is fixed when the tile is rendered
; $B5 $00 $48
;
; A = dynamic tile id (must be an 8-bit value)

:DynTile
               and   #$00FF
               ora   #$4800
               sta:  $0004,y
               sta   $1004,y
               sta   $2004,y
               sta   $3004,y
               sta   $4004,y
               sta   $5004,y
               sta   $6004,y
               sta   $7004,y
               inc
               inc
               sta:  $0001,y
               sta   $1001,y
               sta   $2001,y
               sta   $3001,y
               sta   $4001,y
               sta   $5001,y
               sta   $6001,y
               sta   $7001,y

               sep   #$20
               lda   #$B5
               sta:  $0000,y
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
               rep   #$20
               rts
