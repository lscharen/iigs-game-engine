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

# Setting up the play field

Once the engine is initialized, the play field must be set up.  The play field defines a rectangular area of the physical graphics screen that is managed by the Tile Engine.

The size of the play field can be set directly by passing the width and height in the `x` and `y` registers.  Also, there are 9 predefined[^1] screen sizes that correspond to well-known Apple IIgs software titles and hardware of the era which can be selected by the `x` register argument.

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

[^1]: Table of predefined `SetScreenMode` sizes 
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
# API



GTE provides the following capabilities

# References

* [Apple IIgs Tech Note #70: Fast Graphics Hints](http://www.1000bit.it/support/manuali/apple/technotes/iigs/tn.iigs.070.html)
* [Super Merryo Trolls](http://garote.bdmonkeys.net/merryo_trolls/)
* [Coding Secrets of Wolfenstein IIgs](https://www.kansasfest.org/wp-content/uploads/2004-sheppy-wolf3d.pdf)
* [Apple IIgs Graphics and Sound College](https://www.kansasfest.org/wp-content/uploads/1992-heineman-gs.pdf)