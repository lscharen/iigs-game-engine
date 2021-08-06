; Test driver to exercise graphics routines.
;
; The general organization of the code is
;
;  1. The blitter/ folder contains all of the low-level graphics primitives
;  2. The blitter/DirectPage.s file defines all of the DP locations
;  3. Subroutines are written to try and be stateless, but, if local
;     storage is needed, it is takes from the stack and uses stack-relative
;     addressing.

; Allow dynamic resizing to benchmark against different games
                     REL
                     DSK        MAINSEG

                     use        Util.Macs.s
                     use        Locator.Macs.s
                     use        Mem.Macs.s
                     use        Misc.Macs.s
                     put        ..\macros\App.Macs.s
                     put        ..\macros\EDS.GSOS.MACS.s
                     put        ..\macros\Tool222.MACS.s
                     put        .\blitter\DirectPage.s

                     mx         %00

SHADOW_REG           equ        $E0C035
STATE_REG            equ        $E0C068
NEW_VIDEO_REG        equ        $E0C029
BORDER_REG           equ        $E0C034              ; 0-3 = border, 4-7 Text color
VBL_VERT_REG         equ        $E0C02E
VBL_HORZ_REG         equ        $E0C02F

KBD_REG              equ        $E0C000
KBD_STROBE_REG       equ        $E0C010
VBL_STATE_REG        equ        $E0C019

SHADOW_SCREEN        equ        $012000
SHR_SCREEN           equ        $E12000
SHR_SCB              equ        $E19D00
SHR_PALETTES         equ        $E19E00

; External references
tiledata             ext

; Feature flags
NO_INTERRUPTS        equ        0                    ; turn off for crossrunner debugging

; Typical init

                     phk
                     plb

; Tool startup

                     _TLStartUp                      ; normal tool initialization
                     pha
                     _MMStartUp
                     _Err                            ; should never happen
                     pla
                     sta        MasterId             ; our master handle references the memory allocated to us
                     ora        #$0100               ; set auxID = $01  (valid values $01-0f)
                     sta        UserId               ; any memory we request must use our own id 

                     _MTStartUp

                     pea        $00DE
                     pea        $0000
                     _LoadOneTool
                     _Err

                     lda        UserId
                     pha
                     _NTPStartUp

                     pea        #^MusicFile
                     pea        #MusicFile
                     _NTPLoadOneMusic

                     pea        $0001                ; loop
                     _NTPPlayMusic

; Use Tool222 (NinjaTrackerPlus) for music playback

; Install interrupt handlers.  We use the VBL interrupt to keep animations
; moving at a consistent rate, regarless of the rendered frame rate.  The 
; one-second timer is generally just used for counters and as a handy 
; frames-per-second trigger.

                     lda        #NO_INTERRUPTS
                     bne        :no_interrupts
                     PushLong   #0
                     pea        $0015                ; Get the existing 1-second interrupt handler and save
                     _GetVector
                     PullLong   OldOneSecVec

                     pea        $0015                ; Set the new handler and enable interrupts
                     PushLong   #OneSecHandler
                     _SetVector

                     pea        $0006
                     _IntSource

                     PushLong   #VBLTASK             ; Also register a Heart Beat Task
                     _SetHeartBeat
:no_interrupts

; Start up the graphics engine...

                     jsr        MemInit              ; Allocate memory
                     jsr        BlitInit             ; Initialize the memory
                     jsr        GrafInit             ; Initialize the graphics screen

                     ldx        #6                   ; Gameboy Advance size
                     jsr        SetScreenMode

                     lda        #0                   ; Set the virtual Y-position
                     jsr        SetBG0YPos

                     lda        #0                   ; Set the virtual X-position
                     jsr        SetBG0XPos

                     jsr        _InitBG1             ; Initialize the second background

                     lda        #0
                     jsr        _ClearBG1Buffer

; Set up our level data
                     jsr        BG0SetUp

; Allocate room to load data

                     jsr        AllocOneBank2        ; Alloc 64KB for Load/Unpack
                     sta        BankLoad             ; Store "Bank Pointer"

                     ldx        #0
                     jsr        SetScreenMode
;                     jsr        DoTiles
;                     jsr        DoLoadBG1
;                     jsr        Demo
EvtLoop
                     jsr        WaitForKey

                     cmp        #'q'
                     bne        :1
                     brl        Exit

:1                   cmp        #'l'
                     bne        :1_1
                     jsr        DoLoadFG
                     bra        EvtLoop

:1_1                 cmp        #'b'
                     bne        :2
                     jsr        DoLoadBG1
                     bra        EvtLoop

:2                   cmp        #'m'
                     bne        :3
                     jsr        DumpBanks
                     bra        EvtLoop

:3                   cmp        #'f'                 ; render a 'f'rame
                     bne        :4
                     jsr        DoFrame
                     bra        EvtLoop

:4                   cmp        #'h'                 ; Show the 'h'eads up display
                     bne        :5
                     jsr        DoHUP
                     bra        EvtLoop

:5                   cmp        #'1'                 ; User selects a new screen size
                     bcc        :6
                     cmp        #'9'+1
                     bcs        :6
                     sec
                     sbc        #'1'
                     tax
                     jsr        SetScreenMode
                     brl        EvtLoop

:6                   cmp        #'t'
                     bne        :7
                     jsr        DoTiles
                     brl        EvtLoop

:7                   cmp        #$15                 ; left = $08, right = $15, up = $0B, down = $0A
                     bne        :8
                     lda        #1
                     jsr        MoveRight
                     brl        EvtLoop

:8                   cmp        #$08
                     bne        :9
                     lda        #1
                     jsr        MoveLeft
                     brl        EvtLoop

:9                   cmp        #$0B
                     bne        :10
                     lda        #1
                     jsr        MoveUp
                     brl        EvtLoop

:10                  cmp        #$0A
                     bne        :11
                     lda        #1
                     jsr        MoveDown
                     brl        EvtLoop

:11                  cmp        #'d'
                     bne        :12
                     lda        #1
                     jsr        Demo
                     brl        EvtLoop

:12                  cmp        #'z'
                     bne        :13
                     jsr        AngleUp
                     brl        EvtLoop

:13                  cmp        #'x'
                     bne        :14
                     jsr        AngleDown
                     brl        EvtLoop

:14                  brl        EvtLoop

; Exit code
Exit
                     lda        #NO_INTERRUPTS
                     bne        :no_interrupts

                     pea        $0007                ; disable 1-second interrupts
                     _IntSource

                     PushLong   #VBLTASK             ; Remove our heartbeat task
                     _DelHeartBeat

                     pea        $0015
                     PushLong   OldOneSecVec         ; Reset the interrupt vector
                     _SetVector
:no_interrupts

                     _NTPShutDown

                     PushWord   UserId               ; Deallocate all of our memory
                     _DisposeAll

                     _QuitGS    qtRec

                     bcs        Fatal
Fatal                brk        $00

ClearBankLoad
                     lda        BankLoad
                     phb
                     pha
                     plb
                     ldx        #$FFFE
:lp                  sta:       $0000,x
                     dex
                     dex
                     cpx        #0
                     bne        :lp
                     plb
                     plb
                     rts

; Allow the user to dynamically select one of the pre-configured screen sizes
;
;  1. Full Screen           : 40 x 25   320 x 200 (32,000 bytes (100.0%)) 
;  2. Sword of Sodan        : 34 x 24   272 x 192 (26,112 bytes ( 81.6%))
;  3. ~NES                  : 32 x 25   256 x 200 (25,600 bytes ( 80.0%))
;  4. Task Force            : 32 x 22   256 x 176 (22,528 bytes ( 70.4%))
;  5. Defender of the World : 35 x 20   280 x 160 (22,400 bytes ( 70.0%))
;  6. Rastan                : 32 x 20   256 x 160 (20,480 bytes ( 64.0%))
;  7. Game Boy Advanced     : 30 x 20   240 x 160 (19,200 bytes ( 60.0%))
;  8. Ancient Land of Y's   : 36 x 16   288 x 128 (18,432 bytes ( 57.6%))
;  9. Game Boy Color        : 20 x 18   160 x 144 (11,520 bytes ( 36.0%))
; 10. DEBUG                 : 40 x 1    320 x 1
;  X=mode number

]ScreenModeWidth     dw         320,272,256,256,280,256,240,288,160,320
]ScreenModeHeight    dw         200,192,200,176,160,160,160,128,144,1

SetScreenMode        cpx        #9
                     bcc        :rangeOk
                     ldx        #9

:rangeOk             txa
                     asl
                     tax

                     lda        #320                 ; Calculate the screen offset
                     sec
                     sbc:       ]ScreenModeWidth,x
                     lsr
                     lsr
                     xba
                     pha

                     lda        #200
                     sec
                     sbc:       ]ScreenModeHeight,x
                     lsr
                     ora        1,s
                     sta        1,s

                     ldy:       ]ScreenModeHeight,x
                     lda:       ]ScreenModeWidth,x
                     lsr
                     tax
                     pla
                     jsr        SetScreenRect
                     jsr        FillScreen
                     rts

SecondsStr           str        'SECONDS'
TicksStr             str        'TICKS'

; Print a bunch of messages on screen
DoHUP
                     lda        #SecondsStr
                     ldx        #{160-12*4}
                     ldy        #$7777
                     jsr        DrawString
                     lda        OneSecondCounter     ; Number of elapsed seconds
                     ldx        #{160-4*4}           ; Render the word 4 charaters from right edge
                     jsr        DrawWord

                     lda        #TicksStr
                     ldx        #{8*160+160-12*4}
                     ldy        #$7777
                     jsr        DrawString
                     PushLong   #0
                     _GetTick
                     pla
                     plx
                     ldx        #{8*160+160-4*4}
                     jsr        DrawWord
                     rts

; Fill up the virtual buffer with tile data
DoTiles
:row                 equ        1
:column              equ        3
:tile                equ        5

                     pea        $0000                ; Allocate local variable space
                     pea        $0000
                     pea        $0000

:rowloop
                     lda        #0
                     sta        :column,s
                     lda        #$0010
                     sta        :tile,s

:colloop
                     lda        :row,s
                     tay
                     lda        :column,s
                     tax
                     lda        :tile,s
                     jsr        CopyTile

;                     lda        :tile,s
;                     eor        #$0003
;                     sta        :tile,s

                     lda        :column,s
                     inc
                     sta        :column,s
                     cmp        #41
                     bcc        :colloop

                     lda        :row,s
                     inc
                     sta        :row,s
                     cmp        #26
                     bcc        :rowloop

                     pla                             ; restore the stack
                     pla
                     pla
                     rts

; Set up the code field and render it
DoFrame
                     lda        #$FFFF
                     sta        DirtyBits
                     jsr        Render               ; Render the play field
                     rts

; Load a binary file in the BG1 buffer
DoLoadBG1
                     lda        BankLoad
                     ldx        #BG1DataFile
                     jsr        LoadFile

                     ldx        BankLoad
                     lda        #0
                     ldy        BG1DataBank
                     jsr        CopyBinToBG1

                     lda        BankLoad
                     ldx        #BG1AltDataFile
                     jsr        LoadFile

                     ldx        BankLoad
                     lda        #0
                     ldy        BG1AltBank
                     jsr        CopyBinToBG1

                     rts

; Load a raw pixture into the code buffer
DoLoadFG
                     lda        BankLoad
                     ldx        #FGName
                     jsr        LoadFile

                     ldx        BankLoad             ; Copy it into the code field
                     lda        #0
                     jsr        CopyBinToField
                     rts

; Load a simple picture format onto the SHR screen
DoLoadPic
                     lda        BankLoad
                     ldx        #ImageName           ; Load+Unpack Boot Picture
                     jsr        LoadPicture          ; X=Name, A=Bank to use for loading

                     ldx        BankLoad             ; Copy it into the code field
                     lda        #0
                     jsr        CopyPicToField
                     rts

; Copy a raw data file into the code field
;
; A=low word of picture address
; X=high word of pixture address
CopyBinToField
:srcptr              equ        tmp0
:line_cnt            equ        tmp2
:dstptr              equ        tmp3
:col_cnt             equ        tmp5
:mask                equ        tmp6
:data                equ        tmp7
:mask_color          equ        tmp8

                     sta        :srcptr
                     stx        :srcptr+2

; Check that this is a GTERAW image and save the transparent color

                     ldy        #4
:chkloop
                     lda        [:srcptr],y
                     cmp        :headerStr,y
                     beq        *+3
                     rts
                     dey
                     dey
                     bpl        :chkloop

; We have a valid header, now get the transparency word and load it in
                     ldy        #6
                     lda        [:srcptr],y
                     sta        :mask_color

; Advance over the header
                     lda        :srcptr
                     clc
                     adc        #8
                     sta        :srcptr

                     stz        :line_cnt
:rloop
                     lda        :line_cnt            ; get the pointer to the code field line
                     asl
                     tax

                     lda        BTableLow,x
                     sta        :dstptr
                     lda        BTableHigh,x
                     sta        :dstptr+2

                     ldx        #162                 ; move backwards in the code field
                     ldy        #0                   ; move forward in the image data

                     lda        #82                  ; keep a running column count
                     sta        :col_cnt

:cloop
                     phy
                     lda        [:srcptr],y          ; load the picture data
                     cmp        :mask_color
                     beq        :transparent         ; a value of $0000 is transparent

                     jsr        :toMask              ; Infer a mask value for this. If it's $0000, then
                     cmp        #$0000
                     bne        :mixed               ; the data is solid, otherwise mixed

; This is a solid word
:solid
                     lda        [:srcptr],y
                     ldy        Col2CodeOffset,x     ; Get the offset to the code from the line start

                     pha                             ; Save the data
                     lda        #$00F4               ; PEA instruction
                     sta        [:dstptr],y
                     iny
                     pla
                     sta        [:dstptr],y          ; PEA operand
                     bra        :next
:transparent
                     lda        :mask_color          ; Make sure we actually have to mask
                     cmp        #$A5A5
                     beq        :solid

                     ldy        Col2CodeOffset,x     ; Get the offset to the code from the line start
                     lda        #$B1                 ; LDA (dp),y
                     sta        [:dstptr],y
                     iny
                     lda        1,s                  ; load the saved Y-index
                     ora        #$4800               ; put a PHA after the offset
                     sta        [:dstptr],y
                     bra        :next

:mixed
                     sta        :mask                ; Save the mask
                     lda        [:srcptr],y          ; Refetch the screen data
                     sta        :data

                     ldy        Col2CodeOffset,x     ; Get the offset into the code field
                     lda        #$4C                 ; JMP exception
                     sta        [:dstptr],y
                     iny

                     lda        JTableOffset,x       ; Get the address offset and add to the base address
                     clc
                     adc        :dstptr
                     sta        [:dstptr],y

                     ldy        JTableOffset,x       ; This points to the code fragment
                     lda        1,s                  ; load the offset
                     xba
                     ora        #$00B1
                     sta        [:dstptr],y          ; write the LDA (--),y instruction
                     iny
                     iny
                     iny                             ; advance to the AND #imm operand
                     lda        :mask
                     sta        [:dstptr],y
                     iny
                     iny
                     iny                             ; advance to the ORA #imm operand
                     lda        :mask
                     eor        #$FFFF               ; invert the mask to clear up the data
                     and        :data
                     sta        [:dstptr],y

:next
                     ply

                     dex
                     dex
                     iny
                     iny

                     dec        :col_cnt
                     bne        :cloop

                     lda        :srcptr
                     clc
                     adc        #164
                     sta        :srcptr

                     inc        :line_cnt
                     lda        :line_cnt
                     cmp        #200
                     bcs        :exit
                     brl        :rloop

:exit
                     rts

:toMask              pha                             ; save original

                     lda        1,s
                     eor        :mask_color          ; only identical bits produce zero
                     and        #$F000
                     beq        *+7
                     pea        #$0000
                     bra        *+5
                     pea        #$F000


                     lda        3,s
                     eor        :mask_color
                     and        #$0F00
                     beq        *+7
                     pea        #$0000
                     bra        *+5
                     pea        #$0F00

                     lda        5,s
                     eor        :mask_color
                     and        #$00F0
                     beq        *+7
                     pea        #$0000
                     bra        *+5
                     pea        #$00F0

                     lda        7,s
                     eor        :mask_color
                     and        #$000F
                     beq        *+7
                     lda        #$0000
                     bra        *+5
                     lda        #$000F

                     ora        1,s
                     sta        1,s
                     pla
                     ora        1,s
                     sta        1,s
                     pla
                     ora        1,s
                     sta        1,s
                     pla

                     sta        1,s                  ; pop the saved word
                     pla
                     rts

:headerStr           asc        'GTERAW'

; Copy a loaded SHR picture into the code field
;
; A=low word of picture address
; X=high workd of pixture address
;
; Picture must be within one bank
CopyPicToField
:srcptr              equ        tmp0
:line_cnt            equ        tmp2
:dstptr              equ        tmp3
:col_cnt             equ        tmp5
:mask                equ        tmp6
:data                equ        tmp7

                     sta        :srcptr
                     stx        :srcptr+2

                     stz        :line_cnt
:rloop
                     lda        :line_cnt            ; get the pointer to the code field line
                     asl
                     tax

                     lda        BTableLow,x
                     sta        :dstptr
                     lda        BTableHigh,x
                     sta        :dstptr+2

                     ldx        #162                 ; move backwards in the code field
                     ldy        #0                   ; move forward in the image data

                     lda        #80                  ; keep a running column count
;                     lda        #82                  ; keep a running column count
                     sta        :col_cnt

:cloop
                     phy
                     lda        [:srcptr],y          ; load the picture data
                     beq        :transparent         ; a value of $0000 is transparent

                     jsr        :toMask              ; Infer a mask value for this. If it's $0000, then
                     bne        :mixed               ; the data is solid, otherwise mixed

; This is a solid word
                     lda        [:srcptr],y
                     ldy        Col2CodeOffset,x     ; Get the offset to the code from the line start

                     pha                             ; Save the data
                     lda        #$00F4               ; PEA instruction
                     sta        [:dstptr],y
                     iny
                     pla
                     sta        [:dstptr],y          ; PEA operand
                     bra        :next
:transparent
                     ldy        Col2CodeOffset,x     ; Get the offset to the code from the line start
                     lda        #$B1                 ; LDA (dp),y
                     sta        [:dstptr],y
                     iny
                     lda        1,s                  ; load the saved Y-index
                     ora        #$4800               ; put a PHA after the offset
                     sta        [:dstptr],y
                     bra        :next

:mixed
                     sta        :mask                ; Save the mask
                     lda        [:srcptr],y          ; Refetch the screen data
                     sta        :data

                     ldy        Col2CodeOffset,x     ; Get the offset into the code field
                     lda        #$4C                 ; JMP exception
                     sta        [:dstptr],y
                     iny

                     lda        JTableOffset,x       ; Get the address offset and add to the base address
                     clc
                     adc        :dstptr
                     sta        [:dstptr],y

                     ldy        JTableOffset,x       ; This points to the code fragment
                     lda        1,s                  ; load the offset
                     xba
                     ora        #$00B1
                     sta        [:dstptr],y          ; write the LDA (--),y instruction
                     iny
                     iny
                     iny                             ; advance to the AND #imm operand
                     lda        :mask
                     sta        [:dstptr],y
                     iny
                     iny
                     iny                             ; advance to the ORA #imm operand
                     lda        :data
                     sta        [:dstptr],y

:next
                     ply

                     dex
                     dex
                     iny
                     iny

                     dec        :col_cnt
                     bne        :cloop

                     lda        :srcptr
                     clc
;                     adc        #164
                     adc        #160
                     sta        :srcptr

                     inc        :line_cnt
                     lda        :line_cnt
;                     cmp        #208
                     cmp        #200
                     bcs        :exit
                     brl        :rloop

:exit
                     rts

:toMask              bit        #$F000
                     beq        *+7
                     and        #$0FFF
                     bra        *+5
                     ora        #$F000

                     bit        #$0F00
                     beq        *+7
                     and        #$F0FF
                     bra        *+5
                     ora        #$0F00

                     bit        #$00F0
                     beq        *+7
                     and        #$FF0F
                     bra        *+5
                     ora        #$00F0

                     bit        #$000F
                     beq        *+7
                     and        #$FFF0
                     bra        *+5
                     ora        #$000F
                     rts

; Copy a binary image data file into BG1.  Assumes the file is the correct size.
;
; A=low word of picture address
; X=high word of pixture address
; Y=high word of BG1 bank

CopyBinToBG1
:srcptr              equ        tmp0
:line_cnt            equ        tmp2
:dstptr              equ        tmp3
:col_cnt             equ        tmp5

                     sta        :srcptr
                     stx        :srcptr+2
                     sty        :dstptr+2            ; Everything goes into this bank

                                                     ; Advance over the header
                     lda        :srcptr
                     clc
                     adc        #8
                     sta        :srcptr

                     stz        :line_cnt
:rloop
                     lda        :line_cnt            ; get the pointer to the code field line
                     asl
                     tax

                     lda        BG1YTable,x
                     sta        :dstptr

                     ldy        #0                   ; move forward in the image data and image data
:cloop
                     lda        [:srcptr],y
                     sta        [:dstptr],y

                     iny
                     iny

                     cpy        #164
                     bcc        :cloop

                     lda        [:srcptr]            ; Duplicate the last byte in the extra space at the end of the line
                     sta        [:dstptr],y

                     lda        :srcptr
                     clc
                     adc        #164                 ; Each line is 328 pixels
                     sta        :srcptr

                     inc        :line_cnt
                     lda        :line_cnt
                     cmp        #208                 ; A total of 208 lines
                     bcc        :rloop
                     rts

****************************************
* Fatal Error Handler                  *
****************************************
PgmDeath             tax
                     pla
                     inc
                     phx
                     phk
                     pha
                     bra        ContDeath
PgmDeath0            pha
                     pea        $0000
                     pea        $0000
ContDeath            ldx        #$1503
                     jsl        $E10000

; Interrupt handlers. We install a heartbeat (1/60th second and a 1-second timer)
OneSecHandler        mx         %11
                     phb
                     pha
                     phk
                     plb

                     rep        #$20
                     inc        OneSecondCounter
                     sep        #$20

                     ldal       $E0C032
                     and        #%10111111           ;clear IRQ source
                     stal       $E0C032

                     pla
                     plb
                     clc
                     rtl
                     mx         %00
OneSecondCounter     dw         0
OldOneSecVec         ds         4

VBLTASK              hex        00000000
                     dw         0
                     hex        5AA5

; Blitter initialization
BlitInit
                     stz        ScreenHeight
                     stz        ScreenWidth
                     stz        ScreenY0
                     stz        ScreenY1
                     stz        ScreenX0
                     stz        ScreenX1
                     stz        ScreenTileHeight
                     stz        ScreenTileWidth
                     stz        StartX
                     stz        StartXMod164
                     stz        StartY
                     stz        StartYMod208
                     stz        EngineMode
                     stz        DirtyBits
                     stz        LastPatchOffset
                     stz        BG1StartX
                     stz        BG1StartXMod164
                     stz        BG1StartY
                     stz        BG1StartYMod208
                     stz        BG1OffsetIndex

]step                equ        0
                     lup        13
                     ldx        #BlitBuff
                     lda        #^BlitBuff
                     ldy        #]step
                     jsr        BuildBank
]step                equ        ]step+4
                     --^
                     rts


; Graphic screen initialization
GrafInit
                     jsr        ShadowOn
                     jsr        GrafOn
                     lda        #$8888
                     jsr        ClearToColor
                     lda        #0000
                     jsr        SetSCBs
                     ldx        #DefaultPalette
                     lda        #0
                     jsr        SetPalette
                     rts

;DefaultPalette       dw         $0000,$007F,$0090,$0FF0
;                     dw         $000F,$0080,$0f70,$0FFF
                     dw         $0fa9,$0ff0,$00e0,$04DF
                     dw         $0d00,$078f,$0ccc,$0FFF

; DefaultPalette       dw         $09BE,$0AA6,$0DC9,$0DB7,$09AA
                     dw         $0080,$0f70,$0FFF
                     dw         $0fa9,$0ff0,$00e0,$04DF
                     dw         $0d00,$078f,$0ccc,$0FFF

; Super Mario World Assets
;DefaultPalette       dw         $0EEF,$0342,$0C95,$0852,$0DB4,$00C0
                     dw         $0FDA,$0DEE,$0000,$0CC5,$09A0,$0680,$0470,$0051

;DefaultPalette       dw         $0000,$0000,$0778,$0BCC,$0368,$00AF,$0556,$0245
                     dw         $0000,$0778,$0AAA,$0CFF,$0368,$00AF,$0556

; Woz
;DefaultPalette       dw         $0EEF,$0342,$0C95,$0852,$0DB4,$00C0
                     dw         $0666,$0999,$0CCC,$0222,$09A0,$0680,$0470,$0051

; Fatdog color cycling
;DefaultPalette       dw         $0EEF,$0342,$0C95,$0852,$0DB4,$00C0
                     dw         $0156,$0288,$03A8,$07B8,$0034,$0013,$0470,$0051

; Plant
DefaultPalette       dw         $0EEF,$0342,$0C95,$0852,$0DB4,$00C0
                     dw         $0222,$0333,$0444,$0888,$09A0,$0680,$0470,$0051
; Return the current border color ($0 - $F) in the accumulator
GetBorderColor       lda        #0000
                     sep        #$20
                     ldal       BORDER_REG
                     and        #$0F
                     rep        #$20
                     rts

; Set the border color to the accumulator value.
SetBorderColor       sep        #$20                 ; ACC = $X_Y, REG = $W_Z
                     eorl       BORDER_REG           ; ACC = $(X^Y)_(Y^Z)
                     and        #$0F                 ; ACC = $0_(Y^Z)
                     eorl       BORDER_REG           ; ACC = $W_(Y^Z^Z) = $W_Y
                     stal       BORDER_REG
                     rep        #$20
                     rts

; Clear to SHR screen to a specific color
ClearToColor         ldx        #$7D00               ;start at top of pixel data! ($2000-9D00)
:clearloop           dex
                     dex
                     stal       SHR_SCREEN,x         ;screen location
                     bne        :clearloop           ;loop until we've worked our way down to 0
                     rts

; Set a palette values
; A = palette number, X = palette address
SetPalette
                     and        #$000F               ; palette values are 0 - 15 and each palette is 32 bytes
                     asl
                     asl
                     asl
                     asl
                     asl
                     txy
                     tax

]idx                 equ        0
                     lup        16
                     lda:       $0000+]idx,y
                     stal       SHR_PALETTES+]idx,x
]idx                 equ        ]idx+2
                     --^
                     rts

; Initialize the SCB
SetSCBs              ldx        #$0100               ;set all $100 scbs to A
:scbloop             dex
                     dex
                     stal       SHR_SCB,x
                     bne        :scbloop
                     rts

; Turn SHR screen On/Off
GrafOn               sep        #$20
                     lda        #$81
                     stal       NEW_VIDEO_REG
                     rep        #$20
                     rts

GrafOff              sep        #$20
                     lda        #$01
                     stal       NEW_VIDEO_REG
                     rep        #$20
                     rts

; Enable/Disable Shadowing.
ShadowOn             sep        #$20
                     ldal       SHADOW_REG
                     and        #$F7
                     stal       SHADOW_REG
                     rep        #$20
                     rts

ShadowOff            sep        #$20
                     ldal       SHADOW_REG
                     ora        #$08
                     stal       SHADOW_REG
                     rep        #$20
                     rts

GetVBL               sep        #$20
                     ldal       VBL_HORZ_REG
                     asl
                     ldal       VBL_VERT_REG
                     rol                             ; put V5 into carry bit, if needed. See TN #39 for details.
                     rep        #$20
                     and        #$00FF
                     rts

WaitForVBL           sep        #$20
:wait1               ldal       VBL_STATE_REG        ; If we are already in VBL, then wait
                     bmi        :wait1
:wait2               ldal       VBL_STATE_REG
                     bpl        :wait2               ; spin until transition into VBL
                     rep        #$20
                     rts

WaitForKey           sep        #$20
                     stal       KBD_STROBE_REG       ; clear the strobe
:WFK                 ldal       KBD_REG
                     bpl        :WFK
                     rep        #$20
                     and        #$007F
                     rts

ClearKeyboardStrobe  sep        #$20
                     stal       KBD_STROBE_REG
                     rep        #$20
                     rts

; Graphics helpers

LoadPicture
                     jsr        LoadFile             ; X=Nom Image, A=Banc de chargement XX/00
                     bcc        :loadOK
                     rts
:loadOK
                     jsr        UnpackPicture        ; A=Packed Size
                     rts


UnpackPicture        sta        UP_PackedSize        ; Size of Packed Data
                     lda        #$8000               ; Size of output Data Buffer
                     sta        UP_UnPackedSize
                     lda        BankLoad             ; Banc de chargement / Decompression
                     sta        UP_Packed+1          ; Packed Data
                     clc
                     adc        #$0080
                     stz        UP_UnPacked          ; On remet a zero car modifie par l'appel
                     stz        UP_UnPacked+2
                     sta        UP_UnPacked+1        ; Unpacked Data buffer

                     PushWord   #0                   ; Space for Result : Number of bytes unpacked 
                     PushLong   UP_Packed            ; Pointer to buffer containing the packed data
                     PushWord   UP_PackedSize        ; Size of the Packed Data
                     PushLong   #UP_UnPacked         ; Pointer to Pointer to unpacked buffer
                     PushLong   #UP_UnPackedSize     ; Pointer to a Word containing size of unpacked data
                     _UnPackBytes
                     pla                             ; Number of byte unpacked
                     rts

UP_Packed            hex        00000000             ; Address of Packed Data
UP_PackedSize        hex        0000                 ; Size of Packed Data
UP_UnPacked          hex        00000000             ; Address of Unpacked Data Buffer (modified)
UP_UnPackedSize      hex        0000                 ; Size of Unpacked Data Buffer (modified)

; Basic I/O function to load files

LoadFile
                     stx        openRec+4            ; X=File, A=Bank (high word) assumed zero for low
                     stz        readRec+4
                     sta        readRec+6
                     jsr        ClearBankLoad

:openFile            _OpenGS    openRec
                     bcs        :openReadErr
                     lda        openRec+2
                     sta        eofRec+2
                     sta        readRec+2

                     _GetEOFGS  eofRec
                     lda        eofRec+4
                     sta        readRec+8
                     lda        eofRec+6
                     sta        readRec+10

                     _ReadGS    readRec
                     bcs        :openReadErr

:closeFile           _CloseGS   closeRec
                     clc
                     lda        eofRec+4             ; File Size
                     rts

:openReadErr         jsr        :closeFile
                     nop
                     nop

                     PushWord   #0
                     PushLong   #msgLine1
                     PushLong   #msgLine2
                     PushLong   #msgLine3
                     PushLong   #msgLine4
                     _TLTextMountVolume
                     pla
                     cmp        #1
                     bne        :loadFileErr
                     brl        :openFile
:loadFileErr         sec
                     rts

msgLine1             str        'Unable to load File'
msgLine2             str        'Press a key :'
msgLine3             str        ' -> Return to Try Again'
msgLine4             str        ' -> Esc to Quit'

; Data storage    
MusicFile            str        '1/main.ntp'
BG1DataFile          strl       '1/bg1a.bin'
BG1AltDataFile       strl       '1/bg1b.bin'

ImageName            strl       '1/test.pic'
FGName               strl       '1/fg1.bin'
MasterId             ds         2
UserId               ds         2

openRec              dw         2                    ; pCount
                     ds         2                    ; refNum
                     adrl       FGName               ; pathname

eofRec               dw         2                    ; pCount
                     ds         2                    ; refNum
                     ds         4                    ; eof

readRec              dw         4                    ; pCount
                     ds         2                    ; refNum
                     ds         4                    ; dataBuffer
                     ds         4                    ; requestCount
                     ds         4                    ; transferCount

closeRec             dw         1                    ; pCount
                     ds         2                    ; refNum

qtRec                adrl       $0000
                     da         $00

                     put        App.Init.s
                     put        App.Msg.s
                     put        Actions.s
                     put        font.s
                     put        Render.s
                     put        blitter/Blitter.s
                     put        blitter/Horz.s
                     put        blitter/PEISlammer.s
                     put        blitter/Tables.s
                     put        blitter/Template.s
                     put        blitter/Tiles.s
                     put        blitter/Vert.s
                     put        blitter/BG1.s
                     PUT        TileMap.s
                     PUT        Level.s




