#include <loader.h>
#include <locator.h>
#include <memory.h>
#include <misctool.h>
#include <types.h>

#include "gte.h"
#include "demo_data.h"

#define TOOLFAIL(string) if (toolerror()) SysFailMgr(toolerror(), "\p" string "\n\r    Error Code -> $");

#define SPRITE_START_TILE 2
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
  Word sec;

  TLStartUp();
  TOOLFAIL("Unable to start tool locator");

  userId = MMStartUp();
  TOOLFAIL("Unable to start memory manager");

  MTStartUp();
  TOOLFAIL("Unable to start misc tools");

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

  GTECreateSpriteStamp(GTE_SPRITE_8X8 | SPRITE_START_TILE, SPRITE_VBUFF);
  GTEAddSprite(SPRITE_SLOT, 0, SPRITE_VBUFF, px, py);

  do {
    controlMask = GTEReadControl();
    keyPress = controlMask & 0x007F;

    switch (keyPress) {
      case ' ':  // Toggle background
        sec = GTEGetSeconds();
        GTEFillTileStore(1 + (sec & 1));
        break;

      case 'a': if (x > 0) { x--; }
        break;
  
      case 'd': if (x < 1000) { x++; }
        break;

      case 'w': if (y > 0) { y--; }
        break;

      case 's': if (y < 1000) { y++; }
        break;


      case 'j': if (px > 0) { px--; }
        break;

      case 'l': if (px < 154) { px++; }
        break;

      case 'i': if (py > 0) { py--; }
        break;

      case 'k': if (py < 192) { py++; }
        break;
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
