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
            