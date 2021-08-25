; Test driver to exercise graphics routines.

                    REL
                    DSK        MAINSEG

                    use        EDS.GSOS.MACS.s
                    put        ./GTE.s

                    mx         %00

; External references
tiledata            ext

; Feature flags
NO_INTERRUPTS       equ        1                       ; turn off for crossrunner debugging
NO_MUSIC            equ        1                       ; turn music + tool loading off

; Typical init

                    phk
                    plb

                    jsl        EngineStartUp

                    ldx        #0
                    jsl        SetScreenMode

                    jsr        _InitBG1                ; Initialize the second background

                    lda        #0
                    jsr        _ClearBG1Buffer

; Set up our level data
                    jsr        BG0SetUp
                    jsr        BG1SetUp

; Allocate room to load data

                    jsr        AllocOneBank2           ; Alloc 64KB for Load/Unpack
                    sta        BankLoad                ; Store "Bank Pointer"

                    jsr        MovePlayerToOrigin      ; Put the player at the beginning of the map

                    lda        #DIRTY_BIT_BG0_REFRESH  ; Redraw all of the tiles on the next Render
                    ora        #DIRTY_BIT_BG1_REFRESH
                    tsb        DirtyBits

                    jsl        Render
EvtLoop
                    jsl        ReadControl
                    and        #$007F                  ; Ignore the buttons for now

                    cmp        #'q'
                    bne        :1
                    brl        Exit

:1                  cmp        #'l'
                    bne        :1_1
                    jsr        DoLoadFG
                    bra        EvtLoop

:1_1                cmp        #'b'
                    bne        :2
                    jsr        DoLoadBG1
                    bra        EvtLoop

:2                  cmp        #'m'
                    bne        :3
                    jsr        DumpBanks
                    bra        EvtLoop

:3                  cmp        #'f'                    ; render a 'f'rame
                    bne        :4
                    jsl        Render
                    bra        EvtLoop

:4                  cmp        #'h'                    ; Show the 'h'eads up display
                    bne        :5
                    jsr        DoHUP
                    bra        EvtLoop

:5                  cmp        #'1'                    ; User selects a new screen size
                    bcc        :6
                    cmp        #'9'+1
                    bcs        :6
                    sec
                    sbc        #'1'
                    tax
                    jsr        SetScreenMode
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
                    jsr        SetBG0XPos
                    lda        #0
                    jsr        SetBG1XPos

                    lda        TileMapHeight
                    asl
                    asl
                    asl
                    sec
                    sbc        ScreenHeight
                    pha
                    jsr        SetBG0YPos
                    pla
                    jsr        SetBG1YPos

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
                    jsr        CopyTile

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

                    ldx        BankLoad                ; Copy it into the code field
                    lda        #0
                    jsr        CopyBinToField
                    rts

; Load a simple picture format onto the SHR screen
DoLoadPic
                    lda        BankLoad
                    ldx        #ImageName              ; Load+Unpack Boot Picture
                    jsr        LoadPicture             ; X=Name, A=Bank to use for loading

                    ldx        BankLoad                ; Copy it into the code field
                    lda        #0
                    jsr        CopyPicToField
                    rts

; Copy a raw data file into the code field
;
; A=low word of picture address
; X=high word of pixture address
CopyBinToField
:srcptr             equ        tmp0
:line_cnt           equ        tmp2
:dstptr             equ        tmp3
:col_cnt            equ        tmp5
:mask               equ        tmp6
:data               equ        tmp7
:mask_color         equ        tmp8

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
                    lda        :line_cnt               ; get the pointer to the code field line
                    asl
                    tax

                    lda        BTableLow,x
                    sta        :dstptr
                    lda        BTableHigh,x
                    sta        :dstptr+2

;                     ldx        #162                    ; move backwards in the code field
                    ldy        #0                      ; move forward in the image data

                    lda        #82                     ; keep a running column count
                    sta        :col_cnt

:cloop
                    phy
                    lda        [:srcptr],y             ; load the picture data
                    cmp        :mask_color
                    beq        :transparent            ; a value of $0000 is transparent

                    jsr        :toMask                 ; Infer a mask value for this. If it's $0000, then
                    cmp        #$0000
                    bne        :mixed                  ; the data is solid, otherwise mixed

; This is a solid word
:solid
                    lda        [:srcptr],y
                    pha                                ; Save the data

                    lda        Col2CodeOffset,y        ; Get the offset to the code from the line start
                    tay

                    lda        #$00F4                  ; PEA instruction
                    sta        [:dstptr],y
                    iny
                    pla
                    sta        [:dstptr],y             ; PEA operand
                    bra        :next
:transparent
                    lda        :mask_color             ; Make sure we actually have to mask
                    cmp        #$A5A5
                    beq        :solid

                    lda        Col2CodeOffset,y        ; Get the offset to the code from the line start
                    tay
                    lda        #$B1                    ; LDA (dp),y
                    sta        [:dstptr],y
                    iny
                    lda        1,s                     ; load the saved Y-index
                    ora        #$4800                  ; put a PHA after the offset
                    sta        [:dstptr],y
                    bra        :next

:mixed
                    sta        :mask                   ; Save the mask
                    lda        [:srcptr],y             ; Refetch the screen data
                    sta        :data

                    tyx
                    lda        Col2CodeOffset,y        ; Get the offset into the code field
                    tay
                    lda        #$4C                    ; JMP exception
                    sta        [:dstptr],y
                    iny

                    lda        JTableOffset,x          ; Get the address offset and add to the base address
                    clc
                    adc        :dstptr
                    sta        [:dstptr],y

                    ldy        JTableOffset,x          ; This points to the code fragment
                    lda        1,s                     ; load the offset
                    xba
                    ora        #$00B1
                    sta        [:dstptr],y             ; write the LDA (--),y instruction
                    iny
                    iny
                    iny                                ; advance to the AND #imm operand
                    lda        :mask
                    sta        [:dstptr],y
                    iny
                    iny
                    iny                                ; advance to the ORA #imm operand
                    lda        :mask
                    eor        #$FFFF                  ; invert the mask to clear up the data
                    and        :data
                    sta        [:dstptr],y

:next
                    ply

;                     dex
;                     dex
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

:toMask             pha                                ; save original

                    lda        1,s
                    eor        :mask_color             ; only identical bits produce zero
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

                    sta        1,s                     ; pop the saved word
                    pla
                    rts

:headerStr          asc        'GTERAW'

; Copy a loaded SHR picture into the code field
;
; A=low word of picture address
; X=high workd of pixture address
;
; Picture must be within one bank
CopyPicToField
:srcptr             equ        tmp0
:line_cnt           equ        tmp2
:dstptr             equ        tmp3
:col_cnt            equ        tmp5
:mask               equ        tmp6
:data               equ        tmp7

                    sta        :srcptr
                    stx        :srcptr+2

                    stz        :line_cnt
:rloop
                    lda        :line_cnt               ; get the pointer to the code field line
                    asl
                    tax

                    lda        BTableLow,x
                    sta        :dstptr
                    lda        BTableHigh,x
                    sta        :dstptr+2

;                     ldx        #162                    ; move backwards in the code field
                    ldy        #0                      ; move forward in the image data

                    lda        #80                     ; keep a running column count
;                     lda        #82                  ; keep a running column count
                    sta        :col_cnt

:cloop
                    phy
                    lda        [:srcptr],y             ; load the picture data
                    beq        :transparent            ; a value of $0000 is transparent

                    jsr        :toMask                 ; Infer a mask value for this. If it's $0000, then
                    bne        :mixed                  ; the data is solid, otherwise mixed

; This is a solid word
                    lda        [:srcptr],y
                    pha                                ; Save the data

                    lda        Col2CodeOffset,y        ; Get the offset to the code from the line start
                    tay

                    lda        #$00F4                  ; PEA instruction
                    sta        [:dstptr],y
                    iny
                    pla
                    sta        [:dstptr],y             ; PEA operand
                    bra        :next
:transparent
                    lda        Col2CodeOffset,y        ; Get the offset to the code from the line start
                    tay

                    lda        #$B1                    ; LDA (dp),y
                    sta        [:dstptr],y
                    iny
                    lda        1,s                     ; load the saved Y-index
                    ora        #$4800                  ; put a PHA after the offset
                    sta        [:dstptr],y
                    bra        :next

:mixed
                    sta        :mask                   ; Save the mask
                    lda        [:srcptr],y             ; Refetch the screen data
                    sta        :data

                    tyx
                    lda        Col2CodeOffset,y        ; Get the offset into the code field
                    tay

                    lda        #$4C                    ; JMP exception
                    sta        [:dstptr],y
                    iny

                    lda        JTableOffset,x          ; Get the address offset and add to the base address
                    clc
                    adc        :dstptr
                    sta        [:dstptr],y

                    ldy        JTableOffset,x          ; This points to the code fragment
                    lda        1,s                     ; load the offset
                    xba
                    ora        #$00B1
                    sta        [:dstptr],y             ; write the LDA (--),y instruction
                    iny
                    iny
                    iny                                ; advance to the AND #imm operand
                    lda        :mask
                    sta        [:dstptr],y
                    iny
                    iny
                    iny                                ; advance to the ORA #imm operand
                    lda        :data
                    sta        [:dstptr],y

:next
                    ply

;                     dex
;                     dex
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

:toMask             bit        #$F000
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
:srcptr             equ        tmp0
:line_cnt           equ        tmp2
:dstptr             equ        tmp3
:col_cnt            equ        tmp5

                    sta        :srcptr
                    stx        :srcptr+2
                    sty        :dstptr+2               ; Everything goes into this bank

                                                       ; Advance over the header
                    lda        :srcptr
                    clc
                    adc        #8
                    sta        :srcptr

                    stz        :line_cnt
:rloop
                    lda        :line_cnt               ; get the pointer to the code field line
                    asl
                    tax

                    lda        BG1YTable,x
                    sta        :dstptr

                    ldy        #0                      ; move forward in the image data and image data
:cloop
                    lda        [:srcptr],y
                    sta        [:dstptr],y

                    iny
                    iny

                    cpy        #164
                    bcc        :cloop

                    lda        [:srcptr]               ; Duplicate the last byte in the extra space at the end of the line
                    sta        [:dstptr],y

                    lda        :srcptr
                    clc
                    adc        #164                    ; Each line is 328 pixels
                    sta        :srcptr

                    inc        :line_cnt
                    lda        :line_cnt
                    cmp        #208                    ; A total of 208 lines
                    bcc        :rloop
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
;MasterId            ds         2
;UserId              ds         2

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

                    PUT        App.TileMapBG0.s
                    PUT        App.TileMapBG1.s


























