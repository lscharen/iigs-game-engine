; External entrypoint to render a tile directly into the code field
RenderTile

; If there are no sprites, then we copy the tile data into the code field as fast as possible.
; If there are sprites, then additional work is required
_RenderTile
            lda   TileStore+TS_SPRITE_FLAG,x       ; any sprites on this tile?
            bne   _HasSprites
            jmp   (K_TS_BASE_TILE_DISP,x)          ; go to the tile copy routine

; Probably best to rework this to just jump to the tile routine directly, even if there
; is some boilerplate code because it is useful to be able to access the data bank before
; switching to the code field bank.

            lda   TileStore+TS_CODE_ADDR_HIGH,x    ; load the bank of the target code field line
            pha                                    ; and put on the stack for later. Has TileStore bank in high byte.
            ldy   TileStore+TS_CODE_ADDR_LOW,x     ; load the address of the code field
            lda   TileStore+TS_TILE_ADDR,x         ; load the address of this tile's data (pre-calculated)
            plb                                    ; set the code field bank
            jmp   (K_TS_BASE_TILE_DISP,x)          ; go to the tile copy routine

; This is the specialized renderer for the dirty tile rendering mode. The difference is that
; it is assumed that the screen is static and the tiles are aligned with the graphics screen.
; The engine must be in "Fast" tile mode for dirty tile rendering to work.  It is possible
; to switch the engine into this mode by rendering a full screen of solid tiles and then
; doing a dirty tile rendering.
;
; The main result is that this renderer skips copying tile data into the play field and
; just draws to the screen directly, and only draws tiles in the dirty tile queue
_RenderDirtyTile
            lda   TileStore+TS_SPRITE_FLAG,x       ; any sprites on this tile?
            bne   _HasSprites
            jmp   (K_TS_BASE_TILE_DISP,x)          ; This is just to select between H/V flips

; Execute the sprite tree.  If there is only one sprite, control will immediately be passed to
; the routine at K_TS_ONE_SPRITE.  Otherwise, the control is passed to a routine based on the
; different number of sprites.  These routines need to copy the flattened sprite data and mask
; into the direct page workspace to be used by the K_TS_SPRITE_TILE_DISP routine
_HasSprites txy
            SpriteBitsToVBuffAddrs $0000;TwoSprites;ThreeSprites;FourSprites

; Dispatch vectors for the two, three and four sprite functions.  These just
; flatten the sprite data into the direct page workspace and then pass control
; to the configurable routine which is set in SetTile and knows what to do
; based on the tile properties (over/under, engine mode, etc.)
;
; NOTE: Could pull the CopyXXXSprites function inline and save the 3 cycles for the JMP,
;       - or - put the TYX into the macro and jump directly from there.
TwoSprites  tyx
            jmp   CopyTwoSpritesDataAndMaskToDP

ThreeSprites tyx
            jmp   CopyThreeSpritesDataAndMaskToDP

FourSprites tyx
            jmp   CopyFourSpritesDataAndMaskToDP
