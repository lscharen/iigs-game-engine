echo off

REM Copy all of the assets into the ProDOS image for emulator testing
REM
REM Pass the path of the Cadius tool as the first argument (%1)

set CADIUS="%1"
set IMAGE="..\\..\\emu\\Target.2mg"
set FOLDER="/GTEDEV/Sprites"

REM Cadius does not overwrite files, so clear the root folder first
%CADIUS% DELETEFOLDER %IMAGE% %FOLDER%
%CADIUS% CREATEFOLDER %IMAGE% %FOLDER%

REM Now copy files and folders as needed
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\GTETestSprites
%CADIUS% ADDFILE %IMAGE% %FOLDER% ..\..\src\Tool160

REM Copy in the image assets
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\assets\mario1.c1
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\assets\octane.c1
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\assets\pix.forest.c1
%CADIUS% ADDFILE %IMAGE% %FOLDER% .\assets\sunset.c1
