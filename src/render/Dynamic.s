; Rendering functions for Dynamic tiles.  There are no Fast/Slow variants here
CopyDynamicTile
            ldal   TileStore+TS_TILE_ID,x
            and    #$007F
            ora    #$4800

]line       equ    0             ; render the first column
            lup    8
            sta:   $0004+{]line*$1000},y
]line       equ    ]line+1
            --^

            inc                  ; advance to the next word
            inc

]line       equ    0             ; render the second column
            lup    8
            sta:   $0001+{]line*$1000},y
]line       equ    ]line+1
            --^

            sep    #$20
            lda    #$B5
            sta:   $0000,y
            sta:   $0003,y
            sta    $1000,y
            sta    $1003,y
            sta    $2000,y
            sta    $2003,y
            sta    $3000,y
            sta    $3003,y
            sta    $4000,y
            sta    $4003,y
            sta    $5000,y
            sta    $5003,y
            sta    $6000,y
            sta    $6003,y
            sta    $7000,y
            sta    $7003,y
            rep    #$20
            plb
            rts

; These routines handle the sprites.  They rely on a fairly complicated macro that takes care of
; populating the code field and snippet space
DynamicOver
            lda     TileStore+TS_JMP_ADDR,x      ; Get the address of the exception handler
            sta     _JTBL_CACHE

            lda     TileStore+TS_TILE_ID,x       ; Get the original tile descriptor
            and     #$007F             ; clamp to < (32 * 4)
            ora     #$B500
            xba
            sta     _OP_CACHE          ; This is the 2-byte opcode for to load the data

            lda   TileStore+TS_CODE_ADDR_HIGH,x
            pha
            ldy   TileStore+TS_CODE_ADDR_LOW,x
            plb

            CopyDynOver  0;$0003
            CopyDynOver  4;$1003
            CopyDynOver  8;$2003
            CopyDynOver  12;$3003
            CopyDynOver  16;$4003
            CopyDynOver  20;$5003
            CopyDynOver  24;$6003
            CopyDynOver  28;$7003

            sec
            lda     _JTBL_CACHE
            sbc     #SNIPPET_SIZE      ; Advance to the next snippet (Reverse indexing)
            sta     _JTBL_CACHE

            clc
            lda     _OP_CACHE
            adc     #$0200             ; Advance to the next word
            sta     _OP_CACHE

            CopyDynOver  2;$0000
            CopyDynOver  6;$1000
            CopyDynOver  10;$2000
            CopyDynOver  14;$3000
            CopyDynOver  18;$4000
            CopyDynOver  22;$5000
            CopyDynOver  26;$6000
            CopyDynOver  30;$7000

            plb
            rts

DynamicUnder
            lda     TileStore+TS_JMP_ADDR,x      ; Get the address of the exception handler
            sta     _JTBL_CACHE

            lda     TileStore+TS_TILE_ID,x       ; Get the original tile descriptor
            and     #$007F             ; clamp to < (32 * 4)
            ora     #$3580             ; Pre-calc the AND $80,x opcode + operand            
            xba
            sta     _OP_CACHE          ; This is the 2-byte opcode for to load the data

            lda   TileStore+TS_CODE_ADDR_HIGH,x
            pha
            ldy   TileStore+TS_CODE_ADDR_LOW,x
            plb

            CopyDynUnder  0;$0003
            CopyDynUnder  4;$1003
            CopyDynUnder  8;$2003
            CopyDynUnder  12;$3003
            CopyDynUnder  16;$4003
            CopyDynUnder  20;$5003
            CopyDynUnder  24;$6003
            CopyDynUnder  28;$7003

            sec
            lda     _JTBL_CACHE
            sbc     #SNIPPET_SIZE
            sta     _JTBL_CACHE

            clc
            lda     _OP_CACHE
            adc     #$0200             ; Advance to the next word
            sta     _OP_CACHE

            CopyDynUnder  2;$0000
            CopyDynUnder  6;$1000
            CopyDynUnder  10;$2000
            CopyDynUnder  14;$3000
            CopyDynUnder  18;$4000
            CopyDynUnder  22;$5000
            CopyDynUnder  26;$6000
            CopyDynUnder  30;$7000

; Now fill in the JMP opcodes
            sep   #$20
            lda   #$4C
            sta:            $0000,y
            sta:            $0003,y
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

            plb
            rts

; Create a masked render based on data in the direct page temporary buffer.
;
; If the MASK is $0000, then insert a PEA
; If the MASK is $FFFF, then insert a LDA DP,x / PHA
; If mixed, create a snippet of LDA DP,x / AND #MASK / ORA #DATA / PHA
; 
; ]1 : sprite buffer offset
; ]2 : code field offset
CopyDynOver mac
            lda   tmp_sprite_mask+{]1}     ; load the mask value
            bne   mixed          ; a non-zero value may be mixed

; This is a solid word
            lda   #$00F4         ; PEA instruction
            sta:  ]2,y
            lda   tmp_sprite_data+{]1}     ; load the sprite data
            sta:  ]2+1,y         ; PEA operand
            bra   next

mixed       cmp   #$FFFF         ; All 1's in the mask is a fully transparent sprite word
            beq   transparent

            lda   #$004C         ; JMP to handler
            sta:  {]2},y
            lda   _JTBL_CACHE    ; Get the offset to the exception handler for this column
            ora   #{]2&$7000}    ; adjust for the current row offset
            sta:  {]2}+1,y
            tax        ; This becomes the new address that we use to patch in

            lda   _OP_CACHE       ; Get the LDA dp,x instruction for this column
            sta:  $0000,x

            lda   #$0029          ; AND #SPRITE_MASK
            sta:  $0002,x
            lda   tmp_sprite_mask+{]1}
            sta:  $0003,x

            lda   #$0009          ; ORA #SPRITE_DATA
            sta:  $0005,x
            lda   tmp_sprite_data+{]1}
            sta:  $0006,x

            lda   #$0D80          ; branch to the prologue (BRA *+15)
            sta:  $0008,x
            bra   next

; This is a transparent word, so just show the dynamic data
transparent
            lda   #$4800          ; Put the PHA in the third byte
            sta:  {]2}+1,y
            lda   _OP_CACHE       ; Store the LDA dp,x instruction with operand
            sta:  {]2},y
next
            <<<

; Masked renderer for a dynamic tile on top of the sprite data.  There are no transparent vs
; solid vs mixed considerations here.  This only sets the JMP address, setting the JMP opcodes
; must happen elsewhere
;
; ]1 : sprite plane offset
; ]2 : code field offset
CopyDynUnder MAC

; Need to fill in the first 9 bytes of the JMP handler with the following code sequence where
; the data and mask from from the sprite plane
;
;            lda  #DATA
;            and  $80,x
;            ora  $00,x
;            bra  *+16

            lda   _JTBL_CACHE     ; Get the offset to the exception handler for this column
            ora   #{]2&$7000}     ; adjust for the current row offset
            sta:  {]2}+1,y
            tax         ; This becomes the new address that we use to patch in

            lda   #$00A9          ; LDA #DATA
            sta:  $0000,x
            lda   tmp_sprite_data+{]1}
            sta:  $0001,x

            lda   _OP_CACHE
            sta:  $0003,x         ; AND $80,x
            eor   #$8020          ; Switch the opcode to an ORA and remove the high bit of the operand
            sta:  $0005,x         ; ORA $00,x

            lda   #$0E80          ; branch to the prologue (BRA *+16)
            sta:  $0007,x
            eom

; Helper functions to move tile data into the dynamic tile space

; Helper functions to copy tile data to the appropriate location in Bank 0
;  X = tile ID
;  Y = dynamic tile ID
CopyTileToDyn 
            txa
            jsr   _GetTileAddr
            tax

            tya
            and   #$001F        ; Maximum of 32 dynamic tiles
            asl
            asl                 ; 4 bytes per page
            adc   BlitterDP               ; Add to the bank 00 base address
            adc   #$0100        ; Go to the next page
            tay
            jsr   CopyTileDToDyn          ; Copy the tile data
            jmp   CopyTileMToDyn          ; Copy the tile mask

;  X = address of tile
;  Y = tile address in bank 0
CopyTileDToDyn
            phb
            pea   $0000
            plb
            plb

            ldal  tiledata+0,x
            sta:  $0000,y
            ldal  tiledata+2,x
            sta:  $0002,y
            ldal  tiledata+4,x
            sta   $0100,y
            ldal  tiledata+6,x
            sta   $0102,y
            ldal  tiledata+8,x
            sta   $0200,y
            ldal  tiledata+10,x
            sta   $0202,y
            ldal  tiledata+12,x
            sta   $0300,y
            ldal  tiledata+14,x
            sta   $0302,y
            ldal  tiledata+16,x
            sta   $0400,y
            ldal  tiledata+18,x
            sta   $0402,y
            ldal  tiledata+20,x
            sta   $0500,y
            ldal  tiledata+22,x
            sta   $0502,y
            ldal  tiledata+24,x
            sta   $0600,y
            ldal  tiledata+26,x
            sta   $0602,y
            ldal  tiledata+28,x
            sta   $0700,y
            ldal  tiledata+30,x
            sta   $0702,y

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
            pea   $0000
            plb
            plb

            ldal  tiledata+32+0,x
            sta:  $0080,y
            ldal  tiledata+32+2,x
            sta:  $0082,y
            ldal  tiledata+32+4,x
            sta   $0180,y
            ldal  tiledata+32+6,x
            sta   $0182,y
            ldal  tiledata+32+8,x
            sta   $0280,y
            ldal  tiledata+32+10,x
            sta   $0282,y
            ldal  tiledata+32+12,x
            sta   $0380,y
            ldal  tiledata+32+14,x
            sta   $0382,y
            ldal  tiledata+32+16,x
            sta   $0480,y
            ldal  tiledata+32+18,x
            sta   $0482,y
            ldal  tiledata+32+20,x
            sta   $0580,y
            ldal  tiledata+32+22,x
            sta   $0582,y
            ldal  tiledata+32+24,x
            sta   $0680,y
            ldal  tiledata+32+26,x
            sta   $0682,y
            ldal  tiledata+32+28,x
            sta   $0780,y
            ldal  tiledata+32+30,x
            sta   $0782,y

            plb
            rts