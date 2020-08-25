; Collection of data tables
;

; Tile2CodeOffset
;
; Takes a tile number (0 - 40) and returns the offset into the blitter code
; template.
;
; This is used for rendering tile data into the code field. For example, is we assume that
; we are filling in the operans for a bunch of PEA values, we could do this
;
;  ldy tileNumber*2
;  lda #DATA
;  ldx Tile2CodeOffset,y
;  sta $0001,x 
;
; This table is necessary, because due to the data being draw via stack instructions, the
; tile order is reversed.

PER_TILE_SIZE     equ   3
]step             equ   0
Tile2CodeOffset   lup   82
                  dw    CODE_TOP+{]step*PER_TILE_SIZE}
]step             equ   ]step+1
                  --^
; Table of BRA instructions that are used to exit the code field.  Separate tables for
; even and odd aligned cases.
;
; The even exit point is closest to the code field. The odd exit point is 3 bytes further
CodeFieldEvenBRA
                  bra   *-3         ; 0
                  bra   *-6         ; 1
                  bra   *-9         ; 2
                  bra   *-12        ; 3
                  bra   *-15        ; 4
                  bra   *-18        ; 5
                  bra   *-21        ; 6
                  bra   *-24        ; 7
                  bra   *-27        ; 8
                  bra   *-30        ; 9
                  bra   *-33        ; 10
                  bra   *-36        ; 11
                  bra   *-39        ; 12
                  bra   *-42        ; 13
                  bra   *-45        ; 14
                  bra   *-48        ; 15
                  bra   *-51        ; 16
                  bra   *-54        ; 17
                  bra   *-57        ; 18
                  bra   *-60        ; 19
                  bra   *-63        ; 20
                  bra   *-66        ; 21
                  bra   *-69        ; 22
                  bra   *-72        ; 23
                  bra   *-75        ; 24
                  bra   *-78        ; 25
                  bra   *-81        ; 26
                  bra   *-84        ; 27
                  bra   *-87        ; 28
                  bra   *-90        ; 29
                  bra   *-93        ; 30
                  bra   *-96        ; 31
                  bra   *-99        ; 32
                  bra   *-102       ; 33
                  bra   *-105       ; 34
                  bra   *-108       ; 35
                  bra   *-111       ; 36
                  bra   *-114       ; 37
                  bra   *-117       ; 38
                  bra   *-120       ; 39
                  bra   *-123       ; 40
                  bra   *+126       ; 41
                  bra   *+123       ; 42
                  bra   *+120       ; 43
                  bra   *+117       ; 44
                  bra   *+114       ; 45
                  bra   *+111       ; 46
                  bra   *+108       ; 47
                  bra   *+105       ; 48
                  bra   *+102       ; 49
                  bra   *+99        ; 50
                  bra   *+96        ; 51
                  bra   *+93        ; 52
                  bra   *+90        ; 53
                  bra   *+87        ; 54
                  bra   *+84        ; 55
                  bra   *+81        ; 56
                  bra   *+78        ; 57
                  bra   *+75        ; 58
                  bra   *+72        ; 59
                  bra   *+69        ; 60
                  bra   *+66        ; 61
                  bra   *+63        ; 62
                  bra   *+60        ; 63
                  bra   *+57        ; 64
                  bra   *+54        ; 65
                  bra   *+51        ; 66
                  bra   *+48        ; 67
                  bra   *+45        ; 68
                  bra   *+42        ; 69
                  bra   *+39        ; 70
                  bra   *+36        ; 71
                  bra   *+33        ; 72
                  bra   *+30        ; 73
                  bra   *+27        ; 74
                  bra   *+24        ; 75
                  bra   *+21        ; 76
                  bra   *+18        ; 77
                  bra   *+15        ; 78
                  bra   *+12        ; 79
                  bra   *+9         ; 80
                  bra   *+6         ; 81 -- need to skip over the JMP loop that passed control back

CodeFieldOddBRA
                  bra   *-6         ; 0 -- branch back 6 to skip the JMP even path
                  bra   *-9         ; 1
                  bra   *-12        ; 2
                  bra   *-15        ; 3
                  bra   *-18        ; 4
                  bra   *-21        ; 5
                  bra   *-24        ; 6
                  bra   *-27        ; 7
                  bra   *-30        ; 8
                  bra   *-33        ; 9
                  bra   *-36        ; 10
                  bra   *-39        ; 11
                  bra   *-42        ; 12
                  bra   *-45        ; 13
                  bra   *-48        ; 14
                  bra   *-51        ; 15
                  bra   *-54        ; 16
                  bra   *-57        ; 17
                  bra   *-60        ; 18
                  bra   *-63        ; 19
                  bra   *-66        ; 20
                  bra   *-69        ; 21
                  bra   *-72        ; 22
                  bra   *-75        ; 23
                  bra   *-78        ; 24
                  bra   *-81        ; 25
                  bra   *-84        ; 26
                  bra   *-87        ; 27
                  bra   *-90        ; 28
                  bra   *-93        ; 29
                  bra   *-96        ; 30
                  bra   *-99        ; 31
                  bra   *-102       ; 32
                  bra   *-105       ; 33
                  bra   *-108       ; 34
                  bra   *-111       ; 35
                  bra   *-114       ; 36
                  bra   *-117       ; 37
                  bra   *-120       ; 38
                  bra   *-123       ; 39
                  bra   *-126       ; 40
                  bra   *+129       ; 41
                  bra   *+126       ; 42
                  bra   *+123       ; 43
                  bra   *+120       ; 44
                  bra   *+117       ; 45
                  bra   *+114       ; 46
                  bra   *+111       ; 47
                  bra   *+108       ; 48
                  bra   *+105       ; 49
                  bra   *+102       ; 50
                  bra   *+99        ; 51
                  bra   *+96        ; 52
                  bra   *+93        ; 53
                  bra   *+90        ; 54
                  bra   *+87        ; 55
                  bra   *+84        ; 56
                  bra   *+81        ; 57
                  bra   *+78        ; 58
                  bra   *+75        ; 59
                  bra   *+72        ; 60
                  bra   *+69        ; 61
                  bra   *+66        ; 62
                  bra   *+63        ; 64
                  bra   *+60        ; 64
                  bra   *+57        ; 65
                  bra   *+54        ; 66
                  bra   *+51        ; 67
                  bra   *+48        ; 68
                  bra   *+45        ; 69
                  bra   *+42        ; 70
                  bra   *+39        ; 71
                  bra   *+36        ; 72
                  bra   *+33        ; 73
                  bra   *+30        ; 74
                  bra   *+27        ; 75
                  bra   *+24        ; 76
                  bra   *+21        ; 77
                  bra   *+18        ; 78
                  bra   *+15        ; 79
                  bra   *+12        ; 80
                  bra   *+9         ; 81 -- need to skip over two JMP instructions
