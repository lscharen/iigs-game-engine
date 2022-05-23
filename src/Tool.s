; Toolbox wrapper for the GTE library.  Implemented as a user tool
;
; Ref: Toolbox Reference, Volume 2, Appendix A
; Ref: IIgs Tech Note #73

                use   Mem.Macs.s
                use   Misc.Macs.s
                use   Util.Macs
                use   Locator.Macs
                use   Core.MACS.s

                use   Defs.s
                use   static/TileStoreDefs.s

ToStrip         equ   $E10184

; Define some macros to help streamline the entry and exit from the toolbox calls
_TSEntry        mac
                phd
                phb
                tcd
                jsr  _SetDataBank
                <<<

_TSExit         mac
                plb
                pld
                ldx     ]1                 ; Error code
                ldy     ]2                 ; Number of stack bytes to remove
                jml     ToStrip
                <<<

FirstParam      equ     10                  ; When using the _TSEntry macro, the first parameter is at 10,s

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

                adrl  _TSReadControl-1
                adrl  _TSSetScreenMode-1
                adrl  _TSSetTile-1
                adrl  _TSSetBG0Origin-1
                adrl  _TSRender-1
                adrl  _TSLoadTileSet-1
                adrl  _TSCreateSpriteStamp-1
_CTEnd

; Helper function to set the data back to the toolset default
_SetDataBank    sep  #$20
                lda  #^TileStore
                pha
                plb
                rep  #$20
                rts

; Do nothing when the tool set is installed
_TSBootInit
                lda   #0
                clc
                rtl

; Call the regular GTE startup function after setting the Work Area Pointer (WAP).  The caller must provide
; one page of Bank 0 memory for the tool set's private use and a userId to use for allocating memory
;
; X = tool set number in low byte and function number in high byte
;
; StartUp(dPageAddr, capFlags, userId)
_TSStartUp

userId          =    7
capFlags        =    userId+2
zpToUse         =    userId+4

                lda     zpToUse,s          ; Get the direct page address
                phd                        ; Save the current direct page
                tcd                        ; Set to our working direct page space

                txa
                and     #$00FF             ; Get just the tool number
                sta     ToolNum

                lda     userId+2,s         ; Get the userId for memory allocations
                sta     UserId

                lda     capFlags+2,s       ; Get the engine capability bits
                sta     EngineMode

                phb
                jsr     _SetDataBank
                jsr     _CoreStartUp       ; Initialize the library
                plb

; SetWAP(userOrSystem, tsNum, waptPtr)

                pea     #$8000             ; $8000 = user tool set
                pei     ToolNum            ; Push the tool number from the direct page
                pea     $0000              ; High word of WAP is zero (bank 0)
                phd                        ; Low word of WAP is the direct page
                _SetWAP

                pld                        ; Restore the caller's direct page

                ldx     #0                 ; No error
                ldy     #6                 ; Remove the 6 input bytes
                jml     ToStrip

; ShutDown()
_TSShutDown
                cmp     #0                 ; Acc is low word of the WAP (direct page)
                beq     :inactive

                phd
                tcd                        ; Set the direct page for the toolset

                phb
                jsr     _SetDataBank
                jsr     _CoreShutDown      ; Shut down the library
                plb

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
                sta    1,s                ; 0 if WAP is null, non-zero if WAP is set

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
height          equ     FirstParam
width           equ     FirstParam+2

                _TSEntry

                lda     height,s
                tay
                lda     width,s
                tax
                jsr     _SetScreenMode

                _TSExit #0;#4

; ReadControl()
_TSReadControl
output          equ     FirstParam

                _TSEntry

                jsr     _ReadControl
                sta     output,s

                _TSExit  #0;#0

; SetTile(xTile, yTile, tileId)
_TSSetTile
tileId          equ     FirstParam
yTile           equ     FirstParam+2
xTile           equ     FirstParam+4

                _TSEntry

                lda     xTile,s                ; Valid range [0, 40] (41 columns)
                tax
                lda     yTile,s                ; Valid range [0, 25] (26 rows)
                tay
                lda     tileId,s
                jsr     _SetTile

                _TSExit #0;#6

; SetBG0Origin(x, y)
_TSSetBG0Origin
yPos            equ     FirstParam
xPos            equ     FirstParam+2

                _TSEntry

                lda     xPos,s
                jsr     _SetBG0XPos
                lda     yPos,s
                jsr     _SetBG0YPos

                _TSExit #0;#4

; Render()
_TSRender
                _TSEntry
                 jsr     _Render
                _TSExit #0;#0

; LoadTileSet(Pointer)
_TSLoadTileSet
TSPtr           equ     FirstParam

                _TSEntry

                lda     TSPtr+2,s
                tax
                lda     TSPtr,s
                jsr     _LoadTileSet

                _TSExit #0;#4

; CreateSpriteStamp(spriteId: Word, vbuffAddr: Word)
_TSCreateSpriteStamp
:vbuff          equ     FirstParam
:spriteId       equ     FirstParam+2

                _TSEntry

                lda     :vbuff,s
                tay
                lda     :spriteId,s
                jsr     _CreateSpriteStamp

                _TSExit #0;#4

_TSAddSprite
:spriteSlot     equ    FirstParam+0
:spriteY        equ    FirstParam+2
:spriteX        equ    FirstParam+4
:spriteId       equ    FirstParam+6

                _TSEntry

                lda    :spriteY,s
                and    #$00FF
                xba
                sta    :spriteY,s
                lda    :spriteX,s
                and    #$00FF
                ora    :spriteY,s
                tay

                lda    :spriteSlot,s
                tax

                lda    :spriteId,s
                jsr    _AddSprite

                _TSExit #0;#8

_TSUpdateSprite
:vbuff          equ    FirstParam+0
:spriteFlags    equ    FirstParam+2
:spriteSlot     equ    FirstParam+4
                _TSEntry

                lda    :spriteFlags,s
                tax
                lda    :vbuff,s
                tay
                lda    :spriteSlot,s
                jsr    _UpdateSprite

                _TSExit #0;#6

; Insert the GTE code

                put     Math.s
                put     CoreImpl.s
                put     Memory.s
                put     Timer.s
                put     Graphics.s
                put     Tiles.s
                put     Sprite.s
                put     SpriteRender.s
                put     Render.s
                put     tiles/DirtyTileQueue.s
                put     tiles/FastRenderer.s
                put     blitter/Horz.s
                put     blitter/Vert.s
                put     blitter/BG0.s
                put     blitter/BG1.s
                put     blitter/Template.s
                put     blitter/TemplateUtils.s
                put     blitter/Blitter.s
                put     blitter/TileProcs.s
                put     blitter/Tiles00000.s
;                put     blitter/Tiles.s
