; Basic tile functions

; Copy tileset data from a pointer in memory to the tiledata back
; 
; tmp0 = Pointer to tile data
; X = first tile
; Y = last tile
;
; To copy in four tiles starting at tile 5, for example, X = 5 and Y = 9
_LoadTileSet
                txa
                _Mul128                   ; Jump to the target location
                tax
                tya
                _Mul128
                sta  tmp2                 ; This is the terminating byte

                ldy  #0
:loop           lda  [tmp0],y
                stal tiledata,x
                inx
                inx
                iny
                iny
                cpx  tmp2
                bne  :loop                ; Use BNE so when Y=512 => $0000, we wait for wrap-around
                rts


; Low-level function to take a tile descriptor and return the address in the tiledata
; bank.  This is not too useful in the fast-path because the fast-path does more
; incremental calculations, but it is handy for other utility functions
;
; A = tile descriptor
;
; The address is the TileID * 128 + (HFLIP * 64)
_GetTileAddr
                 asl                                               ; Multiply by 2
                 bit   #2*TILE_HFLIP_BIT                           ; Check if the horizontal flip bit is set
                 beq   :no_flip
                 inc                                               ; Set the LSB
:no_flip         asl                                               ; x4
                 asl                                               ; x8
                 asl                                               ; x16
                 asl                                               ; x32
                 asl                                               ; x64
                 asl                                               ; x128
                 rts

; Ignore the horizontal flip bit
_GetBaseTileAddr
                 asl                                               ; Multiply by 2
                 asl                                               ; x4
                 asl                                               ; x8
                 asl                                               ; x16
                 asl                                               ; x32
                 asl                                               ; x64
                 asl                                               ; x128
                 rts


; Helper function to get the address offset into the tile cachce / tile backing store
; X = tile column [0, 40] (41 columns)
; Y = tile row    [0, 25] (26 rows)
_GetTileStoreOffset
                 phx                        ; preserve the registers
                 phy

                 jsr  _GetTileStoreOffset0

                 ply
                 plx
                 rts

_GetTileStoreOffset0
                 tya
                 asl
                 tay
                 txa
                 asl
                 clc
                 adc  TileStoreYTable,y
                 rts

; Initialize the tile storage data structures.  This takes care of populating the tile records with the
; appropriate constant values.
InitTiles
:col             equ  tmp0
:row             equ  tmp1
:vbuff           equ  tmp2
:base            equ  tmp3

; Initialize the Tile Store

                 ldx  #TILE_STORE_SIZE-2
                 lda  #25
                 sta  :row
                 lda  #40
                 sta  :col
                 lda  #$8000
                 sta  :vbuff

:loop 

; The first set of values in the Tile Store that are changed during each frame based on the actions
; that are happening

                 lda  #0
                 sta  TileStore+TS_TILE_ID,x            ; clear the tile store with the special zero tile
                 sta  TileStore+TS_TILE_ADDR,x
                 sta  TileStore+TS_SPRITE_FLAG,x        ; no sprites are set at the beginning
                 sta  TileStore+TS_DIRTY,x              ; none of the tiles are dirty

; Set the default tile rendering functions

                 lda  EngineMode
                 bit  #ENGINE_MODE_DYN_TILES+ENGINE_MODE_TWO_LAYER
                 beq  :fast
                 bit  #ENGINE_MODE_TWO_LAYER
                 beq  :dyn

                 lda  #0
                 ldy  #TwoLyrProcs
                 jsr  _SetTileProcs
                 bra  :out
:fast
                 lda  #0                                 ; Initialize with Tile 0
;                 ldy  #FastProcs
                 ldy  #LiteProcs
                 jsr  _SetTileProcs
                 bra  :out

:dyn             lda  #0                                 ; Initialize with Tile 0
                 ldy  #FastProcs
                 jsr  _SetTileProcs

:out

; The next set of values are constants that are simply used as cached parameters to avoid needing to
; calculate any of these values during tile rendering

                 lda  :row                              ; Set the long address of where this tile
                 asl                                    ; exists in the code fields
                 tay
                 lda  #>TileStore                       ; get middle 16 bits: "00 -->BBHH<-- LL"
                 and  #$FF00                            ; merge with code field bank
                 ora  BRowTableHigh,y
                 sta  TileStore+TS_CODE_ADDR_HIGH,x     ; High word of the tile address (just the bank)

                 lda  BRowTableLow,y
                 sta  :base

                 lda  :col                              ; Set the offset values based on the column
                 asl                                    ; of this tile
                 asl
                 sta  TileStore+TS_WORD_OFFSET,x        ; This is the offset from 0 to 82, used in LDA (dp),y instruction

                 tay
                 lda  Col2CodeOffset+2,y
                 clc
                 adc  :base
                 sta  TileStore+TS_CODE_ADDR_LOW,x      ; Low word of the tile address in the code field

                 lda  JTableOffset,y
                 clc
                 adc  :base
                 sta  TileStore+TS_JMP_ADDR,x           ; Address of the snippet handler for this tile

                 dec  :col
                 bpl  :hop
                 dec  :row
                 lda  #40
                 sta  :col
:hop

                 dex
                 dex
                 bpl  :loop
                 rts

; Put everything visible on the dirty tile list
_Refresh
:col            equ  tmp0
:row            equ  tmp1
:idx            equ  tmp2

                jsr  _OriginToTileStore

                clc
                txa
                adc  TileStoreLookupYTable,y
                sta  :idx

                lda  ScreenTileWidth
                sta  :col

                lda  ScreenTileHeight
                sta  :row

:oloop          ldy  :idx
:iloop          ldx  TileStoreLookup,y
                jsr  _PushDirtyTileX

                iny
                iny
                dec  :col
                bne  :iloop

                lda  ScreenTileWidth
                sta  :col

                lda  :idx
                clc
                adc  #TS_LOOKUP_SPAN*2
                sta  :idx

                dec  :row
                bne  :oloop
                rts

; Reset all of the tile proc values in the playfield.
_ResetToDirtyTileProcs
                 ldx  #TILE_STORE_SIZE-2
:loop
                 lda  TileStore+TS_TILE_ID,x
                 jsr  _SetDirtyTileProcs
                 dex
                 dex
                 bpl  :loop
                 rts

_ResetToNormalTileProcs
                 ldx  #TILE_STORE_SIZE-2
:loop
                 lda  TileStore+TS_TILE_ID,x
                 jsr  _SetNormalTileProcs
                 dex
                 dex
                 bpl  :loop
                 rts

; A = tileID
; X = tile store index
_SetDirtyTileProcs
                 jsr  _CalcTileProcIndex
                 ldy  #DirtyProcs
                 jmp  _SetTileProcs

; A = tileID
; X = tile store index
_SetNormalTileProcs
                 pha                           ; extra space
                 pha                           ; save the tile ID
                 jsr  _CalcTileProcIndex
                 sta  3,s                      ; save for later

                 lda  EngineMode
                 bit  #ENGINE_MODE_DYN_TILES+ENGINE_MODE_TWO_LAYER
                 beq  :setTileFast

                 bit  #ENGINE_MODE_TWO_LAYER
                 beq  :setTileDyn

                 pla                           ; restore newTileID
                 bit  #TILE_DYN_BIT
                 beq  :pickTwoLyrProc

                 ldy  #TwoLyrDynProcs
                 brl  :pickDynProc

:pickTwoLyrProc  ldy  #TwoLyrProcs
                 pla                          ; pull off the proc index
                 jmp  _SetTileProcs

; Specialized check for when the engine is in "Fast" mode. If is a simple decision tree based on whether
; the tile priority bit is set, and whether this is the special tile 0 or not.
:setTileFast
                 pla                         ; Throw away tile ID copy
;                 ldy  #FastProcs
                 ldy  #LiteProcs
                 pla
                 jmp  _SetTileProcs

; Specialized check for when the engine has enabled dynamic tiles. In this case we are no longer
; guaranteed that the opcodes in a tile are PEA instructions.  
:setTileDyn
                 pla                           ; get the cached tile ID
                 bit  #TILE_DYN_BIT
                 beq  :pickSlowProc            ; If the Dynamic bit is not set, select a tile proc that sets opcodes

                 ldy  #DynProcs                ; use this table
:pickDynProc
                 and  #TILE_PRIORITY_BIT
                 beq  :pickZeroDynProc         ; If the Priority bit is not set, pick the first entry
                 pla
                 lda  #1                       ; If the Priority bit is set, pick the other one
                 jmp  _SetTileProcs

:pickZeroDynProc pla
                 lda  #0
                 jmp  _SetTileProcs

:pickSlowProc    ldy  #SlowProcs
                 pla
                 jmp  _SetTileProcs

; Helper method to calculate the index into the tile proc table given a TileID
; Calculate the base tile proc selector from the tile Id
_CalcTileProcIndex                 
                 bit  #TILE_PRIORITY_BIT             ; 4 if !0, 0 otherwise
                 beq  :low_priority

                 bit  #TILE_ID_MASK                  ; 2 if !0, 0 otherwise
                 beq  :is_zero_a

                 bit  #TILE_VFLIP_BIT                ; 1 if !0, 0 otherwise
                 beq  :no_flip_a

                 lda  #7
                 rts

:no_flip_a       lda  #6
                 rts

:is_zero_a       bit  #TILE_VFLIP_BIT
                 beq  :no_flip_b

                 lda  #5
                 rts

:no_flip_b       lda  #4
                 rts

:low_priority    bit  #TILE_ID_MASK                  ; 2 if !0, 0 otherwise
                 beq  :is_zero_b

                 bit  #TILE_VFLIP_BIT                ; 1 if !0, 0 otherwise
                 beq  :no_flip_c

                 lda  #3
                 rts

:no_flip_c       lda  #2
                 rts

:is_zero_b       bit  #TILE_VFLIP_BIT
                 beq  :no_flip_d

                 lda  #1
                 rts

:no_flip_d       lda  #0
                 rts

; Set a tile value in the tile backing store.  Mark dirty if the value changes
;
; A = tile id
; X = tile column [0, 40] (41 columns)
; Y = tile row    [0, 25] (26 rows)
;
; Registers are not preserved
oldTileId  equ  blttmp                              ; This location is used in _SetTileProcs, too
newTileId  equ  blttmp+2
procIdx    equ  blttmp+4

_SetTile
                 sta  newTileId
                 jsr  _GetTileStoreOffset0          ; Get the address of the X,Y tile position
                 tax

                 lda  TileStore+TS_TILE_ID,x
                 cmp  newTileId                    ; Lift this up to the caller
                 bne  :changed
                 rts

:changed         sta  oldTileId
                 lda  newTileId
                 sta  TileStore+TS_TILE_ID,x        ; Value is different, store it.

; If the user bit is set, then skip most of the setup and just fill in the TileProcs with the user callback
; target
                 bit  #TILE_USER_BIT
                 bne  :set_user_tile

                 jsr  _GetTileAddr
                 sta  TileStore+TS_TILE_ADDR,x      ; Committed to drawing this tile, so get the address of the tile in the tiledata bank for later

; Set the renderer procs for this tile.
;
; NOTE: Later on, optimize this to just take the Tile ID & TILE_CTRL_MASK and lookup the right proc
;       table address from a lookup table....
;
;  1. The dirty render proc is always set the same.
;  2. If BG1 and DYN_TILES are disabled, then the TS_BASE_TILE_DISP is selected from the Fast Renderers, otherwise
;     it is selected from the full tile rendering functions.
;  3. The copy process is selected based on the flip bits
;
; When a tile overlaps the sprite, it is the responsibility of the Render function to compose the appropriate
; functionality.  Sometimes it is simple, but in cases of the sprites overlapping Dynamic Tiles and other cases
; it can be more involved.

; Calculate the base tile proc selector from the tile Id (need X-register set to tile store index)

                 lda  newTileId
                 jsr  _SetNormalTileProcs
                 jmp  _PushDirtyTileX

:set_user_tile
                 and  #$01FF
                 jsr  _GetTileAddr                 ; The user tile callback needs access to this info, too, but
                 sta  TileStore+TS_TILE_ADDR,x     ; we just give the base tile address (hflip bit is ignored)

                 lda  #UserTileDispatch
                 stal K_TS_BASE_TILE_DISP,x
                 stal K_TS_SPRITE_TILE_DISP,x
                 stal K_TS_ONE_SPRITE,x
                 jmp  _PushDirtyTileX

; Trampoline / Dispatch table for user-defined tiles.  If the user calls the GTESetAddress toolbox routine,
; then this value is patched out.  Calling GTESetAddress with NULL will disconnect the user's routine.
;
; This hook copies essential information from the TileStore into a local record on the direct page and then
; passes that record to callback function.  We are in the second direct page of the GTE bank 0 space.
UserTileDispatch
                 lda   TileStore+TS_TILE_ID,x
                 sta   USER_TILE_ID
                 lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
                 sta   USER_TILE_CODE_PTR+2
                 lda   TileStore+TS_CODE_ADDR_LOW,x
                 sta   USER_TILE_CODE_PTR
                 lda   TileStore+TS_TILE_ADDR,x
                 sta   USER_TILE_ADDR

                 ldx   #USER_TILE_RECORD                ; pass the direct page offset to the user
                 pei   DP2_TILEDATA_AND_TILESTORE_BANKS ; set the bank to the tiledata bank
                 plb
_UTDPatch        jsl   UserHook1                        ; Call the users code
                 plb                                    ; Restore the curent bank

; When the user's code returns, it can ask GTE to invoke a utility routine to copy data from the 
; temporary buffer space into the code field

                 cmp  #0
                 beq  :done
;                 jmp  FastCopyTmpDataA                 ; Non-zero value to continue additional work
                 jmp LiteCopyTmpDataA
:done
                 rts

; Stub to have a valid address for initialization / reset
UserHook1        rtl

; Fast utility function to just copy tile data straight from the tmp_tile_data buffer to the code field.  This is only
; used by the user callback, so we can assume knowledge of the values on the direct page.
FastCopyTmpDataA
                 pei   USER_TILE_CODE_PTR+2
                 ldy   USER_TILE_CODE_PTR
                 plb

]line            equ   0
                 lup   8
                 lda   tmp_tile_data+{]line*4}
                 sta:  $0004+{]line*$1000},y
                 lda   tmp_tile_data+{]line*4}+2
                 sta:  $0001+{]line*$1000},y
]line            equ   ]line+1
                 --^
                 plb
                 rts

LiteCopyTmpDataA
                 pei   USER_TILE_CODE_PTR+2
                 ldy   USER_TILE_CODE_PTR
                 plb

]line            equ   0
                 lup   8
                 lda   tmp_tile_data+{]line*4}
                 sta:  $0004+{]line*_LINE_SIZE},y
                 lda   tmp_tile_data+{]line*4}+2
                 sta:  $0001+{]line*_LINE_SIZE},y
]line            equ   ]line+1
                 --^
                 plb
                 rts

; X = Tile Store offset
; Y = Engine Mode Base Table address
; A = Table proc index
;
; see TileProcTables in static/TileStore.s
_SetTileProcs
:tblPtr  equ  blttmp

; Multiple the proc index by 6 to get the correct table entry offset

                 asl
                 sta  :tblPtr
                 asl
                 adc  :tblPtr
                 sta  :tblPtr

; Add this offset to the base table address

                 tya
                 adc  :tblPtr
                 sta  :tblPtr

; Set the pointer to this bank

                 phk
                 phk
                 pla
                 and  #$00FF
                 sta  :tblPtr+2

; Lookup the tile procedures

                 ldy  #0
                 lda  [:tblPtr],y
                 stal K_TS_BASE_TILE_DISP,x

                 ldy  #2
                 lda  [:tblPtr],y
                 stal K_TS_SPRITE_TILE_DISP,x

                 ldy  #4
                 lda  [:tblPtr],y
                 stal K_TS_ONE_SPRITE,x
                 rts

; TileProcTables
;
; Tables of tuples used to populate the K_TS_* dispatch arrays for different combinations. This is
; easier to maintain than a bunch of conditional code.  Each entry holds three addresses.
;
; First address:  Draw a tile directly into the code buffer (no sprites)
; Second address: Draw a tile merged with sprite data from the direct page
; Third address:  Specialize routine to draw a tile merged with one sprite
;
; There are unique tuples of routines for all of the different combinations of tile properties
; and engine modes.  This is an extensive number of combinations, but it simplifies the development
; and maintainence of the rendering subroutines.  Also, the different subroutines can be written
; in any way and can make use of their own subroutines to reduce code size.
;
; Properties:
;
;  [MODE]         ENGINE_MODE: Fast, Dyn, TwoLayer
;  [Z | N]        Is Tile 0? : Yes, No
;  [A | V]        Is VFLIP?  : Yes, No
;  [Over | Under] Priority?  : Yes, No
;
; So eight tuples per engine mode; 24 tuples total.  Table name convention
;
; <MODE><Over|Under><Z|N><A|V>
FastProcs
FastOverZA   dw   ConstTile0Fast,SpriteOver0Fast,OneSpriteFastOver0
FastOverZV   dw   ConstTile0Fast,SpriteOver0Fast,OneSpriteFastOver0
FastOverNA   dw   CopyTileAFast,SpriteOverAFast,OneSpriteFastOverA
FastOverNV   dw   CopyTileVFast,SpriteOverVFast,OneSpriteFastOverV
FastUnderZA  dw   ConstTile0Fast,SpriteUnder0Fast,SpriteUnder0Fast
FastUnderZV  dw   ConstTile0Fast,SpriteUnder0Fast,SpriteUnder0Fast
FastUnderNA  dw   CopyTileAFast,SpriteUnderAFast,OneSpriteFastUnderA
FastUnderNV  dw   CopyTileVFast,SpriteUnderVFast,OneSpriteFastUnderV

; "Lite" procs. For when the engine is in GTE Lite mode.  Different
; stride than the "Fast" procs.
LiteProcs
LiteOverZA   dw   ConstTile0Lite,SpriteOver0Lite,OneSpriteLiteOver0
LiteOverZV   dw   ConstTile0Lite,SpriteOver0Lite,OneSpriteLiteOver0
LiteOverNA   dw   CopyTileALite,SpriteOverALite,OneSpriteLiteOverA
LiteOverNV   dw   CopyTileVLite,SpriteOverVLite,OneSpriteLiteOverV
LiteUnderZA  dw   ConstTile0Lite,SpriteUnder0Lite,SpriteUnder0Lite
LiteUnderZV  dw   ConstTile0Lite,SpriteUnder0Lite,SpriteUnder0Lite
LiteUnderNA  dw   CopyTileALite,SpriteUnderALite,OneSpriteLiteUnderA
LiteUnderNV  dw   CopyTileVLite,SpriteUnderVLite,OneSpriteLiteUnderV

; "Slow" procs.  These are duplicates of the "Fast" functions, but also
; set the PEA opcode in all cases.
SlowProcs
SlowOverZA   dw   ConstTile0Slow,SpriteOver0Slow,OneSpriteSlowOver0
SlowOverZV   dw   ConstTile0Slow,SpriteOver0Slow,OneSpriteSlowOver0
SlowOverNA   dw   CopyTileASlow,SpriteOverASlow,OneSpriteSlowOverA
SlowOverNV   dw   CopyTileVSlow,SpriteOverVSlow,OneSpriteSlowOverV
SlowUnderZA  dw   ConstTile0Slow,SpriteUnder0Slow,SpriteUnder0Slow
SlowUnderZV  dw   ConstTile0Slow,SpriteUnder0Slow,SpriteUnder0Slow
SlowUnderNA  dw   CopyTileASlow,SpriteUnderASlow,OneSpriteSlowUnderA
SlowUnderNV  dw   CopyTileVSlow,SpriteUnderVSlow,OneSpriteSlowUnderV

; "Dynamic" procs. These are the specialized routines for a dynamic tiles
; that does not need to worry about a second background.  Because dynamic
; tiles don't support horizontal or vertical flipping, there are only two 
; sets of procedures: one for Over and one for Under.
DynProcs
DynOver      dw   CopyDynamicTile,DynamicOver,OneSpriteDynamicOver
DynUnder     dw   CopyDynamicTile,DynamicUnder,OneSpriteDynamicUnder

; "Two Layer" procs. These are the most complex procs.  Generally,
; all of these methods are implemented by building up the data
; and mask into the direct page space and then calling a common
; function to create the complex code fragments in the code field.
; There is not a lot of opportuinity to optimize these routines.
;
; To improve the performance when two-layer rendering is enabled,
; the TILE_SOLID_BIT hint bit can be set to indicate that a tile
; has no transparency.  This allows one of the faster routines
; to be selected from the other Proc tables
;
; FUTURE: An optimization that can be done is to have the snippets
; code layout fixed based on the EngineFlags and then the Two Layer
; routines should only need to update the DATA and MASK operands in
; the snippet at a fixed location rather than rebuild the ~20 bytes
; of data.
TwoLyrProcs
TwoLyrOverZA   dw   Tile0TwoLyr,SpriteOver0TwoLyr,OneSpriteOver0TwoLyr
TwoLyrOverZV   dw   Tile0TwoLyr,SpriteOver0TwoLyr,OneSpriteOver0TwoLyr
TwoLyrOverNA   dw   CopyTileATwoLyr,SpriteOverATwoLyr,OneSpriteTwoLyrOverA
TwoLyrOverNV   dw   CopyTileVTwoLyr,SpriteOverVTwoLyr,OneSpriteTwoLyrOverV
TwoLyrUnderZA  dw   Tile0TwoLyr,SpriteOver0TwoLyr,OneSpriteOver0TwoLyr   ; if sprites are over or under the transparent tile, same rendering code
TwoLyrUnderZV  dw   Tile0TwoLyr,SpriteOver0TwoLyr,OneSpriteOver0TwoLyr
TwoLyrUnderNA  dw   CopyTileATwoLyr,SpriteUnderATwoLyr,OneSpriteTwoLyrUnderA
TwoLyrUnderNV  dw   CopyTileVTwoLyr,SpriteUnderVTwoLyr,OneSpriteTwoLyrUnderV

; "Dynamic" procs that can handle the second background.
TwoLyrDynProcs
TwoLyrDynOver  dw   CopyDynamicTileTwoLyr,DynamicOverTwoLyr,OneSpriteDynamicOverTwoLyr
TwoLyrDynUnder dw   CopyDynamicTileTwoLyr,DynamicUnderTwoLyr,OneSpriteDynamicUnderTwoLyr

; "Dirty" procs that are for dirty tile direct rendering.  No moving background.
DirtyProcs
DirtyOverZA   dw   ConstTile0Dirty,SpriteOver0Dirty,OneSpriteDirtyOver0
DirtyOverZV   dw   ConstTile0Dirty,SpriteOver0Dirty,OneSpriteDirtyOver0
DirtyOverNA   dw   CopyTileADirty,SpriteOverADirty,OneSpriteDirtyOverA
DirtyOverNV   dw   CopyTileVDirty,SpriteOverVDirty,OneSpriteDirtyOverV
DirtyUnderZA  dw   ConstTile0Dirty,SpriteUnder0Dirty,SpriteUnder0Dirty
DirtyUnderZV  dw   ConstTile0Dirty,SpriteUnder0Dirty,SpriteUnder0Dirty
DirtyUnderNA  dw   CopyTileADirty,SpriteUnderADirty,OneSpriteDirtyUnderA
DirtyUnderNV  dw   CopyTileVDirty,SpriteUnderVDirty,OneSpriteDirtyUnderV

; SetBG0XPos
;
; Set the virtual horizontal position of the primary background layer.  In addition to 
; updating the direct page state locations, this routine needs to preserve the original
; value as well.  This is a bit subtle, because if this routine is called multiple times
; with different values, we need to make sure the *original* value is preserved and not
; continuously overwrite it.
;
; We assume that there is a clean code field in this routine
_SetBG0XPos
                    cmp   StartX
                    beq   :out                       ; Easy, if nothing changed, then nothing changes

                    ldx   StartX                     ; Load the old value (but don't save it yet)
                    sta   StartX                     ; Save the new position

                    lda   #DIRTY_BIT_BG0_X
                    tsb   DirtyBits                  ; Check if the value is already dirty, if so exit
                    bne   :out                       ; without overwriting the original value

                    stx   OldStartX                  ; First change, so preserve the value
:out                rts


; SetBG0YPos
;
; Set the virtual position of the primary background layer.
_SetBG0YPos
                     cmp   StartY
                     beq   :out                 ; Easy, if nothing changed, then nothing changes

                     ldx   StartY               ; Load the old value (but don't save it yet)
                     sta   StartY               ; Save the new position

                     lda   #DIRTY_BIT_BG0_Y
                     tsb   DirtyBits            ; Check if the value is already dirty, if so exit
                     bne   :out                 ; without overwriting the original value

                     stx   OldStartY            ; First change, so preserve the value
:out                 rts

; Macro helper for the bit test tree
;           dobit   bit_position,dest;next;exit
dobit       mac
            lsr
            bcc   next_bit
            beq   last_bit
            tax
            lda   (SPRITE_VBUFF_PTR+{]1*2}),y       ; The carry is always set
;            clc
            adc   _Sprites+TS_VBUFF_BASE+{]1*2}     ; [!! INTERLOCK !!] The table is pre-decremented in Sprite2.s
            sta   sprite_ptr0+{]2*4}
            txa
            jmp   ]3
last_bit    lda   (SPRITE_VBUFF_PTR+{]1*2}),y
;            clc    ; pre-adjust these later
            adc   _Sprites+TS_VBUFF_BASE+{]1*2}
            sta   sprite_ptr0+{]2*4}
            jmp   ]4
next_bit
            <<<

; Specialization for the first sprite which can optimize its dispatch if its the only one
;           dobit   bit_position,dest;next;exit
dobit1      mac
            lsr
            bcc   next_bit
            beq   last_bit
            tax
            lda   (SPRITE_VBUFF_PTR+{]1*2}),y
;            clc
            adc   _Sprites+TS_VBUFF_BASE+{]1*2}
            sta   sprite_ptr0+{]2*4}
            txa
            jmp   ]3
last_bit    lda   (SPRITE_VBUFF_PTR+{]1*2}),y
;            clc    ; pre-adjust these later
            adc   _Sprites+TS_VBUFF_BASE+{]1*2}
            sta   sprite_ptr0+{]2*4}
            tyx
            jmp   (K_TS_ONE_SPRITE,x)
next_bit
            <<<

; If we find a last bit (4th in this case) and will exit
stpbit      mac
            lsr
            bcc   next_bit
            lda   (SPRITE_VBUFF_PTR+{]1*2}),y
;            clc    ; pre-adjust these later
            adc   _Sprites+TS_VBUFF_BASE+{]1*2}
            sta   sprite_ptr0+{]2*4}
            jmp   ]3
next_bit
            <<<

; Last bit test which *must* be set
endbit      mac
            lda   (SPRITE_VBUFF_PTR+{]1*2}),y
;            clc    ; pre-adjust these later
            adc   _Sprites+TS_VBUFF_BASE+{]1*2}
            sta   sprite_ptr0+{]2*4}
            jmp   ]3
            <<<

endbit1     mac
            lda   (SPRITE_VBUFF_PTR+{]1*2}),y
;            clc    ; pre-adjust these later
            adc   _Sprites+TS_VBUFF_BASE+{]1*2}
            sta   sprite_ptr0+{]2*4}
            tyx
            jmp   (K_TS_ONE_SPRITE,x)
            <<<

; OPTIMIZATION:
;
;           bit     #$00FF                    ; Skip the first 8 bits if they are all zeros
;           bne     norm_entry
;           xba
;           jmp     skip_entry
;
; Placed at the entry point

; This is a complex, but fast subroutine that is called from the core tile rendering code.  It
; Takes a bitmap of sprites in the Accumulator and then extracts the VBuff addresses for the
; target TileStore entry and places them in specific direct page locations.
;
; Inputs:
;  A = sprite bitmap (assumed to be non-zero)
;  Y = tile store index
;  D = second work page
;  B = vbuff array bank
; Output:
;  X = 
;
; ]1 address of single sprite process
; ]2 address of two sprite process
; ]3 address of three sprite process
; ]4 address of four sprite process

SpriteBitsToVBuffAddrs mac
           dobit1  0;0;b_1_1
           dobit1  1;0;b_2_1
           dobit1  2;0;b_3_1
           dobit1  3;0;b_4_1
           dobit1  4;0;b_5_1
           dobit1  5;0;b_6_1
           dobit1  6;0;b_7_1
           dobit1  7;0;b_8_1
           dobit1  8;0;b_9_1
           dobit1  9;0;b_10_1
           dobit1  10;0;b_11_1
           dobit1  11;0;b_12_1
           dobit1  12;0;b_13_1
           dobit1  13;0;b_14_1
           dobit1  14;0;b_15_1
           endbit1 15;0

b_1_1      dobit  1;1;b_2_2;]2
b_2_1      dobit  2;1;b_3_2;]2
b_3_1      dobit  3;1;b_4_2;]2
b_4_1      dobit  4;1;b_5_2;]2
b_5_1      dobit  5;1;b_6_2;]2
b_6_1      dobit  6;1;b_7_2;]2
b_7_1      dobit  7;1;b_8_2;]2
b_8_1      dobit  8;1;b_9_2;]2
b_9_1      dobit  9;1;b_10_2;]2
b_10_1     dobit  10;1;b_11_2;]2
b_11_1     dobit  11;1;b_12_2;]2
b_12_1     dobit  12;1;b_13_2;]2
b_13_1     dobit  13;1;b_14_2;]2
b_14_1     dobit  14;1;b_15_2;]2
b_15_1     endbit 15;1;]2

b_2_2      dobit  2;2;b_3_3;]3
b_3_2      dobit  3;2;b_4_3;]3
b_4_2      dobit  4;2;b_5_3;]3
b_5_2      dobit  5;2;b_6_3;]3
b_6_2      dobit  6;2;b_7_3;]3
b_7_2      dobit  7;2;b_8_3;]3
b_8_2      dobit  8;2;b_9_3;]3
b_9_2      dobit  9;2;b_10_3;]3
b_10_2     dobit  10;2;b_11_3;]3
b_11_2     dobit  11;2;b_12_3;]3
b_12_2     dobit  12;2;b_13_3;]3
b_13_2     dobit  13;2;b_14_3;]3
b_14_2     dobit  14;2;b_15_3;]3
b_15_2     endbit 15;2;]3

b_3_3      stpbit 3;3;]4
b_4_3      stpbit 4;3;]4
b_5_3      stpbit 5;3;]4
b_6_3      stpbit 6;3;]4
b_7_3      stpbit 7;3;]4
b_8_3      stpbit 8;3;]4
b_9_3      stpbit 9;3;]4
b_10_3     stpbit 10;3;]4
b_11_3     stpbit 11;3;]4
b_12_3     stpbit 12;3;]4
b_13_3     stpbit 13;3;]4
b_14_3     stpbit 14;3;]4
b_15_3     endbit 15;3;]4
           <<<

; Store some tables in the K bank that will be used exclusively for jmp (abs,x) dispatch

K_TS_BASE_TILE_DISP   ds TILE_STORE_SIZE      ; draw the tile without a sprite
;K_TS_COPY_TILE_DATA   ds TILE_STORE_SIZE      ; copy/merge the tile into temp storage
K_TS_SPRITE_TILE_DISP ds TILE_STORE_SIZE      ; select the sprite routine for this tile
K_TS_ONE_SPRITE       ds TILE_STORE_SIZE      ; specialized sprite routine when only one sprite covers the tile
;K_TS_APPLY_TILE_DATA  ds TILE_STORE_SIZE      ; move tile from temp storage into code field