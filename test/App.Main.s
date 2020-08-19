; Test program for graphics stufff...

                 rel

                 use        Util.Macs.s
                 use        Locator.Macs.s
                 use        Mem.Macs.s
                 use        Misc.Macs.s
                 put        ..\macros\App.Macs.s
                 put        ..\macros\EDS.GSOS.MACS.s

                 mx         %00

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

; Start up the graphics engine...

                 jsr        MemInit

; Load a picture and copy it into Bank $E1.  Then turn on the screen.

                 jsr        AllocOneBank         ; Alloc 64KB for Load/Unpack
                 sta        BankLoad             ; Store "Bank Pointer"

                 ldx        #ImageName           ; Load+Unpack Boot Picture
                 jsr        LoadPicture          ; X=Name, A=Bank to use for loading

                 lda        BankLoad             ; get address of loaded/uncompressed picture
                 clc
                 adc        #$0080               ; skip header? 
                 sta        :copySHR+2           ;  and store that over the 'ldal' address below
                 ldx        #$7FFE               ; copy all image data
:copySHR         ldal       $000000,x            ; load from BankLoad we allocated
                 stal       $E12000,x            ; store to SHR screen
                 dex
                 dex
                 bpl        :copySHR

                 jsr        GrafOn
                 jsr        WaitForKey

; Deallocate all of our memory
                 PushWord   UserId
                 _DisposeAll

Exit             _QuitGS    qtRec

                 bcs        Fatal
Fatal            brk        $00

WaitForKey       sep        #$30
:WFK             ldal       $00C000
                 bpl        :WFK
                 stal       $00C010
                 rep        #$30
                 rts

****************************************
* Fatal Error Handler                  *
****************************************
PgmDeath         tax
                 pla
                 inc
                 phx
                 phk
                 pha
                 bra        ContDeath
PgmDeath0        pha
                 pea        $0000
                 pea        $0000
ContDeath        ldx        #$1503
                 jsl        $E10000

; Graphic screen initialization

GrafInit         ldx        #$7FFE
                 lda        #0000
:loop            stal       $E12000,x
                 dex
                 dex
                 bne        :loop
                 rts


GrafOn           sep        #$30
                 lda        #$81
                 stal       $00C029
                 rep        #$30
                 rts

; Bank allocator (for one full, fixed bank of memory. Can be immediately deferenced)

AllocOneBank     PushLong   #0
                 PushLong   #$10000
                 PushWord   UserId
                 PushWord   #%11000000_00011100
                 PushLong   #0
                 _NewHandle                      ; returns LONG Handle on stack
                 plx                             ; base address of the new handle
                 pla                             ; high address 00XX of the new handle (bank)
                 xba                             ; swap accumulator bytes to XX00	
                 sta        :bank+2              ; store as bank for next op (overwrite $XX00)
:bank            ldal       $000001,X            ; recover the bank address in A=XX/00	
                 rts

; Graphics helpers

LoadPicture      jsr        LoadFile             ; X=Nom Image, A=Banc de chargement XX/00
                 bcc        :loadOK
                 brl        Exit
:loadOK          jsr        UnpackPicture        ; A=Packed Size
                 rts


UnpackPicture    sta        UP_PackedSize        ; Size of Packed Data
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

UP_Packed        hex        00000000             ; Address of Packed Data
UP_PackedSize    hex        0000                 ; Size of Packed Data
UP_UnPacked      hex        00000000             ; Address of Unpacked Data Buffer (modified)
UP_UnPackedSize  hex        0000                 ; Size of Unpacked Data Buffer (modified)

; Basic I/O function to load files

LoadFile         stx        openRec+4            ; X=File, A=Bank/Page XX/00
                 sta        readRec+5

:openFile        _OpenGS    openRec
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

:closeFile       _CloseGS   closeRec
                 clc
                 lda        eofRec+4             ; File Size
                 rts

:openReadErr     jsr        :closeFile
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
:loadFileErr     sec
                 rts

msgLine1         str        'Unable to load File'
msgLine2         str        'Press a key :'
msgLine3         str        ' -> Return to Try Again'
msgLine4         str        ' -> Esc to Quit'

; Data storage
ImageName        strl       '1/test.pic'
MasterId         ds         2
UserId           ds         2
BankLoad         hex        0000

openRec          dw         2                    ; pCount
                 ds         2                    ; refNum
                 adrl       ImageName            ; pathname

eofRec           dw         2                    ; pCount
                 ds         2                    ; refNum
                 ds         4                    ; eof

readRec          dw         4                    ; pCount
                 ds         2                    ; refNum
                 ds         4                    ; dataBuffer
                 ds         4                    ; requestCount
                 ds         4                    ; transferCount

closeRec         dw         1                    ; pCount
                 ds         2                    ; refNum

qtRec            adrl       $0000
                 da         $00

                 put        App.Init.s



















































