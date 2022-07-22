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

_TSExit1        mac
                plb
                pld
;                ldx     ]1                 ; Error code already in X
                ldy     ]1                 ; Number of stack bytes to remove
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
                adrl  _TSAddSprite-1
                adrl  _TSMoveSprite-1
                adrl  _TSUpdateSprite-1
                adrl  _TSRemoveSprite-1

                adrl  _TSGetSeconds-1

                adrl  _TSCopyTileToDynamic-1

                adrl  _TSSetPalette-1
                adrl  _TSCopyPicToBG1-1
                adrl  _TSBindSCBArray-1
                adrl  _TSGetBG0TileMapInfo-1
                adrl  _TSGetScreenInfo-1
                adrl  _TSSetBG1Origin-1
                adrl  _TSGetTileAt-1

                adrl  _TSSetBG0TileMapInfo-1
                adrl  _TSSetBG1TileMapInfo-1

                adrl  _TSAddTimer-1
                adrl  _TSRemoveTimer-1
                adrl  _TSStartScript-1

                adrl  _TSSetOverlay-1
                adrl  _TSClearOverlay-1

                adrl  _TSGetTileDataAddr-1
                adrl  _TSFillTileStore-1
                adrl  _TSRefresh-1
                adrl  _TSRenderDirty-1
                adrl  _TSSetBG1Displacement-1
                adrl  _TSSetBG1Rotation-1
_CTEnd
_GTEAddSprite        MAC
                     UserTool  $1000+GTEToolNum
                     <<<
_GTEMoveSprite       MAC
                     UserTool  $1100+GTEToolNum
                     <<<
_GTEUpdateSprite     MAC
                     UserTool  $1200+GTEToolNum
                     <<<
_GTERemoveSprite     MAC
                     UserTool  $1300+GTEToolNum
                     <<<
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
:output         equ     FirstParam

                _TSEntry

                jsr     _ReadControl
                sta     :output,s

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

; Render(flags)
_TSRender
:flags          equ     FirstParam+0

                _TSEntry
                lda     :flags,s
                jsr     _Render
                _TSExit #0;#2


; RenderDirty(flags)
_TSRenderDirty
:flags          equ     FirstParam+0

                _TSEntry
                lda     :flags,s
                jsr     _RenderDirty
                _TSExit #0;#2

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

_TSMoveSprite
:spriteY        equ    FirstParam+0
:spriteX        equ    FirstParam+2
:spriteSlot     equ    FirstParam+4
                _TSEntry

                lda    :spriteX,s
                tax
                lda    :spriteY,s
                tay
                lda    :spriteSlot,s
                jsr    _MoveSprite

                _TSExit #0;#6

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

_TSRemoveSprite
:spriteSlot     equ    FirstParam+0
                _TSEntry

                lda    :spriteSlot,s
                jsr    _RemoveSprite

                _TSExit #0;#2

_TSGetSeconds
:output         equ     FirstParam

                _TSEntry

                ldal    OneSecondCounter
                sta     :output,s

                _TSExit  #0;#0

_TSCopyTileToDynamic
:dynId          equ    FirstParam+0
:tileId         equ    FirstParam+2
                _TSEntry

                lda     EngineMode
                bit     #ENGINE_MODE_DYN_TILES
                beq     :notEnabled

                lda     :tileId,s
                tax
                lda     :dynId,s
                tay
                jsr     CopyTileToDyn

:notEnabled
                _TSExit  #0;#4


; SetPalette(palNum, Pointer)
_TSSetPalette
:ptr            equ    FirstParam+0
:palNum         equ    FirstParam+4

                _TSEntry

                phb
                lda     :ptr+3,s                ; add one extra byte for the phb
                xba
                pha
                plb
                plb

                lda     :ptr+1,s
                tax
                lda     :palNum+1,s
                jsr     _SetPalette
                plb

                _TSExit  #0;#6

; CopyPicToBG1(width, height, stride, ptr, flags)
_TSCopyPicToBG1
:flags          equ    FirstParam+0
:ptr            equ    FirstParam+2
:stride         equ    FirstParam+6
:height         equ    FirstParam+8
:width          equ    FirstParam+10

                _TSEntry

; Lots of parameters for this function, so pass them on the direct page
:src_width      equ    tmp6
:src_height     equ    tmp7
:src_stride     equ    tmp8

                lda    :width,s
                sta    :src_width
                lda    :height,s
                sta    :src_height
                lda    :stride,s
                sta    :src_stride

                ldy    BG1DataBank              ; Pick the target data bank
                lda    :flags,s
                bit    #$0001
                beq    *+4
                ldy    BG1AltBank
                
                lda    :ptr+2,s
                tax
                lda    :ptr,s
                jsr    _CopyToBG1

                _TSExit  #0;#12

_TSBindSCBArray
:ptr            equ    FirstParam+0

                _TSEntry

                lda     :ptr,s
                tax
                lda     :ptr+2,s
                jsr     _BindSCBArray

                _TSExit  #0;#4

_TSGetBG0TileMapInfo
:ptr            equ     FirstParam+4
:height         equ     FirstParam+2
:width          equ     FirstParam+0
                _TSEntry

                lda     TileMapWidth
                sta     :width,s
                lda     TileMapHeight
                sta     :height,s
                lda     TileMapPtr
                sta     :ptr,s
                lda     TileMapPtr+2
                sta     :ptr+2,s

                _TSExit  #0;#0


_TSGetScreenInfo
:height         equ     FirstParam+6
:width          equ     FirstParam+4
:y              equ     FirstParam+2
:x              equ     FirstParam+0
                _TSEntry

                lda     ScreenX0
                sta     :x,s
                lda     ScreenY0
                sta     :y,s
                lda     ScreenWidth
                sta     :width,s
                lda     ScreenHeight
                sta     :height,s

                _TSExit  #0;#0

; SetBG1Origin(x, y)
_TSSetBG1Origin
:y              equ     FirstParam
:x              equ     FirstParam+2

                _TSEntry

                lda     :x,s
                jsr     _SetBG1XPos
                lda     :y,s
                jsr     _SetBG1YPos

                _TSExit #0;#4

; GetTileAt(x, y)
_TSGetTileAt
:y            equ     FirstParam
:x            equ     FirstParam+2
:output       equ     FirstParam+4

                _TSEntry

; Convert the x, y coordinated to tile store block coordinates
                lda  :x,s
                tax
                lda  :y,s
                tay
                jsr  _GetTileAt
                bcc  :ok
                lda  #0
                bra  :out

; Load the tile at that tile store location

:ok
                jsr  _GetTileStoreOffset0          ; Get the address of the X,Y tile position
                tax
                lda  TileStore+TS_TILE_ID,x
:out
                sta  :output,s

                _TSExit #0;#4

; SetBG0TileMapInfo(width, height, ptr)
_TSSetBG0TileMapInfo
:ptr            equ     FirstParam+0
:height         equ     FirstParam+4
:width          equ     FirstParam+6

                _TSEntry

                lda     :width,s
                sta     TileMapWidth
                lda     :height,s
                sta     TileMapHeight
                lda     :ptr,s
                sta     TileMapPtr
                lda     :ptr+2,s
                sta     TileMapPtr+2

                lda     #DIRTY_BIT_BG0_REFRESH     ; force a refresh of the BG0 on the next Render
                tsb     DirtyBits

                _TSExit #0;#8

; SetBG1TileMapInfo(width, height, ptr)
_TSSetBG1TileMapInfo
:ptr            equ     FirstParam+0
:height         equ     FirstParam+4
:width          equ     FirstParam+6

                _TSEntry

                lda     :width,s
                sta     BG1TileMapWidth
                lda     :height,s
                sta     BG1TileMapHeight
                lda     :ptr,s
                sta     BG1TileMapPtr
                lda     :ptr+2,s
                sta     TileMapPtr+2

                _TSExit #0;#8

; AddTimer(numTicks, callback, flags)
_TSAddTimer
:flags          equ     FirstParam+0
:callback       equ     FirstParam+2
:numTicks       equ     FirstParam+6
:output         equ     FirstParam+8

                _TSEntry

                lda     :callback+2,s
                tax
                lda     :numTicks,s
                tay
                lda     :flags,s
                ror                        ; put low bit into carry
                lda     :callback,s
                jsr     _AddTimer
                sta     :output,s
                ldx     #0
                bcc     :no_err
                ldx     #NO_TIMERS_AVAILABLE
:no_err
                _TSExit1 #8

; RemoveTimer(timerId)
_TSRemoveTimer
:timerId        equ     FirstParam+0

                _TSEntry

                lda     :timerId,s
                jsr     _RemoveTimer

                _TSExit #0;#2


; StartScript(timerId)
_TSStartScript
:scriptAddr     equ     FirstParam+0
:numTicks       equ     FirstParam+4

                _TSEntry

                lda     :numTicks,s
                tay
                lda     :scriptAddr+2,s
                tax
                lda     :scriptAddr,s
                jsr     _StartScript

                _TSExit #0;#6
; SetOverlay(top, bottom, proc)
_TSSetOverlay
:proc           equ     FirstParam+0
:bottom         equ     FirstParam+4
:top            equ     FirstParam+6

                _TSEntry

                lda     #1
                sta     Overlays
                lda     :top,s
                sta     Overlays+2
                lda     :bottom,s
                sta     Overlays+4
                lda     :proc,s
                sta     Overlays+6
                lda     :proc+2,s
                sta     Overlays+8

                _TSExit #0;#8

; ClearOverlay()
_TSClearOverlay

                _TSEntry

                lda     #0
                sta     Overlays

                _TSExit #0;#0

; GetTileDataAddr()
_TSGetTileDataAddr
:output         equ     FirstParam+0

                 _TSEntry

                lda     #tiledata
                sta     :output,s
                lda     #^tiledata
                sta     :output+2,s

                _TSExit #0;#0

; FillTileStore(tileId)
_TSFillTileStore
:tileId         equ     FirstParam+0

                _TSEntry

                stz    tmp0   
:oloop
                stz    tmp1
:iloop
                ldx    tmp1
                ldy    tmp0
                lda    :tileId,s
                jsr    _SetTile
                
                lda    tmp1
                inc
                sta    tmp1
                cmp    #TILE_STORE_WIDTH
                bcc    :iloop

                lda    tmp0
                inc
                sta    tmp0
                cmp    #TILE_STORE_HEIGHT
                bcc    :oloop

                _TSExit #0;#2

; _TSRefresh()
_TSRefresh
                _TSEntry
                jsr     _Refresh
                _TSExit #0;#0


; SetBG1Displacement(offset)
_TSSetBG1Displacement
:offset          equ     FirstParam+0

                _TSEntry

                lda     :offset,s
                and     #$001E
                sta     BG1OffsetIndex

                _TSExit #0;#2

; SetBG1Rotation(rotIndex)
_TSSetBG1Rotation
:rotIndex       equ     FirstParam+0
x_angles        EXT
y_angles        EXT

                _TSEntry

                lda     :rotIndex,s
                and     #$003F               ; only 64 angles to choose from

                asl
                tax
                ldal    x_angles,x           ; load the address of addresses for this angle
                tay
                phx
                jsr     _ApplyBG1XPosAngle
                plx

                ldal     y_angles,x           ; load the address of addresses for this angle
                tay
                jsr     _ApplyBG1YPosAngle

                _TSExit #0;#2

; Insert the GTE code

                put     Math.s
                put     CoreImpl.s
                put     Memory.s
                put     Timer.s
                put     Script.s
                put     TileMap.s
                put     Graphics.s
                put     Tiles.s
                put     Sprite.s
                put     Sprite2.s
                put     SpriteRender.s
                put     Render.s
                put     render/Render.s
                put     render/Fast.s
                put     render/Slow.s
                put     render/Dynamic.s
                put     render/TwoLayer.s
                put     render/Dirty.s
                put     render/Sprite1.s
                put     render/Sprite2.s
                put     tiles/DirtyTileQueue.s
                put     blitter/SCB.s
                put     blitter/Horz.s
                put     blitter/Vert.s
                put     blitter/BG0.s
                put     blitter/BG1.s
                put     blitter/Rotation.s
                put     blitter/Template.s
                put     blitter/TemplateUtils.s
                put     blitter/Blitter.s
