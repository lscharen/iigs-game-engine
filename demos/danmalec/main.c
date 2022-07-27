#include <loader.h>
#include <locator.h>
#include <memory.h>
#include <misctool.h>
#include <types.h>

#include "main.h"
#include "gte_user.h"
#include "demo_data.h"

#define TOOLFAIL(string) if (toolerror()) SysFailMgr(toolerror(), "\p" string "\n\r    Error Code -> $");

typedef struct PString {
  byte length;
  char text[32];
} PString;

PString toolPath = {9, "1/Tool160" };

void LoadGTEToolSet(Word userId) {
  InitialLoadOutputRec loadRec;
  
  // Load the tool from the local directory
  loadRec = InitialLoad(userId, (Pointer) (&toolPath), 1);
  TOOLFAIL("Unable to load Tool160 from local path");

  // Install the tool using the system tool vector
  SetTSPtr(0x8000, 160, loadRec.startAddr);
  TOOLFAIL("Could not install tool");
}

#define SPRITE_SLOT 0
#define SPRITE_VBUFF (GTE_VBUFF_SPRITE_START+0*GTE_VBUFF_SPRITE_STEP)

int main (void) {
  Word controlMask;
  Word keyPress;
  Word userId;
  Handle dpHndl;
  Word dpWord;
  Word x = 0, y = 0;
  Word px = 0, py = 0;
  Word sec, lastSec = 0;

  TLStartUp();
  TOOLFAIL("Unable to start tool locator");

  userId = MMStartUp();
  TOOLFAIL("Unable to start memory manager");

  MTStartUp();
  TOOLFAIL("Unable to start misc tools");

  /* If GTE is installed in System:Tools use this and switch to "gte.h" */
  /*
  LoadOneTool(160, 0);
  TOOLFAIL("Unable to load GTE toolset");
  */

  /* If GTE is installed with the application, use this and "gte_user.h" */
  LoadGTEToolSet(userId);

  dpHndl = NewHandle(0x0200, userId, 0x4015, 0);
  if (dpHndl == NULL) {
    TOOLFAIL("Unable to allocate page 0 memory");
  }
  dpWord = (Word)(*dpHndl);
  if ((dpWord & 0x00FF) != 0x0000) {
    TOOLFAIL("Allocated page 0 memory is not aligned");
  }

  GTEStartUp(dpWord, 0x0000, userId);
  TOOLFAIL("Unable to start GTE");

  GTESetScreenMode(160, 200);
  GTELoadTileSet(tiles);
  GTESetPalette(0, (Pointer)palette);
  GTEFillTileStore(1);

  GTECreateSpriteStamp(GTE_SPRITE_8X8|2, SPRITE_VBUFF);
  GTEAddSprite(SPRITE_SLOT, 0, SPRITE_VBUFF, px, py);

  do {
    controlMask = GTEReadControl();
    keyPress = controlMask & 0x007F;

    switch (keyPress) {
      case 'a': if (x > 0) {
        x--;
        break;
      }
      case 'd': if (x < 1000) {
        x++;
        break;
      }
      case 'w': if (y > 0) {
        y--;
        break;
      }
      case 's': if (y < 1000) {
        y++;
        break;
      }


      case 'j': if (px > 0) {
        px--;
        break;
      }
      case 'l': if (px < 154) {
        px++;
        break;
      }
      case 'i': if (py > 0) {
        py--;
        break;
      }
      case 'k': if (py < 192) {
        py++;
        break;
      }
    }

    sec = GTEGetSeconds();
    if (sec != lastSec) {
      lastSec = sec;
      GTEFillTileStore(1 + (lastSec & 1));
    }
 
    GTESetBG0Origin(x, y);
    GTEMoveSprite(SPRITE_SLOT, px, py);
    GTERender(0);

  } while (keyPress != 'q' && keyPress != 'Q');

  GTEShutDown();

  DisposeHandle(dpHndl);

  MTShutDown();
  TOOLFAIL("Unable to shutdown misc tool");

  MMShutDown(userId);
  TOOLFAIL("Unable to shutdown memory manager");

  TLShutDown();
  TOOLFAIL("Unable to shutdown tool locator");
}