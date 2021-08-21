echo off

set MRSPRITE="%1"

mkdir build
copy assets\all-sprites.gif build\all-sprites.gif
%MRSPRITE% EXTRACT build\all-sprites.gif 0026FF FC0204
%MRSPRITE% RENAME build\all-sprites_spr*.gif Ship
%MRSPRITE% CODE build\Ship_*.gif 0026FF 09162A 181425 293C5A 3A455B 5400D9 9C44FF A50989 FC0204 FF00AF FFCA00 FFFFFF
type build\Ship_*.txt > sprites\Ships.s

REM Create a wallpaper and copy that for reference
%MRSPRITE% WALLPAPER build\Ship_*.gif 0026FF FC0204
copy build\Ship_Wall.gif sprites\Ship_Wallpaper.gif
del /q build\*
