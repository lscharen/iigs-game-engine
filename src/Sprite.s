; Functions for sprie handling.  Mostly maintains the sprite list and provides
; utility functions to calculate sprite/tile intersections
;
; The sprite plane actually covers two banks so that more than 32K can be used as a virtual 
; screen buffer.  In order to be able to draw sprites offscreen, the virtual screen must be 
; wider and taller than the physical graphics screen.
;
; Initialize the sprite plane data and mask banks (all data = $0000, all masks = $FFFF)
InitSprites
           ldx    #$FFFE
           lda    #0
:loop1     stal   spritedata,x
           dex
           dex
           cpx    #$FFFE
           bne    :loop1

           ldx    #$FFFE
           lda    #$FFFF
:loop2     stal   spritemask,x
           dex
           dex
           cpx    #$FFFE
           bne    :loop2

           rts


; This function looks at the sprite list and renders the sprite plane data into the appropriate
; tiles in the code field
_RenderSprites
            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x
            beq   :out
;            cmp   #SPRITE_STATUS_DIRTY
;            beq   :render
            bra   :render
:next       inx
            inx
            bra   :loop
:out        rts

; This is the complicated part; we need to draw the sprite into the sprite plane, but then
; calculate the code field tiles that this sprite potentially overlaps with and mark those
; tiles as dirty and store the appropriate sprite plane address that those tiles need to copy
; from.
:render
            stx   tmp0                                ; stash the X register

            txy
            ldx   _Sprites+OLD_VBUFF_ADDR,y   
            jsr   _EraseTileSprite                    ; erase from the old position

            ldx   _Sprites+VBUFF_ADDR,y
            lda   _Sprites+TILE_DATA_OFFSET,y
            tay
            jsr   _DrawTileSprite                     ; draw the sprite into the sprite plane
            ldx   tmp0

            ldy   #0                                  ; flags to mark if the sprite is aligned to the code field grid or not

            lda   _Sprites+SPRITE_X,x                 ; Will need some special handling for X < 0
            sta   tmp3

            clc
            adc   StartXMod164

            bit   #$0003                              ; If the botton bit are zero, then we're aligned
            beq   :aligned_x
            ldy   #4
:aligned_x

            cmp   #164
            bcc   *+5
            sbc   #164
            lsr
            lsr
            pha                                       ; Save the tile column

            lda   _Sprites+SPRITE_Y,x
            sta   tmp2

            clc
            adc   StartYMod208

            bit   #$0007
            beq   :aligned_y
            iny
            iny
:aligned_y

            cmp   #208
            bcc   *+5
            sbc   #208
            lsr
            lsr
            lsr

            tyx                                   ; stash the alignment in the x register for dispatch
            jmp   (:mark_dirty,x)
; :mark_dirty  dw   :corner,:column,:row,:square
:mark_dirty  dw   :corner,:corner,:corner,:corner

; Just mark the square with the sprite as dirty
:corner     tay
            plx
            jsr   _MarkAsDirty
            ldx   tmp0
            brl   :next

; Mark the left column (x, y) and (x, y+1) as dirty
:column     tay
            plx 
            jsr   _MarkAsDirty

            iny
            cpy   #26
            bcc   *+5
            ldy   #0
            lda   tmp2
            clc
            adc   #8
            sta   tmp2

            jsr   _MarkAsDirty
            ldx   tmp0
            brl   :next

; Mark the top row (x, y) and (x+1, y) as dirty
:row        tay
            plx 
            jsr   _MarkAsDirty

            inx
            cpx   #41
            bcc   *+5
            ldx   #0
            lda   tmp3
            clc
            adc   #4
            sta   tmp3


            jsr   _MarkAsDirty
            ldx   tmp0
            brl   :next

; Mark all four squares as dirty
:square     tay
            lda   1,s
            tax
            jsr   _MarkAsDirty

            inx
            cpx   #41
            bcc   *+5
            ldx   #0
            lda   tmp3
            clc
            adc   #4
            sta   tmp3

            jsr   _MarkAsDirty

            iny
            cpy   #26
            bcc   *+5
            ldy   #0
            lda   tmp2
            clc
            adc   #8
            sta   tmp2

            jsr   _MarkAsDirty

            plx
            lda   tmp3
            sec
            sbc   #4
            sta   tmp3

            jsr   _MarkAsDirty
            ldx   tmp0
            brl   :next

_MarkAsDirty
            phx
            phy

            jsr   _GetTileStoreOffset             ; Get the tile store value
            jsr   _PushDirtyTile                  ; Enqueue for processing (Returns offset in Y-register)

            lda   TileStore+TS_SPRITE_FLAG,y      ; If this tile has already been flagged on this frame, avoid recalculating the address
            beq   :early_out

            lda   #TILE_SPRITE_BIT                ; Mark this tile as having a sprite, regardless of whether it was already enqueued
            sta   TileStore+TS_SPRITE_FLAG,y

            jsr   _SetSpriteAddr

:early_out
            ply
            plx
            rts

; Set the TileStore+TS_SPRITE_ADDR for tile that a sprite is on.
;
; To calculate the sprite plane coordinate for this tile column.  We really just have to compensate
; for the StartXMod164 mod 4 value, so the final value is (SPRITE_X + (StartXMod164 mod 4)) & 0xFFFC
; for the horizontal and (SPRITE_Y + (StartYMod208 mod 8)) & 0xFFF8
;
; The final address is (Y + NUM_BUFF_LINES) * 256 + X
;
; tmp2 = sprite Y coordinate
; tmp3 = sprite X coordinate
; Y = tile record index
_SetSpriteAddr
            lda   StartYMod208
            and   #$0007
            clc
            adc   tmp2
            and   #$00F8
            clc
            adc   #NUM_BUFF_LINES
            xba
            sta   tmp4

            lda   StartXMod164
            and   #$0003
            clc
            adc   tmp3
            and   #$00FC
            clc
            adc   tmp4
            sta   TileStore+TS_SPRITE_ADDR,y

            rts

; _GetTileAt
;
; Given a relative playfield coordinate [0, ScreenWidth), [0, ScreenHeight) return the
;  X = horizontal point [0, ScreenTileWidth]
;  Y = vertical point [0, ScreenTileHeight]
;
; Return 
;  C = 1, out of range
;  C = 0, X = column, Y = row
_GetTileAt
            cpx   ScreenWidth
            bcc   *+3
            rts

            cpy   ScreenHeight
            bcc   *+3
            rts

            tya                           ; carry is clear here
            adc   StartYMod208            ; This is the code field line that is at the top of the screen
            cmp   #208
            bcc   *+5
            sbc   #208

            lsr
            lsr
            lsr
            tay                           ; This is the code field row for this point

            clc
            txa
            adc   StartXMod164
            cmp   #164
            bcc   *+5
            sbc   #164

            lsr
            lsr
            tax                           ; Could call _CopyBG0Tile with these arguments

            clc
            rts

; _DrawSprite
;
; Draw the sprites on the _Sprite list into the Sprite Plane data and mask buffers. This is using the 
; tile data right now, but could be replaced with compiled sprite routines.
_DrawSprites
            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x
            beq   :out                          ; The first open slot is the end of the list
            cmp   #SPRITE_STATUS_DIRTY
            bne   :skip

            phx

            lda   _Sprites+VBUFF_ADDR,x          ; Load the address in the sprite plane
            ldy   _Sprites+TILE_DATA_OFFSET,x    ; Load the address in the tile data bank
            tax
            jsr   _DrawTileSprite
            plx
:skip
            inx
            inx
            bra   :loop
:out        rts

DrawTileSprite ENT
            jsr   _DrawTileSprite
            rtl

_DrawTileSprite 
            phb
            pea   #^tiledata                     ; Set the bank to the tile data
            plb

]line       equ   0
            lup   8
            lda:  tiledata+32+{]line*4},y
            andl  spritemask+{]line*256},x
            stal  spritemask+{]line*256},x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN},x
            and:  tiledata+32+{]line*4},y
            ora:  tiledata+{]line*4},y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN},x

            lda:  tiledata+32+{]line*4}+2,y
            andl  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            stal  spritemask+{]line*SPRITE_PLANE_SPAN}+2,x
            
            ldal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
            and:  tiledata+32+{]line*4}+2,y
            ora:  tiledata+{]line*4}+2,y
            stal  spritedata+{]line*SPRITE_PLANE_SPAN}+2,x
]line       equ   ]line+1
            --^

            plb                                  ; pop extra byte
            plb
            rts

; Erase is easy -- set an 8x8 area of the data region to all $0000 and the corresponding mask
; resgion to all $FFFF
; 
; X = address is sprite plane -- erases an 8x8 region
SPRITE_PLANE_SPAN equ 256

EraseTileSprite ENT
            jsr    _EraseTileSprite
            rtl

_EraseTileSprite
            phb                                   ; Save the bank to switch to the sprite plane

            pea    #^spritedata
            plb

            lda    #0
            sta:   {0*SPRITE_PLANE_SPAN}+0,x
            sta:   {0*SPRITE_PLANE_SPAN}+2,x
            sta:   {1*SPRITE_PLANE_SPAN}+0,x
            sta:   {1*SPRITE_PLANE_SPAN}+2,x
            sta:   {2*SPRITE_PLANE_SPAN}+0,x
            sta:   {2*SPRITE_PLANE_SPAN}+2,x
            sta:   {3*SPRITE_PLANE_SPAN}+0,x
            sta:   {3*SPRITE_PLANE_SPAN}+2,x
            sta:   {4*SPRITE_PLANE_SPAN}+0,x
            sta:   {4*SPRITE_PLANE_SPAN}+2,x
            sta:   {5*SPRITE_PLANE_SPAN}+0,x
            sta:   {5*SPRITE_PLANE_SPAN}+2,x
            sta:   {6*SPRITE_PLANE_SPAN}+0,x
            sta:   {6*SPRITE_PLANE_SPAN}+2,x
            sta:   {7*SPRITE_PLANE_SPAN}+0,x
            sta:   {7*SPRITE_PLANE_SPAN}+2,x

            pea    #^spritemask
            plb

            lda    #$FFFF
            sta:   {0*SPRITE_PLANE_SPAN}+0,x
            sta:   {0*SPRITE_PLANE_SPAN}+2,x
            sta:   {1*SPRITE_PLANE_SPAN}+0,x
            sta:   {1*SPRITE_PLANE_SPAN}+2,x
            sta:   {2*SPRITE_PLANE_SPAN}+0,x
            sta:   {2*SPRITE_PLANE_SPAN}+2,x
            sta:   {3*SPRITE_PLANE_SPAN}+0,x
            sta:   {3*SPRITE_PLANE_SPAN}+2,x
            sta:   {4*SPRITE_PLANE_SPAN}+0,x
            sta:   {4*SPRITE_PLANE_SPAN}+2,x
            sta:   {5*SPRITE_PLANE_SPAN}+0,x
            sta:   {5*SPRITE_PLANE_SPAN}+2,x
            sta:   {6*SPRITE_PLANE_SPAN}+0,x
            sta:   {6*SPRITE_PLANE_SPAN}+2,x
            sta:   {7*SPRITE_PLANE_SPAN}+0,x
            sta:   {7*SPRITE_PLANE_SPAN}+2,x

            pla
            plb
            rts

; Add a new sprite to the rendering pipeline
;
; A = tileId
; X = x position
; Y = y position
AddSprite   ENT
            phb
            phk
            plb
            jsr    _AddSprite
            plb
            rtl

_AddSprite
            phx                                  ; Save the horizontal position and tile ID
            pha

            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x       ; Look for an open slot
            beq   :open
            inx
            inx
            cpx   #MAX_SPRITES*2
            bcc   :loop

            pla                    ; Early out
            pla
            sec                    ; Signal that no sprite slot was available
            rts

:open       lda   #SPRITE_STATUS_DIRTY
            sta   _Sprites+SPRITE_STATUS,x      ; Mark this sprite slot as occupied and that it needs to be drawn
            pla
            jsr   _GetTileAddr
            sta   _Sprites+TILE_DATA_OFFSET,x

            tya
            clc
            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
            clc
            adc   1,s                           ; Add the horizontal position
            sta   _Sprites+VBUFF_ADDR,x

            pla                                 ; Pop off the saved value
            clc                                 ; Mark that the sprite was successfully added
            txa                                 ; And return the sprite ID
            rts

; X = x coordinate
; Y = y coordinate
GetSpriteVBuffAddr ENT
            tya
            clc
            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
            phx
            clc
            adc   1,s
            plx
            rtl

; Move a sprite to a new location.  If the tile ID of the sprite needs to be changed, then
; a full remove/add cycle needs to happen
;
; A = sprite ID
; X = x position
; Y = y position
UpdateSprite ENT
            phb
            phk
            plb
            jsr    _UpdateSprite
            plb
            rtl

_UpdateSprite
            cmp   #MAX_SPRITES*2                ; Make sure we're in bounds
            bcc   :ok
            rts

:ok
            stx   tmp0                          ; Save the horizontal position
            and   #$FFFE                        ; Defensive
            tax                                 ; Get the sprite index

            lda   #SPRITE_STATUS_DIRTY          ; Position is changing, mark as dirty
            sta   _Sprites+SPRITE_STATUS,x      ; Mark this sprite slot as occupied and that it needs to be drawn

            lda   _Sprites+VBUFF_ADDR,x         ; Save the previous draw location for erasing
            sta   _Sprites+OLD_VBUFF_ADDR,x

            lda   tmp0                          ; Update the X coordinate
            sta   _Sprites+SPRITE_X,x

            tya                                 ; Update the Y coordinate
            sta   _Sprites+SPRITE_Y,x

            clc
            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
            clc
            adc   tmp0                          ; Add the horizontal position
            sta   _Sprites+VBUFF_ADDR,x

            rts

; Sprite data structures.  We cache quite a few pieces of information about the sprite
; to make calculations faster, so this is hidden from the caller.
;
; Each sprite record contains the following properties:
;
; +0: Sprite status word (0 = unoccupied)
; +2: Tile data address
; +4: Screen offset address (used for data and masks)

; Number of "off-screen" lines above logical (0,0)
NUM_BUFF_LINES equ 24

MAX_SPRITES  equ 64
SPRITE_REC_SIZE equ 12

SPRITE_STATUS_EMPTY equ 0
SPRITE_STATUS_CLEAN equ 1
SPRITE_STATUS_DIRTY equ 2

SPRITE_STATUS equ 0
TILE_DATA_OFFSET equ {MAX_SPRITES*2}
VBUFF_ADDR equ {MAX_SPRITES*4}
SPRITE_X equ {MAX_SPRITES*6}
SPRITE_Y equ {MAX_SPRITES*8}
OLD_VBUFF_ADDR equ {MAX_SPRITES*10}

_Sprites     ds  SPRITE_REC_SIZE*MAX_SPRITES
