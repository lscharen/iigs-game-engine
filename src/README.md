= Rendering Pipeline =

The engine run through the following render loop on every frame

1. Lock in any changes to the play field scroll position
1. Erase/Redraw dirty sprites into the sprite plane
   - If a sprite has moved a different amount than the scroll position, it's marked dirty
   - If a sprite was just added on this frame, it's marked dirty
   - Any sprite that overlaps a dirty sprite is marked as impacted
   - All dirty sprites are erased from the sprite plane
   - All dirty and impacted sprites are drawn into the sprite plane
   - All of the play field tiles that intersect dirty sprites are marked as dirty with the sprite flag set
1. If a scroll map is defined
   - Calculate the new regions of the screen that have been scrolled into view
   - For each new tile
      - Copy the tile descriptor from the tile map into the tile store
      - Mark the tile as dirty
1. For each dirty tile
   - Load the tile descriptor from the tile store
   - Dispatch to the appropriate tile renderer
   - Clear the tile dirty flag
1. If any Masked Overlays are defined
   - Turn off shadowing
   - Draw the play field on the Overlay rows
   - Turn on shadowing
1. In top-to-bottom order
   - Draw any Maksed Overlays
   - Draw any Opaque Overlays
   - Draw any play field rows

*NOTES*

* The dirty tile list has a fast test to see if a tile has already been marked as dirty it is not added twice
* The tile renderer is where data from the sprite plane is combined with tile data to show the sprites on-screen.
* Typically, there will not be Overlays defined and the last step of the renderer is just a single render of all playfield lines at once.

= Sprite Redesign =

In the rendering function, for a given TileStore location, we need to be able to read and array of VBUFF addresses
for sprite data.  This can be done by processing the SPRITE_BIT array in to a list to get a set of offsets.  These
VBUFF addresses also need to be set.  Currently we are calculating the addresses in the sprite functions, but the
issue is that we need to find an addressing scheme that's essentially 2D because we have >TileStore+VARNAME,x and 
Sprite+VARNAME,y, but we need something like >TileStore+VARNAME[x][y]

In a perfect scenario, we can use the following code sequence to render stacked sprites

   lda   tiledata,y         ; tile addressed (bank register set)
   ldx   activeSprite+4     ; sprite VBUFF address cached on direct page
   andl  >spritemask,x
   oral  >spritedata,x
   ldx   activeSprite+2
   andl  >spritemask,x
   oral  >spritedata,x
   ldx   activeSprite
   andl  >spritemask,x
   oral  >spritedata,x
   sta   tmp0


; Core phases

; Convert bit field to compact array of sprite indexes
   lda   TileStore+VBUFF_ARR_PTR,x
   sta   cache
   lda   TileStore+SPRITE_BITS,x
   bit   #$0008
   bne   ...

   lda   cache                          ; This is 11 cycles.  A PEA + TSB is 13, so a bit faster to do it at once
   ora   #$0006
   pha

; When storing for a sprite, the corner VBUFF is calulated and stored at
  
  base = TileStore+VBUFF_ARR_ADDR,x + SPRITE_ID

  sta base
  sta base+32 ; next column (mod columns)
  sta base+(32*width) ; next row
  sta base+(32*width+32) ; next corner

Possibilities

1. Have >TileStore+SPRITE_VBUFF be the address to an array and then manually add the y-register value so we can still use
   absolute addressing

   tya
   adc  >TileStore+SPRITE_VBUFF_ARR_ADDR,x   ; Points to addreses 32 bytes apart ad Y-reg is [0, 30]
   tax
   lda  >TileStore,x                         ; Load the address
   tay

   lda  0000,y
   lda  0002,y
   ...

= HOWTO: Custom tiles =

   pea  #^MyTileRenderer         ; Define the callback function
   pea  #MyTileRenderer
   _GTESetCustomTileCallback

   pea  0                        ; Put tiles with the TILE_USER_BIT set
   pea  0
   pea  TILE_ID+TILE_USER_BIT
   _GTESetTile

; On entry
;
; A = Tile Id. Use this to select what to draw
; Y = Address of tile in the code field
; X = Tile Store array offset
; B = code field bank
;
; Use absolute addressing to fill in the code bank and address offsets $0000, $0003, $1000, $1003, ..., $7000, $7003. If
; code needs to create snippets, it can be loaded from the tile store array by using the address returned from 
; GTEGetAddress(tileStoreJmpAddr)
;
; User-defined tiles are always marked as damaged.

MyTileRenderer
   lda   #00A3                   ; Inserts LDA 00,s / PHA code to show a static background from Bank 0
   sta:  $0000,y
   sta:  $0003,y
   sta:  $1000,y
   sta:  $1003,y
   ...
   lda   #$4800
   sta:  $0001,y
   sta:  $0004,y
   sta:  $1001,y
   sta:  $1004,y
   ...
   rtl                           ; Must do a long return
 