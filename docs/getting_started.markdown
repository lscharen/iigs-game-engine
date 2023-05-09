---
permalink: /getting-started
layout: page
---

# Getting Started
* Set Up
  * Windows
  * Linux
  * Native

This tutorial page will walk through the process of setting up your computer to build Apple IIgs applications
that leverage the GTE toolset.  
## Set Up

### Windows

### Linux

### Native

If you are developing directly on an Apple IIgs machine, dowload the GTE-1.0.shk archive into your GS/OS environment.  There
are several ways of getting the file onto your system.

 1. Use the [NetDisk](https://sheumann.github.io/NetDisk/) utility to mount to the remote disk image directly from GS/OS and copy the Tool160 file
 1. Use [ADTPro](https://adtpro.com/index.html) to transfer the disk image to the apple IIgs and write it onto a physical floppy disk

## Installing GTE

Copy the `Tool160` file into the `System:Tools` folder of your GS/OS boot volume.  It is also possible to load the toolset from the application's folder (or any file system location), which will be covered later.

## Your First Program

```c
#include <loader.h>
#include <locator.h>
#include <memory.h>
#include <misctool.h>
#include <gte.h>

/* create two solid tiles */
extern Byte tiles[] = { STATIC_TILE(0x00), STATIC_TILE(0xFF) };

/* define a couple of key codes for the arrow keys */
#define LEFT_ARROW  0x08
#define RIGHT_ARROW 0x15
#define UP_ARROW    0x0B
#define DOWN_ARROW  0x0A

Word userId;
Handle dpHandle;

void startUp(void) {
    TLStartUp();
    userId = MMStartUp();
    MTStartUp();

    LoadOneTool(160, 0x0100);
    dpHandle = NewHandle(0x200L, userId, attrBank + attrPage + attrFixed + attrLocked + attrNoCross, 0);
    GTEStartUp((Word) *dpHandle, (Word) 0, userId);
}

void shutDown(void) {
    GTEShutDown();
    DisposeHandle(dpHandle);
    UnloadOneTool(160);
    MTShutDown();
    MMShutDown(userId);
    TLShutDown();
}

void main(void) {
    Word keyPress;
    int x, y;

    /* Start up GTE and its dependencies */
    startUp();

    /* Create a 256x160 playfield (128 bytes x 160 lines) */
    GTESetScreenMode(128, 160);

    /* Load in two tiles */
    GTELoadTileSet(0, 2, tiles);

    /* Fill the tile store with a checkerboard pattern */
    for (y = 0; y < GTE_TILE_STORE_HEIGHT; y++) {
        for (x = 0; x < GTE_TILE_STORE_WIDTH; x++) {
            GTESetTile(x, y, (x + y) & 1);
        }
    }

    /* Enter into the main loop */
    x = y = 0;
    do {
        keyPress = GTEReadControl() & PAD_KEY_CODE;

        if (keyPress == LEFT_ARROW && x > 0) x--;
        if (keyPress == RIGHT_ARROW && x < 1000) x++;
        if (keyPress == UP_ARROW && y > 0) y--;
        if (keyPress == DOWN_ARROW && y < 1000) y++;

        /* Position the screen and render */
        GTESetBG0Origin(x, y);
        GTERender(0);
    }
    while (keyPress != 'Q' && keyPress != 'q');

    shutDown();
}
```