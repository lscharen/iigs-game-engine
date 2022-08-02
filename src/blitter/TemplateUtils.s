; Untility function related to patching and manipulating the blitter template code

                   mx    %00

; Generalized routine that calculates the on-screen address of the tiles and takes the 
; StartX and StartY values into consideration.  This routine really exists to support
; the dirty tile rendering mode and the tiles *must* be aligned with the playfield.
; That is, StartX % 4 == 0 and StartY % 8 == 0.  If these conditions are not met, then
; screen will not render correctly.
_RecalcTileScreenAddrs
NextColPtr         equ   tmp0
RowAddrPtr         equ   tmp1
OnScreenAddr       equ   tmp2
Counter            equ   tmp3

                   jsr   _OriginToTileStore          ; Get the (col,row) of the tile in the upper-left corner of the playfield

; Manually add the offsets to the NextCol and TileStoreYTable array address and put in a direct page
; location so we can free up the registers.

                   clc
                   txa
                   adc   #NextCol
                   sta   NextColPtr

                   tya
                   adc   #TileStoreYTable
                   sta   RowAddrPtr

; Calculate the on-screen address of the upper-left corner of the playfiled

                   lda   ScreenY0                   ; Calculate the address of the first byte
                   asl                              ; of the right side of the playfield
                   tax
                   lda   ScreenAddr,x               ; This is the address for the left edge of the physical screen
                   clc
                   adc   ScreenX0
                   sta   OnScreenAddr

; Now, loop through the tile store

                   lda   #MAX_TILES
                   sta   Counter
                   ldy   #0
:tsloop
                   lda   (NextColPtr),y             ; Need to recalculate each time since the wrap-around could
                   clc                              ; happen anywhere
                   adc   (RowAddrPtr)               ;
                   tax                              ; NOTE: Try to rework to use new TileStoreLookup array

                   lda   OnScreenAddr
                   sta   TileStore+TS_SCREEN_ADDR,x

                   clc
                   adc   #4                         ; Go to the next tile

                   iny
                   iny
                   cpy   #2*41                      ; If we've done 41 columns, move to the next line
                   bcc   :nohop

                   inc   RowAddrPtr                 ; Advance the row address (with wrap-around)
                   inc   RowAddrPtr
                   ldy   #0                         ; Reset the column counter
                   clc
                   adc   #{8*160}-{4*41}
:nohop
                   sta   OnScreenAddr               ; Save the updated on-screen address
                   dec   Counter
                   bne   :tsloop

                   rts


; Patch an 8-bit or 16-bit valueS into the bank.  These are a set up unrolled loops to 
; quickly patch in a constant value, or a value from an array into a given set of 
; templates.
;
; Because we have structured everything as parallel code blocks, most updates to the blitter
; reduce to storing a constant value and have an amortized cost of just a single store.
;
; The utility of these routines is that they also handle setting just a range of lines
; within a single bank.
;
; X = number of lines * 2, 0 to 32
; Y = starting line * $1000
; A = value
;
; Set M to 0 or 1
SetConst           mac
                   jmp   (dispTbl,x)
dispTbl            da    bottom-00,bottom-03,bottom-06,bottom-09
                   da    bottom-12,bottom-15,bottom-18,bottom-21
                   da    bottom-24,bottom-27,bottom-30,bottom-33
                   da    bottom-36,bottom-39,bottom-42,bottom-45
                   da    bottom-48
                   sta   $F000,y
                   sta   $E000,y
                   sta   $D000,y
                   sta   $C000,y
                   sta   $B000,y
                   sta   $A000,y
                   sta   $9000,y
                   sta   $8000,y
                   sta   $7000,y
                   sta   $6000,y
                   sta   $5000,y
                   sta   $4000,y
                   sta   $3000,y
                   sta   $2000,y
                   sta   $1000,y
                   sta:  $0000,y
bottom
                   <<<

; SetDPAddrs
;
; A = absolute address (largest)
; Y = offset
;
; Initializes a bank of direct page offsets
SetDPAddrs
                   lda   #$0800
                   sta   $F000,y
                   lda   #$0700
                   sta   $E000,y
                   lda   #$0600
                   sta   $D000,y
                   lda   #$0500
                   sta   $C000,y
                   lda   #$0400
                   sta   $B000,y
                   lda   #$0300
                   sta   $A000,y
                   lda   #$0200
                   sta   $9000,y
                   lda   #$0100
                   sta:  $8000,y

                   lda   #$0800
                   sta   $7000,y
                   lda   #$0700
                   sta   $6000,y
                   lda   #$0600
                   sta   $5000,y
                   lda   #$0500
                   sta   $4000,y
                   lda   #$0400
                   sta   $3000,y
                   lda   #$0300
                   sta   $2000,y
                   lda   #$0200
                   sta   $1000,y
                   lda   #$0100
                   sta:  $0000,y
                   rts

; SetAbsAddrs
;
; A = absolute address (largest)
; Y = offset
; X = number of lines
;
; Stores a value and decrements by $1000 for each line
SetAbsAddrs        sec
                   jmp   (:tbl,x)
:tbl               da    :bottom-00,:bottom-03,:bottom-09,:bottom-15
                   da    :bottom-21,:bottom-27,:bottom-33,:bottom-39
                   da    :bottom-45,:bottom-51,:bottom-57,:bottom-63
                   da    :bottom-69,:bottom-75,:bottom-81,:bottom-87
                   da    :bottom-93
:top               sta   $F000,y
                   sbc   #$1000
                   sta   $E000,y
                   sbc   #$1000
                   sta   $D000,y
                   sbc   #$1000
                   sta   $C000,y
                   sbc   #$1000
                   sta   $B000,y
                   sbc   #$1000
                   sta   $A000,y
                   sbc   #$1000
                   sta   $9000,y
                   sbc   #$1000
                   sta   $8000,y
                   sbc   #$1000
                   sta   $7000,y
                   sbc   #$1000
                   sta   $6000,y
                   sbc   #$1000
                   sta   $5000,y
                   sbc   #$1000
                   sta   $4000,y
                   sbc   #$1000
                   sta   $3000,y
                   sbc   #$1000
                   sta   $2000,y
                   sbc   #$1000
                   sta   $1000,y
                   sbc   #$1000
                   sta:  $0000,y
:bottom            rts

; Fill up a full bank with blitter templates.  Currently we can fit 16 lines per bank, so need
; a total of 13 banks to hold the 208 lines for full-screen support
;
; A = high word of bank table
; Y = index * 4 of the bank to initialize
BuildBank

:bankArray         equ   tmp0
:target            equ   tmp2
:nextBank          equ   tmp4
:entryOffset       equ   tmp6

                   stx   :bankArray
                   sta   :bankArray+2

                   stz   :target
                   iny
                   iny
                   lda   [:bankArray],y
                   sta   :target+2

                   iny                              ; move to the next item
                   iny
                   iny                              ; middle byte
                   cpy   #4*13                      ; if greater than the array length, wrap back to zero
                   bcc   :ok
                   ldy   #1
:ok                lda   [:bankArray],y             ; Get the middle and high bytes of the address
                   sta   :nextBank

:next
                   jsr   :BuildLine2
                   lda   :target
                   clc
                   adc   #$1000
                   sta   :target
                   bcc   :next

                   phb
                   pei   :target+1
                   plb
                   plb

; Change the patched value to one of BANK_ENTRY, DP_ENTRY, TWO_LYR_ENTRY or ONE_LYR_ENTRY based
; on the capabilities that the engine needs.

                   lda   #DP_ENTRY
                   sta   :entryOffset
                   lda   EngineMode
                   bne   :not_simple
                   lda   #ONE_LYR_ENTRY
                   sta   :entryOffset
:not_simple

                   lda   #$F000                        ; Set the address from each line to the next
                   ora   :entryOffset
                   ldy   #CODE_EXIT+1
                   ldx   #15*2
                   jsr   SetAbsAddrs

                   ldy   #DP_ADDR
                   jsr   SetDPAddrs

                   ldy   #$F000+CODE_EXIT           ; Patch the last line with a JML to go to the next bank
                   lda   :entryOffset
                   xba
                   ora   #$005C
                   sta   [:target],y
                   ldy   #$F000+CODE_EXIT+2
                   lda   :nextBank
                   sta   [:target],y

                   ldy   #$8000+CODE_EXIT           ; Patch one line per bank to enable interrupts
                   lda   #{$004C+{ENABLE_INT}*256}
                   sta   [:target],y

                   plb
                   rts

; This is the relocation subroutine, it is responsible for copying the template to a
; memory location and patching up the necessary instructions.
;
; X = low word of address (must be a multiple of $1000)
; A = high word of address (bank)
:BuildLine
                   stx   :target
                   sta   :target+2

:BuildLine2
                   phb                              ; save bank and reset to the code bank because
                   phk                              ; the template is part of this bank
                   plb

                   lda   #CODE_LEN                  ; round up to an even number of bytes
                   inc
                   and   #$FFFE
                   beq   :nocopy
                   dec
                   dec
                   tay
:loop              lda   base,y
                   sta   [:target],y

                   dey
                   dey
                   bpl   :loop

:nocopy            lda   #0                         ; copy is complete, now patch up the addresses
                   sep   #$20

                   ldx   #0
                   lda   :target+2                  ; patch in the bank for the absolute long addressing mode
:dobank            ldy   BankPatches,x
                   sta   [:target],y
                   inx
                   inx
                   cpx   #BankPatchNum
                   bcc   :dobank

                   ldx   #0
:dopage            ldy   PagePatches,x              ; patch the page addresses by adding the page offset to each
                   lda   [:target],y
                   clc
                   adc   :target+1
                   sta   [:target],y
                   inx
                   inx
                   cpx   #PagePatchNum
                   bcc   :dopage

                   rep   #$20
                   plb
                   rts