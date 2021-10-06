; Test driver to exercise graphics routines.

                    REL
                    DSK        MAINSEG

                    use        Locator.Macs.s
                    use        Misc.Macs.s
                    use        EDS.GSOS.MACS.s
                    use        Tool222.Macs.s
                    use        Util.Macs.s
                    use        CORE.MACS.s
                    use        ../../src/GTE.s
                    use        ../../src/Defs.s

                    mx         %00

; Feature flags
NO_INTERRUPTS       equ        0                       ; turn off for crossrunner debugging
NO_MUSIC            equ        1                       ; turn music + tool loading off

; Typical init
                    phk
                    plb

                    jsl        EngineStartUp

                    lda        #^MyPalette
                    ldx        #MyPalette
                    ldy        #0
                    jsl        SetPalette

                    ldx        #0
                    jsl        SetScreenMode

; Set up our level data
                    jsr        BG0SetUp
;                    jsr        BG1SetUp
                    jsr        TileAnimInit

; Allocate room to load data

                    jsl        AllocBank               ; Alloc 64KB for Load/Unpack
                    sta        BankLoad                ; Store "Bank Pointer"

                    jsr        MovePlayerToOrigin      ; Put the player at the beginning of the map

                    lda        #DIRTY_BIT_BG0_REFRESH  ; Redraw all of the tiles on the next Render
                    ora        #DIRTY_BIT_BG1_REFRESH
                    tsb        DirtyBits

                    lda        #$FFFF
                    jsl        Render
EvtLoop
                    jsl        ReadControl
                    and        #$007F                  ; Ignore the buttons for now

                    cmp        #'q'
                    bne        :1
                    brl        Exit

tcounter            dw         0
tileIDs             dw         168,170,172,174,168,170,172,174
                    dw         169,171,173,175,169,171,173,175
                    dw         208,210,212,214,208,210,212,214
                    dw         209,211,213,215,209,211,213,215

;tileIDs             dw         1,1,1,1,1,1,1,5
;                    dw         2,2,2,2,2,2,2,6
;                    dw         3,3,3,3,3,3,3,7
;                    dw         4,4,4,4,4,4,4,8


:1
                    cmp        #'r'
                    bne        EvtLoop

                    jsl        DoTimers

                    inc        tcounter

                    lda        tcounter
                    and        #$0007
                    asl
                    tay
                    lda        tileIDs,y
                    pha
                    lda        tileIDs+16,y
                    pha
                    lda        tileIDs+32,y
                    pha
                    ldx        tileIDs+48,y
                    inx
                    ldy        #3
                    jsl        CopyTileToDyn

                    plx
                    inx
                    ldy        #2
                    jsl        CopyTileToDyn

                    plx
                    inx
                    ldy        #1
                    jsl        CopyTileToDyn

                    plx
                    inx
                    ldy        #0
                    jsl        CopyTileToDyn

                    jsl        Render
                    brl        EvtLoop

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
;                    jsr        MovePlayerToOrigin
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

MyPalette           dw         $0E51,$0EDA,$0000,$068F,$0BF1,$00A0,$0EEE,$0777,$0FA4,$0F59,$0F31,$02E3,$09B9,$01CE,$0EE6

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
;DefaultPalette       dw         $0EEF,$0342,$0C95,$0852,$0DB4,$00C0
                    dw         $0222,$0333,$0444,$0888,$09A0,$0680,$0470,$0051

; SMB
DefaultPalette      dw         $0E51,$0EDB,$0000,$068F,$0BF1,$00A0,$0EEE,$0777,$0FA4,$0F59,$0E05,$0F30
                    dw         $0680,$0470,$0051

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

                    PUT        App.Msg.s
                    PUT        Actions.s
                    PUT        font.s
                    PUT        Overlay.s

                    PUT        gen/App.TileMapBG0.s
                    PUT        gen/App.TileMapBG1.s
                    PUT        gen/App.TileSetAnim.s
































































