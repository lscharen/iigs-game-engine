* Memory Manager macros
*   by Dave Klimas
;
; Copyright Apple Computer, Inc. 1986, 1987
; and Roger Wagner Publishing, Inc. 1988
; All Rights Reserved
;
_MMBootInit          MAC
                     Tool  $102
                     <<<
~MMStartUp           MAC
                     PHA
_MMStartUp           MAC
                     Tool  $202
                     <<<
~MMShutDown          MAC
                     PHW   ]1
_MMShutDown          MAC
                     Tool  $302
                     <<<
~MMVersion           MAC
                     PHA
_MMVersion           MAC
                     Tool  $402
                     <<<
_MMReset             MAC
                     Tool  $502
                     <<<
~MMStatus            MAC
                     PHA
_MMStatus            MAC
                     Tool  $602
                     <<<
~NewHandle           MAC
                     P2SL  ]1
                     PxW   ]2;]3
                     PHL   ]4
_NewHandle           MAC
                     Tool  $902
                     <<<
~ReallocHandle       MAC
                     PHLW  ]1;]2
                     PHWL  ]3;]4
                     PHL   ]5
_ReallocHandle       MAC
                     Tool  $A02
                     <<<
~RestoreHandle       MAC
                     PHL   ]1
_RestoreHandle       MAC
                     Tool  $B02
                     <<<
~AddToOOMQueue       MAC
                     PHL   ]1
_AddToOOMQueue       MAC
                     Tool  $C02
                     <<<
~DeleteFromOOMQueue  MAC
                     PHL   ]1
_DeleteFromOOMQueue  MAC
                     Tool  $D02
                     <<<
~DisposeHandle       MAC
                     PHL   ]1
_DisposeHandle       MAC
                     Tool  $1002
                     <<<
~DisposeAll          MAC
                     PHW   ]1
_DisposeAll          MAC
                     Tool  $1102
                     <<<
~PurgeHandle         MAC
                     PHL   ]1
_PurgeHandle         MAC
                     Tool  $1202
                     <<<
~PurgeAll            MAC
                     PHW   ]1
_PurgeAll            MAC
                     Tool  $1302
                     <<<
~GetHandleSize       MAC
                     P2SL  ]1
_GetHandleSize       MAC
                     Tool  $1802
                     <<<
~SetHandleSize       MAC
                     PxL   ]1;]2
_SetHandleSize       MAC
                     Tool  $1902
                     <<<
~FindHandle          MAC
                     P2SL  ]1
_FindHandle          MAC
                     Tool  $1A02
                     <<<
~FreeMem             MAC
                     PHS   2
_FreeMem             MAC
                     Tool  $1B02
                     <<<
~MaxBlock            MAC
                     PHS   2
_MaxBlock            MAC
                     Tool  $1C02
                     <<<
~TotalMem            MAC
                     PHS   2
_TotalMem            MAC
                     Tool  $1D02
                     <<<
~CheckHandle         MAC
                     PHL   ]1
_CheckHandle         MAC
                     Tool  $1E02
                     <<<
_CompactMem          MAC
                     Tool  $1F02
                     <<<
~HLock               MAC
                     PHL   ]1
_HLock               MAC
                     Tool  $2002
                     <<<
~HLockAll            MAC
                     PHW   ]1
_HLockAll            MAC
                     Tool  $2102
                     <<<
~HUnlock             MAC
                     PHL   ]1
_HUnlock             MAC
                     Tool  $2202
                     <<<
~HUnlockAll          MAC
                     PHW   ]1
_HUnlockAll          MAC
                     Tool  $2302
                     <<<
~SetPurge            MAC
                     PHWL  ]1;]2
_SetPurge            MAC
                     Tool  $2402
                     <<<
~SetPurgeAll         MAC
                     PxW   ]1;]2
_SetPurgeAll         MAC
                     Tool  $2502
                     <<<
~PtrToHand           MAC
                     PxL   ]1;]2;]3
_PtrToHand           MAC
                     Tool  $2802
                     <<<
~HandToPtr           MAC
                     PxL   ]1;]2;]3
_HandToPtr           MAC
                     Tool  $2902
                     <<<
~HandToHand          MAC
                     PxL   ]1;]2;3
_HandToHand          MAC
                     Tool  $2A02
                     <<<
~BlockMove           MAC
                     PxL   ]1;]2;]3
_BlockMove           MAC
                     Tool  $2B02
                     <<<
~RealFreeMem         MAC
                     PHS   2
_RealFreeMem         MAC
                     Tool  $2F02
                     <<<
_SetHandleID         MAC
                     Tool  $3002
                     <<<

