<h1 align="center">
  <img src="https://raw.githubusercontent.com/lscharen/iigs-game-engine/master/.github/images/GTE_Logo.jpg" width="512px"/><br/>
  Generic Tile Engine for the Apple IIgs
</h1>
<p align="center">A <b>high-performance</b> library for writing <b>tile-based</b> games for the Apple IIgs personal computer in 65816 assembly langugage.  Unlock the full, 16-bit potential of the last machine of the Apple ][ line.</p>

# Introduction

The Generic Tile Engine (GTE) project is a tile engine built to exploit the unique hardware capabilities of the Apple IIgs personal computer.  It supports the Apple IIgs super hires graphics mode (320x200, 16/256 colors) and provides two full-screen independent scrolling layers along with software sprites.  The API and core functionality of the library is inspired by the graphics hardware of the NES/SMS/SNES/Genesis console era.

<p align="center">
  <img src="https://raw.githubusercontent.com/lscharen/iigs-game-engine/master/.github/images/armada.gif"/><br/>
  Parallax scrolling of two full-screen static layers
</p>

# Building from Source

The library iscurrently implemented as a set of source files that must be compiled into a GS/OS application.  A set of example project can be found under the `demos` folder.  Each demo folder uses a `package.json` file to define the build targets and a build of each application can be created by executing a `npm run build` command.

Each demo application has a build script that also builds the toolset and copies it, along with the demo S16 application file, to the target disk image.

## Dependencies

GTE uses the [merlin32](https://brutaldeluxe.fr/products/crossdevtools/merlin/) assembler to compile its source into GS/OS OMF files and [Cadius](https://brutaldeluxe.fr/products/crossdevtools/cadius/index.html) to copy those files onto a ProDOS disk image. The paths to these tool can be set in the `package.json` file.

An empty 2MG disk image is included in `emu/Target.2mg` and is used as the default location for copying demo applications.  This image can be mounted in any IIgs emulator.

<p align="center">
  <img src="https://raw.githubusercontent.com/lscharen/iigs-game-engine/master/.github/images/finder.png"/><br/>
  Build of demo app in the IIgs Finder
</p>


# Documentation

Please refer to the <a href="https://lscharen.github.io/iigs-game-engine/toolboxref.html">GTE Toolbox documentation</a>.

# References

* [Apple IIgs Tech Note #70: Fast Graphics Hints](http://www.1000bit.it/support/manuali/apple/technotes/iigs/tn.iigs.070.html)
* [Super Merryo Trolls](http://garote.bdmonkeys.net/merryo_trolls/)
* [Coding Secrets of Wolfenstein IIgs](https://www.kansasfest.org/wp-content/uploads/2004-sheppy-wolf3d.pdf)
* [Apple IIgs Graphics and Sound College](https://www.kansasfest.org/wp-content/uploads/1992-heineman-gs.pdf)
* [John Brooks' Fast GS graphics notes](https://groups.google.com/g/comp.sys.apple2/c/6HWlRPkuuDY/m/NNc1msmmCwAJ)
* [Adaptive Tile Refresh](https://en.wikipedia.org/wiki/Adaptive_tile_refresh)
* [A Guide to the Graphics of the Sega Mega Drive / Genesis](https://rasterscroll.com/mdgraphics/)
* [Jon Burton / Traveller's Tales / Coding Secrets](https://ttjontt.wixsite.com/gamehut/coding-secrets)
* [Lou's Pseudo 3d Page](http://www.extentofthejam.com/pseudo/)
* [A Great Old-Timey Game-Programming Hack](https://blog.moertel.com/posts/2013-12-14-great-old-timey-game-programming-hack.html)
