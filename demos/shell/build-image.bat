echo off

REM Copy all of the assets into the ProDOS image for emulator testing
REM
REM Pass the path of the Cadius tool as the first argument (%1)

set CADIUS="%1"
set IMAGE="emu\\Target.2mg"
set FOLDER="/GTEDEV/Build"

REM Cadius does not overwrite files, so clear the root folder first
%CADIUS% DELETEFOLDER %IMAGE% %FOLDER%
%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%

REM Now copy files and folders as needed
%CADIUS% ADDFILE %IMAGE% %FOLDER% src\\GTETestApp
%CADIUS% ADDFILE %IMAGE% %FOLDER% emu\\test.pic
%CADIUS% ADDFILE %IMAGE% %FOLDER% emu\\bg1a.bin
%CADIUS% ADDFILE %IMAGE% %FOLDER% emu\\bg1b.bin
%CADIUS% ADDFILE %IMAGE% %FOLDER% emu\\fg1.bin
%CADIUS% ADDFILE %IMAGE% %FOLDER% assets\\music\\main.ntp
