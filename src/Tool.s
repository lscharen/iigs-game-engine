; Toolbox wrapper for the GTE library.  Implemented as a user tool
;
; Ref: Toolbox Reference, Volume 2, Appendix A
; Ref: IIgs Tech Note #73

;                  use       Load.Macs.s
                use   Mem.Macs.s
                use   Misc.Macs.s
                use   Util.Macs
                use   Locator.Macs
                use   Core.MACS.s

                use   Defs.s

ToStrip         equ   $E10184

                mx    %00

_CallTable
                adrl  {_CTEnd-_CallTable}/4
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

; Call the regular GTE startup function after setting the Work Area Pointer (WAP).  The caller must provide
; one page of Bank 0 memory for the tool set's private use and a userId to use for allocating memory
;
; X = tool set number in low byte and function umber in high byte
;
; StartUp(dPageAddr, userId)
_TSStartUp

userId          =    7
zpToUse         =    userId+2

                lda     zpToUse,s          ; Get the direct page address
                phd                        ; Save the current direct page
                tcd                        ; Set to our working direct page space

                txa
                and     #$00FF             ; Get just the tool number
                sta     ToolNum

                lda     userId+2,s         ; Get the userId for memory allocations
                sta     UserId

                jsr     _CoreStartUp       ; Initialize the library

; SetWAP(userOrSystem, tsNum, waptPtr)

                pea     #$8000             ; $8000 = user tool set
                pei     ToolNum            ; Push the tool number from the direct page
                pea     $0000              ; High word of WAP is zero (bank 0)
                phd                        ; Low word of WAP is the direct page
                _SetWAP

                pld                        ; Restore the caller's direct page

                ldx     #0                 ; No error
                ldy     #4                 ; Remove the 4 input bytes
                jml     ToStrip

_TSShutDown
                cmp     #0                 ; Acc is low word of the WAP (direct page)
                beq     :inactive

                phd
                tcd                        ; Set the direct page for the toolset

                jsr     _CoreShutDown      ; Shut down the library

                pea     $8000
                pei     ToolNum
                pea     $0000              ; Set WAP to null
                pea     $0000
                _SetWAP

                pld                        ; Restore the direct page

:inactive
                lda     #0
                clc
                rtl

_TSVersion
                lda     #$0100             ; Version 1
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

; SetScreenMode(width, height)
_TSSetScreenMode
:height         equ     9
:width          equ     11

                phd                       ; Preserve the direct page
                tcd                       ; Set the tool set direct pafe from WAP

                lda     :height,s
                tay
                lda     :width,s
                tax
;                jsr     _SetScreenMode   ; Not implemented yet

                pld                       ; Restore direct page

                ldx     #0                 ; No error
                ldy     #4                 ; Remove the 4 input bytes
                jml     ToStrip

_TSReadControl
:output         equ     9

                phd                       ; Preserve the direct page
                tcd

                jsr     _ReadControl
                sta     :output,s

                pld
                ldx     #0                 ; No error
                ldy     #0                 ; Remove zero input bytes
                jml     ToStrip

; Insert the core GTE functions

                put     CoreImpl.s
                put     Memory.s
                put     Timer.s
;                put     Graphics.s
;                put     blitter/Template.s
                put     blitter/Tables.s
