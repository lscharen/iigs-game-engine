; PPU simulator
;
; Any read/write to the PPU registers in the ROM is intercepted and passed here.

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

PPUDATA_WRITE ENT
        php
        phb
        phk
        plb
        pha
        phx

        rep  #$10
        ldx  ppuaddr
        sta  PPU_MEM,x

        rep  #$30
        txa
        clc
        adc  ppuincr
        sta  ppuaddr

        cpx  #$3F00
        bcs  :extra

        sep  #$30
        plx
        pla
        plb
        plp
        rtl

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

ppu_3F00
        lda  PPU_MEM+$3F00
        ldx  #0
        brl  extra_out

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

ppu_3F05
        lda  PPU_MEM+$3F05
        ldx  #8
        brl  extra_out

ppu_3F06
        lda  PPU_MEM+$3F06
        ldx  #10
        brl  extra_out

ppu_3F07
        lda  PPU_MEM+$3F07
        ldx  #12
        brl  extra_out

ppu_3F09
        lda  PPU_MEM+$3F05
        ldx  #14
        brl  extra_out

ppu_3F0A
        lda  PPU_MEM+$3F06
        ldx  #16
        brl  extra_out

ppu_3F0B
        lda  PPU_MEM+$3F07
        ldx  #18
        brl  extra_out

ppu_3F0D
        lda  PPU_MEM+$3F05
        ldx  #20
        brl  extra_out

ppu_3F0E
        lda  PPU_MEM+$3F06
        ldx  #22
        brl  extra_out

ppu_3F0F
        lda  PPU_MEM+$3F07
        ldx  #24
        brl  extra_out

ppu_3F10
        lda  PPU_MEM+$3F10
        ldx  #0
        brl  extra_out

ppu_3F04
ppu_3F08
ppu_3F0C
ppu_3F11
ppu_3F12
ppu_3F13
ppu_3F14
ppu_3F15
ppu_3F16
ppu_3F17
ppu_3F18
ppu_3F19
ppu_3F1A
ppu_3F1B
ppu_3F1C
ppu_3F1D
ppu_3F1E
ppu_3F1F

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

drawOAMSprites
:tmp    equ  238

        phb
        php

        phk
        plb

        sep   #$30          ; 8-bit cpu
        ldx   #4            ; Ok to always skip sprite 0

:oam_loop
        lda   PPU_OAM+3,x   ; remove this test once we can clip sprites
        cmp   #241
        bcs   :hidden

        lda  PPU_OAM+1,x    ; $FC is an empty tile, don't draw it
        cmp  #$FC
        beq  :hidden

        lda   PPU_OAM,x     ; Y-coordinate
        cmp   #200+y_offset-9
        bcs   :hidden

        phx
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

        lda  PPU_OAM+3,x
        lsr
        and  #$007F
        clc
        adc  :tmp
        tay

        lda  PPU_OAM+2,x
        pha
        bit  #$0040                  ; horizontal flip
        bne  :hflip

        lda  PPU_OAM,x               ; Load the tile index into the high byte (x256)
        and  #$FF00
        lsr                          ; multiple by 128
        tax
        bra  :noflip

:hflip
        lda  PPU_OAM,x               ; Loda the tile index into the high byte (x256)
        and  #$FF00
        lsr                          ; multiple by 128
        adc  #64                     ; horizontal flip
        tax

:noflip
        pla
        and   #$0080                 ; Set the vflip bit

drawTilePatch
        jsl   $000000                ; Draw the tile on the graphics screen

        sep   #$30
        plx

:hidden
        inx
        inx
        inx
        inx
        bne  :oam_loop

        plp
        plb
        rtl