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
           bpl    :loop1

           ldx    #$FFFE
           lda    #$FFFF
:loop2     stal   spritemask,x
           dex
           dex
           bpl    :loop2

           rts


; This function looks at the sprite list and renders the sprite plane data into the appropriate
; tiles in the code field
_RenderSprites
            ldx   #0
:loop       lda   _Sprites+SPRITE_STATUS,x
            beq   :out
            cmp    #SPRITE_STATUS_DIRTY
            beq   :render
:next       inx
            inx
            bra   :loop
:out        rts

; This is the complicated part; we need to draw the sprite into the sprite place, but then
; calculate the code field tiles that this sprite potentially overlaps with and mark those
; tiles as dirty.
:render
            phx                                       ; stash the X register
            jsr   _DrawTileSprite                     ; draw the sprite into the sprite plane

            stz   tmp0                                ; flags to mark if the sprite is aligned to the code field grid or not
            stz   tmp1

            lda   _Sprites+SPRITE_X,x                 ; Will need some special handling for X < 0
            clc
            adc   StartXMod164

            bit   #$0003                              ; If the botton bit are zero, then we're aligned
            beq   *+4
            inc   tmp0

            cmp   #164
            bcc   *+5
            sbc   #164
            lsr
            lsr
            pha                                       ; Save the tile column

            lda   _Sprites+SPRITE_Y,x
            clc
            adc   StartYMod208

            bit   #$0007
            beq   *+4
            inc   tmp1

            cmp   #208
            bcc   *+5
            sbc   #208
            lsr
            lsr
            lsr

; Mark the tile as dirty

            tay
            plx
            jsr   _GetTileStoreOffset    ; Get the tile store value
            jsr   _PushDirtyTile         ; Enqueue for processing (Returns offset in Y-register)

            lda   #TILE_SPRITE_BIT       ; Mark this tile as having a sprite, regardless of whether it was already enqueued
            sta   TileStore+TS_SPRITE_FLAG,y

; TODO: Mark adjacent tiles as dirty based on tmp0 and tmp1 values

            plx                          ; Restore the X register
            brl   :next

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
            bne   :draw                          ; The first open slot is the end of the list
            rts

:draw       cmp   #SPRITE_STATUS_DIRTY
            bne   :loop

            jsr   _DrawTileSprite
            bra   :loop

_DrawTileSprite 
            phx                                  ; preserve the x register

; Copy the tile data + mask into the sprite plane
            lda   _Sprites+VBUFF_ADDR,x          ; Load the address in the sprite plane
            ldy   _Sprites+TILE_DATA_OFFSET,x
            tax

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
            plx
            rts

; Erase is easy -- set an 8x8 area of the data region to all $0000 and the corresponding mask
; resgion to all $FFFF
; 
; A = sprite ID
SPRITE_PLANE_SPAN equ 256

_EraseSprite
            asl
            tay
            ldx   _Sprites+VBUFF_ADDR,y

            phb

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
            phx                                 ; Save the horizontal position
            tax                                 ; Get the sprite index

            lda   #SPRITE_STATUS_DIRTY          ; Position is changing, mark as dirty
            sta   _Sprites+SPRITE_STATUS,x      ; Mark this sprite slot as occupied and that it needs to be drawn

            tya
            clc
            adc   #NUM_BUFF_LINES               ; The virtual buffer has 24 lines of off-screen space
            xba                                 ; Each virtual scan line is 256 bytes wide for overdraw space
            clc
            adc   1,s                           ; Add the horizontal position
            sta   _Sprites+VBUFF_ADDR,x

            pla                                 ; Pop off the saved value
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
SPRITE_REC_SIZE equ 10

SPRITE_STATUS_EMPTY equ 0
SPRITE_STATUS_CLEAN equ 1
SPRITE_STATUS_DIRTY equ 2

SPRITE_STATUS equ 0
TILE_DATA_OFFSET equ {MAX_SPRITES*2}
VBUFF_ADDR equ {MAX_SPRITES*4}
SPRITE_X equ {MAX_SPRITES*6}
SPRITE_Y equ {MAX_SPRITES*8}

_Sprites     ds  SPRITE_REC_SIZE*MAX_SPRITES
