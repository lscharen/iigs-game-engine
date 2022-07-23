; Shared subroutines for all demos
;
; Load the GTE User Tool and install it
;
; A = Engine Mode
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

            clc                            ; Give GTE a page of direct page memory
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

; Generic key handling common to all demos
;
; A = result from GTEReadControl (preserved)
; C = 1 if not handled
; C = 0 if handled
HandleKeys
            pha
            and   #$007F

            cmp   #'q'
            bne   :not_q
            lda   #Exit-1                         ; replace the return address with the exit
            sta   1,s
            rts

:not_q
            cmp   #'1'
            bcc   :not_digit
            cmp   #':'                            ; next character after '9'
            bcs   :not_digit
            sec
            sbc   #'1'
            pha
            pea   $0000
            _GTESetScreenMode
            _GTERefresh
            jsr   SetLimits
            bra   :handled

:not_digit
            bra   :unhandled

:handled    pla
            clc
            rts

:unhandled  pla
            sec
            rts

_Deref      MAC
            phb                   ; save caller's data bank register
            pha                   ; push high word of handle on stack
            plb                   ; sets B to the bank byte of the pointer
            lda   |$0002,x        ; load the high word of the master pointer
            pha                   ; and save it on the stack
            lda   |$0000,x        ; load the low word of the master pointer
            tax                   ; and return it in X
            pla                   ; restore the high word in A
            plb                   ; pull the handle's high word high byte off the
                                    ; stack
            plb                   ; restore the caller's data bank register    
            <<<

AllocBank   PushLong  #0
            PushLong  #$10000
            PushWord  MyUserId
            PushWord  #%11000000_00011100
            PushLong  #0
            _NewHandle
            plx                                   ; base address of the new handle
            pla                                   ; high address 00XX of the new handle (bank)
            _Deref
            rts

; Shared I/O
; Basic I/O function to load files
LoadFile
            stx        openRec+4               ; X=File, A=Bank (high word) assumed zero for low
            stz        readRec+4
            sta        readRec+6
            phb
            phb
            pla
            and        #$00FF
            sta        openRec+6

:openFile   _OpenGS    openRec
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

:closeFile  _CloseGS   closeRec
            clc
            lda        eofRec+4                ; File Size
            rts

:openReadErr jsr        :closeFile
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
:loadFileErr sec
            rts

msgLine1   str        'Unable to load File'
msgLine2   str        'Press a key :'
msgLine3   str        ' -> Return to Try Again'
msgLine4   str        ' -> Esc to Quit'

openRec     dw         2                       ; pCount
            ds         2                       ; refNum
            ds         4                       ; pathname

eofRec      dw         2                       ; pCount
            ds         2                       ; refNum
            ds         4                       ; eof

readRec     dw         4                       ; pCount
            ds         2                       ; refNum
            ds         4                       ; dataBuffer
            ds         4                       ; requestCount
            ds         4                       ; transferCount

closeRec    dw         1                       ; pCount
            ds         2                       ; refNum