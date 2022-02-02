* Load Manager macros
*   by Dave Klimas
;
; Copyright Apple Computer, Inc. 1986, 1987
; and Roger Wagner Publishing, Inc. 1988
; All Rights Reserved
;
_LoaderInitialization  MAC
                       Tool  $111
                       <<<
_LoaderStartUp         MAC
                       Tool  $211
                       <<<
_LoaderShutDown        MAC
                       Tool  $311
                       <<<
~LoaderVersion         MAC
                       PHA
_LoaderVersion         MAC
                       Tool  $411
                       <<<
_LoaderReset           MAC
                       Tool  $511
                       <<<
~LoaderStatus          MAC
                       PHA
_LoaderStatus          MAC
                       Tool  $611
                       <<<
~InitialLoad           MAC
                       PHS   5
                       PHWL  ]1;]2
                       PHW   ]3
_InitialLoad           MAC
                       Tool  $911
                       <<<
~InitialLoad2          MAC
                       PHS   5
                       PHWL  ]1;]2
                       PxW   ]3;]4
_InitialLoad2          MAC
                       Tool  $2011
                       <<<
~Restart               MAC
                       PHS   5
                       PHW   ]1
_Restart               MAC
                       Tool  $A11
                       <<<
~LoadSegNum            MAC
                       PHS   2
                       PxW   ]1;]2;]3
_LoadSegNum            MAC
                       Tool  $B11
                       <<<
~UnloadSegNum          MAC
                       PxW   ]1;]2;]3
_UnloadSegNum          MAC
                       Tool  $C11
                       <<<
~LoadSegName           MAC
                       PHS   4
                       PHW   ]1
                       PxL   ]2;]3
_LoadSegName           MAC
                       Tool  $D11
                       <<<
~UnloadSeg             MAC
                       PHS   3
                       PHL   ]1
_UnloadSeg             MAC
                       Tool  $E11
                       <<<
~GetLoadSegInfo        MAC
                       PxW   ]1;]2;]3
                       PHL   ]4
_GetLoadSegInfo        MAC
                       Tool  $F11
                       <<<
~GetUserID             MAC
                       P1SL  ]1
_GetUserID             MAC
                       Tool  $1011
                       <<<
~GetUserID2            MAC
                       P1SL  ]1
_GetUserID2            MAC
                       Tool  $2111
                       <<<
~LGetPathname          MAC
                       PHS   2
                       PxW   ]1;]2
_LGetPathname          MAC
                       Tool  $1111
                       <<<
~LGetPathname2         MAC
                       PHS   2
                       PxW   ]1;]2
_LGetPathname2         MAC
                       Tool  $2211
                       <<<
~UserShutDown          MAC
                       PHA
                       PxW   ]1;]2
_UserShutDown          MAC
                       Tool  $1211
                       <<<
~RenamePathname        MAC
                       PxL   ]1;]2
_RenamePathname        MAC
                       Tool  $1311
                       <<<

