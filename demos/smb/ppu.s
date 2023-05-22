; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.


const8  mac
        db    ]1,]1,]1,]1,]1,]1,]1,]1
        <<<

const32 mac
        const8 ]1
        const8 ]1+1
        const8 ]1+2
        const8 ]1+3
        <<<

rep8    mac
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        db     ]1
        <<<

          mx    %11
          dw $a5a5 ; marker to find in memory
ppuaddr   ds 2     ; 16-bit ppu address
w_bit     dw 1     ; currently writing to high or low to the address latch
vram_buff dw 0     ; latched data when reading VRAM ($0000 - $3EFF)

ppuincr   dw 1     ; 1 or 32 depending on bit 2 of PPUCTRL
spadr     dw $0000 ; Sprite pattern table ($0000 or $1000) depending on bit 3 of PPUCTRL
ntaddr    dw $2000 ; Base nametable address ($2000, $2400, $2800, $2C00), bits 0 and 1 of PPUCTRL
bgadr     dw $0000 ; Background pattern table address
ppuctrl   dw 0     ; Copy of the ppu ctrl byte
ppumask   dw 0     ; Copy of the ppu mask byte
ppustatus dw 0
oamaddr   dw 0     ; Typically this will always be 0
ppuscroll dw 0     ; Y X coordinates

ntbase    db $20,$24,$28,$2c

assert_lt mac
        cmp ]1
        bcc ok
        brk ]2
ok
        <<<

assert_x_lt mac
        cpx ]1
        bcc ok
        brk ]2
ok
        <<<

cond    mac
        bit ]1
        beq cond_0
        lda ]3
        bra cond_s
cond_0  lda ]2
cond_s  sta ]4
        <<<

; $2000 - PPUCTRL (Write only)
PPUCTRL_WRITE ENT
        php
        phb
        phk
        plb

        sta  ppuctrl
        phx

; Set the pattern table base address
        and  #$03
        tax
        lda  ntbase,x
        sta  ntaddr+1

; Set the vram increment
        lda  ppuctrl
        cond #$04;#$01;#$20;ppuincr

; Set the sprite table address
        lda  ppuctrl
        cond #$08;#$00;#$10;spadr+1

; Set the background table address
        lda  ppuctrl
        cond #$10;#$00;#$10;bgadr+1

        plx
        lda  ppuctrl
        plb
        plp
        rtl

; $2001 - PPUMASK (Write only)
PPUMASK_WRITE ENT
        stal ppumask
        rtl


; $2002 - PPUSTATUS For "ldx ppustatus"
PPUSTATUS_READ_X ENT
        php
        pha

        lda  #1
        stal w_bit             ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        tax
        and  #$7F              ; Clear the VBL flag
        stal ppustatus

        pla                    ; Restore the accumulator (return value in X)
        plp
        phx                    ; re-read x to set any relevant flags
        plx

        rtl

PPUSTATUS_READ ENT
        php

        lda  #1
        stal w_bit           ; Reset the address latch used by PPUSCROLL and PPUADDR

        ldal ppustatus
        pha
        and  #$7F              ; Clear the VBL flag
        stal ppustatus

        pla                  ; pop the return value
        plp
        pha                  ; re-read accumulator to set any relevant flags
        pla
        rtl

; $2003
OAMADDR_WRITE ENT
        stal oamaddr
        rtl

; $2005 - PPU SCROLL
PPUSCROLL_WRITE ENT
        php
        phb
        phk
        plb
        phx
        pha

        ldx  w_bit
        sta  ppuscroll,x
        txa
        eor  #$01
        sta  w_bit

        pla
        plx
        plb
        plp
        rtl

; $2006 - PPUADDR
PPUADDR_WRITE ENT
        php
        phb
        phk
        plb
        phx
        pha

        ldx  w_bit
        sta  ppuaddr,x
;        assert_lt #$40;$D0
        txa
        eor  #$01
        sta  w_bit

        pla
        plx
        plb
        plp
        rtl


; 2007 - PPUDATA (Read/Write)
;
; If reading from the $0000 - $3EFF range, the value from vram_buff is returned and the actual data is loaded
; post-fetch.
PPUDATA_READ ENT
        php
        phb
        phk
        plb
        phx

        rep  #$30       ; do a 16-bit update of the address
        ldx  ppuaddr
        txa
;        assert_lt #$4000;$d1

        clc
        adc  ppuincr
        sta  ppuaddr
        sep  #$20       ; back to 8-bit acc for the read itself

        cpx  #$3F00     ; check which range of memory we are accessing?
        bcc  :buff_read

        lda  PPU_MEM,x
        bra  :out

:buff_read
        lda  vram_buff  ; read from the buffer
        pha
        lda  PPU_MEM,x  ; put the data in the buffer for the next read
        sta  vram_buff
        pla             ; pop the return value

:out
        sep #$10
        plx
        plb
        plp

        pha
        pla
        rtl

nt_queue_front dw 0
nt_queue_end   dw 0
nt_queue       ds 2*{NT_QUEUE_SIZE}

PPUDATA_WRITE ENT
        php
        phb
        phk
        plb
        pha
        phx

        rep  #$10
        ldx  ppuaddr
        cmp  PPU_MEM,x
        beq  :nochange

        sta  PPU_MEM,x

        rep  #$30
        txa
        clc
        adc  ppuincr
        sta  ppuaddr

; Anything between $2000 and $3000, we need to add to the queue.  We can't reject updates here because we may not
; actually update the GTE tile store for several game frames and the position of the tile within the tile store
; may change if the screen is scrolling

        cpx  #$3000
        bcs  :nocache
        cpx  #$2000
        bcc  :nocache

        phy
        lda  nt_queue_end
        tay
        inc
        inc
        and  #NT_QUEUE_MOD
        cmp  nt_queue_front
        beq  :full

        sta  nt_queue_end
        txa
        sta  nt_queue,y

:full
        lda  #1
        jsr  setborder
        ply

:nocache
        cpx  #$3F00
        bcs  :extra
        bra  :done

:nochange
        rep  #$30
        txa
        clc
        adc  ppuincr
        sta  ppuaddr

:done
        sep  #$30
        plx
        pla
        plb
        plp
        rtl


setborder
        php
        sep  #$20
        eorl $E0C034
        and  #$F0
        eorl $E0C034
        stal $E0C034
        plp
        rts
; Do some extra work to keep palette data in sync
;
; Based on the palette data that SMB uses, we map the NES palette entries as
;
; NES      Description        IIgs Palette
; ----------------------------------------
; BG0      Background color   0
; BG0,1    Light Green        1
; BG0,2    Dark Green         2
; BG0,3    Black              3
; BG1,1    Peach              4
; BG1,2    Brown              5
; BG1,3    Black              3
; BG2,1    White              6
; BG2,2    Light Blue         7
; BG2,3    Black              3
; BG3,1    Cycle              8          ; Coins / Blocks
; BG3,2    Brown              5
; BG3,3    Black              3
; SP0                         0
; SP0,1    Red                9
; SP0,2    Orange            10
; SP0,3    Olive             11
; SP1,1    Dark Green         2
; SP1,2    White              6
; SP1,3    Orange            10
; SP2,1    Red                9
; SP2,2    White              6
; SP2,3    Orange            10
; SP3,1    Black              3
; SP3,2    Peach              4
; SP3,3    Brown              5
;
; There are 4 color to spare in case we need to add more entries.  This mapping table is important because
; we have to have a custom tile rendering function and custom sprite rendering function that will dynamically
; map the 2-bit tile data into the proper palette range.  This will likely be implemented with an 8-bit
; swizzle table.  Possible optimization later on is to pre-swizzle certain tiles assuming that the palette
; assignments never change.
;
; BG Palette 2 can probably be ignored because it's just for the top of the screen and we can use a separate
; SCB palette for that line
        mx   %00
:extra
        txa
        and  #$001F
        asl
        tax
        jmp  (palTbl,x)

palTbl  dw   ppu_3F00,ppu_3F01,ppu_3F02,ppu_3F03
        dw   ppu_3F04,ppu_3F05,ppu_3F06,ppu_3F07
        dw   ppu_3F08,ppu_3F09,ppu_3F0A,ppu_3F0B
        dw   ppu_3F0C,ppu_3F0D,ppu_3F0E,ppu_3F0F
        dw   ppu_3F10,ppu_3F11,ppu_3F12,ppu_3F13
        dw   ppu_3F14,ppu_3F15,ppu_3F16,ppu_3F17
        dw   ppu_3F18,ppu_3F19,ppu_3F1A,ppu_3F1B
        dw   ppu_3F1C,ppu_3F1D,ppu_3F1E,ppu_3F1F

; Background color
ppu_3F00
        lda  PPU_MEM+$3F00
        ldx  #0
        brl  extra_out

; Background Palette 0
ppu_3F01
        lda  PPU_MEM+$3F01
        ldx  #2
        brl  extra_out

ppu_3F02
        lda  PPU_MEM+$3F02
        ldx  #4
        brl  extra_out

ppu_3F03
        lda  PPU_MEM+$3F03
        ldx  #6
        brl  extra_out

; Shadow for background color
ppu_3F10
        lda  PPU_MEM+$3F10
        ldx  #0
        brl  extra_out

; Sprite Palette 0
ppu_3F11
        lda  PPU_MEM+$3F11
        ldx  #8
        brl  extra_out

ppu_3F12
        lda  PPU_MEM+$3F12
        ldx  #10
        brl  extra_out

ppu_3F13
        lda  PPU_MEM+$3F13
        ldx  #12
        brl  extra_out

; Sprite Palette 1
ppu_3F15
        lda  PPU_MEM+$3F15
        ldx  #14
        brl  extra_out

ppu_3F16
        lda  PPU_MEM+$3F16
        ldx  #16
        brl  extra_out

ppu_3F17
        lda  PPU_MEM+$3F17
        ldx  #18
        brl  extra_out

; Sprite Palette 2
ppu_3F19
        lda  PPU_MEM+$3F19
        ldx  #20
        brl  extra_out

ppu_3F1A
        lda  PPU_MEM+$3F1A
        ldx  #22
        brl  extra_out

ppu_3F1B
        lda  PPU_MEM+$3F1B
        ldx  #24
        brl  extra_out

; Sprite Palette 3
ppu_3F1D
        lda  PPU_MEM+$3F1D
        ldx  #26
        brl  extra_out

ppu_3F1E
        lda  PPU_MEM+$3F1E
        ldx  #28
        brl  extra_out

ppu_3F1F
        lda  PPU_MEM+$3F1F
        ldx  #30
        brl  extra_out

ppu_3F04
ppu_3F05
ppu_3F06
ppu_3F07

ppu_3F08
ppu_3F09
ppu_3F0A
ppu_3F0B

ppu_3F0C
ppu_3F0D
ppu_3F0E
ppu_3F0F

ppu_3F14
ppu_3F18
ppu_3F1C
        brl  no_pal
; Exit code to set a IIgs palette entry from the PPU memory
;
; A = NES palette value
; X = IIgs Palette index
extra_out
        phy
        and  #$00FF
        asl
        tay
        lda  nesPalette,y
        ply
        stal $E19E00,x

no_pal
        sep  #$30
        plx
        pla
        plb
        plp
        rtl

; Trigger a copy from a page of memory to OAM.  Since this is a DMA operation, we can cheat and do a 16-bit copy
PPUDMA_WRITE ENT
        php
        phb
        phk
        plb

        phx
        pha

        rep  #$30
        xba
        and  #$FF00
        tax

]n      equ   0
        lup   128
        ldal  ROMBase+]n,x
        sta   PPU_OAM+]n
]n      =     ]n+2
        --^

        sep #$30

        pla
        plx
        plb
        plp
        rtl

y_offset equ 16
x_offset equ 16

; Scan the OAM memory and copy the values of the sprites that need to be drawn. There are two reasons to do this
;
; 1. Freeze the OAM memory at this instanct so that the NES ISR can keep running without changing values
; 2. We have to scan this list twice -- once to build up the shadow list and once to actually render the sprites
OAM_COPY    ds 256
spriteCount ds 0
            db 0                 ; Pad in case we can to access using 16-bit instructions

        mx   %00
scanOAMSprites
        stz  Tmp5

        sep  #$30

        ldx  #4                  ; Always skip sprite 0
        ldy  #0

:loop
        lda    PPU_OAM,x         ; Y-coordinate
        cmp    #200+y_offset-9
        bcs    :skip
        cmp    #16
        bcc    :skip

        lda    PPU_OAM+1,x       ; $FC is an empty tile, don't draw it
        cmp    #$FC
        beq    :skip

        lda    PPU_OAM+3,x       ; If X-coordinate is off the edge skip it, too.
        cmp    #241
        bcs    :skip

        rep    #$20
        lda    PPU_OAM,x
        sta    OAM_COPY,y
        lda    PPU_OAM+2,x
        sta    OAM_COPY+2,y
        sep    #$20

* ; Debug OAM values
*         phy
*         phx

*         rep    #$30
*         ldx    Tmp5
*         cpx    #{160*190}
*         bcs    :nodraw

*         lda    OAM_COPY+2,y
*         pha
*         lda    OAM_COPY,y
*         ldy    #$FFFF
*         jsr    DrawWord

*         lda    Tmp5
*         clc
*         adc    #128+16
*         tax
*         ldy    #$FFFF
*         pla
*         jsr    DrawWord

*         lda    Tmp5
*         clc
*         adc    #8*160
*         sta    Tmp5

* :nodraw
*         sep    #$30
*         plx
*         ply

        iny
        iny
        iny
        iny

:skip
        inx
        inx
        inx
        inx
        bne  :loop

        sty  spriteCount                     ; Count * 4
        rep  #$30
        rts

; Screen is 200 lines tall. It's worth it be exact when building the list because one extra
; draw + shadow sequence takes at least 1,000 cycles.
shadowBitmap    ds 32              ; Provide enough space for the full ppu range (240 lines) + 16 since the y coordinate can be off-screen

; A representation of the list as [top, bot) pairs
shadowListCount dw 0            ; Pad for 16-bit comparisons
shadowListTop   ds 64
shadowListBot   ds 64

        mx  %00
buildShadowBitmap

; zero out the bitmap (16-bit writes)
]n      equ   0
        lup   15
        stz   shadowBitmap+]n
]n      =     ]n+2
        --^

; Run through the list of visible sprites and ORA in the bits that represent them
        sep   #$30

        ldx   #0
        cpx   spriteCount
        beq   :exit

:loop
        phx

;        ldy   PPU_OAM,x
        ldy   OAM_COPY,x
        iny                               ; This is the y-coordinate of the top of the sprite

        ldx   y2idx,y                     ; Get the index into the shadowBitmap array for this y coordinate
        lda   y2low,y                     ; Get the bit pattern for the first byte
        ora   shadowBitmap,x
        sta   shadowBitmap,x
        lda   y2high,y                    ; Get the bit pattern for the second byte
        ora   shadowBitmap+1,x
        sta   shadowBitmap+1,x

        plx
        inx
        inx
        inx
        inx
        cpx   spriteCount
        bcc   :loop

:exit
        rep   #$30
        rts

y2idx   const32 $00
        const32 $04
        const32 $08
        const32 $0C                ; 128 bytes
        const32 $10
        const32 $14
        const32 $18
        const32 $1C

; Repeating pattern of 8 consecutive 1 bits
y2low   rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01
        rep8 $FF,$7F,$3F,$1F,$0F,$07,$03,$01

y2high  rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE
        rep8 $00,$80,$C0,$E0,$F0,$F8,$FC,$FE

; 25 entries to multiple steps in the shadow bitmap to scanlines
mul8    db   $00,$08,$10,$18,$20,$28,$30,$38
        db   $40,$48,$50,$58,$60,$68,$70,$78
        db   $80,$88,$90,$98,$A0,$A8,$B0,$B8
        db   $C0,$C8,$D0,$D8,$E0,$E8,$F0,$F8

; Given a bit pattern, create a LUT that count to the first set bit (MSB -> LSB), e.g. $0F = 4, $3F = 2
offset  db   0,7,6,6,5,5,5,5,4,4,4,4,4,4,4,4,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3     ; 0, 1, 2, 4, 8, 16
        db   2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2     ; 32
        db   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Scan the bitmap list and call BltRange on the ranges
        mx   %00
drawShadowList
        ldx  #0
        cpx  shadowListCount
        beq  :exit

:loop
        phx

        lda  shadowListBot,x
        and  #$00FF
        tay
        cpy  #201
        bcc  *+4
        brk  $cc

        lda  shadowListTop,x
        and  #$00FF
        tax
        cpx  #200
        bcc  *+4
        brk  $dd

        lda  #0                 ; Invoke the BltRange function
        jsl  LngJmp

        plx
        inx
        cpx  shadowListCount
        bcc  :loop
:exit
        rts

; Altername between BltRange and PEISlam to expose the screen
exposeShadowList
:last   equ  Tmp0
:top    equ  Tmp1
:bottom equ  Tmp2

        ldx  #0
        stx  :last
        cpx  shadowListCount
        beq  :exit

:loop
        phx

        lda  shadowListTop,x
        and  #$00FF
        sta  :top

        cmp  #200
        bcc  *+4
        brk  $44

        lda  shadowListBot,x
        and  #$00FF
        sta  :bottom

        cmp  #201
        bcc  *+4
        brk   $66

        cmp  :top
        bcs  *+4
        brk  $55

        ldx  :last
        ldy  :top
        lda  #0
        jsl  LngJmp             ; Draw the background up to this range

        ldx  :top
        ldy  :bottom
        sty  :last              ; This is where we ended
        lda  #1
        jsl  LngJmp             ; Expose the already-drawn sprites

        plx
        inx
        cpx  shadowListCount
        bcc  :loop

:exit
        ldx  :last              ; Expose the final part
        ldy  #200
        lda  #0
        jsl  LngJmp
        rts

; This routine needs to adjust the y-coordinates based of the offset of the GTE playfield within
; the PPU RAM
shadowBitmapToList
:top    equ  Tmp0
:bottom equ  Tmp2

        sep  #$30

        ldx  #2               ; Start at he third row (y_offset = 16) walk the bitmap for 25 bytes (200 lines of height)
        lda  #0
        sta  shadowListCount  ; zero out the shadow list count

; This loop is called when we are not tracking a sprite range
:zero_loop
        ldy  shadowBitmap,x
        beq  :zero_next

        lda  mul8-2,x           ; This is the scanline we're on (offset by the starting byte)
        clc
        adc  offset,y         ; This is the first line defined by the bit pattern
        sta  :top
        bra  :one_next

:zero_next
        inx
        cpx  #28              ; End at byte 27
        bcc  :zero_loop
        bra  :exit           ; ended while not tracking a sprite, so exit the function

:one_loop
        lda  shadowBitmap,x  ; if the next byte is all sprite, just continue
        eor  #$FF
        beq  :one_next

        tay                  ; Use the inverted bitfield in order to re-use the same lookup table
        lda  mul8-2,x
        clc
        adc  offset,y

        ldy  shadowListCount
        sta  shadowListBot,y
        lda  :top
        sta  shadowListTop,y
        iny
        sty  shadowListCount
        bra  :zero_next

:one_next
        inx
        cpx  #28
        bcc  :one_loop

; If we end while tracking a sprite, add to the list as the last item

        ldx  shadowListCount
        lda  :top
        sta  shadowListTop,x
        lda  #200
        sta  shadowListBot,x
        inx
        stx  shadowListCount

:exit
        rep  #$30
        lda  shadowListCount
        cmp  #64
        bcc  *+4
        brk  $13


        rts

; Helper to bounce into the function in the FTblPtr. See IIgs TN #90
LngJmp
        sty  FTblTmp
        asl
        asl
        tay
        iny
        lda  [FTblPtr],y
        pha
        dey
        lda  [FTblPtr],y
        dec
        phb
        sta  1,s
        ldy  FTblTmp          ; Restore the y register
        rtl

; Callback entrypoint from the GTE renderer
drawOAMSprites
        phb
        phd

        phk
        plb

        pha

        lda   DPSave
        tcd

; Save the pointer to the function table

        sty   FTblPtr
        stx   FTblPtr+2

        pla

; Check what phase we're in
;
; Phase 1: A = 0
; Phase 2: A = 1

        cmp   #0
        bne   :phase2

; This is phase 1.  We will build the sprite list and draw the background in the areas covered by
; sprites.  This phase draws the sprites, too


; We need to "freeze" the OAM values, otherwise they can change between when we build the rendering pipeline

        sei
        ldal  nmiCount
        pha
        jsr   scanOAMSprites              ; Filter out any sprites that don't need to be drawn
        pla
        cmpl  nmiCount
        beq   *+4
        brk   $1F                         ; Should not have serviced the VBL interrupt here....
        cli

        jsr   buildShadowBitmap           ; Run though and quickly create a bitmap of lines with sprites
        jsr   shadowBitmapToList          ; Can the bitmap and create (top, bottom) pairs of ranges

        jsr   drawShadowList              ; Draw the background lines that have sprite on them
        jsr   drawSprites                 ; Draw the sprites on top of the lines they occupy

        bra   :exit

; In Phase 2 we scan the shadow list and alternately blit the background in empty areas and
; PEI slam the sprite regions
:phase2
        jsr   exposeShadowList            ; Show everything on the SHR screen

; Return form the callback
:exit
        pld
        plb
        rtl

drawSprites
:tmp    equ   Tmp0

        sep   #$30          ; 8-bit cpu

; Run through the copy of the OAM memory

        ldx   #0
        cpx   spriteCount
        bne   oam_loop
        rep   #$30
        rts

        mx %11
oam_loop
        phx                 ; Save x

        lda   OAM_COPY,x     ; Y-coordinate
        inc                 ; Compensate for PPU delayed scanline

        rep   #$30
        and   #$00FF
        asl
        asl
        asl
        asl
        asl
        sta  :tmp
        asl
        asl
        clc
        adc  :tmp
        clc
        adc  #$2000-{y_offset*160}+x_offset
        sta  :tmp

        lda  OAM_COPY+3,x
        lsr
        and  #$007F
        clc
        adc  :tmp
        tay

        lda  OAM_COPY+2,x
        pha
        bit  #$0040                  ; horizontal flip
        bne  :hflip

        lda  OAM_COPY,x               ; Load the tile index into the high byte (x256)
        and  #$FF00
        lsr                          ; multiple by 128
        tax
        bra  :noflip

:hflip
        lda  OAM_COPY,x               ; Load the tile index into the high byte (x256)
        and  #$FF00
        lsr                          ; multiple by 128
        adc  #64                     ; horizontal flip
        tax

:noflip
        pla
        asl
        and   #$0106                 ; Set the vflip bit and palette select bits

drawTilePatch
        jsl   $000000                ; Draw the tile on the graphics screen

        sep   #$30
        plx                          ; Restore the counter
        inx
        inx
        inx
        inx
        cpx   spriteCount
        bcc   oam_loop

        rep   #$30
        rts

