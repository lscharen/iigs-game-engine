* Misc Tool macros
*   by Dave Klimas
;
; Copyright Apple Computer, Inc. 1986, 1987
; and Roger Wagner Publishing, Inc. 1988
; All Rights Reserved
;
_MTBootInit           MAC
                      Tool  $103
                      <<<
_MTStartUp            MAC
                      Tool  $203
                      <<<
_MTShutDown           MAC
                      Tool  $303
                      <<<
~MTVersion            MAC
                      PHA
_MTVersion            MAC
                      Tool  $403
                      <<<
_MTReset              MAC
                      Tool  $503
                      <<<
~MTStatus             MAC
                      PHA
_MTStatus             MAC
                      Tool  $603
                      <<<
~WriteBRam            MAC
                      PHL   ]1
_WriteBRam            MAC
                      Tool  $903
                      <<<
~ReadBRam             MAC
                      PHL   ]1
_ReadBRam             MAC
                      Tool  $A03
                      <<<
~WriteBParam          MAC
                      PxW   ]1;]2
_WriteBParam          MAC
                      Tool  $B03
                      <<<
~ReadBParam           MAC
                      P1SW  ]1
_ReadBParam           MAC
                      Tool  $C03
                      <<<
~ReadTimeHex          MAC
                      PHS   4
_ReadTimeHex          MAC
                      Tool  $D03
                      <<<
~WriteTimeHex         MAC
                      PxW   ]1;]2;]3
_WriteTimeHex         MAC
                      Tool  $E03
                      <<<
~ReadAsciiTime        MAC
                      PHL   ]1
_ReadAsciiTime        MAC
                      Tool  $F03
                      <<<
~SetVector            MAC
                      PHWL  ]1;]2
_SetVector            MAC
                      Tool  $1003
                      <<<
~GetVector            MAC
                      P2SW  ]1
_GetVector            MAC
                      Tool  $1103
                      <<<
~SetHeartBeat         MAC
                      PHL   ]1
_SetHeartBeat         MAC
                      Tool  $1203
                      <<<
~DelHeartBeat         MAC
                      PHL   ]1
_DelHeartBeat         MAC
                      Tool  $1303
                      <<<
_ClrHeartBeat         MAC
                      Tool  $1403
                      <<<
~SysFailMgr           MAC
                      PHWL  ]1;]2
_SysFailMgr           MAC
                      Tool  $1503
                      <<<
~GetAddr              MAC
                      P2SW  ]1
_GetAddr              MAC
                      Tool  $1603
                      <<<
~ReadMouse            MAC
                      PHS   3
_ReadMouse            MAC
                      Tool  $1703
                      <<<
~InitMouse            MAC
                      PHW   ]1
_InitMouse            MAC
                      Tool  $1803
                      <<<
~SetMouse             MAC
                      PHW   ]1
_SetMouse             MAC
                      Tool  $1903
                      <<<
_HomeMouse            MAC
                      Tool  $1A03
                      <<<
_ClearMouse           MAC
                      Tool  $1B03
                      <<<
~ClampMouse           MAC
                      PxW   ]1;]2;]3;]4
_ClampMouse           MAC
                      Tool  $1C03
                      <<<
~GetMouseClamp        MAC
                      PHS   4
_GetMouseClamp        MAC
                      Tool  $1D03
                      <<<
~PosMouse             MAC
                      PxW   ]1;]2
_PosMouse             MAC
                      Tool  $1E03
                      <<<
~ServeMouse           MAC
                      PHA
_ServeMouse           MAC
                      Tool  $1F03
                      <<<
~GetNewID             MAC
                      P1SW  ]1
_GetNewID             MAC
                      Tool  $2003
                      <<<
~DeleteID             MAC
                      PHW   ]1
_DeleteID             MAC
                      Tool  $2103
                      <<<
~StatusID             MAC
                      PHW   ]1
_StatusID             MAC
                      Tool  $2203
                      <<<
~IntSource            MAC
                      PHW   ]1
_IntSource            MAC
                      Tool  $2303
                      <<<
~FWEntry              MAC
                      PHS   4
                      PxW   ]1;]2;]3;]4
_FWEntry              MAC
                      Tool  $2403
                      <<<
~GetTick              MAC
                      PHS   2
_GetTick              MAC
                      Tool  $2503
                      <<<
~PackBytes            MAC
                      P1SL  ]1
                      PxL   ]2;]3
                      PHW   ]4
_PackBytes            MAC
                      Tool  $2603
                      <<<
~UnPackBytes          MAC
                      P1SL  ]1
                      PHW   ]2
                      PxL   ]3;]4
_UnPackBytes          MAC
                      Tool  $2703
                      <<<
~Munger               MAC
                      P1SL  ]1
                      PxL   ]2;]3
                      PHWL  ]4;]5
                      PHWL  ]6;]7
_Munger               MAC
                      Tool  $2803
                      <<<
~GetIRQEnable         MAC
                      PHA
_GetIRQEnable         MAC
                      Tool  $2903
                      <<<
~SetAbsClamp          MAC
                      PxW   ]1;]2;]3;]4
_SetAbsClamp          MAC
                      Tool  $2A03
                      <<<
~GetAbsClamp          MAC
                      PHS   4
_GetAbsClamp          MAC
                      Tool  $2B03
                      <<<
_SysBeep              MAC
                      Tool  $2C03
                      <<<
~AddToQueue           MAC
                      PxL   ]1;]2
_AddToQueue           MAC
                      Tool  $2E03
                      <<<
~DeleteFromQueue      MAC
                      PxL   ]1;]2
_DeleteFromQueue      MAC
                      Tool  $2F03
                      <<<
~SetInterruptState    MAC
                      PHLW  ]1;]2
_SetInterruptState    MAC
                      Tool  $3003
                      <<<
~GetInterruptState    MAC
                      PHLW  ]1;]2
_GetInterruptState    MAC
                      Tool  $3103
                      <<<
~GetIntStateRecSize   MAC
                      PHA
_GetIntStateRecSize   MAC
                      Tool  $3203
                      <<<
~ReadMouse2           MAC
                      PHS   3
_ReadMouse2           MAC
                      Tool  $3303
                      <<<
~GetCodeResConverter  MAC
                      PHS   2
_GetCodeResConverter  MAC
                      Tool  $3403
                      <<<
_GetROMResource       MAC                ;private
                      Tool  $3503
                      <<<
_ReleaseROMResource   MAC                ;private
                      Tool  $3603
                      <<<
_ConvSeconds          MAC
                      Tool  $3703
                      <<<
_SysBeep2             MAC
                      Tool  $3803
                      <<<
_VersionString        MAC
                      Tool  $3903
                      <<<
_WaitUntil            MAC
                      Tool  $3A03
                      <<<
_StringToText         MAC
                      Tool  $3B03
                      <<<
_ShowBootInfo         MAC
                      Tool  $3C03
                      <<<
_ScanDevices          MAC
                      Tool  $3D03
                      <<<
_AlertMessage         MAC
                      Tool  $3E03
                      <<<
_DoSysPrefs           MAC
                      Tool  $3F03
                      <<<

