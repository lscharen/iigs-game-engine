; Functions to handle rendering sprites into 8x8 tile buffers for dirty tile rendering.  Because we
; are rendering directly to the graphics screen instead of the code field, we can map the direct
; page into Bank 01 and use that to avoid writing the merge sprite and tile data to an intermediate
; buffer.

;DirtyTileSpriteProcs dw  _TBDirtySpriteTile_00,_TBDirtySpriteTile_0H,_TBDirtySpriteTile_V0,_TBDirtySpriteTile_VH

; Optimization Note: The single-sprite blitter seems like it could be made faster by taking advantage of
;                    the fact that only a single set of sprite data needs to be read, but the extra overhead
;                    of using the direct page and setting up and restoring registers wipes out the 2 cycle
;                    per word advantage.
;
; A = screen address
; X = address of sprite data
; Y = address of tile data
; B = tile data bank

_OneDirtySprite_00
_OneDirtySprite_0H

                 phd
                 sei
                 clc
                 tcd
                 _R0W1

                 _ODS_Line 0,0,$0
                 _ODS_Line 1,1,$A0
                 tdc
                 adc   #320
                 tcd
                 _ODS_Line 2,2,$0
                 _ODS_Line 3,3,$A0
                 tdc
                 adc   #320
                 tcd
                 _ODS_Line 4,4,$0
                 _ODS_Line 5,5,$A0
                 tdc
                 adc   #320
                 tcd
                 _ODS_Line 6,6,$0
                 _ODS_Line 7,7,$A0

                 _R0W0
                 cli
                 pld
                 rts


_OneDirtySprite_V0
_OneDirtySprite_VH
                 phd
                 sei
                 clc
                 tcd
                 _R0W1

                 _ODS_Line 0,7,$0
                 _ODS_Line 1,6,$A0
                 tdc
                 adc   #320
                 tcd
                 _ODS_Line 2,5,$0
                 _ODS_Line 3,4,$A0
                 tdc
                 adc   #320
                 tcd
                 _ODS_Line 4,3,$0
                 _ODS_Line 5,2,$A0
                 tdc
                 adc   #320
                 tcd
                 _ODS_Line 6,1,$0
                 _ODS_Line 7,0,$A0

                 _R0W0
                 cli
                 pld
                 rts


; Build up from here
_FourDirtySprites
                 lda   TileStore+TS_VBUFF_ADDR_0,y
                 sta   spriteIdx
                 lda   TileStore+TS_VBUFF_ADDR_1,y
                 sta   spriteIdx+4
                 lda   TileStore+TS_VBUFF_ADDR_2,y
                 sta   spriteIdx+8
                 lda   TileStore+TS_VBUFF_ADDR_3,y
                 sta   spriteIdx+12