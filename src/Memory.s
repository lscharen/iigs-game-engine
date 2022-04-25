; Initialize the system for fun!
;
; Mostly memory allocation
;
; * 13 banks of memory for the blitter
; *  1 bank of memory for the second background
; *  1 bank of memory for the second background alt/mask
;
; * $01/2000 - $01/9FFF for the shadow screen
; * $00/2000 - $00/9FFF for the fixed background
;
; * 10 pages of direct page in Bank $00
;   - 1 page for scratch space
;   - 1 page for pointer to the second background
;   - 8 pages for the dynamic tiles

               mx        %00

InitMemory     lda       EngineMode
               bit       #ENGINE_MODE_BNK0_BUFF
               beq       :no_bnk0_buff

               PushLong  #0                          ; space for result
               PushLong  #$008000                    ; size (32k)
               PushWord  UserId
               PushWord  #%11000000_00010111         ; Fixed location
               PushLong  #$002000
               _NewHandle                            ; returns LONG Handle on stack
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               _Deref
               stx       Buff00
               sta       Buff00+2
:no_bnk0_buff

               PushLong  #0                          ; space for result
               PushLong  #$008000                    ; size (32k)
               PushWord  UserId
               PushWord  #%11000000_00010111         ; Fixed location
               PushLong  #$012000
               _NewHandle                            ; returns LONG Handle on stack
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               _Deref
               stx       Buff01
               sta       Buff01+2

               PushLong  #0                          ; space for result

               pea       #0000                       ; size (2 or 10 pages)
               lda       EngineMode
               bit       #ENGINE_MODE_DYN_TILES
               beq       :no_dyn_tiles
               pea       #$0A00                      ; 10 pages if dynamic tiles are enabled
               bra       :dyn_done
:no_dyn_tiles  pea       #$0200                      ; 2 pages if dynamic tiles are disabled
:dyn_done
               PushWord  UserId
               PushWord  #%11000000_00010101         ; Page-aligned, fixed bank
               PushLong  #$000000
               _NewHandle                            ; returns LONG Handle on stack
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               _Deref
               stx       BlitterDP

; Allocate banks of memory for BG1
               lda       EngineMode
               bit       #ENGINE_MODE_TWO_LAYER
               beq       :no_bg1
               jsr       AllocOneBank2
               sta       BG1DataBank

               jsr       AllocOneBank2
               sta       BG1AltBank
:no_bg1

; Allocate the 13 banks of memory we need and store in double-length array
]step          equ       0
               lup       13
               jsr       AllocOneBank2
               sta       BlitBuff+]step+2
               stz       BlitBuff+]step
]step          equ       ]step+4
               --^

; Fill in a table with the adddress of all 208 scanlines across all 13 banks.  Also fill in
; a shorter table that just holds the starting address of the 26 tile block rows.

               ldx       #0
               ldy       #0
:bloop
               lda       BlitBuff+2,y                ; Copy the high word first
]step          equ       0
               lup       16
               sta       BTableHigh+]step,x          ; 16 lines per bank
               sta       BTableHigh+]step+{208*2},x  ; 16 lines per bank
]step          equ       ]step+2
               --^
               lda       BlitBuff,y
               sta       BTableLow,x
               sta       BTableLow+{208*2},x
               clc
]step          equ       2
               lup       15
               adc       #$1000
               sta       BTableLow+]step,x
               sta       BTableLow+]step+{208*2},x
]step          equ       ]step+2
               --^

               txa
               adc       #16*2                       ; move to the next chunk of BTableHigh and BTableLow
               tax

               tya
               adc       #4                          ; move to the next bank address
               tay
               cmp       #4*13
               bcs       :exit1
               brl       :bloop
:exit1


               ldx       #0
               ldy       #0
:bloop2
               lda       BlitBuff+2,y                ; Copy the high word first

               sta       BRowTableHigh,x             ; Two rows per bank
               sta       BRowTableHigh+{26*2},x
               sta       BRowTableHigh+2,x
               sta       BRowTableHigh+{26*2}+2,x

               lda       BlitBuff,y
               sta       BRowTableLow,x
               sta       BRowTableLow+{26*2},x
               clc
               adc       #$8000
               sta       BRowTableLow+2,x
               sta       BRowTableLow+{26*2}+2,x

               txa
               adc       #4
               tax

               tya
               adc       #4                          ; move to the next bank address
               tay
               cmp       #4*13
               bcs       :exit
               brl       :bloop2
:exit
               rts

Buff00         ds        4
Buff01         ds        4

; Bank allocator (for one full, fixed bank of memory. Can be immediately deferenced)

AllocOneBank   PushLong  #0
               PushLong  #$10000
               PushWord  UserId
               PushWord  #%11000000_00011100
               PushLong  #0
               _NewHandle                            ; returns LONG Handle on stack
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               xba                                   ; swap accumulator bytes to XX00	
               sta       :bank+2                     ; store as bank for next op (overwrite $XX00)
:bank          ldal      $000001,X                   ; recover the bank address in A=XX/00	
               rts

; Variation that returns the pointer in the X/A registers (X = low, A = high)
AllocBank      ENT
               phb
               phk
               plb
               jsr       AllocOneBank2
               plb
               rtl

AllocOneBank2  PushLong  #0
               PushLong  #$10000
               PushWord  UserId
               PushWord  #%11000000_00011100
               PushLong  #0
               _NewHandle
               plx                                   ; base address of the new handle
               pla                                   ; high address 00XX of the new handle (bank)
               _Deref
               rts


