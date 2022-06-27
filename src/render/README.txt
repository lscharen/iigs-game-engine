This folder contains the rendering tuples for the different type of tile rendering modes
that are defined by both the engine mode and the specific tile attributes.  There are
a *lot* or variants, so they are cataloged here.

The top-level TileRender function in the main entry point that defined the overal tile render
flow as well as the register parameters and calling conventions for each of the modular 
components.

There are 5 pluggable functions that make up a rendering mode

1. K_TS_BASE_TILE_DISP

   An address to a function that will render a tile into the code field.  There are no
   sprites to handle in this case.

   Arguments:
     A: TileData/TileMask address
     B: code field bank
     Y: address of the tile in the code bank
     X: TileStore offset

   Return:
     None

   If additional TileStore properties are needed for the renderer, they can be read using the X
   register.

2. K_TS_SPRITE_TILE_DISP

   Selects the top-level handler for rendering a tile with a sprite.  Currently, this is used to
   select between rendering a sprite above the tile, or under the tile based on the value of the
   TILE_PRIORITY_BIT.

    Arguments:
     A: TileStore+TS_SPRITE_FLAG
     X: TileStore offset

    Return:
     Y: TileStore offset
     sprite_ptrX dirct page values set to the sprite VBuff addresses

   The handler routine is responsible for examining the TS_SPRITE_FLAG value and dispatching
   to an appropriate routine to handle the number of sprites intersecting the tile.

3. K_TS_ONE_SPRITE

   A specialized routine when K_TS_SPRITE_TILE_DISP determines there is only one sprite to render
   it MUST dispatch to this function.  The K_TS_ONE_SPRITE routine MAY make use of the K_TS_COPY_TILE_DATA
   and K_TS_APPLY_TILE_DATA functions, but is not required to do so.

4. K_TS_COPY_TILE_DATA & K_TS_APPLY_TILE_DATA

   A pair of function that copye tile data (and possible mask information) into a temporary
   direct page space and then render that workspace into the code field.

   These functions are used as building blocks by the generic Over/Under multi-sprite
   rendering code.

   K_TS_COPY_TILE_DATA
     Arguments:
      B: Set to the TileData bank
      Y: Set to the tile address
     Return:
      X: preserve the X register

   K_TS_APPLY_TILE_DATA
     Arguments:
        B: code field bank
        Y: address of the tile in the code bank
     Return:
        None



Generic Flow

  1. Is there a sprite?
     No -> Call K_TS_BASE_TILE_DISP to render a tile into the code field

     Yes -> Call K_TS_SPRITE_TILE_DISP

      Over  : Copy tile data + mask to DP, Copy sprite data + mask to DP, render tile to code field
      Under : Copy sprite data to DP, 