; Test driver to exercise graphics routines.

                    REL
                    DSK        MAINSEG

                    use        Locator.Macs.s
                    use        Misc.Macs.s
                    use        EDS.GSOS.MACS.s
                    use        Tool222.Macs.s
                    use        Util.Macs.s
                    use        CORE.MACS.s
                    use         GTE.Macs

                    use        ../../src/Defs.s

                    mx         %00

TSet                EXT

; Feature flags
NO_INTERRUPTS       equ        0                       ; turn off for crossrunner debugging
NO_MUSIC            equ        1                       ; turn music + tool loading off

; Typical init
                    phk
                    plb

                    sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program
                    _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

                    jsr   GTEStartUp              ; Load and install the GTE User Tool

; Load a tileset

                pea   #^TSet
                pea   #TSet
                _GTELoadTileSet


                pea   $0000
                pea   #^MyPalette
                pea   #MyPalette
                _GTESetPalette

                pea   $0000
                pea   $0000
                _GTESetScreenMode

; Set up our level data
                jsr        BG0SetUp
                jsr        BG1SetUp
                jsr        TileAnimInit

; Allocate room to load data

                jsl        AllocBank               ; Alloc 64KB for Load/Unpack
                sta        BankLoad                ; Store "Bank Pointer"

                jsr        MovePlayerToOrigin      ; Put the player at the beginning of the map

                lda        #193                    ; Tile ID of '0'
                jsr        InitOverlay             ; Initialize the status bar

EvtLoop
                    jsl        DoTimers
                    jsl        Render
                    inc        frameCount

                    ldal       OneSecondCounter
                    cmp        oldOneSecondCounter
                    beq        :noudt
                    sta        oldOneSecondCounter
                    jsr        UdtOverlay
                    stz        frameCount
:noudt

                    jsl        ReadControl
                    and        #$007F                  ; Ignore the buttons for now

                    cmp        #'q'
                    bne        :1
                    brl        Exit

:1
                    cmp        #'l'
                    bne        :1_1
                    jsr        DoLoadFG
                    brl        EvtLoop

:1_1                cmp        #'b'
                    bne        :2
                    jsr        DoLoadBG1
                    brl        EvtLoop

:2                  cmp        #'m'
                    bne        :3
                    jsr        DumpBanks
                    brl        EvtLoop

:3                  cmp        #'f'                    ; render a 'f'rame
                    bne        :4
                    jsl        Render
                    brl        EvtLoop

:4                  cmp        #'h'                    ; Show the 'h'eads up display
                    bne        :5
                    jsr        DoHUP
                    brl        EvtLoop

:5                  cmp        #'1'                    ; User selects a new screen size
                    bcc        :6
                    cmp        #'9'+1
                    bcs        :6
                    sec
                    sbc        #'1'
                    tax
                    jsl        SetScreenMode
                    jsr        MovePlayerToOrigin
                    brl        EvtLoop

:6                  cmp        #'t'
                    bne        :7
                    jsr        DoTiles
                    brl        EvtLoop

:7                  cmp        #$15                    ; left = $08, right = $15, up = $0B, down = $0A
                    bne        :8
                    lda        #1
                    jsr        MoveRight
                    brl        EvtLoop

:8                  cmp        #$08
                    bne        :9
                    lda        #1
                    jsr        MoveLeft
                    brl        EvtLoop

:9                  cmp        #$0B
                    bne        :10
                    lda        #1
                    jsr        MoveUp
                    brl        EvtLoop

:10                 cmp        #$0A
                    bne        :11
                    lda        #1
                    jsr        MoveDown
                    brl        EvtLoop

:11                 cmp        #'d'
                    bne        :12
                    lda        #1
                    jsr        Demo
                    brl        EvtLoop

:12                 cmp        #'z'
                    bne        :13
                    jsr        AngleUp
                    brl        EvtLoop

:13                 cmp        #'x'
                    bne        :14
                    jsr        AngleDown
                    brl        EvtLoop

:14                 brl        EvtLoop

; Exit code
Exit
                    jsl        EngineShutDown

                    _QuitGS    qtRec

                    bcs        Fatal
Fatal               brk        $00

MyPalette           dw         $0000,$0777,$0F31,$0E51,$00A0,$02E3,$0BF1,$0FA4,$0FD7,$0EE6,$0F59,$068F,$01CE,$09B9,$0EDA,$0EEE

StartMusic
                    pea        #^MusicFile
                    pea        #MusicFile
                    _NTPLoadOneMusic

                    pea        $0001                   ; loop
                    _NTPPlayMusic
                    rts

; Position the screen with the botom-left corner of the tilemap visible
MovePlayerToOrigin
                    lda        #0                      ; Set the player's position
                    jsl        SetBG0XPos
                    lda        #0
                    jsl        SetBG1XPos

                    lda        TileMapHeight
                    asl
                    asl
                    asl
                    sec
                    sbc        ScreenHeight
                    pha
                    jsl        SetBG0YPos
                    pla
                    jsl        SetBG1YPos

                    rts

ClearBankLoad
                    lda        BankLoad
                    phb
                    pha
                    plb
                    ldx        #$FFFE
:lp                 sta:       $0000,x
                    dex
                    dex
                    cpx        #0
                    bne        :lp
                    plb
                    plb
                    rts

SecondsStr          str        'SECONDS'
TicksStr            str        'TICKS'

; Print a bunch of messages on screen
DoHUP
                    lda        #SecondsStr
                    ldx        #{160-12*4}
                    ldy        #$7777
                    jsr        DrawString
                    lda        OneSecondCounter        ; Number of elapsed seconds
                    ldx        #{160-4*4}              ; Render the word 4 charaters from right edge
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
:row                equ        1
:column             equ        3
:tile               equ        5

                    pea        $0000                   ; Allocate local variable space
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
                    jsl        CopyBG0Tile

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

                    pla                                ; restore the stack
                    pla
                    pla
                    rts

; Load a binary file in the BG1 buffer
DoLoadBG1
                    lda        BankLoad
                    ldx        #BG1DataFile
                    jsr        LoadFile

                    ldx        BankLoad
                    lda        #0
                    ldy        BG1DataBank
                    jsl        CopyBinToBG1

                    lda        BankLoad
                    ldx        #BG1AltDataFile
                    jsr        LoadFile

                    ldx        BankLoad
                    lda        #0
                    ldy        BG1AltBank
                    jsl        CopyBinToBG1

                    rts

; Load a raw pixture into the code buffer
DoLoadFG
                    lda        BankLoad
                    ldx        #FGName
                    jsr        LoadFile

                    ldx        BankLoad                ; Copy it into the code field
                    lda        #0
                    jsl        CopyBinToField
                    rts

; Load a simple picture format onto the SHR screen
DoLoadPic
                    lda        BankLoad
                    ldx        #ImageName              ; Load+Unpack Boot Picture
                    jsr        LoadPicture             ; X=Name, A=Bank to use for loading

                    ldx        BankLoad                ; Copy it into the code field
                    lda        #0
                    jsl        CopyPicToField
                    rts

; Graphics helpers

LoadPicture
                    jsr        LoadFile                ; X=Nom Image, A=Banc de chargement XX/00
                    bcc        :loadOK
                    rts
:loadOK
                    jsr        UnpackPicture           ; A=Packed Size
                    rts


UnpackPicture       sta        UP_PackedSize           ; Size of Packed Data
                    lda        #$8000                  ; Size of output Data Buffer
                    sta        UP_UnPackedSize
                    lda        BankLoad                ; Banc de chargement / Decompression
                    sta        UP_Packed+1             ; Packed Data
                    clc
                    adc        #$0080
                    stz        UP_UnPacked             ; On remet a zero car modifie par l'appel
                    stz        UP_UnPacked+2
                    sta        UP_UnPacked+1           ; Unpacked Data buffer

                    PushWord   #0                      ; Space for Result : Number of bytes unpacked 
                    PushLong   UP_Packed               ; Pointer to buffer containing the packed data
                    PushWord   UP_PackedSize           ; Size of the Packed Data
                    PushLong   #UP_UnPacked            ; Pointer to Pointer to unpacked buffer
                    PushLong   #UP_UnPackedSize        ; Pointer to a Word containing size of unpacked data
                    _UnPackBytes
                    pla                                ; Number of byte unpacked
                    rts

UP_Packed           hex        00000000                ; Address of Packed Data
UP_PackedSize       hex        0000                    ; Size of Packed Data
UP_UnPacked         hex        00000000                ; Address of Unpacked Data Buffer (modified)
UP_UnPackedSize     hex        0000                    ; Size of Unpacked Data Buffer (modified)

; Basic I/O function to load files

LoadFile
                    stx        openRec+4               ; X=File, A=Bank (high word) assumed zero for low
                    stz        readRec+4
                    sta        readRec+6
                    jsr        ClearBankLoad

:openFile           _OpenGS    openRec
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

:closeFile          _CloseGS   closeRec
                    clc
                    lda        eofRec+4                ; File Size
                    rts

:openReadErr        jsr        :closeFile
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
:loadFileErr        sec
                    rts

msgLine1            str        'Unable to load File'
msgLine2            str        'Press a key :'
msgLine3            str        ' -> Return to Try Again'
msgLine4            str        ' -> Esc to Quit'

; Data storage    
MusicFile           str        '1/main.ntp'
BG1DataFile         strl       '1/bg1a.bin'
BG1AltDataFile      strl       '1/bg1b.bin'

ImageName           strl       '1/test.pic'
FGName              strl       '1/fg1.bin'

openRec             dw         2                       ; pCount
                    ds         2                       ; refNum
                    adrl       FGName                  ; pathname

eofRec              dw         2                       ; pCount
                    ds         2                       ; refNum
                    ds         4                       ; eof

readRec             dw         4                       ; pCount
                    ds         2                       ; refNum
                    ds         4                       ; dataBuffer
                    ds         4                       ; requestCount
                    ds         4                       ; transferCount

closeRec            dw         1                       ; pCount
                    ds         2                       ; refNum

qtRec               adrl       $0000
                    da         $00


; Load the GTE User Tool and install it
GTEStartUp
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
                bcc    :ok1
                brk    $01

:ok1
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
                bcc    :ok2
                brk    $02

:ok2
                clc                             ; Give GTE a page of direct page memory
                tdc
                adc   #$0100
                pha
                pea   #ENGINE_MODE_DYN_TILES+ENGINE_MODE_TWO_LAYER   ; Enable Dynamic Tiles and Two Layer
                lda   MyUserId                  ; Pass the userId for memory allocation
                pha
                _GTEStartUp
                bcc    :ok3
                brk    $03

:ok3
                rts

                    PUT        App.Msg.s
                    PUT        Actions.s
                    PUT        font.s

                    PUT        gen/App.TileMapBG0.s
                    PUT        gen/App.TileMapBG1.s
                    PUT        gen/App.TileSetAnim.s

                    PUT        Overlay.s
