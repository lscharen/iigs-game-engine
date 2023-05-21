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
TileX       equ   10                      ; GTE tile store coordinates that correspond to the PPUSCROLL edge
TileY       equ   12
ROMScreenEdge equ 14
ROMScrollEdge equ 16
ROMScrollDelta equ 18
OldROMScrollEdge equ 20
CurrScrollEdge equ 22

Tmp0        equ   240
Tmp1        equ   242
Tmp2        equ   244
Tmp3        equ   246
Tmp4        equ   248
Tmp5        equ   250

FTblPtr     equ   224
FTblTmp     equ   228

            phk
            plb
            sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
            _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

            stz   LastScroll
            stz   TileX
            stz   TileY
            stz   ROMScreenEdge
            stz   ROMScrollEdge
            stz   ROMScrollDelta
            stz   OldROMScrollEdge

; The next two direct pages will be used by GTE, so get another 2 pages beyond that for the ROM.  We get
; 4K of DP/Stack space by default, so there is plenty to share
            tdc
            sta   DPSave
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

; Install a custom callback to update the tile store as the screen scrolls
            pea   extBG0TileUpdate
            pea   #^UpdateFromPPU
            pea   #UpdateFromPPU
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
;            pea   #80
;            pea   #144
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

; Set an internal flag to tell the VBL interrupt handler that it is
; ok to start invoking the game logic.  The ROM code has to be run
; at 60 Hz because it controls the audio.  Bad audio is way worse
; than a choppy refresh rate.
;
; Call the boot code in the ROM

            ldx   #SMBStart
            jsr   romxfer

EvtLoop
:spin       lda   nmiCount
            beq   :spin
            stz   nmiCount

; The GTE playfield is 41 tiles wide, but the NES is 32 tiles wide.  Fortunately, the game
; keeps track of the global coordinates of each level at
;
; ScreenEdge_PageLoc          =     $071a
; ScreenEdge_X_Pos            =     $071c
;
; So we can keep our scrolling in sync with the game.  In order to efficiently update the
; GTE tile store, we handle this in two stages
;
; 1. When new column(s) are exposed, set the tiles directly from the PPU nametable memory
; 2. When the PPU nametable memory is updated in an area that is already on-screen, set the tile

; Get the current global coordinates

            sei
            lda   ROMScrollEdge     ; This is set in the VBL IRQ
            sta   CurrScrollEdge    ; Freeze it, then we can let the IRQs continue
            cli

            lsr
            lsr
            lsr
            sta   ROMScreenEdge

; Calculate how many blocks have been scrolled into view

            lda   CurrScrollEdge
            sec
            sbc   OldROMScrollEdge
            sta   Tmp1             ; This is the raw number of pixels moved

            lda   OldROMScrollEdge ; This is the number of partial pixels the old scroll position occupied
            and   #7
            sta   Tmp0
            lda   #7
            sec
            sbc   Tmp0             ; This account for situations where going from 8 -> 9 reveals a new column
            clc
            adc   Tmp1
            lsr
            lsr
            lsr
            sta   ROMScrollDelta   ; This many columns have been revealed

            lda   CurrScrollEdge
            sta   OldROMScrollEdge ; Stash a copy for the next round through
            lsr
            pha
            pea   $0000
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
            sta   native_joy                        ; Put inputs on both controllers
            sta   native_joy+1
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
            sta   native_joy+1
:nes_done
            pla
;            bit   #PAD_KEY_DOWN
;            bne   *+5
;            brl   EvtLoop

            and   #$007F

            cmp   #'r'         ; Refresh
            bne   :not_1
            jsr   CopyStatus

            lda   ROMScreenEdge      ; global tile index
            and   #$003F             ; mod the mirrored nametable size
            ldx   #33
            ldy   #0
            jsr   CopyNametable
            brl   EvtLoop
:not_1
            cmp   #'1'
            bne   :not_v
            lda   ROMScreenEdge
            clc
            adc   #33
            and   #$003F
            ldx   #1
            ldy   #33
            jsr   CopyNametable
            brl   EvtLoop

:not_v

            cmp   #'t'         ; test by placing markers on screen
            bne   :not_t
            pea   0
            pea   #3
            pea   $0150
            _GTESetTile
            pea   #31
            pea   #3
            pea   $0150
            _GTESetTile
            pea   #32
            pea   #3
            pea   $0150
            _GTESetTile
            pea   #39
            pea   #3
            pea   $0150
            _GTESetTile

            brl   EvtLoop
:not_t

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

nmiCount    dw    0
DPSave      dw    0

; Take a PPU address and convert it to a tile store coordinate
;
; Inputs
;   A = PPU address
;   X = Global Address in GTE bytes

; Outputs
;   X = relative tile store column
;   Y = relative tile store row
PPUAddrToTileStore
:PPUAddr    equ   Tmp0
:PPUTopLeft equ   Tmp1

            sta   :PPUAddr

; Based on the global coordiate, figure out whhat the left column in the PPU RAM is
            txa
            lsr                        ; Convert from bytes to tiles
            lsr
            and   #$003F               ; Logically there are 64 tiles in the mirrored PPU RAM
            sta   :PPUTopLeft

; Now we have the PPU address of the column that corresponds to the left edge of the GTE
; playfield.  Now, calculate the relative coordinates of the passed PPU address

; The y-coordinate is easy. Since the top-left address is always on the top row (row = 0),
; we just have to extract the row that the PPU address occupies.

            lda   :PPUAddr
            and   #$03E0               ; Take the middle 5 bits (ignore nametable)
            lsr
            lsr
            lsr
            lsr
            lsr
            tay                        ; Save the y-index here

; The GTE playfield is positioned with the third PPU row as it's origin and is 25 tiles high.
; If the PPU tile is in rows 0, 1, 27, 28 or 29 then we can ignore it

            cpy  #2
            bcc  :outOfRange
            cpy  #27
            bcs  :outOfRange

; Adjust the relative position down by 2

            dey
            dey

; The horizontal coordinate is a bit trickier. We need to add 32 to the horizontal
; coordinate in it's in the second nametable

            lda   :PPUAddr
            and   #$041F               ; Project it to the top row
            bit   #$0400
            beq   *+5
            ora   #$0020               ; Add 32
            and   #$003F               ; Clamp to range of 0 - 63

; If we're in the top two row, they don't scroll, so skip the displacement
            cpy   #2
            bcc   :noshift
 
; Now calculate the difference between the PPUTopLeft index and this value

            cmp   :PPUTopLeft
            bcs   :ahead               ; If the provided address is > than the origin, just calc the difference
            adc   #64                  ; Else distance is (a - 0) + (64 - b) = a + 64 - b
            sec
:ahead      sbc   :PPUTopLeft
:noshift

; If this value is larger than the payfield + 1, then we have the carry set or clear

            tax
            cmp   #33
            rts

:outOfRange
            sec
            rts

; If there is some other reason to draw the full screen, this will empty the queue
ClearNTQueue
            stz   nt_queue_front
            stz   nt_queue_end
            rts

; Scan through the queue of tiles that need to be updated before applying the scroll change
DrainNTQueue
:GTELeftEdge equ Tmp3
:PPUAddr     equ Tmp4

; Prep item -- get the logical block of the left edge of the scroll window

            lda   CurrScrollEdge             ; Global position that the GTE playfield was set to
            lsr 
            sta   :GTELeftEdge

            lda   nt_queue_front
            cmp   nt_queue_end
            beq   :out

:loop
            tax
            phx                              ; Save the x register

            lda   nt_queue,x                 ; get the PPU address that was stored
            sta   :PPUAddr                   ; save for later if we draw this tile

            ldx   :GTELeftEdge               ; get the global coordinate
            jsr   PPUAddrToTileStore         ; convert the PPU address to realtive tile store coordinates
            bcs   :skip                      ; if it's offscreen, no reason to draw it

; Now we have the relative position from the left edge of the tile.  Add the origin
; tile to it (uless we're in rows 0 or 1)

            txa
            cpy   #2
            bcc   :toprow
            clc
            adc   TileX
            cmp   #41
            bcc   *+5
            sbc   #41
:toprow
            pha                             ; Tile Store horizontal tile coordinate

            phy                             ; No translation needed for y

            ldx   :PPUAddr
            lda   PPU_MEM,x
            and   #$00FF
            ora   #$0100
            pha
            _GTESetTile

:skip
            pla                             ; Pop the saved x-register into the accumulator
            inc
            inc
            and   #{2*1024}-1
            cmp   nt_queue_end
            bne   :loop

:out
            sta   nt_queue_front
            rts

; Copy the necessary columns into the TileStore when setting a new scroll position
UpdateFromPPU
:StartXMod164 equ   36

            phb
            phd

; Snag the StartXmod164 value from the GTE direct page so we can calulate the tile origin
; ourselves

            ldx  :StartXMod164

            phk
            plb
            lda   DPSave
            tcd

            txa
            lsr
            lsr
            sta   TileX              ; Tile column of playfield origin

; Check the scroll delta, if it's negative or just large enough, do a whole copy of the current PPU
; memory into the TileStore

            lda   ROMScrollDelta
            beq   :queue

            cmp   #32
            bcc   :partial

            jsr   ClearNTQueue       ; kill any pending updates
            lda   ROMScreenEdge      ; global tile index
            and   #$003F             ; mod the mirrored nametable size
            ldx   #33                ; do the full width
            ldy   #0
            jsr   CopyNametable
            bra   :done

; Calculate the difference between the old and new
:partial
            jsr   DrainNTQueue

            lda   #33
            sec
            sbc   ROMScrollDelta
            tay

            ldx   ROMScrollDelta
            inx
            inx

            lda   ROMScreenEdge
            clc
            adc   #33
            sec
            sbc   ROMScrollDelta
            and   #$003F

            jsr   CopyNametable
:done
            pld
            plb
            rtl

; Just drain the queue of any on-screen changes and then exit
:queue
            jsr   DrainNTQueue
            pld
            plb
            rtl

CopyStatus
; Copy the first two rows from $2400 because they don't scroll

            ldy   #0
:yloop
            ldx   #0
            tya
            clc
            adc   #2
            asl
            asl
            asl
            asl
            asl
            sta   Tmp2
            stz   Tmp3
:xloop
            phx                            ; Save X and Y
            phy

            phx                            ; x = GTE tile index = PPU tile index
            phy                            ; No vertical scroll, so screen_y = tile_y

            ldx   Tmp2                     ; Nametable address
            lda   PPU_MEM+$2000,x
            and   #$00FF
            ora   #$0100
            pha

; Advance to the next tile (no wrapping needed)

            inx
            stx   Tmp2

            _GTESetTile

            ply
            plx

            inx
            cpx   #33
            bcc   :xloop

            iny
            cpy   #2
            bcc   :yloop
            rts

; Copy the tile and attribute bytes into the GTE buffer
;
; A = logical column in mirrored PPU memory (0 - 63)
; X = number of columns to copy
; Y = number of GTE tiles to offset
CopyNametable
;            cmp   #5
;            bcc   *+4
;            brk   $88
            sta   Tmp2
            bit   #$0020                  ; Is it >32?
            beq   *+5
            ora   #$0400                  ; Move to the next nametable
            and   #$041F                  ; Mask to the top of a valid column

            clc                           ; Add in the offset since we only copy rows 2 - 27
            adc   #4*32
            sta   Tmp0                    ; base address offset into nametable memory

            stx   Tmp4

            tya
            clc
            adc   TileX
            cmp   #41
            bcc   *+5
            sbc   #41
            sta   Tmp5

; NES RAM $6D = page, $86 = player_x_in_page can be used to get a global position in the level, then subtracting the 
; player's x coordinate will give us the global coordinate of the left edge of the screen and allow us to map between
; the GTE tile buffer and the PPU nametables

; Skip the first two rows -- call CopyStatus to get those

            ldy   #2
:yloop
            ldx   #0

            lda   Tmp0                    ; Get the base address for this row
            sta   Tmp2                    ; coarse x-scroll

            lda   Tmp5
            sta   Tmp3                    ; Keep a separate variable for the GTE tile position
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
            cpx   Tmp4
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

            ldal  ppustatus             ; Set the bit that the VBL has started
            ora   #$80
            stal  ppustatus

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
            ldal  nmiCount
            inc
            stal  nmiCount

            php
            rep   #$30
            phb
            phd

            phk
            plb
            lda   DPSave
            tcd

            jsr   triggerNMI

; Immediately after the NMI returns, freeze some of the global state variables so we can sync up with this frame when
; we render the next frame.  Since we're in an interrupt handler here, sno change of the variables changing under
; our nose

            sep   #$20
            ldal  ROMBase+$071a
            xba
            ldal  ROMBase+$071c
            rep   #$20
            sta   ROMScrollEdge

            pld
            plb
            plp
:skip
            rtl
            mx    %00
            put   App.Msg.s
            put   font.s
            put   palette.s
            put   ppu.s

            ds    \,$00                      ; pad to the next page boundary
PPU_MEM
CHR_ROM     put chr2.s         ; 8K of CHR-ROM at PPU memory $0000 - $2000
PPU_NT      ds  $2000          ; Nametable memory from $2000 - $3000, $3F00 - $3F14 is palette RAM
PPU_OAM     ds  256            ; 256 bytes of separate OAM RAM
 
