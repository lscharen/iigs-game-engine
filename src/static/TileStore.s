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
                      dw   ]row*2*TILE_STORE_WIDTH
]row                  equ  ]row+1
                      --^

; Second copy
]row                  equ  0
                      lup  TILE_STORE_HEIGHT
                      TileStoreData ]row*2*TILE_STORE_WIDTH
                      TileStoreData ]row*2*TILE_STORE_WIDTH
                      dw   ]row*2*TILE_STORE_WIDTH
]row                  equ  ]row+1
                      --^

; Last row
                      TileStoreData 0*2*TILE_STORE_WIDTH
                      TileStoreData 0*2*TILE_STORE_WIDTH
                      dw   0*2*TILE_STORE_WIDTH

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
                  lup   26
                  dw    1,1,1,2,2,2,2,2,1,1,1,0,0,0,0,0
                  --^

; Other Toolset variables
OneSecondCounter  ENT
                  dw        0
OldOneSecVec      ENT
                  ds        4
Timers            ENT
                  ds        TIMER_REC_SIZE*MAX_TIMERS
DefaultPalette   ENT
                 dw    $0000,$007F,$0090,$0FF0
                 dw    $000F,$0080,$0f70,$0FFF
                 dw    $0fa9,$0ff0,$00e0,$04DF
                 dw    $0d00,$078f,$0ccc,$0FFF

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
                 dw        320,272,256,256,280,256,240,288,160,288,160,320
ScreenModeHeight ENT
                 dw        200,192,200,176,160,160,160,128,144,192,102,1

; VBuff arrays for each sprite. We need at least a 3x3 block for each sprite and the shape of the
; array must match the TileStore structure.  The TileStore is 41 blocks wide.  To keep things simple
; we allocate 8 sprites in the first row and 8 more sprites in the 4th row.  So we need to allocate a
; total of 6 rows of TileStore space
;
; It is *critical* that this array be placed in a memory location that is greated than the largest
; TileStore offset.
VBuffArray       ENT
                 ds  6*{TILE_STORE_WIDTH*2}

; Convert sprite index to a bit position
_SpriteBits      ENT
                 dw $0001,$0002,$0004,$0008,$0010,$0020,$0040,$0080,$0100,$0200,$0400,$0800,$1000,$2000,$4000,$8000
_SpriteBitsNot   ENT
                 dw $FFFE,$FFFD,$FFFB,$FFF7,$FFEF,$FFDF,$FFBF,$FF7F,$FEFF,$FDFF,$FBFF,$F7FF,$EFFF,$DFFF,$BFFF,$7FFF

; Steps to the different sprite stamps
_stamp_step      ENT
                 dw  0,12,24,36

blt_return
stk_save