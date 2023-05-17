            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs
            use   Externals.s

; Keycodes
LEFT_ARROW      equ   $08
RIGHT_ARROW     equ   $15
UP_ARROW        equ   $0B
DOWN_ARROW      equ   $0A

            mx    %00

; Direct page space
MyUserId    equ   0
ROMStk      equ   2
ROMZeroPg   equ   4
LastScroll  equ   6
Tmp0        equ   240
Tmp1        equ   242
Tmp2        equ   244
Tmp3        equ   246

            phk
            plb
            sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
            _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

            stz   LastScroll

; The next two direct pages will be used by GTE, so get another 2 pages beyond that for the ROM.  We get
; 4K of DP/Stack space by default, so there is plenty to share
            tdc
            clc
            adc   #$300
            sta   ROMZeroPg
            clc
            adc   #$1FF                   ; Stack starts at the top of the page
            sta   ROMStk

*             ldx   #SMBStart
*             jsr   romxfer

* ; Call the main loop 23 times
*             lda   #23
* :pre        pha
*             jsr   triggerNMI
*             pla
*             dec
*             bne   :pre

* :gloop
*             jsr   triggerNMI
*             bra   :gloop

*             brl   Quit

            lda   #ENGINE_MODE_USER_TOOL  ; Engine in Fast Mode as a User Tool
            jsr   GTEStartUp              ; Load and install the GTE User Tool

; Install a VBL callback task that we will use to invoke the NMI routine in the ROM
            pea   vblCallback
            pea   #^nmiTask
            pea   #nmiTask
            _GTESetAddress

; Install a custom sprite renderer that will read directly off of the OAM table
            pea   extSpriteRenderer
            pea   #^drawOAMSprites
            pea   #drawOAMSprites
            _GTESetAddress

; Get the address of a low-level routine that can be used to draw a tile directly to the graphics screen
            pea   rawDrawTile
            _GTEGetAddress
            lda   1,s
            sta   drawTilePatch+1
            lda   2,s
            sta   drawTilePatch+2
            pla
            plx

; Initialize the graphics screen playfield (256x160).  The NES is 240 lines high, so 160
; is a reasonable compromise.

            pea   #128
            pea   #200
            _GTESetScreenMode

            pea   $0000
            pea   #^Greyscale
            pea   #Greyscale
            _GTESetPalette

; Convert the CHR ROM from the cart into GTE tiles

            ldx   #0
            ldy   #0
:tloop
            phx
            phy

            lda   #TileBuff
            jsr  ConvertROMTile

            lda  1,s

            pha
            inc
            pha
            pea   #^TileBuff
            pea   #TileBuff
            _GTELoadTileSet

            ply
            iny

            pla
            clc
            adc  #16                         ; NES tiles are 16 bytes
            tax
            cpx  #512*16
            bcc  :tloop

; Put the tile set on the screen

*             lda   #0
*             stz   Tmp1
* :yloop      stz   Tmp0
* :xloop
*             pha
*             pei   Tmp0
*             pei   Tmp1
*             pha
*             _GTESetTile
*             pla
*             inc

*             inc   Tmp0
*             ldx   Tmp0
*             cpx   #32
*             bcc   :xloop

*             inc   Tmp1
*             ldx   Tmp1
*             cpx   #20
*             bcc   :yloop

* ; Render and wait for the user to continue
*             pea   $0000
*             _GTERender

* :wait1
*             pha
*             _GTEReadControl
*             pla
*             and   #$007F
*             cmp   #' '
*             bne   :wait1

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            ldx   #SMBStart
            jsr   romxfer

EvtLoop
:spin       lda   ppustatus             ; Set the bit that the VBL has started
            bit   #$80
            beq   :spin
            and   #$FF7F
            sta   ppustatus

            jsr   triggerNMI

            lda   #$2000
            jsr   CopyNametable

            lda   ppuscroll+1
            and   #$00FF
            lsr
            pha
            sta   LastScroll
            lda   ppuscroll
            and   #$00FF
            pha
            _GTESetBG0Origin

            pea   $FFFF      ; NES mode
            _GTERender

            pha
            _GTEReadControl
            pla

; Map the GTE field to the NES controller format: A-B-Select-Start-Up-Down-Left-Right

            pha
            and   #PAD_BUTTON_A+PAD_BUTTON_B        ; bits 0x200 and 0x100
            lsr
            lsr
            sta   native_joy 
            lda   1,s
            and   #$00FF
            cmp   #'n'
            bne   *+7
            lda   #$0020
            bra   :nes_merge
            cmp   #'m'
            bne   *+7
            lda   #$0010
            bra   :nes_merge
            cmp   #UP_ARROW
            bne   *+7
            lda   #$0008
            bra   :nes_merge
            cmp   #DOWN_ARROW
            bne   *+7
            lda   #$0004
            bra   :nes_merge
            cmp   #LEFT_ARROW
            bne   *+7
            lda   #$0002
            bra   :nes_merge
            cmp   #RIGHT_ARROW
            bne   :nes_done
            lda   #$0001
:nes_merge  ora   native_joy 
            sta   native_joy 
:nes_done
            pla
;            bit   #PAD_KEY_DOWN
;            bne   *+5
;            brl   EvtLoop

            and   #$007F

            cmp   #'1'         ; Copy nametable 1
            bne   :not_1
            lda   #$2000
            jsr   CopyNametable
            brl   EvtLoop
:not_1

            cmp   #'2'
            bne   :not_2
            lda   #$2400
            jsr   CopyNametable
:not_2

            cmp   #'s'         ; next step
            bne   :not_n
            jsr   triggerNMI
:not_n

            cmp   #'q'
            beq   Exit
            brl   EvtLoop

Exit
            _GTEShutDown
Quit
            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00
Greyscale   dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF
            dw    $0000,$5555,$AAAA,$FFFF

; Copy the tile and attribute bytes into the GTE buffer
;
; A = Nametable address ($2000, $2400, $2800, or $2C00)
CopyNametable
            lda   ppuctrl
            and   #$0003                  ; nametable select bits
            xba
            asl
            asl
            clc
            adc   #2*32
            sta   Tmp0                    ; base address offset into nametable memory

;            ora   #$2000
;            clc
;            adc   #PPU_MEM
;            clc
;            adc   #2*32
;            sta   Tmp0                    ; base address

; NES RAM $6D = page, $86 = player_x_in_page can be used to get a global position in the level, then subtracting the 
; player's x coordinate will give us the global coordinate of the left edge of the screen and allow us to map between
; the GTE tile buffer and the PPU nametables

            lda   ppuscroll+1
            lsr
            lsr
            lsr
            and   #$001F
            sta   Tmp1                    ; starting offset

; Copy the first two rows from $2400 because they don't scroll

            ldy   #0
:yloop
            ldx   #0

            cpy   #2
            bcs   :offset

            tya
            clc
            adc   #2
            asl
            asl
            asl
            asl
            asl

            sta   Tmp2
            lda   #0
            sta   Tmp3
            bra   :xloop

:offset
            lda   Tmp0                    ; Get the base address for this line
            ora   Tmp1                    ; Move over to the first horizontal tile
            sta   Tmp2                    ; coarse x-scroll

            lda   Tmp1
            sta   Tmp3                    ; Keep a separate count for the GTE tile position
:xloop
            phx                            ; Save X and Y
            phy

            pei   Tmp3                     ; Wrap-around tile column
            phy                            ; No vertical scroll, so screen_y = tile_y

            ldx   Tmp2                     ; Nametable address
            lda   PPU_MEM+$2000,x
            and   #$00FF
            ora   #$0100
            pha

; Advance to the next tile (handle nametable wrapping)

            lda   #$001F
            and   Tmp2
            cmp   #$001F
            bne   :inc_x
            txa
            and   #$FFE0
            eor   #$0400
            sta   Tmp2
            bra   :x_hop

:inc_x      inx
            stx   Tmp2
:x_hop

            _GTESetTile

            ply
            plx

            lda   Tmp3
            inc
            cmp   #41
            bcc   *+5
            lda   #0
            sta   Tmp3

            inx
            cpx   #33
            bcc   :xloop

            lda   Tmp0
            clc
            adc   #32
            sta   Tmp0

            iny
            cpy   #25
            bcc   :yloop

            rts

; Trigger an NMI in the ROM
triggerNMI
            ldal  ppuctrl               ; If the ROM has not enabled VBL NMI, also skip
            bit   #$80
            beq   :skip

            lda   ppustatus             ; Set the bit that the VBL has started
            ora   #$80
            sta   ppustatus

            ldx   #NonMaskableInterrupt
            jmp   romxfer
:skip       rts

; Expose joypad bits from GTE to the ROM: A-B-Select-Start-Up-Down-Left-Right
native_joy  ENT
            db   0,0

; X = address in the rom file
; A = address to write
;
; This keeps the tile in 2-bit mode in a format that makes it easy to look up pixel data
; based on a dynamic palette selection


; X = address in the rom file
; A = address to write

ConvertROMTile
DPtr        equ   Tmp1
MPtr        equ   Tmp2

            sta   DPtr
            clc
            adc   #32                ; Move to the mask
            sta   MPtr
            lda   #0                 ; Clear A and B

            sep   #$20               ; 8-bit mode
            ldy   #0

:loop
            lda   CHR_ROM,x          ; Load the high bits
            rol
            rol
            rol
            rol
            and   #$06
            sta   Tmp0

            lda   CHR_ROM+8,x
            and   #$C0
            lsr
            lsr
            lsr
            ora   Tmp0               ; Combine the two and create a lookup value

            phx
            tax
            lda   DLUT,x              ; Look up the two, 4-bit pixel values for this quad of bits
            sta   (DPtr),y
            lda   MLUT,x
            sta   (MPtr),y
            iny
            plx

; Repeat for bits 4 & 5

            ldal  CHR_ROM,x          ; Load the high bits
            and   #$30
            lsr
            lsr
            lsr
            sta   Tmp0

            ldal  CHR_ROM+8,x
            and   #$30
            lsr
            ora   Tmp0               ; Combine the two and create a lookup value

            phx
            tax
            lda   DLUT,x
            sta   (DPtr),y
            lda   MLUT,x
            sta   (MPtr),y
            iny
            plx

; Repeat for bits 2 & 3

            ldal  CHR_ROM,x          ; Load the high bits
            and   #$0C
            lsr
            sta   Tmp0

            ldal  CHR_ROM+8,x
            and   #$0C
            asl
            ora   Tmp0               ; Combine the two and create a lookup value

            phx
            tax
            lda   DLUT,x
            sta   (DPtr),y
            lda   MLUT,x
            sta   (MPtr),y
            iny
            plx

; Repeat for bits 0 & 1

            ldal  CHR_ROM,x          ; Load the high bits
            and   #$03
            asl
            sta   Tmp0

            ldal  CHR_ROM+8,x
            and   #$03
            asl
            asl
            asl
            ora   Tmp0                ; Combine the two and create a lookup value

            phx
            tax
            lda   DLUT,x
            sta   (DPtr),y
            lda   MLUT,x
            sta   (MPtr),y
            iny
            plx

            inx
            cpy   #32
            bcs   :done
            brl   :loop
:done
            rep    #$20

; Flip the tile before returning
            ldy    #16
            ldx    DPtr
:rloop
            lda:   0,x
            jsr    reverse
            sta:   66,x
            lda:   2,x
            jsr    reverse
            sta:   64,x
            inx
            inx
            inx
            inx
            dey
            bne    :rloop
            rts

reverse
            xba
            sta   Tmp0
            and   #$0F0F
            asl
            asl
            asl
            asl
            sta   Tmp1
            lda   Tmp0
            and   #$F0F0
            lsr
            lsr
            lsr
            lsr
            ora   Tmp1
            rts


DLUT        dw    $00,$01,$10,$11    ; CHR_ROM[0] = xx, CHR_ROM[8] = 00
            dw    $02,$03,$12,$13    ; CHR_ROM[0] = xx, CHR_ROM[8] = 01
            dw    $20,$21,$30,$31    ; CHR_ROM[0] = xx, CHR_ROM[8] = 10
            dw    $22,$23,$32,$33    ; CHR_ROM[0] = xx, CHR_ROM[8] = 11

;MLUT        dw    $FF,$F0,$0F,$00
;            dw    $F0,$F0,$00,$00
;            dw    $0F,$00,$0F,$00
;            dw    $00,$00,$00,$00

; Inverted mask for using eor/and/eor rendering
MLUT        dw    $00,$0F,$F0,$FF
            dw    $0F,$0F,$FF,$FF
            dw    $F0,$FF,$F0,$FF
            dw    $FF,$FF,$FF,$FF

; Extracted tiles
TileBuff    ds    128

GTEStartUp
            pha                           ; Save engine mode

            pea   $0000
            _LoaderStatus
            pla

            pea   $0000
            pea   $0000
            pea   $0000
            pea   $0000
            pea   $0000                   ; result space

            lda   MyUserId
            pha

            pea   #^ToolPath
            pea   #ToolPath
            pea   $0001                   ; do not load into special memory
            _InitialLoad
            bcc    *+4
            brk    $01

            ply
            pla                           ; Address of the loaded tool
            plx
            ply
            ply

            pea   $8000                   ; User toolset
            pea   $00A0                   ; Set the tool set number
            phx
            pha                           ; Address of function pointer table
            _SetTSPtr
            bcc    *+4
            brk    $02

            plx                            ; Pop the Engine Mode value

            clc                            ; Give GTE two pages of direct page memory
            tdc
            adc   #$0100
            pha
            phx
            lda   MyUserId                 ; Pass the userId for memory allocation
            pha
            _GTEStartUp
            bcc    *+4
            brk    $03

            rts

ToolPath    str   '1/Tool160'

* ; Store sprite and tile data as 0000000w wxxyyzz0 to facilitate swizzle loads

* ; sprite high priority (8-bit acc, compiled)
*             ldy   #PPU_DATA
*             lda   screen
*             andl  tilemask,x
*             ora   (palptr),y          ; 512 byte lookup table per palette
*             sta   screen

* ; sprite low (this is just slow) ....
*             lda   screen
*             beq   empty
*             ; do 4 bits to figure out a mask and then


*             bit   #$FF00
*             ...
*             ...
*             ldy   #PPU_DATA
*             lda   (palptr),y
*             eor   screen
*             andl  tilemask,x
*             and   bgmask
*             eor   screen
*             sta   screen

* ; tile
*             ldy   tiledata,x
*             lda   (palptr),y
*             ldy   tmp
*             sta   abs,y


* ; Custom tile renderer that swizzles the tile data based on the PPU attribute tables. This
* ; is more complicate than just combining the palette select bits with the tile index bits
* ; because the NES can have >16 colors on screen at once, we remap the possible colors
* ; onto a smaller set of indices.
* SwizzleTile
*                  tax
* ]line            equ             0
*                  lup             8
*                  ldal            tiledata+{]line*4},x     ; Tile data is 00ww00xx 00yy00zz
*                  ora             metatile                 ; Pre-calculated metatile mask
*                  and             tilemask+{]line*4},x     ; Set any zero indices to actual zero
*                  sta:            $0004+{]line*$1000},y
*                  ldal            tiledata+{]line*4}+2,x
*                  sta:            $0001+{]line*$1000},y
* ]line            equ             ]line+1
*                  --^
*                  plb
*                  rts



; Transfer control to the ROM.  This function is trampoline that is responsible for
; setting up the direct page and stack for the ROM and then passing control into
; the ROM wrapped in a JSL/RTL vector stashed in the ROM space.
;
; X = ROM Address
romxfer     phb                             ; Save the bank and direct page
            phd
            tsc
            sta   StkSave+1                 ; Save the current stack in the main program
            pea   #^ExtIn                   ; Set the bank to the ROM
            plb

            lda   ROMStk                    ; Set the ROM stack address
            tcs
            lda   ROMZeroPg                 ; Set the ROM zero page
            tcd

            jml   ExtIn
ExtRtn      ENT
            tsx                             ; Copy the stack address returned by the emulator
StkSave     lda   #$0000
            tcs

            pld
            plb
            stx   ROMStk                    ; Keep an updated copy of the stack address
            rts

; VBL Interrupt task (called in native 8-bit mode)
            mx    %11
nmiTask
            ldal  ppustatus             ; Set the bit that the VBL has started
            ora   #$80
            stal  ppustatus

            ldal  ppuctrl
            bit   #$80                  ; Should an NMI be generated with the VBL?
            beq   :skip

            php
;            jsr   triggerNMI
            plp
:skip
            rtl
            mx    %00
            put   palette.s
            put   ppu.s

            ds    \,$00                      ; pad to the next page boundary
PPU_MEM
CHR_ROM     put chr2.s         ; 8K of CHR-ROM at PPU memory $0000 - $2000
PPU_NT      ds  $2000         ; Nametable memory from $2000 - $3000, $3F00 - $3F14 is palette RAM
PPU_OAM     ds  256           ; 256 bytes of separate OAM RAM

