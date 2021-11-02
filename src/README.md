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