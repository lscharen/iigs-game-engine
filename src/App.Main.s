; Test program for graphics stufff...
;
; Allow dynamic resizing to benchmark against different games

                     rel

                     use        Util.Macs.s
                     use        Locator.Macs.s
                     use        Mem.Macs.s
                     use        Misc.Macs.s
                     put        ..\macros\App.Macs.s
                     put        ..\macros\EDS.GSOS.MACS.s
                     put        .\blitter\DirectPage.s

                     mx         %00

SHADOW_REG           equ        $E0C035
STATE_REG            equ        $E0C068
NEW_VIDEO_REG        equ        $E0C029
BORDER_REG           equ        $E0C034              ; 0-3 = border 4-7 Text color
VBL_VERT_REG         equ        $E0C02E
VBL_HORZ_REG         equ        $E0C02F

KBD_REG              equ        $E0C000
KBD_STROBE_REG       equ        $E0C010
VBL_STATE_REG        equ        $E0C019

SHR_SCREEN           equ        $E12000
SHR_SCB              equ        $E19D00

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

; Install interrupt handlers

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

; Start up the graphics engine...

                     jsr        MemInit              ; Allocate memory
                     jsr        BlitInit             ; Initialize the memory
                     jsr        GrafInit             ; Initialize the graphics screen

                     ldx        #6                   ; Gameboy Advance size
                     jsr        SetScreenMode

                     lda        #0                   ; Set the virtual Y-position
                     jsr        SetYPos

; Load a picture and copy it into Bank $E1.  Then turn on the screen.

                     jsr        AllocOneBank         ; Alloc 64KB for Load/Unpack
                     sta        BankLoad             ; Store "Bank Pointer"
EvtLoop
                     jsr        WaitForKey

                     cmp        #'q'
                     bne        :1
                     brl        Exit

:1                   cmp        #'l'
                     bne        :2
                     jsr        DoLoadPic
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

:5                   cmp        #'1'
                     bcc        :6
                     cmp        #'9'+1
                     bcs        :6
                     sec
                     sbc        #'1'
                     tax
                     jsr        SetScreenMode

:6                   bra        EvtLoop

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
;
;  X=mode number
]ScreenModeWidth     dw         320,272,256,256,280,256,240,288,160
]ScreenModeHeight    dw         200,192,200,176,160,160,160,128,144

SetScreenMode        cpx        #8
                     bcc        :rangeOk
                     ldx        #8

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


; Set up the code field and render it
DoFrame

; Render some tiles
:bank                equ        0
:column              equ        2
:tile                equ        4

                     stz        :bank
                     stz        :tile
:bankloop
                     ldx        :bank
                     ldal       BlitBuff+1,x         ; set the data bank to the code field
                     pha
                     plb
                     plb

                     stz        :column

:tileloop
                     ldx        :column
                     ldal       Col2CodeOffset,x
                     tay
                     iny
                     lda        :tile
                     jsr        CopyTile

                     lda        :tile
                     inc
                     and        #$000F
                     sta        :tile

                     lda        :column
                     clc
                     adc        #4
                     sta        :column
                     cmp        #4*40
                     bcc        :tileloop

                     lda        :bank
                     clc
                     adc        #4
                     sta        :bank
                     cmp        #4*13
                     bcc        :bankloop

                     phk
                     plb

; This sets up the environment for calling the blitter. The blitter code takes care of moving from
; line to line and should be set up ahead of time with appropriate epilogues for lines to periodically
; enable interrupts and other stuff.  In short, we call into the code once and, when it returns, all of
; the lines set up to render will be finished.

                     sep        #$20                 ; 8-bit acc
                     lda        BlitBuff+2           ; set the data bank to the code field
                     sta        blt_entry+3          ; Patch into the long jump
                     pha
                     pha                             ; push twice because we will use it later
                     rep        #$20

                     ldx        #80*2                ; This is the word to exit from
                     ldy        Col2CodeOffset,x     ; Get the offset

                     sep        #$20                 ; 8-bit acc
                     lda        BlitBuff+2           ; set the data bank to the code field
                     sta        blt_entry+3          ; Patch into the long jump
                     rep        #$20

                     plb                             ; set the data bank to the code field

                     ldx        #16*2                ; Y-register is set correctly
                     lda        #OPCODE_SAVE
                     jsr        SaveOpcode

                     ldx        #80*2                ; X-register is overwritten by SaveOpcode
                     ldal       CodeFieldEvenBRA,x   ; Get the value to place there
                     ldx        #16*2
                     jsr        SetConst

;                     lda        #{$2000+159+15*160}  ; Set the stack address to the right edge of the screen
;                     ldy        #0
;                     ldx        #16*2
;                     jsr        SetScreenAddrs

                     sep        #$20                 ; only need to do an 8-bit store
                     lda        #$06                 ; This is the entry address to start drawing
                     ldy        #CODE_ENTRY          ; don't actually need to set these again
                     ldx        #16*2
                     jsr        SetConst
                     rep        #$30

                     ldy        #$7000               ; Set the return after line 200 (Bank 13, line 8)
                     jsr        SetReturn

                     sei                             ; disable interrupts

                     ldal       STATE_REG
                     ora        #$0010               ; Read Bank 0 / Write Bank 1
                     stal       STATE_REG

                     tsc                             ; save the stack pointer
                     stal       stk_save+1

blt_entry            jml        $000006              ; Jump into the blitter code $XX/YY06

blt_return           ldal       STATE_REG            ; Read Bank 0 / Write Bank 0
                     and        #$FFCF
                     stal       STATE_REG
stk_save             lda        #0000                ; load the stack
                     tcs
                     cli                             ; re-enable interrupts

                     plb                             ; set the bank back to the code field
                     ldx        #80*2                ; This is the word to exit from
                     ldal       Col2CodeOffset,x     ; Get the offset
                     tay
                     ldx        #16*2
                     lda        #OPCODE_SAVE
;                     jsr        RestoreOpcode

                     phk                             ; restore data bank
                     plb
                     rts

DoLoadPic
                     lda        BankLoad
                     ldx        #ImageName           ; Load+Unpack Boot Picture
                     jsr        LoadPicture          ; X=Name, A=Bank to use for loading

                     lda        BankLoad             ; get address of loaded/uncompressed picture
                     clc
                     adc        #$0080               ; skip header? 
                     sta        :copySHR+2           ;  and store that over the 'ldal' address below
                     ldx        #$7FFE               ; copy all image data
:copySHR             ldal       $000000,x            ; load from BankLoad we allocated
                     stal       $E12000,x            ; store to SHR screen
                     dex
                     dex
                     bpl        :copySHR
                     rts

Exit
                     pea        $0007                ; disable 1-second interrupts
                     _IntSource

                     PushLong   #VBLTASK             ; Remove our heartbeat task
                     _DelHeartBeat

                     pea        $0015
                     PushLong   OldOneSecVec         ; Reset the interrupt vector
                     _SetVector

                     PushWord   UserId               ; Deallocate all of our memory
                     _DisposeAll

                     _QuitGS    qtRec

                     bcs        Fatal
Fatal                brk        $00

Hello                str        '000000'             ; str adds leading length byte

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
GrafInit             lda        #$8888
                     jsr        ClearToColor
                     lda        #0000
                     jsr        SetSCBs
                     jsr        GrafOn
                     jsr        ShadowOn
                     rts

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

LoadFile             stx        openRec+4            ; X=File, A=Bank/Page XX/00
                     sta        readRec+5

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
ImageName            strl       '1/test.pic'
MasterId             ds         2
UserId               ds         2
BankLoad             hex        0000

openRec              dw         2                    ; pCount
                     ds         2                    ; refNum
                     adrl       ImageName            ; pathname

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
                     put        font.s
                     put        blitter/Template.s
                     put        blitter/Tables.s



















































