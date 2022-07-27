; Bank of memory that holds the core sprite and tile store data structures

                put  ../Defs.s
                put  TileStoreDefs.s

;-------------------------------------------------------------------------------------
;
                put  ../blitter/Template.s

;-------------------------------------------------------------------------------------

TileStore      ENT
               ds   {TILE_STORE_SIZE*TILE_STORE_NUM}

;-------------------------------------------------------------------------------------
;
; A list of dirty tiles that need to be updated in a given frame

               ds    \,$00             ; pad to the next page boundary
DirtyTileCount ENT
               ds   2
DirtyTiles     ENT
               ds   TILE_STORE_SIZE    ; At most this many tiles can possibly be updated at once

;-------------------------------------------------------------------------------------
;

               ds  \,$00             ; pad to the next page boundary
_Sprites       ENT
               ds  SPRITE_REC_SIZE*MAX_SPRITES

;-------------------------------------------------------------------------------------
;
; A double-sized table of lookup values.  It is double-width and double-height so that,
; if we know a tile's address position of (X + 41*Y), then any relative tile store address
; can be looked up by adding a constant value.
                      ds  \,$00             ; pad to the next page boundary
TileStoreLookupYTable ENT
]line                 equ  0
                      lup  TS_LOOKUP_HEIGHT
                      dw   ]line
]line                 equ  ]line+{2*TS_LOOKUP_SPAN}
                      --^

; Width of tile store is 41 elements
TileStoreData mac
              dw  ]1+0,]1+2,]1+4,]1+6,]1+8,]1+10,]1+12,]1+14
              dw  ]1+16,]1+18,]1+20,]1+22,]1+24,]1+26,]1+28,]1+30
              dw  ]1+32,]1+34,]1+36,]1+38,]1+40,]1+42,]1+44,]1+46
              dw  ]1+48,]1+50,]1+52,]1+54,]1+56,]1+58,]1+60,]1+62
              dw  ]1+64,]1+66,]1+68,]1+70,]1+72,]1+74,]1+76,]1+78
              dw  ]1+80
              <<<
; Create a lookup table with two runs of offsets, plus an overlap area on the end (41+41+1 = 83 = TS_LOOKUP_SPAN)
TileStoreLookup       ENT

; First copy
]row                  equ  0
                      lup  TILE_STORE_HEIGHT
                      TileStoreData ]row*2*TILE_STORE_WIDTH
                      TileStoreData ]row*2*TILE_STORE_WIDTH
                      dw   ]row*2*TILE_STORE_WIDTH,]row*2*TILE_STORE_WIDTH+2
]row                  equ  ]row+1
                      --^

; Second copy
]row                  equ  0
                      lup  TILE_STORE_HEIGHT
                      TileStoreData ]row*2*TILE_STORE_WIDTH
                      TileStoreData ]row*2*TILE_STORE_WIDTH
                      dw   ]row*2*TILE_STORE_WIDTH,]row*2*TILE_STORE_WIDTH+2
]row                  equ  ]row+1
                      --^

; Last two rows
                      TileStoreData 0*2*TILE_STORE_WIDTH
                      TileStoreData 0*2*TILE_STORE_WIDTH
                      dw   0*2*TILE_STORE_WIDTH,0*2*TILE_STORE_WIDTH+2
                      TileStoreData 1*2*TILE_STORE_WIDTH
                      TileStoreData 1*2*TILE_STORE_WIDTH
                      dw   1*2*TILE_STORE_WIDTH,1*2*TILE_STORE_WIDTH+2

;-------------------------------------------------------------------------------------
;
; Other data tables

; Col2CodeOffset
;
; Takes a column number (0 - 81) and returns the offset into the blitter code
; template.
;
; This is used for rendering tile data into the code field. For example, is we assume that
; we are filling in the operands for a bunch of PEA values, we could do this
;
;  ldy tileColumn*2
;  lda #DATA
;  ldx Col2CodeOffset,y
;  sta $0001,x 
;
; The table values are pre-reversed so that loop can go in logical order 0, 2, 4, ...
; and the resulting offsets will map to the code instructions in right-to-left order.
;
; Remember, because the data is pushed on to the stack, the last instruction, which is
; in the highest memory location, pushed data that apepars on the left edge of the screen.

]step             equ   0
                  dw    CODE_TOP    ; There is a spot where we load Col2CodeOffet-2,x
Col2CodeOffset    ENT
                  lup   82
                  dw    CODE_TOP+{{81-]step}*PER_TILE_SIZE}
]step             equ   ]step+1
                  --^
                  dw    CODE_TOP+{81*PER_TILE_SIZE}

; A parallel table to Col2CodeOffset that holds the offset to the exception handler address for each column
]step             equ   0
                  dw    SNIPPET_BASE
JTableOffset      ENT
                  lup   82
                  dw    SNIPPET_BASE+{{81-]step}*SNIPPET_SIZE}
]step             equ   ]step+1
                  --^
                  dw    SNIPPET_BASE+{81*SNIPPET_SIZE}

; Table of BRA instructions that are used to exit the code field.  Separate tables for
; even and odd aligned cases.
;
; The even exit point is closest to the code field. The odd exit point is 3 bytes further
;
; These tables are reversed to be parallel with the JTableOffset and Col2CodeOffset tables above.  The
; physical word index that each instruction is intended to be placed at is in the comment.
CodeFieldEvenBRA  ENT
                  bra   *+6         ; 81 -- need to skip over the JMP loop that passed control back
                  bra   *+9         ; 80
                  bra   *+12        ; 79
                  bra   *+15        ; 78
                  bra   *+18        ; 77
                  bra   *+21        ; 76
                  bra   *+24        ; 75
                  bra   *+27        ; 74
                  bra   *+30        ; 73
                  bra   *+33        ; 72
                  bra   *+36        ; 71
                  bra   *+39        ; 70
                  bra   *+42        ; 69
                  bra   *+45        ; 68
                  bra   *+48        ; 67
                  bra   *+51        ; 66
                  bra   *+54        ; 65
                  bra   *+57        ; 64
                  bra   *+60        ; 63
                  bra   *+63        ; 62
                  bra   *+66        ; 61
                  bra   *+69        ; 60
                  bra   *+72        ; 59
                  bra   *+75        ; 58
                  bra   *+78        ; 57
                  bra   *+81        ; 56
                  bra   *+84        ; 55
                  bra   *+87        ; 54
                  bra   *+90        ; 53
                  bra   *+93        ; 52
                  bra   *+96        ; 51
                  bra   *+99        ; 50
                  bra   *+102       ; 49
                  bra   *+105       ; 48
                  bra   *+108       ; 47
                  bra   *+111       ; 46
                  bra   *+114       ; 45
                  bra   *+117       ; 44
                  bra   *+120       ; 43
                  bra   *+123       ; 42
                  bra   *+126       ; 41
                  bra   *-123       ; 40
                  bra   *-120       ; 39
                  bra   *-117       ; 38
                  bra   *-114       ; 37
                  bra   *-111       ; 36
                  bra   *-108       ; 35
                  bra   *-105       ; 34
                  bra   *-102       ; 33
                  bra   *-99        ; 32
                  bra   *-96        ; 31
                  bra   *-93        ; 30
                  bra   *-90        ; 29
                  bra   *-87        ; 28
                  bra   *-84        ; 27
                  bra   *-81        ; 26
                  bra   *-78        ; 25
                  bra   *-75        ; 24
                  bra   *-72        ; 23
                  bra   *-69        ; 22
                  bra   *-66        ; 21
                  bra   *-63        ; 20
                  bra   *-60        ; 19
                  bra   *-57        ; 18
                  bra   *-54        ; 17
                  bra   *-51        ; 16
                  bra   *-48        ; 15
                  bra   *-45        ; 14
                  bra   *-42        ; 13
                  bra   *-39        ; 12
                  bra   *-36        ; 11
                  bra   *-33        ; 10
                  bra   *-30        ; 9
                  bra   *-27        ; 8
                  bra   *-24        ; 7
                  bra   *-21        ; 6
                  bra   *-18        ; 5
                  bra   *-15        ; 4
                  bra   *-12        ; 3
                  bra   *-9         ; 2
                  bra   *-6         ; 1
                  bra   *-3         ; 0

CodeFieldOddBRA   ENT
                  bra   *+9         ; 81 -- need to skip over two JMP instructions
                  bra   *+12        ; 80
                  bra   *+15        ; 79
                  bra   *+18        ; 78
                  bra   *+21        ; 77
                  bra   *+24        ; 76
                  bra   *+27        ; 75
                  bra   *+30        ; 74
                  bra   *+33        ; 73
                  bra   *+36        ; 72
                  bra   *+39        ; 71
                  bra   *+42        ; 70
                  bra   *+45        ; 69
                  bra   *+48        ; 68
                  bra   *+51        ; 67
                  bra   *+54        ; 66
                  bra   *+57        ; 65
                  bra   *+60        ; 64
                  bra   *+63        ; 64
                  bra   *+66        ; 62
                  bra   *+69        ; 61
                  bra   *+72        ; 60
                  bra   *+75        ; 59
                  bra   *+78        ; 58
                  bra   *+81        ; 57
                  bra   *+84        ; 56
                  bra   *+87        ; 55
                  bra   *+90        ; 54
                  bra   *+93        ; 53
                  bra   *+96        ; 52
                  bra   *+99        ; 51
                  bra   *+102       ; 50
                  bra   *+105       ; 49
                  bra   *+108       ; 48
                  bra   *+111       ; 47
                  bra   *+114       ; 46
                  bra   *+117       ; 45
                  bra   *+120       ; 44
                  bra   *+123       ; 43
                  bra   *+126       ; 42
                  bra   *+129       ; 41
                  bra   *-126       ; 40
                  bra   *-123       ; 39
                  bra   *-120       ; 38
                  bra   *-117       ; 37
                  bra   *-114       ; 36
                  bra   *-111       ; 35
                  bra   *-108       ; 34
                  bra   *-105       ; 33
                  bra   *-102       ; 32
                  bra   *-99        ; 31
                  bra   *-96        ; 30
                  bra   *-93        ; 29
                  bra   *-90        ; 28
                  bra   *-87        ; 27
                  bra   *-84        ; 26
                  bra   *-81        ; 25
                  bra   *-78        ; 24
                  bra   *-75        ; 23
                  bra   *-72        ; 22
                  bra   *-69        ; 21
                  bra   *-66        ; 20
                  bra   *-63        ; 19
                  bra   *-60        ; 18
                  bra   *-57        ; 17
                  bra   *-54        ; 16
                  bra   *-51        ; 15
                  bra   *-48        ; 14
                  bra   *-45        ; 13
                  bra   *-42        ; 12
                  bra   *-39        ; 11
                  bra   *-36        ; 10
                  bra   *-33        ; 9
                  bra   *-30        ; 8
                  bra   *-27        ; 7
                  bra   *-24        ; 6
                  bra   *-21        ; 5
                  bra   *-18        ; 4
                  bra   *-15        ; 3
                  bra   *-12        ; 2
                  bra   *-9         ; 1
                  bra   *-6         ; 0 -- branch back 6 to skip the JMP even path

]step             equ   $2000
ScreenAddr        ENT
                  lup   200
                  dw    ]step
]step             =     ]step+160
                  --^

; Table of offsets into each row of a Tile Store table.  We currently have two tables defined; one
; that is the backing store for the tiles rendered into the code field, and another that holds 
; backlink information on the sprite entries that overlap various tiles.
;
; This table is double-length to support accessing off the end modulo its legth
TileStoreYTable   ENT
]step             equ   0
                  lup   26
                  dw    ]step
]step             =     ]step+{41*2}
                  --^
]step             equ   0
                  lup   26
                  dw    ]step
]step             =     ]step+{41*2}
                  --^

; Create a table to look up the "next" column with modulo wraparound.  Basically a[i] = i
; and the table is double-length.  Use constant offsets to pick an amount to advance
NextCol           ENT
]step             equ   0
                  lup   41
                  dw    ]step
]step             =     ]step+2
                  --^
]step             equ   0
                  lup   41
                  dw    ]step
]step             =     ]step+2
                  --^

; This is a double-length table that holds the right-edge adresses of the playfield on the physical
; screen.  At most, it needs to hold 200 addresses for a full height playfield.  It is double-length
; so that code can pick any offset and copy values without needing to check for a wrap-around. If the
; playfield is less than 200 lines tall, then any values after 2 * PLAYFIELD_HEIGHT are undefined.
RTable            ENT
                  ds    400
                  ds    400

; Array of addresses for the banks that hold the blitter. 
BlitBuff          ENT
                  ds    4*13

; The blitter table (BTable) is a double-length table that holds the full 4-byte address of each
; line of the blit fields.  We decompose arrays of pointers into separate high and low words so
; that everything can use the same indexing offsets
BTableHigh        ENT
                  ds    208*2*2
BTableLow         ENT
                  ds    208*2*2

; A shorter table that just holds the blitter row addresses
BRowTableHigh     ENT
                  ds    26*2*2
BRowTableLow      ENT
                  ds    26*2*2

; A double-length table of addresses for the BG1 bank.  The BG1 buffer is 208 rows of 256 bytes each and
; the first row starts $1800 bytes in to center the buffer in the bank
]step             equ   $1800
BG1YTable         ENT
                  lup   208
                  dw    ]step
]step             =     ]step+256
                  --^
]step             equ   256
                  lup   208
                  dw    ]step
]step             =     ]step+256
                  --^

; Repeat
BG1YOffsetTable   ENT
                  lup   2
                  dw    1,1,1,2,2,2,2,2,1,1,1,0,0,0,0,0
;                  dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                  --^

; Other Toolset variables
OneSecondCounter  ENT
                  dw        0
OldOneSecVec      ENT
                  ds        4
Timers            ENT
                  ds        TIMER_REC_SIZE*MAX_TIMERS
Overlays          ENT
                  dw        0     ; count
                  ds        8     ; only support one or now (start_line, end_line, function call)

; From the IIgs ref 
DefaultPalette   ENT
                 dw    $0000,$0777,$0841,$072C
                 dw    $000F,$0080,$0F70,$0D00
                 dw    $0FA9,$0FF0,$00E0,$04DF
                 dw    $0DAF,$078F,$0CCC,$0FFF

;  0. Full Screen           : 40 x 25   320 x 200 (32,000 bytes (100.0%)) 
;  1. Sword of Sodan        : 34 x 24   272 x 192 (26,112 bytes ( 81.6%))
;  2. ~NES                  : 32 x 25   256 x 200 (25,600 bytes ( 80.0%))
;  3. Task Force            : 32 x 22   256 x 176 (22,528 bytes ( 70.4%))
;  4. Defender of the World : 35 x 20   280 x 160 (22,400 bytes ( 70.0%))
;  5. Rastan                : 32 x 20   256 x 160 (20,480 bytes ( 64.0%))
;  6. Game Boy Advanced     : 30 x 20   240 x 160 (19,200 bytes ( 60.0%))
;  7. Ancient Land of Y's   : 36 x 16   288 x 128 (18,432 bytes ( 57.6%))
;  8. Game Boy Color        : 20 x 18   160 x 144 (11,520 bytes ( 36.0%))
;  9. Agony (Amiga)         : 36 x 24   288 x 192 (27,648 bytes ( 86.4%))
; 10. Atari Lynx            : 20 x 13   160 x 102 (8,160 bytes  ( 25.5%))
ScreenModeWidth  ENT
                 dw        160,136,128,128,140,128,120,144,80,144,80,160
ScreenModeHeight ENT
                 dw        200,192,200,176,160,160,160,128,144,192,102,1

; VBuff arrays for each sprite. We need at least a 3x3 block for each sprite and the shape of the
; array must match the TileStore structure.  The TileStore is 41 blocks wide. 
;
; It is *critical* that this array be placed in a memory location that is greater than the largest
; TileStore offset because the engine maintaines a per-sprite pointer equal to the VBuff array
; address minut the TileStore offset for the top-left corner of that sprite.  This allows all of
; the sprites to share the same table, but the result of the subtraction has to be positive.
;
; Each block of data contains fixed offsets for the relative position of vbuff addresses.  There
; are multiple copies of the array to handle cases where a sprite needs to transition across the
; boundary.
;
; For example. If a sprite is drawn in the last column, but is two blocks wide, the TileIndex
; value for the first column is $52 and the second column is $00.  Since the pointer to the
; VBuffArray is pre-adjusted by the first column's size, the first offset value will be read
; from (VBuffArray - $52)[$52] = VBuffArray[0], which is correct.  However, the second column will be
; read from (VBuffArray - $52)[$00] which is one row off from the correct value's location.
;
; The wrapping also need to account for vertical wrapping. Consider a 16x16 sprite with its top-left
; conder inside the physical tile that is the bottom-right-most tile in the Tile Store.  So, the
; lookup index for this tile is (26*41*2)-2 = 2130.  When using the lookup table, each step to the
; right or down will cause wrap-around.  So the lookup addresses look like this
;
;   +------+------+     +------+------+
;   | $852 | $800 |     | $000 | $004 |
;   +------+------+ --> +------+------+
;   | $052 | $000 |     | $030 | $034 |
;   +------+------+     +------+------+
;
; We need to maintain 9 different lookup table variations, which is equal to the number of tile
; in the largest sprite (3x3 tiles = 9 different border cases)

;COL_BYTES        equ 4                                   ; VBUFF_TILE_COL_BYTES
;ROW_BYTES        equ 384                                 ; VBUFF_TILE_ROW_BYTES

; Define the offset values
;___NA_NA___      equ 0
;ROW_0_COL_0      equ {{0*COL_BYTES}+{0*ROW_BYTES}}
;ROW_0_COL_1      equ {{1*COL_BYTES}+{0*ROW_BYTES}}
;ROW_0_COL_2      equ {{2*COL_BYTES}+{0*ROW_BYTES}}
;ROW_1_COL_0      equ {{0*COL_BYTES}+{1*ROW_BYTES}}
;ROW_1_COL_1      equ {{1*COL_BYTES}+{1*ROW_BYTES}}
;ROW_1_COL_2      equ {{2*COL_BYTES}+{1*ROW_BYTES}}
;ROW_2_COL_0      equ {{0*COL_BYTES}+{2*ROW_BYTES}}
;ROW_2_COL_1      equ {{1*COL_BYTES}+{2*ROW_BYTES}}
;ROW_2_COL_2      equ {{2*COL_BYTES}+{2*ROW_BYTES}}

; Allocate an amount of space equal to a TileStore block because we could have vertical wrap around.
; The rest of the values are in just the first few rows following this block
;
; The first block of 4 values is the "normal" case, (X in [0, N-3], Y in [0, M-3]), so no wrap around is needed
; The second block is (X = N-1, Y in [0, M-3])
; The third block is (X = N-2, Y in [0, M-3])
; The fourth block is (X in [0, N-3], Y = M-1)
; The fifth block is (X = N-1, Y = M-1)
; The sixth block is (X = N-2, Y = M-1)
; The seventh block is (X in [0, N-3], Y = M-2)
; The eighth block is (X = N-1, Y = M-2)
; The ninth block is (X = N-2, Y = M-2)

VBuffVertTableSelect ENT                            ; 51 entries
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,48,24
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,48,24
VBuffHorzTableSelect ENT
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,16,8
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,0
                  dw 0,0,0,0,0,0,0,0,0,16,8

VBuffStart        ds  TILE_STORE_SIZE
VBuffArray        ENT
                  ds  {TILE_STORE_WIDTH*2}*3

; Convert sprite index to a bit position
_SpriteBits      ENT
                 dw $0001,$0002,$0004,$0008,$0010,$0020,$0040,$0080,$0100,$0200,$0400,$0800,$1000,$2000,$4000,$8000
_SpriteBitsNot   ENT
                 dw $FFFE,$FFFD,$FFFB,$FFF7,$FFEF,$FFDF,$FFBF,$FF7F,$FEFF,$FDFF,$FBFF,$F7FF,$EFFF,$DFFF,$BFFF,$7FFF

; Steps to the different sprite stamps
_stamp_step      ENT
                 dw  0,12,24,36

BG1YCache        ENT
                 ds  32

; Scaling tables for the BG1 rotation tables.
ScalingTables    ENT
                 dw  Scale0,Scale1,Scale2,Scale3
                 dw  Scale4,Scale5,Scale6,Scale7
                 dw  Scale8,Scale9,Scale10,Scale11
                 dw  Scale12,Scale13,Scale14,Scale15

Scale0   dw $0050,$0054,$0058,$005C,$0060,$0064,$0068,$006C,$0070,$0074,$0078,$007C,$0080,$0084,$0088,$008C,$0090,$0094,$0098,$009C,$00A0,$0002,$0006,$000A,$000E,$0012,$0016,$001A,$001E,$0022,$0026,$002A,$002E,$0032,$0036,$003A,$003E,$0042,$0046,$004A,$004E,$0052,$0056,$005A,$005E,$0062,$0066,$006A,$006E,$0072,$0076,$007A,$007E,$0082,$0086,$008A,$008E,$0092,$0096,$009A,$009E,$00A2,$0004,$0008,$000C,$0010,$0014,$0018,$001C,$0020,$0024,$0028,$002C,$0030,$0034,$0038,$003C,$0040,$0044,$0048,$004C,$0050  
Scale1   dw $0072,$0074,$0078,$007A,$007E,$0082,$0084,$0088,$008A,$008E,$0092,$0094,$0098,$009A,$009E,$0000,$0002,$0006,$0008,$000C,$000E,$0012,$0016,$0018,$001C,$001E,$0022,$0026,$0028,$002C,$002E,$0032,$0036,$0038,$003C,$003E,$0042,$0044,$0048,$004C,$004E,$0052,$0054,$0058,$005C,$005E,$0062,$0064,$0068,$006A,$006E,$0072,$0074,$0078,$007A,$007E,$0082,$0084,$0088,$008A,$008E,$0092,$0094,$0098,$009A,$009E,$00A0,$0002,$0006,$0008,$000C,$000E,$0012,$0016,$0018,$001C,$001E,$0022,$0026,$0028,$002C,$002E  
Scale2   dw $0086,$0088,$008C,$008E,$0090,$0094,$0096,$0098,$009C,$009E,$00A0,$0002,$0004,$0006,$000A,$000C,$000E,$0012,$0014,$0016,$001A,$001C,$001E,$0022,$0024,$0026,$002A,$002C,$002E,$0032,$0034,$0036,$003A,$003C,$003E,$0042,$0044,$0046,$004A,$004C,$004E,$0052,$0054,$0056,$005A,$005C,$005E,$0062,$0064,$0066,$006A,$006C,$006E,$0072,$0074,$0076,$007A,$007C,$007E,$0082,$0084,$0086,$008A,$008C,$008E,$0092,$0094,$0096,$009A,$009C,$009E,$00A2,$0002,$0004,$0008,$000A,$000C,$0010,$0012,$0014,$0018,$001A  
Scale3   dw $0094,$0098,$009A,$009C,$009E,$00A0,$0000,$0002,$0006,$0008,$000A,$000C,$000E,$0010,$0014,$0016,$0018,$001A,$001C,$001E,$0020,$0024,$0026,$0028,$002A,$002C,$002E,$0030,$0034,$0036,$0038,$003A,$003C,$003E,$0042,$0044,$0046,$0048,$004A,$004C,$004E,$0052,$0054,$0056,$0058,$005A,$005C,$005E,$0062,$0064,$0066,$0068,$006A,$006C,$0070,$0072,$0074,$0076,$0078,$007A,$007C,$0080,$0082,$0084,$0086,$0088,$008A,$008C,$0090,$0092,$0094,$0096,$0098,$009A,$009E,$00A0,$00A2,$0002,$0004,$0006,$0008,$000C  
Scale4   dw $0000,$0002,$0004,$0006,$0008,$000A,$000C,$000E,$0010,$0012,$0014,$0016,$0018,$001A,$001C,$001E,$0020,$0022,$0024,$0026,$0028,$002A,$002C,$002E,$0030,$0032,$0034,$0036,$0038,$003A,$003C,$003E,$0040,$0042,$0044,$0046,$0048,$004A,$004C,$004E,$0050,$0052,$0054,$0056,$0058,$005A,$005C,$005E,$0060,$0062,$0064,$0066,$0068,$006A,$006C,$006E,$0070,$0072,$0074,$0076,$0078,$007A,$007C,$007E,$0080,$0082,$0084,$0086,$0088,$008A,$008C,$008E,$0090,$0092,$0094,$0096,$0098,$009A,$009C,$009E,$00A0,$00A2  
Scale5   dw $0008,$000A,$000C,$000E,$0010,$0010,$0012,$0014,$0016,$0018,$001A,$001C,$001E,$0020,$0020,$0022,$0024,$0026,$0028,$002A,$002C,$002E,$0030,$0030,$0032,$0034,$0036,$0038,$003A,$003C,$003E,$0040,$0040,$0042,$0044,$0046,$0048,$004A,$004C,$004E,$0050,$0050,$0052,$0054,$0056,$0058,$005A,$005C,$005E,$0060,$0060,$0062,$0064,$0066,$0068,$006A,$006C,$006E,$0070,$0070,$0072,$0074,$0076,$0078,$007A,$007C,$007E,$0080,$0080,$0082,$0084,$0086,$0088,$008A,$008C,$008E,$0090,$0090,$0092,$0094,$0096,$0098  
Scale6   dw $0010,$0010,$0012,$0014,$0016,$0018,$0018,$001A,$001C,$001E,$0020,$0020,$0022,$0024,$0026,$0028,$0028,$002A,$002C,$002E,$0030,$0030,$0032,$0034,$0036,$0038,$0038,$003A,$003C,$003E,$0040,$0040,$0042,$0044,$0046,$0048,$0048,$004A,$004C,$004E,$0050,$0050,$0052,$0054,$0056,$0058,$0058,$005A,$005C,$005E,$0060,$0060,$0062,$0064,$0066,$0068,$0068,$006A,$006C,$006E,$0070,$0070,$0072,$0074,$0076,$0078,$0078,$007A,$007C,$007E,$0080,$0080,$0082,$0084,$0086,$0088,$0088,$008A,$008C,$008E,$0090,$0090  
Scale7   dw $0016,$0016,$0018,$001A,$001A,$001C,$001E,$0020,$0020,$0022,$0024,$0026,$0026,$0028,$002A,$002A,$002C,$002E,$0030,$0030,$0032,$0034,$0036,$0036,$0038,$003A,$003A,$003C,$003E,$0040,$0040,$0042,$0044,$0046,$0046,$0048,$004A,$004A,$004C,$004E,$0050,$0050,$0052,$0054,$0056,$0056,$0058,$005A,$005A,$005C,$005E,$0060,$0060,$0062,$0064,$0066,$0066,$0068,$006A,$006A,$006C,$006E,$0070,$0070,$0072,$0074,$0076,$0076,$0078,$007A,$007A,$007C,$007E,$0080,$0080,$0082,$0084,$0086,$0086,$0088,$008A,$008A  
Scale8   dw $001A,$001C,$001C,$001E,$0020,$0020,$0022,$0024,$0024,$0026,$0028,$0028,$002A,$002C,$002C,$002E,$0030,$0030,$0032,$0034,$0034,$0036,$0038,$0038,$003A,$003C,$003C,$003E,$0040,$0040,$0042,$0044,$0044,$0046,$0048,$0048,$004A,$004C,$004C,$004E,$0050,$0050,$0052,$0054,$0054,$0056,$0058,$0058,$005A,$005C,$005C,$005E,$0060,$0060,$0062,$0064,$0064,$0066,$0068,$0068,$006A,$006C,$006C,$006E,$0070,$0070,$0072,$0074,$0074,$0076,$0078,$0078,$007A,$007C,$007C,$007E,$0080,$0080,$0082,$0084,$0084,$0086  
Scale9   dw $0020,$0020,$0022,$0022,$0024,$0026,$0026,$0028,$0028,$002A,$002C,$002C,$002E,$002E,$0030,$0032,$0032,$0034,$0034,$0036,$0038,$0038,$003A,$003A,$003C,$003E,$003E,$0040,$0040,$0042,$0044,$0044,$0046,$0046,$0048,$004A,$004A,$004C,$004C,$004E,$0050,$0050,$0052,$0054,$0054,$0056,$0056,$0058,$005A,$005A,$005C,$005C,$005E,$0060,$0060,$0062,$0062,$0064,$0066,$0066,$0068,$0068,$006A,$006C,$006C,$006E,$006E,$0070,$0072,$0072,$0074,$0074,$0076,$0078,$0078,$007A,$007A,$007C,$007E,$007E,$0080,$0080  
Scale10   dw $0024,$0024,$0026,$0028,$0028,$002A,$002A,$002C,$002C,$002E,$002E,$0030,$0030,$0032,$0034,$0034,$0036,$0036,$0038,$0038,$003A,$003A,$003C,$003C,$003E,$0040,$0040,$0042,$0042,$0044,$0044,$0046,$0046,$0048,$0048,$004A,$004C,$004C,$004E,$004E,$0050,$0050,$0052,$0052,$0054,$0054,$0056,$0058,$0058,$005A,$005A,$005C,$005C,$005E,$005E,$0060,$0060,$0062,$0064,$0064,$0066,$0066,$0068,$0068,$006A,$006A,$006C,$006C,$006E,$0070,$0070,$0072,$0072,$0074,$0074,$0076,$0076,$0078,$0078,$007A,$007C,$007C 
Scale11   dw $0028,$0028,$002A,$002A,$002C,$002C,$002E,$002E,$0030,$0030,$0032,$0032,$0034,$0034,$0036,$0036,$0038,$0038,$003A,$003A,$003C,$003C,$003E,$003E,$0040,$0040,$0042,$0042,$0044,$0044,$0046,$0046,$0048,$0048,$004A,$004A,$004C,$004C,$004E,$004E,$0050,$0050,$0052,$0052,$0054,$0054,$0056,$0056,$0058,$0058,$005A,$005A,$005C,$005C,$005E,$005E,$0060,$0060,$0062,$0062,$0064,$0064,$0066,$0066,$0068,$0068,$006A,$006A,$006C,$006C,$006E,$006E,$0070,$0070,$0072,$0072,$0074,$0074,$0076,$0076,$0078,$0078 
Scale12   dw $0030,$0030,$0032,$0032,$0032,$0034,$0034,$0036,$0036,$0036,$0038,$0038,$003A,$003A,$003A,$003C,$003C,$003E,$003E,$003E,$0040,$0040,$0042,$0042,$0042,$0044,$0044,$0046,$0046,$0046,$0048,$0048,$004A,$004A,$004A,$004C,$004C,$004E,$004E,$004E,$0050,$0050,$0052,$0052,$0052,$0054,$0054,$0056,$0056,$0056,$0058,$0058,$005A,$005A,$005A,$005C,$005C,$005E,$005E,$005E,$0060,$0060,$0062,$0062,$0062,$0064,$0064,$0066,$0066,$0066,$0068,$0068,$006A,$006A,$006A,$006C,$006C,$006E,$006E,$006E,$0070,$0070 
Scale13   dw $0036,$0036,$0036,$0038,$0038,$0038,$003A,$003A,$003A,$003C,$003C,$003C,$003E,$003E,$003E,$0040,$0040,$0040,$0042,$0042,$0042,$0044,$0044,$0044,$0046,$0046,$0046,$0048,$0048,$0048,$004A,$004A,$004A,$004C,$004C,$004C,$004E,$004E,$004E,$0050,$0050,$0050,$0052,$0052,$0052,$0054,$0054,$0054,$0056,$0056,$0056,$0058,$0058,$0058,$005A,$005A,$005A,$005C,$005C,$005C,$005E,$005E,$005E,$0060,$0060,$0060,$0062,$0062,$0062,$0064,$0064,$0064,$0066,$0066,$0066,$0068,$0068,$0068,$006A,$006A,$006A,$006C 
Scale14   dw $0038,$003A,$003A,$003A,$003C,$003C,$003C,$003C,$003E,$003E,$003E,$0040,$0040,$0040,$0040,$0042,$0042,$0042,$0044,$0044,$0044,$0044,$0046,$0046,$0046,$0048,$0048,$0048,$0048,$004A,$004A,$004A,$004C,$004C,$004C,$004C,$004E,$004E,$004E,$0050,$0050,$0050,$0050,$0052,$0052,$0052,$0054,$0054,$0054,$0054,$0056,$0056,$0056,$0058,$0058,$0058,$0058,$005A,$005A,$005A,$005C,$005C,$005C,$005C,$005E,$005E,$005E,$0060,$0060,$0060,$0060,$0062,$0062,$0062,$0064,$0064,$0064,$0064,$0066,$0066,$0066,$0068 
Scale15   dw $003C,$003C,$003C,$003E,$003E,$003E,$003E,$0040,$0040,$0040,$0040,$0042,$0042,$0042,$0042,$0044,$0044,$0044,$0044,$0046,$0046,$0046,$0046,$0048,$0048,$0048,$0048,$004A,$004A,$004A,$004A,$004C,$004C,$004C,$004C,$004E,$004E,$004E,$004E,$0050,$0050,$0050,$0050,$0052,$0052,$0052,$0052,$0054,$0054,$0054,$0054,$0056,$0056,$0056,$0056,$0058,$0058,$0058,$0058,$005A,$005A,$005A,$005A,$005C,$005C,$005C,$005C,$005E,$005E,$005E,$005E,$0060,$0060,$0060,$0060,$0062,$0062,$0062,$0062,$0064,$0064,$0064 

; List of handles that are allocated in InitMemory so we can explicitly release the handles
NumHandles ENT
           dw 0
Handles    ENT
           ds  4*32

blt_return
stk_save