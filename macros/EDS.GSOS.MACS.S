**************************************************
*
* GS/OS Macros
*
* by Eric Shepherd
* Public domain -- distribute freely.
*
* Last updated: May 2, 2015
*
*=================================================
* NOTE: If you find any errors, bugs, or anything
*       missing, PLEASE contact me and point out
*       the error:
*
* Email: sheppy@sheppyware.net
* Web:   http://www.sheppyware.net/
*
**************************************************


_AddNotifyProcGS   mac
                   CallGSOS  $2034;]1
                   <<<

_BeginSessionGS    mac
                   CallGSOS  $201D;]1
                   <<<

_BindIntGS         mac
                   CallGSOS  $2031;]1
                   <<<

_ChangePathGS      mac
                   CallGSOS  $2004;]1
                   <<<

_ClearBackupBitGS  mac
                   CallGSOS  $200B;]1
                   <<<

_CloseGS           mac
                   CallGSOS  $2014;]1
                   <<<

_CreateGS          mac
                   CallGSOS  $2001;]1
                   <<<

_DControlGS        mac
                   CallGSOS  $202E;]1
                   <<<

_DelNotifyProcGS   mac
                   CallGSOS  $2035;]1
                   <<<

_DestroyGS         mac
                   CallGSOS  $2002;]1
                   <<<

_DInfoGS           mac
                   CallGSOS  $202C;]1
                   <<<

_DReadGS           mac
                   CallGSOS  $202F;]1
                   <<<

_DRenameGS         mac
                   CallGSOS  $2036;]1
                   <<<

_DStatusGS         mac
                   CallGSOS  $202D;]1
                   <<<

_DWriteGS          mac
                   CallGSOS  $2030;]1
                   <<<

_EndSessionGS      mac
                   CallGSOS  $201E;]1
                   <<<

_EraseDiskGS       mac
                   CallGSOS  $2025;]1
                   <<<

_ExpandPathGS      mac
                   CallGSOS  $200E;]1
                   <<<

_FlushGS           mac
                   CallGSOS  $2015;]1
                   <<<

_FormatGS          mac
                   CallGSOS  $2024;]1
                   <<<

_FSTSpecificGS     mac
                   CallGSOS  $2033;]1
                   <<<

_GetBootVolGS      mac
                   CallGSOS  $2028;]1
                   <<<

_GetDevNumberGS    mac
                   CallGSOS  $2020;]1
                   <<<

_GetDirEntryGS     mac
                   CallGSOS  $201C;]1
                   <<<

_GetEOFGS          mac
                   CallGSOS  $2019;]1
                   <<<

_GetFileInfoGS     mac
                   CallGSOS  $2006;]1
                   <<<

_GetFSTInfoGS      mac
                   CallGSOS  $202B;]1
                   <<<

_GetLevelGS        mac
                   CallGSOS  $201B;]1
                   <<<

_GetMarkGS         mac
                   CallGSOS  $2017;]1
                   <<<

_GetNameGS         mac
                   CallGSOS  $2027;]1
                   <<<

_GetPrefixGS       mac
                   CallGSOS  $200A;]1
                   <<<

_GetRefInfoGS      mac
                   CallGSOS  $2039;]1
                   <<<

_GetRefNumGS       mac
                   CallGSOS  $2038;]1
                   <<<

_GetStdRefNumGS    mac
                   CallGSOS  $2037;]1
                   <<<

_GetSysPrefsGS     mac
                   CallGSOS  $200F;]1
                   <<<

_GetVersionGS      mac
                   CallGSOS  $202A;]1
                   <<<

_JudgeNameGS       mac
                   CallGSOS  $2007;]1
                   <<<

_NewLineGS         mac
                   CallGSOS  $2011;]1
                   <<<

_NullGS            mac
                   CallGSOS  $200D;]1
                   <<<

_OpenGS            mac
                   CallGSOS  $2010;]1
                   <<<

_OSShutDownGS      mac
                   CallGSOS  $2003;]1
                   <<<

_QuitGS            mac
                   CallGSOS  $2029;]1
                   <<<

_ReadGS            mac
                   CallGSOS  $2012;]1
                   <<<

_ResetCacheGS      mac
                   CallGSOS  $2026;]1
                   <<<

_SessionStatusGS   mac
                   CallGSOS  $201F;]1
                   <<<

_SetEOFGS          mac
                   CallGSOS  $2018;]1
                   <<<

_SetFileInfoGS     mac
                   CallGSOS  $2005;]1
                   <<<

_SetLevelGS        mac
                   CallGSOS  $201A;]1
                   <<<

_SetMarkGS         mac
                   CallGSOS  $2016;]1
                   <<<

_SetPrefixGS       mac
                   CallGSOS  $2009;]1
                   <<<

_SetStdRefNumGS    mac
                   CallGSOS  $203A;]1
                   <<<

_SetSysPrefsGS     mac
                   CallGSOS  $200C;]1
                   <<<

_UnbindIntGS       mac
                   CallGSOS  $2032;]1
                   <<<

_VolumeGS          mac
                   CallGSOS  $2008;]1
                   <<<

_WriteGS           mac
                   CallGSOS  $2013;]1
                   <<<

CallGSOS           mac
                   jsl       $E100A8
                   dw        ]1
                   adrl      ]2
                   <<<

