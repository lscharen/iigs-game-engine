/* ********************************************************************
 
 GTE is copyright Lucas Scharenbroich and licensed under the Apache-2.0
 License.

 The following code is taken from a branch of GTE:
 https://github.com/lscharen/iigs-game-engine/blob/ea72e7939262acb84022c83085d24f35f195f3c2/demos/danmalec/main.c
 
 The contents of this file are a derivite work from GTE intended to
 ease the process of calling GTE / Tool 160 from ORCA/C and are believed
 to be permitted under the terms of the Apache-2.0 License.

 ********************************************************************* */

#include <loader.h>
#include <locator.h>
#include <misctool.h>

#include "gte.h"

Str32 toolPath = {9, "1/Tool160" };

#define TOOLFAIL(string) if (toolerror()) SysFailMgr(toolerror(), "\p" string "\n\r    Error Code -> $");

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
