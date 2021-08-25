* Tool Locator macros
*   by Dave Klimas
;
; Copyright Apple Computer, Inc. 1986, 1987
; and Roger Wagner Publishing, Inc. 1988
; All Rights Reserved
;
_TLBootInit         MAC
                    Tool  $101
                    <<<
_TLStartUp          MAC
                    Tool  $201
                    <<<
_TLShutDown         MAC
                    Tool  $301
                    <<<
~TLVersion          MAC
                    PHA
_TLVersion          MAC
                    Tool  $401
                    <<<
_TLReset            MAC
                    Tool  $501
                    <<<
~TLStatus           MAC
                    PHA
_TLStatus           MAC
                    Tool  $601
                    <<<
~GetTSPtr           MAC
                    PHS   2
                    PxW   ]1;]2
_GetTSPtr           MAC
                    Tool  $901
                    <<<
~SetTSPtr           MAC
                    PxW   ]1;]2
                    PHL   ]3
_SetTSPtr           MAC
                    Tool  $A01
                    <<<
~GetFuncPtr         MAC
                    PHS   2
                    PxW   ]1;]2
_GetFuncPtr         MAC
                    Tool  $B01
                    <<<
~GetWAP             MAC
                    PHS   2
                    PxW   ]1;]2
_GetWAP             MAC
                    Tool  $C01
                    <<<
~SetWAP             MAC
                    PxW   ]1;]2
                    PHL   ]3
_SetWAP             MAC
                    Tool  $D01
                    <<<
~LoadTools          MAC
                    PHL   ]1
_LoadTools          MAC
                    Tool  $E01
                    <<<
~LoadOneTool        MAC
                    PxW   ]1;]2
_LoadOneTool        MAC
                    Tool  $F01
                    <<<
~UnloadOneTool      MAC
                    PHW   ]1
_UnloadOneTool      MAC
                    Tool  $1001
                    <<<
~TLMountVolume      MAC
                    PHA
                    PxW   ]1;]2
                    PxL   ]3;]4;]5;]6
_TLMountVolume      MAC
                    Tool  $1101
                    <<<
~TLTextMountVolume  MAC
                    PHA
                    PxL   ]1;]2;]3;]4
_TLTextMountVolume  MAC
                    Tool  $1201
                    <<<
~SaveTextState      MAC
                    PHS   2
_SaveTextState      MAC
                    Tool  $1301
                    <<<
~RestoreTextState   MAC
                    PHL   ]1
_RestoreTextState   MAC
                    Tool  $1401
                    <<<
~MessageCenter      MAC
                    PxW   ]1;]2
                    PHL   ]3
_MessageCenter      MAC
                    Tool  $1501
                    <<<
_SetDefaultTPT      MAC
                    Tool  $1601
                    <<<
~MessageByName      MAC
                    PHS   2
                    PHWL  ]1;]2
                    PxW   ]3;]4
_MessageByName      MAC
                    Tool  $1701
                    <<<
~StartUpTools       MAC
                    PHA
                    PxW   ]1;]2
                    PxL   ]3;]4
_StartUpTools       MAC
                    Tool  $1801
                    <<<
~ShutDownTools      MAC
                    PHWL  ]1;]2
_ShutDownTools      MAC
                    Tool  $1901
                    <<<
_GetMsgHandle       MAC
                    Tool  $1A01
                    <<<
_AcceptRequests     MAC
                    Tool  $1B01
                    <<<
_SendRequest        MAC
                    Tool  $1C01
                    <<<

