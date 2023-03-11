; Test driver to exercise graphics routines.

                REL
                DSK   MAINSEG

                use   Locator.Macs
                use   Load.Macs
                use   Mem.Macs
                use   Misc.Macs
                use   Util.Macs
                use   EDS.GSOS.Macs
                use   GTE.Macs

                mx    %00

tiledata        EXT                           ; tileset buffer
TileSetPalette  EXT

; Keycodes
LEFT_ARROW      equ   $08
RIGHT_ARROW     equ   $15
UP_ARROW        equ   $0B
DOWN_ARROW      equ   $0A

; Direct page space
MyUserId        equ   0
BankLoad        equ   2
StartX          equ   4
StartY          equ   6
TileMapWidth    equ   8
TileMapHeight   equ   10
ScreenWidth     equ   12
ScreenHeight    equ   14
MaxGlobalX      equ   16
MaxGlobalY      equ   18
MaxBG0X         equ   20
MaxBG0Y         equ   22
frameCount      equ   24
OldOneSecondCounter equ 26
appTmp0         equ   28
seg1x           equ   30
seg2x           equ   32
seg3x           equ   34
seg4x           equ   36    ; BG1 x-pos
frameCountTotal equ   38

                phk
                plb

                sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                tdc
                sta   MyDirectPage            ; Keep a copy for the overlay callback

                _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                lda   #ENGINE_MODE_USER_TOOL+ENGINE_MODE_TWO_LAYER  ; Engine in Fast Mode as a User Tool
                jsr   GTEStartUp              ; Load and install the GTE User Tool

; Initialize the graphics screen playfield

                pea   #160
                pea   #200
                _GTESetScreenMode

; Load a tileset

                pea   0
                pea   256
                pea   #^tiledata
                pea   #tiledata
                _GTELoadTileSet

                pea   $0000
                pea   #^TileSetPalette
                pea   #TileSetPalette
                _GTESetPalette

                pea   $0
                _GTEClearBG1Buffer

; Set up our level data

;                jsr   BG0SetUp
                pea   416
                pea   30
                pea   ^App_TileMapBG0
                pea   App_TileMapBG0+{10*416}
                _GTESetBG0TileMapInfo

                stz   seg1x
                stz   seg2x
                stz   seg3x
                stz   seg4x

                jsr   SetLimits
                jsr   DoLoadBG1

; Initialize local variables

                lda   #56
                sta   StartX
                lda   #0
                sta   StartY
                stz   frameCount
                stz   frameCountTotal

                pei   StartX
                pei   StartY
                _GTESetBG0Origin

                lda   #193                    ; Tile ID of '0'
                jsr   InitOverlay             ; Initialize the status bar
                pha
                _GTEGetSeconds
                pla
                sta   OldOneSecondCounter
                jsr   UdtOverlay

; Set up the per-scanline rendering

                lda   StartX
                jsr   InitOffsets

                pea   #scanlineHorzOffset
                pea   #^BG0Offsets
                pea   #BG0Offsets
                _GTESetAddress

                pea   #scanlineHorzOffset2
                pea   #^BG1Offsets
                pea   #BG1Offsets
                _GTESetAddress

                pea   $0000                  ; one regular render to fill the screen with the tilemap
                _GTERender

; Set up a very specific test.  First, we draw a sprite into the sprite plane, and then
; leave it alone.  We are just testing the ability to merge sprite plane data into 
; the play field tiles.
EvtLoop
                pha
                _GTEReadControl
                pla

                jsr   HandleKeys                   ; Do the generic key handlers
                bcs   :do_more
                brl   :do_render

:do_more
                cmp        #'d'
                bne        :not_d
                jsr        DecRanges
                jsr        SetOffsets
                brl        :do_render
:not_d

                cmp        #'a'
                bne        :not_a
                jsr        IncRanges
                jsr        SetOffsets
                brl        :do_render
:not_a

                cmp        #'s'
                bne        :not_s
                lda        StartY
                cmp        MaxBG0Y
                bcs        :do_render
                inc        StartY
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                bra        :do_render
:not_s

                cmp        #'w'
                bne        :not_w
                lda        StartY
                beq        :do_render
                dec        StartY
                pei        StartX
                pei        StartY
                _GTESetBG0Origin
                bra        :do_render
:not_w

:do_render
                jsr  SetBG1Animation                ; Update the per-scanline BG1 offsets

                pea  #RENDER_PER_SCANLINE
;                pea  #0
                _GTERender

; Update the performance counters

                inc   frameCount
                inc   frameCountTotal
                pha
                _GTEGetSeconds
                pla
                cmp   OldOneSecondCounter
                beq   :noudt
                sta   OldOneSecondCounter
                jsr   UdtOverlay
                stz   frameCount
:noudt
                brl   EvtLoop

; Exit code
Exit
                _GTEShutDown
Quit
                _QuitGS    qtRec

                bcs   Fatal
Fatal           brk   $00

qtRec           adrl  $0000
                da    $00

; Color palette
MyDirectPage    ds    2

SetLimits
                pha                       ; Allocate space for width (in tiles), height (in tiles), pointer
                pha
                pha
                pha
                _GTEGetBG0TileMapInfo
                pla
                sta   TileMapWidth
                pla
                sta   TileMapHeight
                pla
                pla                       ; discard the pointer

                pha                       ; Allocate space for x, y, width, height
                pha
                pha
                pha
                _GTEGetScreenInfo
                pla
                pla                       ; Discard screen corner
                pla
                sta   ScreenWidth
                pla
                sta   ScreenHeight

                lda   TileMapWidth
                asl
                asl
                sta   MaxGlobalX
                sec
                sbc   ScreenWidth
                sta   MaxBG0X

                lda   TileMapHeight
                asl
                asl
                asl
                sta   MaxGlobalY
                sec
                sbc   ScreenHeight
                sta   MaxBG0Y

; Check if the current StartX and StartY are out of bounds
                lda   StartX
                cmp   MaxBG0X
                bcc   :x_ok
                lda   MaxBG0X
:x_ok           pha

                lda   StartY
                cmp   MaxBG0Y
                bcc   :y_ok
                lda   MaxBG0Y
:y_ok           pha
                _GTESetBG0Origin

                rts

DecRanges
                lda   seg1x
                bne   *+5
                lda   #164
                dec
                sta   seg1x
                bit   #1
                bne   :out
                lda   seg2x
                bne   *+5
                lda   #164
                dec
                sta   seg2x
                bit   #1
                bne   :out
                lda   seg3x
                bne   *+5
                lda   #164
                dec
                sta   seg3x
:out
                rts

IncRanges
                lda   seg1x
                inc
                cmp   #164
                bcc   *+5
                lda   #0
                sta   seg1x
                bit   #1
                bne   :out
                lda   seg2x
                inc
                cmp   #164
                bcc   *+5
                lda   #0
                sta   seg2x
                bit   #1
                bne   :out
                lda   seg3x
                inc
                cmp   #164
                bcc   *+5
                lda   #0
                sta   seg3x
                bit   #1
                bne   :out
                lda   seg4x
                inc
                cmp   #164
                bcc   *+5
                lda   #0
                sta   seg4x
:out
                rts


InitOffsets
                pha

                ldx   #0
                ldy   #40
                jsr   _InitRange
                ldx   #40
                ldy   #80
                jsr   _InitRange
                ldx   #120
                ldy   #88
                jsr   _InitRange
                jsr   _InitBG1

                pla
                sta   seg1x
                jsr   SetOffset1
                lsr
                sta   seg2x
                jsr   SetOffset2
                lsr
                sta   seg3x
                jsr   SetOffset3
                jsr   SetBG1Offsets
                rts

SetOffsets
                lda   seg1x
                jsr   SetOffset1
                lda   seg2x
                jsr   SetOffset2
                lda   seg3x
                jsr   SetOffset3

SetBG1Offsets
                pei   seg4x
                pea   0
                _GTESetBG1Origin
                rts

SetBG1Animation
                pea   #scanlineHorzOffset2
                pea   #^BG1Offsets
                lda   frameCountTotal
                and  #$000F
                asl
                adc   #BG1Offsets
                pha
                _GTESetAddress
                rts

SetOffset1
                ldx   #120
                ldy   #88
                jmp   _SetRange
SetOffset2
                ldx   #40
                ldy   #80
                jmp   _SetRange
SetOffset3
                ldx   #0
                ldy   #40
                jmp   _SetRange

_SetRange
                pha

                txa
                asl
                tax

:loop2          lda   BG0Offsets,x
                and   #$FF00
                ora   1,s
                sta   BG0Offsets,x

                dey
                beq   :done

                inx
                inx
                cpx   #416
                bcc   :loop2
:done
                pla
                rts

_offsets dw 0,0,0,1,1,2,3,3,4,4,4,3,3,2,1,1
_InitBG1
                ldx   #0
                ldy   #0
:loop           lda   _offsets,y
                sta   BG1Offsets,x
                iny
                iny
                cpy   #31
                bcc   *+5
                ldy   #0

                inx
                inx
                cpx   #448
                bcc   :loop
                rts

_InitRange
                txa
                asl
                tax

                tya
                dec
                and   #$00FF
                xba

:loop1          sta   BG0Offsets,x
                sec
                sbc   #$0100
                dey
                beq   :done
                inx
                inx
                cpx   #416
                bcc   :loop1
:done
                rts

; Load a binary file in the BG1 buffer
DoLoadBG1
                jsr   AllocBank               ; Alloc 64KB for Load/Unpack
                sta   BankLoad                ; Store "Bank Pointer"
                ldx   #BG1DataFile            ; Load the background file into the bank
                jsr   LoadFile

                pea   #164                    ; Fill everything
                pea   #200
                pea   #256
                lda   BankLoad
                pha
                pea   $0000
                pea   $0000                   ; default flags
                _GTECopyPicToBG1
                rts

BG1DataFile     strl  '1/bg1.bin'
BG0Offsets      ds    416
BG1Offsets      ds    448     ; Make this a bit larger so we can just update a pointer

                PUT        ../StartUp.s
                PUT        ../../shell/Overlay.s
                PUT        gen/App.TileMapBG0.s
