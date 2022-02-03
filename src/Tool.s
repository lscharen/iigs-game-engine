; Toolbox wrapper for the GTE library.  Implemented as a user tool
;
; Ref: Toolbox Reference, Volume 2, Appendix A
; Ref: IIgs Tech Note #73

ToStrip         equ   $E10184

_CallTable
                dw    {_CTEnd-_CallTable}/4,0
                adrl  _TSBootInit-1
                adrl  _TSStartUp-1
                adrl  _TSShutDown-1
                adrl  _TSVersion-1
                adrl  _TSReset-1
                adrl  _TSStatus-1
                adrl  _TSReserved-1
                adrl  _TSReserved-1

                adrl  _TSSetScreenMode
_CTEnd

; Do nothing when the tool set is installed
_TSBootInit
                lda   #0
                clc
                rtl

; Call the regular GTE startup function after setting the Work Area Point (WAP).  The caller much provide
; one page of Bank 0 memory for the tool set's private use
;
; X = 
_TSStartUp
:zpToUse        equ     7

                pea     #$8000
                txa
                and     #$00FF
                pha

                pea     $0000
                lda     :zpToUse+6,s
                pha
                _SetWAP

                jsr     _CoreStartUp

_TSShutDown
                cmp     #0                 ; Acc is low word of the WAP (direct page)
                beq     :inactive

                phd
                pha
                pld                        ; Set the direct page for the toolset

                phx                        ; Preserve the X register
                jsr     _CoreShutDown      ; Shut down GTE
                pla

                pea     $8000
                and     #$00FF
                pha
                pea     $0000              ; Set WAP to null
                pea     $0000
                _SetWAP

                pld                        ; Restore the direct page

:inactive
                lda     #0
                clc
                rtl

_TSVersion
                lda     #$0100     ; Version 1
                sta     7,s

                lda     #0
                clc
                rtl

_TSReset
                lda     #0
                clc
                rtl

; Check the WAP values in the A, Y registers
_TSStatus
                sta    1,s
                tya
                ora    1,s
                sta    1,s        ; 0 if WAP is null, non-zero if WAP is set

                lda     #0
                clc
                rtl

_TSReserved
                txa
                xba
                ora     #$00FF            ; Put error code $FF in the accumulator
                sec
                rtl

_TSSetScreenMode
                phd                       ; Preserve the direct page
                pha
                pld

                lda     9,s
                tay
                lda     9,s
                tax
                jsr     _SetScreenMode
                pld

                ldx     #0                 ; No error
                ldy     #4                 ; Remove the 4 input bytes
                jml     ToStrip

_TSReadControl
                phd                       ; Preserve the direct page
                pha
                pld

                jsr     _ReadControl
                sta     9,s

                pld
                ldx     #0                 ; No error
                ldy     #0                 ; Remove zero input bytes
                jml     ToStrip
