#include <loader.h>
#include <locator.h>
#include <memory.h>
#include <misctool.h>
#include <types.h>

/* #define GTE_IS_SYSTEM_TOOLS_INSTALL 1 */
#include "gte.h"

#ifdef GTE_IS_SYSTEM_TOOLS_INSTALL
#define ENGINE_STARTUP_MODE 0x0000
#else
#define ENGINE_STARTUP_MODE ENGINE_MODE_USER_TOOL
#endif

/* toolbox fail handler */
#define TOOLFAIL(string) if (toolerror()) SysFailMgr(toolerror(), "\p" string "\n\r    Error Code -> $");

/* path to the local GTE toolset */
Str32 toolPath = {9, "1/Tool160" };

/* Helper function to load GTE as a user tool or system tool */
#ifdef GTE_IS_SYSTEM_TOOLS_INSTALL
void LoadGTEToolSet(Word unused) {
  LoadOneTool(160, 0);
  TOOLFAIL("Unable to load GTE toolset");
}
#else
void LoadGTEToolSet(Word userId) {
  InitialLoadOutputRec loadRec;

  // Load the tool from the local directory
  loadRec = InitialLoad(userId, (Pointer) (&toolPath), 1);
  TOOLFAIL("Unable to load Tool160 from local path");

  // Install the tool using the user tool vector
  SetTSPtr(0x8000, 160, loadRec.startAddr);
  TOOLFAIL("Could not install tool");
}
#endif // GTE_IS_SYSTEM_TOOLS_INSTALL

#ifdef GTE_IS_SYSTEM_TOOLS_INSTALL
void UnloadGTEToolSet() {
  UnloadOneTool(160);
  TOOLFAIL("Unable to unload GTE toolset");
}
#else
void UnloadGTEToolSet() {
}
#endif // GTE_IS_SYSTEM_TOOLS_INSTALL

extern Byte tiles[];
extern Word tilesPalette[16];

void main(void) {
    Word userId;
    Word tileId;
    Word controlMask, keyPress;
    Handle dpHandle;
    Word   dpAddr;
    int a, b;

    TLStartUp();
    TOOLFAIL("Unable to start tool locator");

    userId = MMStartUp();
    TOOLFAIL("Unable to start memory manager");

    MTStartUp();
    TOOLFAIL("Unable to start misc tools");

    LoadGTEToolSet(userId);

    dpHandle = NewHandle(0x200L, userId, attrBank + attrPage + attrFixed + attrLocked + attrNoCross, 0);
    TOOLFAIL("Could not allocate direct page memory for GTE");
    dpAddr = (Word) (*dpHandle);

    GTEStartUp(dpAddr, (Word) ENGINE_STARTUP_MODE, userId);

    /* GTESetScreenMode(160, 200);  /* 160x200 is the default screen mode */
    GTESetPalette(0, (Pointer)tilesPalette);
    GTELoadTileSet(0, 50, tiles);   /* Load in 50 tiles */

    GTEFillTileStore(1);
    GTERender(0);

    for (a = 3; a < 18; a++) {
        GTESetTile(5, a, a);
    }
    GTESetTile(1, 0, 34);
    GTESetTile(2, 0, 33);
    GTERender(0);

    GTESetTile(0, 3, 3);
    GTESetTile(0, 4, 4);
    for (b = 4; b < 6; b++) {
        for (a = 1; a < 10; a++) {
            GTESetBG0Origin(a, b);
            tileId = (((b - 1) * 10) + a) | TILE_SOLID_BIT | TILE_HFLIP_BIT;
            GTESetTile(a, b, tileId);
            GTERender(0);
        }
    }

    do {
        controlMask = GTEReadControl();
        keyPress = controlMask & 0x007F;
    } while (keyPress != 'Q');

    GTEShutDown();
    UnloadGTEToolSet();

    DisposeHandle(dpHandle);
    MTShutDown();
    MMShutDown(userId);
    TLShutDown();
}
