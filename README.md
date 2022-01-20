<h1 align="center">
  <img src="https://raw.githubusercontent.com/lscharen/iigs-game-engine/master/.github/images/GTE_Logo.jpg" width="512px"/><br/>
  Generic Tile Engine for the Apple IIgs
</h1>
<p align="center">A <b>high-performance</b> library for writing <b>tile-based</b> games for the Apple IIgs personal computer in 65816 assembly langugage.  Unlock the full, 16-bit potential of the last machine of the Apple ][ line.</p>

# Introduction

The Generic Tile Engine (GTE) project is a tile engine built to exploit the unique hardware capabilities of the Apple IIgs personal computer.  It supports the Apple IIgs super hires graphics mode (320x200, 16/256 colors) and provides two full-screen independent scrolling layers along with software sprites.  The API and core functionality of the library is inspired by the graphics hardware of the NES/SMS/SNES/Genesis console era.

# Getting Started

## Initialization

Starting up GTE only requires a single subroutine call to `GTEStartUp`. This subroutine will take care of starting up the necessary Toolboxes and allocating any necessary memory.  GTE heavily leverages memory for its speed.  A total of 4MB is RAM is recommended, with a 2MB as the minimum.

```asm
; Initialize the graphics engine
        jsl      EngineStartUp
        bcs      exit

; Main code here...

; When finished, shut down the engine

        jsl      EngineShutDown

exit    _QuitGS  qtRec
qtRec   adrl     $0000
        da       $00
```

## Setting up the play field

Once the engine is initialized, the play field must be set up.  The play field defines a rectangular area of the physical graphics screen that is managed by the Tile Engine.

The size of the play field can be set directly by passing the width and height in the `x` and `y` registers.  Also, there are 9 predefined screen sizes that correspond to well-known Apple IIgs software titles and hardware of the era which can be selected by the `x` register argument.

```asm
; Main code here...

        ldx      #WIDTH
        ldy      #HEIGHT
        jsl      SetScreenMode

; Alternatively, pick a predefined size

        ldx      #0                   ; 0 = full screen (320x200)
        jsl      SetScreenMode

; When finished, shut down the engine

        jsl      EngineShutDown
```

By default, the play field will be centered on the graphics screen.  If a custom placement of the play field is desired, then the `SetScreenRect` subroutine can be used directly to set a specific area of the graphics screen as the managed area.

 | Play Field Id | Width | Height |                   | Size (bytes) | Percent of Full Screen |
 |---------------|-------|--------|-------------------|---|----|
 | 0             | 320   | 200    | Full Screen       | 32,000 | 100% |
 | 1             | 272   | 192    | Sword of Sodan    | 26,112 | 81.6% |
 | 2             | 256   | 200    | NES (approx.)     | 25,600 | 80.0% |
 | 3             | 256   | 176    |  Task Force       | 22,528  | 70.4% |
 | 4             | 280   | 160    | Defender of the World | 22,400  | 70.0% |
 | 5             | 256   | 160    | Rastan            | 20,480   | 64.0%  |
 | 6             | 240   | 160    | Game Boy Advanced | 19,200 | 60.0% |
 | 7             | 288   | 128    | Ancient Land of Y's | 18,432 | 57.6% |
 | 8             | 160   | 144    | Game Boy Color    | 11,520 | 36.0% |

## Palettes

A simple `SetPalette` subroutine is provided in order to set any of the IIgs' 16 palettes.

```asm
            ldy      #PALETTE_NUMBER      ; 0 - 15
            lda      #^PaletteData        ; High Word of palette color array
            ldx      #PaletteData
            jsl      SetPalette

PaletteData dw       $0000,$007F,$0090,$0FF0
            dw       $000F,$0080,$0f70,$0FFF
            dw       $0fa9,$0ff0,$00e0,$04DF
            dw       $0d00,$078f,$0ccc,$0FFF
```

## Tilemaps

Up to two tile layers are supported in GTE.  Each layer can have its own tile map and origin set, independent of the other.  This allows for a true parallax scrolling effect.
## Background 0

In order to enable a tile map on the first background, the width, height and pointer to tile data must be set by initializing the appropriate values on the GTE direct page.  The direct page locations are defined in the `Defs.s` file and can be included in an application's main source file.

```asm
        lda   #NUMBER_OF_TILE_COLUMNS  ; Set the tile map dimensions
        sta   TileMapWidth
        lda   #NUMBER_OF_TILE_ROWS
        sta   TileMapHeight
        lda   #TileMapBG0              ; Set the pointer to the tile map data
        sta   TileMapPtr
        lda   #^TileMapBG0
        sta   TileMapPtr+2
```

Once the tile map has been initialized, the camera view into the layer is set by defining the upper-left corner of the screen.  The resolution of the tile map coordinates are byte-aligned, so each tile has a width of 4 and height or 8 even though each tile is 8x8 pixels.

```asm
        lda   #TileMapLeft
        jsl   SetBG0XPos
        lda   #TileMapTop
        jsl   SetBG0YPos
```
## Background 1

The second background is initialized in exactly the same manner as the first background.

```asm
        lda   #NUMBER_OF_TILE_COLUMNS  ; Set the tile map dimensions
        sta   BG1TileMapWidth
        lda   #NUMBER_OF_TILE_ROWS
        sta   BG1TileMapHeight
        lda   #TileMapBG1              ; Set the pointer to the tile map data
        sta   BG1TileMapPtr
        lda   #^TileMapBG0
        sta   BG1TileMapPtr+2

        lda   #TileMapLeft
        jsl   SetBG1XPos
        lda   #TileMapTop
        jsl   SetBG1YPos
```
## Sprites

There are four subroutines that are available to provide sprite support in GTE: `AddSprite`, `MoveSprite`, `UpdateSprite` and `RemoveSprite`.  GTE supports up to 8 sprites.

### Adding a Sprite

```asm
            lda      #SPRITE_FLAGS+SPRITE_TILE_ID
            ldx      #X_POSITION
            ldy      #Y_POSITION
            jsl      AddSprite
            bcs      error                         ; sprite could not be added
            sta      SpriteId                      ; Returns an opaque identifier
```

### Moving a Sprite
```asm
            lda      SpriteId
            ldx      #NEW_X_POSITION
            ldy      #NEW_Y_POSITION
            jsl      MoveSprite
```

### Updating a Sprite
```asm
            lda      SpriteId
            ldx      #NEW_SPRITE_FLAGS_AND_TILE_ID
            jsl      UpdateSprite
```

### Removing a Sprite
```asm
            lda      SpriteId
            jsl      RemoveSprite
```

# Rendering a Frame

There is a single `Render` subroutine that applies all of the frame changes and efficiently renders to the super hires screen.  It bears repeating here that most of the GTE functions operate in a deferred manner; any expensive operation that involved updating internal data structures is delayed until the `Render` function in called.

```asm
            jsl      Render
```

# Advanced Usage
# API

GTE provides the following capabilities

# References

* [Apple IIgs Tech Note #70: Fast Graphics Hints](http://www.1000bit.it/support/manuali/apple/technotes/iigs/tn.iigs.070.html)
* [Super Merryo Trolls](http://garote.bdmonkeys.net/merryo_trolls/)
* [Coding Secrets of Wolfenstein IIgs](https://www.kansasfest.org/wp-content/uploads/2004-sheppy-wolf3d.pdf)
* [Apple IIgs Graphics and Sound College](https://www.kansasfest.org/wp-content/uploads/1992-heineman-gs.pdf)
* [Adaptive Tile Refresh](https://en.wikipedia.org/wiki/Adaptive_tile_refresh)
* [A Guide to the Graphics of the Sega Mega Drive / Genesis](https://rasterscroll.com/mdgraphics/)
* [Jon Burton / Traveller's Tales / Coding Secrets](https://ttjontt.wixsite.com/gamehut/coding-secrets)
* [Lou's Pseudo 3d Page](http://www.extentofthejam.com/pseudo/)